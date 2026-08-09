import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/dismissal.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class ScorerLiveMatchRepository {
  final Ref _ref;
  late final ScorerRepository _scorerRepository;
  ScorerMatch? _activeMatch;
  final _controller = StreamController<ScorerMatch?>.broadcast();

  // Snapshot of the pre-ball innings state so that "Undo" can fully restore
  // the striker/non-striker/bowler and the batting/bowling order, not just
  // drop the last ball event.
  final List<_BallUndo> _undoStack = [];

  /// Serializes RTDB live-state writes so a slow earlier payload can never land
  /// AFTER a newer one — the live channel must always reflect the latest ball,
  /// never a stale intermediate state.
  Future<void> _rtdbQueue = Future.value();

  /// Coalesces Firestore persistence during fast scoring. A full match document
  /// is written for the latest state, so skipping intermediate frames loses no
  /// scoring data (the final state always reaches the cloud). Flushed
  /// immediately on status changes, wickets and teardown.
  Timer? _persistDebounce;
  bool _disposed = false;

  ScorerLiveMatchRepository(this._ref) {
    // Captured up front so `dispose()` (which runs while the container is being
    // torn down) can flush the final state without reading from a disposed
    // container.
    _scorerRepository = _ref.read(scorerRepositoryProvider);
  }

  Stream<ScorerMatch?> get stream => _controller.stream;
  ScorerMatch? get activeMatch => _activeMatch;

  static bool _isLive(ScorerMatch m) =>
      m.status == MatchStatus.inProgress || m.status == MatchStatus.live;

  void setActiveMatch(ScorerMatch? match) {
    final switched = match?.id != _activeMatch?.id;
    final previous = _activeMatch;
    _activeMatch = match;
    if (switched) {
      _undoStack.clear();
    }
    _controller.add(match);

    if (match == null) {
      // Scoring stopped: stop the live broadcast and make sure the very last
      // in-memory state is persisted before the scorer navigates away.
      _removeFromRtdb(previous?.id);
      _flushPersist(previous);
      return;
    }

    final wasLive = previous != null && _isLive(previous);
    final isLiveNow = _isLive(match);
    final event = _detectEvent(previous, match);

    // RTDB is the real-time transport: publish the compact live state on every
    // ball (and on status transitions) so all spectators update instantly.
    if (isLiveNow) {
      _publishToRtdb(match, event: event);
    } else if (match.status == MatchStatus.completed) {
      // Publish the final state so the 'complete' event fires (triggering the
      // completion notifications), then drop the live node so RTDB never
      // serves stale live data — Firestore holds the permanent record.
      _publishToRtdb(match, event: event);
      _removeFromRtdb(match.id);
    } else if (wasLive) {
      _removeFromRtdb(match.id);
    }

    // Firestore is the permanent store: persist the latest state (debounced to
    // avoid excessive writes), flushing immediately on transitions/wickets.
    final force = match.status == MatchStatus.completed ||
        (wasLive != isLiveNow) ||
        (event?.type == 'wicket');
    _schedulePersist(match, force: force);
  }

  /// Detects the notification-worthy event represented by this state change
  /// (match start, innings start, a wicket, match completion) plus the generic
  /// ball event.
  LiveMatchEvent? _detectEvent(ScorerMatch? previous, ScorerMatch current) {
    if (current.status == MatchStatus.completed) {
      return LiveMatchEvent(type: 'complete', match: current);
    }
    final wasLive = previous != null && _isLive(previous);
    if (!wasLive && _isLive(current)) {
      return LiveMatchEvent(type: 'start', match: current);
    }
    final inn = current.currentInningsData;
    if (inn != null && inn.balls.isNotEmpty) {
      // 1st / 2nd innings start: the very first ball of that innings.
      final prevInn1 = previous?.innings1;
      if (current.currentInnings == 1 &&
          inn.balls.length == 1 &&
          (prevInn1 == null || prevInn1.balls.isEmpty)) {
        return LiveMatchEvent(type: 'first_innings_start', match: current);
      }
      final prevInn2 = previous?.innings2;
      if (current.currentInnings == 2 &&
          inn.balls.length == 1 &&
          (prevInn2 == null || prevInn2.balls.isEmpty)) {
        return LiveMatchEvent(type: 'second_innings_start', match: current);
      }
      final last = inn.balls.last;
      if (last.isWicket) {
        return LiveMatchEvent(type: 'wicket', match: current, ball: last);
      }
      return LiveMatchEvent(type: 'ball', match: current, ball: last);
    }
    return null;
  }

  /// Writes the compact live payload to RTDB `liveMatches/{matchId}`. The
  /// payload matches the spectator `LiveMatchData` schema (plus team names and
  /// a deduplicated `lastEvent` consumed by the Cloud Function notification
  /// triggers). Writes are serialized so a slow older write can never overwrite
  /// a newer ball.
  void _publishToRtdb(ScorerMatch match, {LiveMatchEvent? event}) {
    if (_disposed) return;
    _rtdbQueue = _rtdbQueue.then((_) async {
      try {
        final payload =
            await buildLiveMatchPayload(match, event: event);
        await _ref
            .read(realtimeDatabaseProvider)
            .updateLiveMatch(match.id, payload);
      } catch (_) {
        // Best-effort: an unavailable RTDB must never break scoring. Firestore
        // persistence below still keeps the permanent record safe.
      }
    });
  }

  void _removeFromRtdb(String? matchId) {
    if (matchId == null || _disposed) return;
    _rtdbQueue = _rtdbQueue.then((_) async {
      try {
        await _ref.read(realtimeDatabaseProvider).deleteLiveMatch(matchId);
      } catch (_) {
        // Best-effort cleanup.
      }
    });
  }

  /// Builds the self-contained live payload that is published to RTDB
  /// `liveMatches/{matchId}` on every ball (and status transition). The payload
  /// matches the spectator `LiveMatchData` schema (plus team names and, when
  /// [event] is provided, a deduplicated `lastEvent` consumed by the Cloud
  /// Function notification triggers).
  ///
  /// It resolves every referenced player (across ALL innings and both XIs)
  /// once, then embeds the resolved names into the live panel, the full
  /// batting/bowling scorecards, the squads and a flat `players` map so
  /// spectators can render real player names and statistics without a
  /// client-side name lookup.
  Future<Map<String, dynamic>> buildLiveMatchPayload(
    ScorerMatch match, {
    LiveMatchEvent? event,
  }) async {
    final scorerRepo = _scorerRepository;
    final t1 = await scorerRepo.getTeam(match.team1Id);
    final t2 = await scorerRepo.getTeam(match.team2Id);
    final inn = match.currentInningsData;

    // Accumulate current striker/bowler figures from ball-by-ball data.
    final batAcc = <String, _BatAccum>{};
    final bowlAcc = <String, _BowlAccum>{};
    for (final ball in inn?.balls ?? const <BallEvent>[]) {
      if (ball.batsmanId.isNotEmpty) {
        final a = batAcc.putIfAbsent(ball.batsmanId, () => _BatAccum());
        if (ball.isLegalBall) {
          a.balls++;
          a.runs += ball.runs;
          if (ball.isBoundary && ball.runs == 4) a.fours++;
          if (ball.isSix) a.sixes++;
        }
      }
      if (ball.bowlerId.isNotEmpty) {
        final b = bowlAcc.putIfAbsent(ball.bowlerId, () => _BowlAccum());
        b.runs += ball.runs +
            (ball.extrasType == ExtrasType.wide ||
                    ball.extrasType == ExtrasType.noBall
                ? ball.extrasRuns
                : 0);
        if (ball.isWicket && ball.dismissal?.type != DismissalType.runOut) {
          b.wickets++;
        }
        if (ball.isLegalBall) b.legalBalls++;
      }
    }

    LiveBatter batter(String? id) {
      final a = batAcc[id] ?? _BatAccum();
      return LiveBatter(
        playerId: id ?? '',
        name: '',
        runs: a.runs,
        balls: a.balls,
        fours: a.fours,
        sixes: a.sixes,
        status: id != null && id == inn?.strikerId ? 'batting' : '',
        onStrike: id != null && id == inn?.strikerId,
      );
    }

    LiveBowler bowler(String? id) {
      final b = bowlAcc[id] ?? _BowlAccum();
      return LiveBowler(
        playerId: id ?? '',
        name: '',
        legalBalls: b.legalBalls,
        maidens: 0,
        runs: b.runs,
        wickets: b.wickets,
        wides: b.wides,
        noBalls: b.noBalls,
        current: id != null && id == inn?.currentBowlerId,
      );
    }

    final legalBalls = inn?.legalBallsDelivered ?? 0;
    final target = match.currentInnings == 2
        ? (match.innings1?.totalRuns ?? 0) + 1
        : null;
    final requiredRunRate = target != null && legalBalls > 0
        ? (target - (inn?.totalRuns ?? 0)) * 6 / legalBalls
        : null;

    final strikerId = inn?.strikerId;
    final nonStrikerId = inn?.nonStrikerId;
    final bowlerId = inn?.currentBowlerId;

    // Self-contained scorecards + squads: resolve every referenced player once
    // so spectators can render real names without a client-side lookup.
    // Names are collected across ALL innings (not just the current one) so the
    // payload can resolve completed innings too, plus both playing XIs and any
    // fielder credited with a dismissal.
    final nameIds = <String>{};
    for (final innings in [
      match.innings1,
      match.innings2,
      match.superOverInnings1,
      match.superOverInnings2,
    ]) {
      if (innings == null) continue;
      if (innings.strikerId != null && innings.strikerId!.isNotEmpty) {
        nameIds.add(innings.strikerId!);
      }
      if (innings.nonStrikerId != null && innings.nonStrikerId!.isNotEmpty) {
        nameIds.add(innings.nonStrikerId!);
      }
      if (innings.currentBowlerId != null &&
          innings.currentBowlerId!.isNotEmpty) {
        nameIds.add(innings.currentBowlerId!);
      }
      nameIds.addAll(innings.battingOrder);
      nameIds.addAll(innings.bowlingOrder);
      for (final ball in innings.balls) {
        if (ball.batsmanId.isNotEmpty) nameIds.add(ball.batsmanId);
        if (ball.bowlerId.isNotEmpty) nameIds.add(ball.bowlerId);
        final f = ball.dismissal?.fielderId;
        if (f != null && f.isNotEmpty) nameIds.add(f);
      }
    }
    nameIds.addAll(match.playingXI1);
    nameIds.addAll(match.playingXI2);

    final players =
        await Future.wait(nameIds.map((id) => scorerRepo.getPlayer(id)));
    final playerMap = <String, String>{};
    for (final p in players) {
      if (p != null) playerMap[p.id] = p.name;
    }
    String resolveName(String? id) => id == null ? '' : (playerMap[id] ?? id);

    final liveData = LiveMatchData(
      status: match.status == MatchStatus.completed ? 'completed' : 'live',
      currentInnings: match.currentInnings,
      battingTeamId: inn?.battingTeamId ?? '',
      bowlingTeamId: inn?.bowlingTeamId ?? '',
      score: LiveMatchScore(
        runs: inn?.totalRuns ?? 0,
        wickets: inn?.wickets ?? 0,
        overs: legalBalls ~/ 6,
        balls: legalBalls % 6,
      ),
      target: target,
      requiredRunRate: requiredRunRate,
      striker: batter(strikerId),
      nonStriker: batter(nonStrikerId),
      currentBowler: bowler(bowlerId),
      thisOverBalls: (inn?.currentOverBalls ?? const <BallEvent>[])
          .map((b) => b.displayLabel)
          .toList(),
      ballHistory: const [],
      lastUpdated: null,
    );

    // Resolve names for the live panel + notifications.
    final strikerName = resolveName(strikerId);
    final nonStrikerName = resolveName(nonStrikerId);
    final bowlerName = resolveName(bowlerId);
    final team1Name = t1?.name ?? match.team1Id;
    final team2Name = t2?.name ?? match.team2Id;

    // Full scorecards + squads make the live payload self-contained.
    final battingCard = inn == null
        ? const <LiveBatter>[]
        : buildBattingScorecard(inn, playerName: resolveName);
    final bowlingCard = inn == null
        ? const <LiveBowler>[]
        : buildBowlingScorecard(inn, playerName: resolveName);
    Map<String, String> squad(List<String> ids) {
      final out = <String, String>{};
      for (final id in ids) {
        out[id] = playerMap[id] ?? id;
      }
      return out;
    }

    final payload = liveData.toJson();
    payload['matchId'] = match.id;
    payload['team1Id'] = match.team1Id;
    payload['team2Id'] = match.team2Id;
    payload['team1Name'] = team1Name;
    payload['team2Name'] = team2Name;
    payload['battingCard'] = battingCard.map((b) => b.toJson()).toList();
    payload['bowlingCard'] = bowlingCard.map((b) => b.toJson()).toList();
    payload['squad1'] = squad(match.playingXI1);
    payload['squad2'] = squad(match.playingXI2);
    // Flat playerId → name map covering every referenced player across ALL
    // innings and both XIs, so spectators can resolve names without any
    // client-side lookup.
    payload['players'] = Map<String, String>.from(playerMap);
    payload['lastUpdated'] = ServerValue.timestamp;
    if (strikerName.isNotEmpty) {
      (payload['striker'] as Map<String, dynamic>)['name'] = strikerName;
    }
    if (nonStrikerName.isNotEmpty) {
      (payload['nonStriker'] as Map<String, dynamic>)['name'] = nonStrikerName;
    }
    if (bowlerName.isNotEmpty) {
      (payload['currentBowler'] as Map<String, dynamic>)['name'] = bowlerName;
    }

    // Recent ball history (last 20) so spectators get ball-by-ball context.
    final balls = inn?.balls ?? const <BallEvent>[];
    final recent = balls.length > 20 ? balls.sublist(balls.length - 20) : balls;
    payload['ballHistory'] = recent.map((b) {
      return LiveBallEvent(
        over: b.overNumber,
        ballInOver: b.ballInOver,
        batsmanId: b.batsmanId,
        bowlerId: b.bowlerId,
        runs: b.runs,
        extraType: b.extrasType == ExtrasType.none ? null : b.extrasType.name,
        wicket: b.isWicket,
        timestamp: b.timestamp.millisecondsSinceEpoch,
      ).toJson();
    }).toList();

    if (event != null) {
      final ball = event.ball;
      final eventId = switch (event.type) {
        'start' => '${match.id}_start',
        'complete' => '${match.id}_complete',
        'first_innings_start' => '${match.id}_first_innings_start',
        'second_innings_start' => '${match.id}_second_innings_start',
        _ => '${match.id}_inn${match.currentInnings}_o${ball?.overNumber}_'
            'b${ball?.ballInOver}_${ball?.timestamp.millisecondsSinceEpoch}',
      };
      final batsmanName = resolveName(ball?.batsmanId);
      final eventBowlerName = resolveName(ball?.bowlerId);
      payload['lastEvent'] = {
        'id': eventId,
        'type': event.type,
        'matchId': match.id,
        'team1Name': team1Name,
        'team2Name': team2Name,
        'over': ball?.overNumber,
        'ballInOver': ball?.ballInOver,
        'runs': ball?.runs,
        'extrasType': ball == null || ball.extrasType == ExtrasType.none
            ? null
            : ball.extrasType.name,
        'isWicket': ball?.isWicket,
        'batsmanId': ball?.batsmanId,
        'batsmanName': batsmanName,
        'bowlerId': ball?.bowlerId,
        'bowlerName': eventBowlerName,
        'score': {
          'runs': inn?.totalRuns ?? 0,
          'wickets': inn?.wickets ?? 0,
        },
        'timestamp': ball?.timestamp.millisecondsSinceEpoch,
      };
    }

    return payload;
  }

  /// Persists the latest in-memory match to Firestore. Debounced during fast
  /// scoring (a full-document set is written, so skipping intermediate frames
  /// loses nothing); forced immediately on status changes, wickets and when
  /// scoring stops/ends.
  void _schedulePersist(ScorerMatch match, {required bool force}) {
    if (force) {
      _persistDebounce?.cancel();
      _persistDebounce = null;
      _flushPersist(match);
      return;
    }
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 800), () {
      if (_disposed) return;
      final current = _activeMatch;
      if (current != null && current.id == match.id) {
        _flushPersist(current);
      }
    });
  }

  void _flushPersist([ScorerMatch? match]) {
    final m = match ?? _activeMatch;
    if (m == null) return;
    // Fire-and-forget; the repository serializes Firestore writes internally so
    // the latest state is always the one that lands.
    _scorerRepository.saveMatch(m);
  }

  /// Returns a copy of [match] with [updatedInnings] written into whichever
  /// slot `currentInnings` refers to (1/2 for the main match, 3/4 for the
  /// super-over decider).
  ScorerMatch _withInnings(ScorerMatch match, Innings updatedInnings) {
    return match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
      superOverInnings1: match.currentInnings == 3
          ? updatedInnings
          : match.superOverInnings1,
      superOverInnings2: match.currentInnings == 4
          ? updatedInnings
          : match.superOverInnings2,
    );
  }

  void recordBall(BallEvent event) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    _undoStack.add(_BallUndo(
      matchId: match.id,
      inningsId: inn.id,
      strikerId: inn.strikerId,
      nonStrikerId: inn.nonStrikerId,
      currentBowlerId: inn.currentBowlerId,
      battingOrder: List<String>.from(inn.battingOrder),
      bowlingOrder: List<String>.from(inn.bowlingOrder),
      retiredHurtBowlerIds: List<String>.from(inn.retiredHurtBowlerIds),
      isComplete: inn.isComplete,
    ));

    final updatedBalls = List<BallEvent>.from(inn.balls)..add(event);
    
    // Auto-swap strike if odd runs (1, 3, 5) were scored off the bat
    String? newStriker = inn.strikerId;
    String? newNonStriker = inn.nonStrikerId;

    if (event.runs % 2 != 0) {
      final temp = newStriker;
      newStriker = newNonStriker;
      newNonStriker = temp;
    }

    // Check if striker was dismissed (and not run out non-striker)
    if (event.isWicket && event.dismissal != null) {
      if (event.dismissal!.batsmanId == newStriker) {
        newStriker = null;
      } else if (event.dismissal!.batsmanId == newNonStriker) {
        newNonStriker = null;
      }
    }

    // Check if over completed (6 legal balls in over)
    final newLegalCount = updatedBalls.where((b) => b.isLegalBall).length;
    final isOverComplete = newLegalCount > 0 && newLegalCount % 6 == 0 && event.isLegalBall;

    if (isOverComplete) {
      // Over finished -> swap strike automatically
      final temp = newStriker;
      newStriker = newNonStriker;
      newNonStriker = temp;
    }

    final updatedInnings = inn.copyWith(
      balls: updatedBalls,
      strikerId: newStriker,
      nonStrikerId: newNonStriker,
    );

    final updatedMatch = _withInnings(match, updatedInnings);

    setActiveMatch(updatedMatch);
  }

  void undoLastBall() {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    // Find and pop the most recent snapshot for this innings.
    _BallUndo? snap;
    for (int i = _undoStack.length - 1; i >= 0; i--) {
      final s = _undoStack[i];
      if (s.matchId == match.id && s.inningsId == inn.id) {
        snap = _undoStack.removeAt(i);
        break;
      }
    }
    if (snap == null || inn.balls.isEmpty) return;

    final updatedBalls = List<BallEvent>.from(inn.balls)..removeLast();

    final updatedInnings = inn.copyWith(
      balls: updatedBalls,
      strikerId: snap.strikerId,
      nonStrikerId: snap.nonStrikerId,
      currentBowlerId: snap.currentBowlerId,
      battingOrder: snap.battingOrder,
      bowlingOrder: snap.bowlingOrder,
      retiredHurtBowlerIds: snap.retiredHurtBowlerIds,
      isComplete: snap.isComplete,
    );
    final updatedMatch = _withInnings(match, updatedInnings);

    setActiveMatch(updatedMatch);
  }

  void swapStrike() {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final updatedInnings = inn.copyWith(
      strikerId: inn.nonStrikerId,
      nonStrikerId: inn.strikerId,
    );

    final updatedMatch = _withInnings(match, updatedInnings);

    setActiveMatch(updatedMatch);
  }

  void setBowler(String bowlerId) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final updatedBowlingOrder = List<String>.from(inn.bowlingOrder);
    if (!updatedBowlingOrder.contains(bowlerId)) {
      updatedBowlingOrder.add(bowlerId);
    }

    final updatedInnings = inn.copyWith(
      currentBowlerId: bowlerId,
      bowlingOrder: updatedBowlingOrder,
    );

    final updatedMatch = _withInnings(match, updatedInnings);

    setActiveMatch(updatedMatch);
  }

  /// Marks a bowler as "retired hurt": they leave the field mid-over and can no
  /// longer bowl in this innings. If they were the current bowler the slot is
  /// cleared so the scorer must pick a replacement before the next ball.
  void retireBowlerHurt(String bowlerId) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final retired = List<String>.from(inn.retiredHurtBowlerIds);
    if (!retired.contains(bowlerId)) {
      retired.add(bowlerId);
    }

    final updatedInnings = inn.copyWith(
      retiredHurtBowlerIds: retired,
      currentBowlerId:
          inn.currentBowlerId == bowlerId ? null : inn.currentBowlerId,
    );

    final updatedMatch = _withInnings(match, updatedInnings);

    setActiveMatch(updatedMatch);
  }

  void setNextBatsman(String batsmanId) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final updatedBattingOrder = List<String>.from(inn.battingOrder);
    if (!updatedBattingOrder.contains(batsmanId)) {
      updatedBattingOrder.add(batsmanId);
    }

    final updatedInnings = inn.copyWith(
      strikerId: inn.strikerId ?? batsmanId,
      nonStrikerId: inn.strikerId == null ? inn.nonStrikerId : (inn.nonStrikerId ?? batsmanId),
      battingOrder: updatedBattingOrder,
    );

    final updatedMatch = _withInnings(match, updatedInnings);

    setActiveMatch(updatedMatch);
  }

  /// Adjusts the number of overs for the match (e.g. mid-innings). Clamped so
  /// the total can never drop below the overs already bowled.
  void setOvers(int overs) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    final minOvers = inn == null
        ? 1
        : (inn.legalBallsDelivered / 6).ceil();
    final clamped = overs.clamp(minOvers, 50).toInt();
    if (clamped == match.overs) return;
    setActiveMatch(match.copyWith(overs: clamped));
  }

  /// Substitutes a player: swaps [playerOutId] for [playerInId] in the team's
  /// playing XI and in any current-innings batting/bowling references.
  void replacePlayer({
    required String teamId,
    required String playerOutId,
    required String playerInId,
  }) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final isTeam1 = teamId == match.team1Id;
    final xi = List<String>.from(isTeam1 ? match.playingXI1 : match.playingXI2);
    final idx = xi.indexOf(playerOutId);
    if (idx == -1) return;
    xi[idx] = playerInId;

    final inn = match.currentInningsData;
    Innings? updatedInn = inn;
    if (inn != null) {
      updatedInn = inn.copyWith(
        battingOrder: inn.battingOrder
            .map((id) => id == playerOutId ? playerInId : id)
            .toList(),
        bowlingOrder: inn.bowlingOrder
            .map((id) => id == playerOutId ? playerInId : id)
            .toList(),
        retiredHurtBowlerIds: inn.retiredHurtBowlerIds
            .map((id) => id == playerOutId ? playerInId : id)
            .toList(),
        strikerId: inn.strikerId == playerOutId ? playerInId : inn.strikerId,
        nonStrikerId: inn.nonStrikerId == playerOutId ? playerInId : inn.nonStrikerId,
        currentBowlerId: inn.currentBowlerId == playerOutId ? playerInId : inn.currentBowlerId,
      );
    }

    final updatedMatch = match.copyWith(
      playingXI1: isTeam1 ? xi : match.playingXI1,
      playingXI2: isTeam1 ? match.playingXI2 : xi,
      innings1: match.currentInnings == 1 ? updatedInn : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInn : match.innings2,
      superOverInnings1:
          match.currentInnings == 3 ? updatedInn : match.superOverInnings1,
      superOverInnings2:
          match.currentInnings == 4 ? updatedInn : match.superOverInnings2,
    );

    setActiveMatch(updatedMatch);
  }

  void switchInnings({
    required String newBattingTeamId,
    required String newBowlingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  }) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;

    final secondInnings = Innings(
      id: 'inn_2',
      battingTeamId: newBattingTeamId,
      bowlingTeamId: newBowlingTeamId,
      inningsNumber: 2,
      balls: const [],
      battingOrder: [strikerId, nonStrikerId],
      bowlingOrder: [bowlerId],
      isComplete: false,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
    );

    final updatedMatch = match.copyWith(
      currentInnings: 2,
      innings2: secondInnings,
      status: MatchStatus.inProgress,
    );

    setActiveMatch(updatedMatch);
  }

  /// Marks the current innings as complete and saves it as a draft.
  /// Does NOT auto-advance to the next innings — the scorer taps a
  /// "Start 2nd Innings" button when ready.
  void completeCurrentInnings() {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null || inn.isComplete) return;

    final updatedInnings = inn.copyWith(isComplete: true);
    final updatedMatch = match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
      superOverInnings1: match.currentInnings == 3
          ? updatedInnings
          : match.superOverInnings1,
      superOverInnings2: match.currentInnings == 4
          ? updatedInnings
          : match.superOverInnings2,
    );

    setActiveMatch(updatedMatch);
  }

  /// Starts a 1-over-per-side super-over decider after a tied match. The first
  /// super-over innings is scored as `currentInnings` 3; the second as 4.
  void startSuperOver({
    required String battingTeamId,
    required String bowlingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  }) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;

    final inn1 = Innings(
      id: 'super_over_1',
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      inningsNumber: 3,
      balls: const [],
      battingOrder: [strikerId, nonStrikerId],
      bowlingOrder: [bowlerId],
      isComplete: false,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
    );

    final updatedMatch = match.copyWith(
      superOverPlayed: true,
      superOverInnings1: inn1,
      superOverInnings2: null,
      currentInnings: 3,
      status: MatchStatus.inProgress,
    );

    setActiveMatch(updatedMatch);
  }

  /// Marks the first super-over innings complete and opens the second one
  /// (`currentInnings` 4) with the provided openers/bowler.
  void completeSuperOverToInnings2({
    required String battingTeamId,
    required String bowlingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  }) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn1 = match.superOverInnings1;

    final inn2 = Innings(
      id: 'super_over_2',
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      inningsNumber: 4,
      balls: const [],
      battingOrder: [strikerId, nonStrikerId],
      bowlingOrder: [bowlerId],
      isComplete: false,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
    );

    final updatedMatch = match.copyWith(
      superOverInnings1: inn1?.copyWith(isComplete: true) ?? inn1,
      superOverInnings2: inn2,
      currentInnings: 4,
    );

    setActiveMatch(updatedMatch);
  }

  /// Restores an in-progress draft match (e.g. after the app was closed
  /// mid-scoring) as the active live match, if none is active.
  Future<void> restoreActiveDraft() async {
    if (_activeMatch != null) return;
    final match = await _ref
        .read(scorerRepositoryProvider)
        .firstInProgressMatch();
    if (match != null) {
      setActiveMatch(match);
    }
  }

  /// Marks the active match as completed (persisting the full result, innings
  /// and ball-by-ball data) and returns the completed match so the caller can
  /// additionally await its persistence before navigating away.
  ScorerMatch? endMatch({
    String? winnerTeamId,
    required String summary,
    String? playerOfTheMatchId,
    String? bestBatsmanId,
    String? bestBowlerId,
    String? playerOfTheMatchPrize,
    String? bestBatsmanPrize,
    String? bestBowlerPrize,
    Map<String, String>? customAwards,
    Map<String, String>? customAwardsPrizes,
  }) {
    if (_activeMatch == null) return null;
    final match = _activeMatch!;

    final updatedMatch = match.copyWith(
      status: MatchStatus.completed,
      winnerTeamId: winnerTeamId,
      resultSummary: summary,
      playerOfTheMatchId: playerOfTheMatchId,
      bestBatsmanId: bestBatsmanId,
      bestBowlerId: bestBowlerId,
      playerOfTheMatchPrize: playerOfTheMatchPrize,
      bestBatsmanPrize: bestBatsmanPrize,
      bestBowlerPrize: bestBowlerPrize,
      customAwards: customAwards ?? match.customAwards,
      customAwardsPrizes: customAwardsPrizes ?? match.customAwardsPrizes,
    );

    setActiveMatch(updatedMatch);
    return updatedMatch;
  }

  void dispose() {
    _disposed = true;
    _persistDebounce?.cancel();
    _persistDebounce = null;
    _flushPersist();
    _controller.close();
  }
}

class _BatAccum {
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
}

class _BowlAccum {
  int legalBalls = 0;
  int runs = 0;
  int wickets = 0;
  int wides = 0;
  int noBalls = 0;
}

/// A scoring state change that is interesting to spectators (match start,
/// innings start, wicket, match completion) or a routine ball delivery.
/// Serialized into the RTDB `lastEvent` field for the notification triggers.
class LiveMatchEvent {
  final String type;
  // 'start' | 'first_innings_start' | 'second_innings_start' | 'ball' |
  // 'wicket' | 'complete'
  final ScorerMatch match;
  final BallEvent? ball;

  const LiveMatchEvent({
    required this.type,
    required this.match,
    this.ball,
  });
}

class _BallUndo {
  final String matchId;
  final String inningsId;
  final String? strikerId;
  final String? nonStrikerId;
  final String? currentBowlerId;
  final List<String> battingOrder;
  final List<String> bowlingOrder;
  final List<String> retiredHurtBowlerIds;
  final bool isComplete;

  const _BallUndo({
    required this.matchId,
    required this.inningsId,
    required this.strikerId,
    required this.nonStrikerId,
    required this.currentBowlerId,
    required this.battingOrder,
    required this.bowlingOrder,
    required this.retiredHurtBowlerIds,
    required this.isComplete,
  });
}

final scorerLiveMatchRepositoryProvider = Provider<ScorerLiveMatchRepository>((ref) {
  final repo = ScorerLiveMatchRepository(ref);
  ref.onDispose(repo.dispose);
  return repo;
});

/// StreamProvider so widgets can reactively read the live match scored by Scorer
final scorerLiveMatchStreamProvider = StreamProvider<ScorerMatch?>((ref) {
  return ref.watch(scorerLiveMatchRepositoryProvider).stream;
});

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class ScorerLiveMatchRepository {
  final Ref _ref;
  ScorerMatch? _activeMatch;
  final _controller = StreamController<ScorerMatch?>.broadcast();

  // Snapshot of the pre-ball innings state so that "Undo" can fully restore
  // the striker/non-striker/bowler and the batting/bowling order, not just
  // drop the last ball event.
  final List<_BallUndo> _undoStack = [];

  ScorerLiveMatchRepository(this._ref);

  Stream<ScorerMatch?> get stream => _controller.stream;
  ScorerMatch? get activeMatch => _activeMatch;

  void setActiveMatch(ScorerMatch? match) {
    final switched = match?.id != _activeMatch?.id;
    _activeMatch = match;
    if (switched) {
      _undoStack.clear();
    }
    _controller.add(match);
    if (match != null) {
      _ref.read(scorerRepositoryProvider).saveMatch(match);
    }
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

  void endMatch({
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
    if (_activeMatch == null) return;
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
  }

  void dispose() => _controller.close();
}

class _BallUndo {
  final String matchId;
  final String inningsId;
  final String? strikerId;
  final String? nonStrikerId;
  final String? currentBowlerId;
  final List<String> battingOrder;
  final List<String> bowlingOrder;
  final bool isComplete;

  const _BallUndo({
    required this.matchId,
    required this.inningsId,
    required this.strikerId,
    required this.nonStrikerId,
    required this.currentBowlerId,
    required this.battingOrder,
    required this.bowlingOrder,
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

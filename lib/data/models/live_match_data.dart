import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/dismissal.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';

class LiveMatchScore {
  final int runs;
  final int wickets;
  final int overs;
  final int balls;

  const LiveMatchScore({
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.balls,
  });

  factory LiveMatchScore.fromJson(Map<dynamic, dynamic>? json) {
    final map = json ?? const <dynamic, dynamic>{};
    return LiveMatchScore(
      runs: (map['runs'] as num?)?.toInt() ?? 0,
      wickets: (map['wickets'] as num?)?.toInt() ?? 0,
      overs: (map['overs'] as num?)?.toInt() ?? 0,
      balls: (map['balls'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'runs': runs,
        'wickets': wickets,
        'overs': overs,
        'balls': balls,
      };

  int get totalBalls => overs * 6 + balls;

  String get oversLabel => '$overs.$balls';
}

class LiveBatter {
  final String playerId;
  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;

  /// Scorecard status for this batter: 'batting', 'not out', 'yet to bat' or
  /// the formatted dismissal text (e.g. 'b X'). Empty for the current-striker
  /// live panel payload.
  final String status;

  /// True when this batter is the current striker (' *' marker on the card).
  final bool onStrike;

  const LiveBatter({
    required this.playerId,
    required this.name,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    this.status = '',
    this.onStrike = false,
  });

  factory LiveBatter.fromJson(Map<dynamic, dynamic>? json) {
    final map = json ?? const <dynamic, dynamic>{};
    return LiveBatter(
      playerId: map['playerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      runs: (map['runs'] as num?)?.toInt() ?? 0,
      balls: (map['balls'] as num?)?.toInt() ?? 0,
      fours: (map['fours'] as num?)?.toInt() ?? 0,
      sixes: (map['sixes'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? '',
      onStrike: map['onStrike'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'runs': runs,
        'balls': balls,
        'fours': fours,
        'sixes': sixes,
        'status': status,
        'onStrike': onStrike,
      };

  double get strikeRate => balls > 0 ? (runs * 100 / balls) : 0;
}

class LiveBowler {
  final String playerId;
  final String name;
  final int legalBalls;
  final int maidens;
  final int runs;
  final int wickets;
  final int wides;
  final int noBalls;

  /// True when this bowler is the current bowler (' *' marker on the card).
  final bool current;

  const LiveBowler({
    required this.playerId,
    required this.name,
    required this.legalBalls,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.wides,
    required this.noBalls,
    this.current = false,
  });

  factory LiveBowler.fromJson(Map<dynamic, dynamic>? json) {
    final map = json ?? const <dynamic, dynamic>{};
    return LiveBowler(
      playerId: map['playerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      legalBalls: (map['legalBalls'] as num?)?.toInt() ?? 0,
      maidens: (map['maidens'] as num?)?.toInt() ?? 0,
      runs: (map['runs'] as num?)?.toInt() ?? 0,
      wickets: (map['wickets'] as num?)?.toInt() ?? 0,
      wides: (map['wides'] as num?)?.toInt() ?? 0,
      noBalls: (map['noBalls'] as num?)?.toInt() ?? 0,
      current: map['current'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'legalBalls': legalBalls,
        'maidens': maidens,
        'runs': runs,
        'wickets': wickets,
        'wides': wides,
        'noBalls': noBalls,
        'current': current,
      };

  String get oversLabel => '${legalBalls ~/ 6}.${legalBalls % 6}';
  double get economy => legalBalls > 0 ? runs / (legalBalls / 6) : 0;
}

class LiveBallEvent {
  final int over;
  final int ballInOver;
  final String batsmanId;
  final String bowlerId;
  final int runs;
  final String? extraType;
  final bool wicket;
  final int? timestamp;

  const LiveBallEvent({
    required this.over,
    required this.ballInOver,
    required this.batsmanId,
    required this.bowlerId,
    required this.runs,
    required this.extraType,
    required this.wicket,
    required this.timestamp,
  });

  factory LiveBallEvent.fromJson(Map<dynamic, dynamic> json) {
    return LiveBallEvent(
      over: (json['over'] as num?)?.toInt() ?? 0,
      ballInOver: (json['ballInOver'] as num?)?.toInt() ?? 0,
      batsmanId: json['batsmanId'] as String? ?? '',
      bowlerId: json['bowlerId'] as String? ?? '',
      runs: (json['runs'] as num?)?.toInt() ?? 0,
      extraType: json['extraType'] as String?,
      wicket: json['wicket'] as bool? ?? false,
      timestamp: (json['timestamp'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'over': over,
        'ballInOver': ballInOver,
        'batsmanId': batsmanId,
        'bowlerId': bowlerId,
        'runs': runs,
        'extraType': extraType,
        'wicket': wicket,
        'timestamp': timestamp,
      };

  String get overLabel => '$over.$ballInOver';
}

class LiveMatchData {
  final String status;
  final int currentInnings;
  final String battingTeamId;
  final String bowlingTeamId;
  final LiveMatchScore score;
  final int? target;
  final double? requiredRunRate;
  final LiveBatter striker;
  final LiveBatter nonStriker;
  final LiveBowler currentBowler;
  final List<String> thisOverBalls;
  final List<LiveBallEvent> ballHistory;
  final int? lastUpdated;

  /// Full batting scorecard for the current innings (player IDs, names and
  /// accumulated stats). Makes the live payload self-contained so the spectator
  /// can render real player names and statistics without a client-side lookup.
  final List<LiveBatter> battingCard;

  /// Full bowling scorecard for the current innings.
  final List<LiveBowler> bowlingCard;

  /// Playing-XI playerId → player name maps for both teams (squads rendering).
  final Map<String, String> squad1;
  final Map<String, String> squad2;

  /// Every player referenced by any innings or XI of the match, as
  /// playerId → name. Lets spectators resolve real names for ALL innings
  /// (current and completed) and the squads without a client-side lookup.
  final Map<String, String> players;

  const LiveMatchData({
    required this.status,
    required this.currentInnings,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.score,
    required this.target,
    required this.requiredRunRate,
    required this.striker,
    required this.nonStriker,
    required this.currentBowler,
    required this.thisOverBalls,
    required this.ballHistory,
    required this.lastUpdated,
    this.battingCard = const [],
    this.bowlingCard = const [],
    this.squad1 = const {},
    this.squad2 = const {},
    this.players = const {},
  });

  factory LiveMatchData.fromJson(Map<dynamic, dynamic> json) {
    final scoreMap = json['score'] is Map ? json['score'] as Map : null;
    final thisOver = (json['thisOverBalls'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final historyRaw = (json['ballHistory'] as List?) ?? const [];
    final history = historyRaw
        .where((e) => e is Map)
        .map((e) => LiveBallEvent.fromJson(e as Map))
        .toList();

    return LiveMatchData(
      status: json['status'] as String? ?? 'live',
      currentInnings: (json['currentInnings'] as num?)?.toInt() ?? 1,
      battingTeamId: json['battingTeamId'] as String? ?? '',
      bowlingTeamId: json['bowlingTeamId'] as String? ?? '',
      score: LiveMatchScore.fromJson(scoreMap),
      target: (json['target'] as num?)?.toInt(),
      requiredRunRate: (json['requiredRunRate'] as num?)?.toDouble(),
      striker: LiveBatter.fromJson(json['striker'] is Map ? json['striker'] as Map : null),
      nonStriker: LiveBatter.fromJson(json['nonStriker'] is Map ? json['nonStriker'] as Map : null),
      currentBowler: LiveBowler.fromJson(json['currentBowler'] is Map ? json['currentBowler'] as Map : null),
      thisOverBalls: thisOver,
      ballHistory: history,
      lastUpdated: (json['lastUpdated'] as num?)?.toInt(),
      battingCard: ((json['battingCard'] as List?) ?? const [])
          .where((e) => e is Map)
          .map((e) => LiveBatter.fromJson(e as Map))
          .toList(),
      bowlingCard: ((json['bowlingCard'] as List?) ?? const [])
          .where((e) => e is Map)
          .map((e) => LiveBowler.fromJson(e as Map))
          .toList(),
      squad1: _stringMap(json['squad1']),
      squad2: _stringMap(json['squad2']),
      players: _stringMap(json['players']),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'currentInnings': currentInnings,
        'battingTeamId': battingTeamId,
        'bowlingTeamId': bowlingTeamId,
        'score': score.toJson(),
        'target': target,
        'requiredRunRate': requiredRunRate,
        'striker': striker.toJson(),
        'nonStriker': nonStriker.toJson(),
        'currentBowler': currentBowler.toJson(),
        'thisOverBalls': thisOverBalls,
        'ballHistory': ballHistory.map((e) => e.toJson()).toList(),
        'lastUpdated': lastUpdated,
        'battingCard': battingCard.map((b) => b.toJson()).toList(),
        'bowlingCard': bowlingCard.map((b) => b.toJson()).toList(),
        'squad1': squad1,
        'squad2': squad2,
        'players': players,
      };

  double get currentRunRate {
    final balls = score.totalBalls;
    if (balls == 0) return 0;
    return score.runs / (balls / 6);
  }
}

Map<String, String> _stringMap(dynamic raw) {
  final out = <String, String>{};
  if (raw is Map) {
    for (final entry in raw.entries) {
      out[entry.key.toString()] = entry.value.toString();
    }
  }
  return out;
}

/// Builds a [LiveMatchData] snapshot straight from a [ScorerMatch]'s current
/// innings. The scorer now stores the full live match document (score, current
/// strikers/bowler, ball-by-ball innings) in Firestore, so spectators derive
/// the live players panel (runs, balls, wickets) directly from that document
/// instead of a separate real-time database payload.
///
/// Returns null when the match is not live or has no innings yet.
LiveMatchData? liveMatchDataFromMatch(ScorerMatch match) {
  if (match.status != MatchStatus.inProgress &&
      match.status != MatchStatus.live) {
    return null;
  }
  final inn = match.currentInningsData;
  if (inn == null) return null;

  final batAcc = <String, _BatAccum>{};
  final bowlAcc = <String, _BowlAccum>{};
  for (final ball in inn.balls) {
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
    );
  }

  LiveBowler bowler(String? id) {
    final b = bowlAcc[id] ?? _BowlAccum();
    return LiveBowler(
      playerId: id ?? '',
      name: '',
      legalBalls: b.legalBalls,
      maidens: b.maidens,
      runs: b.runs,
      wickets: b.wickets,
      wides: b.wides,
      noBalls: b.noBalls,
    );
  }

  final legalBalls = inn.legalBallsDelivered;
  final target = match.currentInnings == 2
      ? (match.innings1?.totalRuns ?? 0) + 1
      : null;
  final requiredRunRate = target != null && legalBalls > 0
      ? (target - inn.totalRuns) * 6 / legalBalls
      : null;

  return LiveMatchData(
    status: 'live',
    currentInnings: match.currentInnings,
    battingTeamId: inn.battingTeamId,
    bowlingTeamId: inn.bowlingTeamId,
    score: LiveMatchScore(
      runs: inn.totalRuns,
      wickets: inn.wickets,
      overs: legalBalls ~/ 6,
      balls: legalBalls % 6,
    ),
    target: target,
    requiredRunRate: requiredRunRate,
    striker: batter(inn.strikerId),
    nonStriker: batter(inn.nonStrikerId),
    currentBowler: bowler(inn.currentBowlerId),
    thisOverBalls: inn.currentOverBalls.map((b) => b.displayLabel).toList(),
    ballHistory: const [],
    lastUpdated: null,
    // Firestore-derived fallback has no resolved names (the RTDB payload does);
    // empty names make spectators fall back to their own player lookup.
    battingCard: buildBattingScorecard(inn, playerName: (_) => ''),
    bowlingCard: buildBowlingScorecard(inn, playerName: (_) => ''),
  );
}

class _BatAccum {
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
}

class _BowlAccum {
  int legalBalls = 0;
  int maidens = 0;
  int runs = 0;
  int wickets = 0;
  int wides = 0;
  int noBalls = 0;
}

/// Builds the batting scorecard rows for [inn] exactly as the spectator
/// scorecard displays them (balls counted on legal deliveries only; runs off
/// the bat on every delivery; dismissal text resolved through [playerName]).
/// Rows follow the batting order, with the current striker marked via
/// [LiveBatter.onStrike] and each batter's status pre-computed so spectators
/// never need a client-side player lookup to render names or stats.
List<LiveBatter> buildBattingScorecard(
  Innings inn, {
  required String Function(String? id) playerName,
}) {
  final acc = <String, _ScoreBatAccum>{};
  final batterIds = <String>{
    ...inn.battingOrder,
    if (inn.strikerId != null && inn.strikerId!.isNotEmpty) inn.strikerId!,
    if (inn.nonStrikerId != null && inn.nonStrikerId!.isNotEmpty) inn.nonStrikerId!,
  };
  for (final id in batterIds) {
    acc[id] = _ScoreBatAccum();
  }

  final dismissals = <String, String>{};
  for (final ball in inn.balls) {
    if (ball.batsmanId.isNotEmpty) {
      final a = acc.putIfAbsent(ball.batsmanId, () => _ScoreBatAccum());
      if (ball.isLegalBall) a.balls++;
      a.runs += ball.runs;
      if (ball.isBoundary && ball.runs == 4) a.fours++;
      if (ball.isSix) a.sixes++;
    }
    if (ball.isWicket && ball.dismissal != null) {
      final d = ball.dismissal!;
      final outId = d.batsmanId.isNotEmpty ? d.batsmanId : ball.batsmanId;
      if (outId.isNotEmpty) {
        acc.putIfAbsent(outId, () => _ScoreBatAccum());
        dismissals[outId] = d.describe(
          playerName(outId),
          bowlerName:
              ball.bowlerId.isNotEmpty ? playerName(ball.bowlerId) : null,
          fielderName: d.fielderId != null && d.fielderId!.isNotEmpty
              ? playerName(d.fielderId)
              : null,
        );
      }
    }
  }

  final ordered = <String>[...inn.battingOrder];
  for (final id in acc.keys) {
    if (!ordered.contains(id)) ordered.add(id);
  }

  return ordered.map((id) {
    final a = acc[id] ?? _ScoreBatAccum();
    final isAtCrease = id == inn.strikerId || id == inn.nonStrikerId;
    final status = dismissals.containsKey(id)
        ? dismissals[id]!
        : isAtCrease
            ? 'batting'
            : (a.balls == 0 && a.runs == 0)
                ? 'yet to bat'
                : 'not out';
    return LiveBatter(
      playerId: id,
      name: playerName(id),
      runs: a.runs,
      balls: a.balls,
      fours: a.fours,
      sixes: a.sixes,
      status: status,
      onStrike: id == inn.strikerId,
    );
  }).toList();
}

/// Builds the bowling scorecard rows for [inn] (runs charged = runs off bat +
/// wide/no-ball extras; wickets exclude run outs). Rows follow the bowling
/// order, with the current bowler marked via [LiveBowler.current].
List<LiveBowler> buildBowlingScorecard(
  Innings inn, {
  required String Function(String? id) playerName,
}) {
  final acc = <String, _ScoreBowlAccum>{};
  final bowlerIds = <String>{
    ...inn.bowlingOrder,
    if (inn.currentBowlerId != null && inn.currentBowlerId!.isNotEmpty)
      inn.currentBowlerId!,
  };
  for (final id in bowlerIds) {
    acc[id] = _ScoreBowlAccum();
  }

  for (final ball in inn.balls) {
    if (ball.bowlerId.isEmpty) continue;
    final b = acc.putIfAbsent(ball.bowlerId, () => _ScoreBowlAccum());
    final runsCharged = ball.runs +
        (ball.extrasType == ExtrasType.wide ||
                ball.extrasType == ExtrasType.noBall
            ? ball.extrasRuns
            : 0);
    b.runs += runsCharged;
    if (ball.isWicket && ball.dismissal?.type != DismissalType.runOut) {
      b.wickets++;
    }
    if (ball.isLegalBall) b.legalBalls++;
  }

  final ordered = <String>[...inn.bowlingOrder];
  for (final id in acc.keys) {
    if (!ordered.contains(id)) ordered.add(id);
  }

  return ordered.map((id) {
    final b = acc[id] ?? _ScoreBowlAccum();
    return LiveBowler(
      playerId: id,
      name: playerName(id),
      legalBalls: b.legalBalls,
      maidens: b.maidens,
      runs: b.runs,
      wickets: b.wickets,
      wides: b.wides,
      noBalls: b.noBalls,
      current: id == inn.currentBowlerId,
    );
  }).toList();
}

class _ScoreBatAccum {
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
}

class _ScoreBowlAccum {
  int legalBalls = 0;
  int maidens = 0;
  int runs = 0;
  int wickets = 0;
  int wides = 0;
  int noBalls = 0;
}

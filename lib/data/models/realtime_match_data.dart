class RealtimeBatterStats {
  final String playerId;
  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;

  const RealtimeBatterStats({
    required this.playerId,
    required this.name,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
  });

  double get strikeRate => balls == 0 ? 0 : (runs / balls * 100);

  factory RealtimeBatterStats.fromJson(Map<dynamic, dynamic> json) {
    return RealtimeBatterStats(
      playerId: json['playerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      runs: (json['runs'] as num?)?.toInt() ?? 0,
      balls: (json['balls'] as num?)?.toInt() ?? 0,
      fours: (json['fours'] as num?)?.toInt() ?? 0,
      sixes: (json['sixes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'name': name,
    'runs': runs,
    'balls': balls,
    'fours': fours,
    'sixes': sixes,
  };
}

class RealtimeBowlerStats {
  final String playerId;
  final String name;
  final int legalBalls;
  final int maidens;
  final int runs;
  final int wickets;
  final int wides;
  final int noBalls;

  const RealtimeBowlerStats({
    required this.playerId,
    required this.name,
    this.legalBalls = 0,
    this.maidens = 0,
    this.runs = 0,
    this.wickets = 0,
    this.wides = 0,
    this.noBalls = 0,
  });

  double get overs => legalBalls ~/ 6 + (legalBalls % 6) / 10;
  double get economy => legalBalls == 0 ? 0 : (runs / (legalBalls / 6));

  factory RealtimeBowlerStats.fromJson(Map<dynamic, dynamic> json) {
    return RealtimeBowlerStats(
      playerId: json['playerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      legalBalls: (json['legalBalls'] as num?)?.toInt() ?? 0,
      maidens: (json['maidens'] as num?)?.toInt() ?? 0,
      runs: (json['runs'] as num?)?.toInt() ?? 0,
      wickets: (json['wickets'] as num?)?.toInt() ?? 0,
      wides: (json['wides'] as num?)?.toInt() ?? 0,
      noBalls: (json['noBalls'] as num?)?.toInt() ?? 0,
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
  };
}

class BallHistoryEntry {
  final int over;
  final int ballInOver;
  final String batsmanId;
  final String bowlerId;
  final int runs;
  final String extraType;
  final bool wicket;
  final int timestamp;

  const BallHistoryEntry({
    required this.over,
    required this.ballInOver,
    required this.batsmanId,
    required this.bowlerId,
    required this.runs,
    this.extraType = '',
    this.wicket = false,
    required this.timestamp,
  });

  factory BallHistoryEntry.fromJson(Map<dynamic, dynamic> json) {
    return BallHistoryEntry(
      over: (json['over'] as num?)?.toInt() ?? 0,
      ballInOver: (json['ballInOver'] as num?)?.toInt() ?? 0,
      batsmanId: json['batsmanId'] as String? ?? '',
      bowlerId: json['bowlerId'] as String? ?? '',
      runs: (json['runs'] as num?)?.toInt() ?? 0,
      extraType: json['extraType'] as String? ?? '',
      wicket: json['wicket'] as bool? ?? false,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
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
}

class RealtimeScore {
  final int runs;
  final int wickets;
  final int overs;
  final int balls;

  const RealtimeScore({
    this.runs = 0,
    this.wickets = 0,
    this.overs = 0,
    this.balls = 0,
  });

  double get oversDisplay => overs + (balls / 10);

  factory RealtimeScore.fromJson(Map<dynamic, dynamic> json) {
    return RealtimeScore(
      runs: (json['runs'] as num?)?.toInt() ?? 0,
      wickets: (json['wickets'] as num?)?.toInt() ?? 0,
      overs: (json['overs'] as num?)?.toInt() ?? 0,
      balls: (json['balls'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'runs': runs,
    'wickets': wickets,
    'overs': overs,
    'balls': balls,
  };
}

class RealtimeMatchData {
  final String status;
  final int currentInnings;
  final String battingTeamId;
  final String bowlingTeamId;
  final RealtimeScore score;
  final int? target;
  final double? requiredRunRate;
  final RealtimeBatterStats striker;
  final RealtimeBatterStats nonStriker;
  final RealtimeBowlerStats currentBowler;
  final List<String> thisOverBalls;
  final List<BallHistoryEntry> ballHistory;
  final int lastUpdated;

  const RealtimeMatchData({
    this.status = 'live',
    this.currentInnings = 1,
    required this.battingTeamId,
    required this.bowlingTeamId,
    this.score = const RealtimeScore(),
    this.target,
    this.requiredRunRate,
    this.striker = const RealtimeBatterStats(playerId: '', name: ''),
    this.nonStriker = const RealtimeBatterStats(playerId: '', name: ''),
    this.currentBowler = const RealtimeBowlerStats(playerId: '', name: ''),
    this.thisOverBalls = const [],
    this.ballHistory = const [],
    this.lastUpdated = 0,
  });

  factory RealtimeMatchData.fromJson(Map<dynamic, dynamic> json) {
    return RealtimeMatchData(
      status: json['status'] as String? ?? 'live',
      currentInnings: (json['currentInnings'] as num?)?.toInt() ?? 1,
      battingTeamId: json['battingTeamId'] as String? ?? '',
      bowlingTeamId: json['bowlingTeamId'] as String? ?? '',
      score: json['score'] != null
          ? RealtimeScore.fromJson(json['score'] as Map<dynamic, dynamic>)
          : const RealtimeScore(),
      target: (json['target'] as num?)?.toInt(),
      requiredRunRate: (json['requiredRunRate'] as num?)?.toDouble(),
      striker: json['striker'] != null
          ? RealtimeBatterStats.fromJson(json['striker'] as Map<dynamic, dynamic>)
          : const RealtimeBatterStats(playerId: '', name: ''),
      nonStriker: json['nonStriker'] != null
          ? RealtimeBatterStats.fromJson(json['nonStriker'] as Map<dynamic, dynamic>)
          : const RealtimeBatterStats(playerId: '', name: ''),
      currentBowler: json['currentBowler'] != null
          ? RealtimeBowlerStats.fromJson(json['currentBowler'] as Map<dynamic, dynamic>)
          : const RealtimeBowlerStats(playerId: '', name: ''),
      thisOverBalls: json['thisOverBalls'] != null
          ? List<String>.from(json['thisOverBalls'] as List)
          : [],
      ballHistory: json['ballHistory'] != null
          ? (json['ballHistory'] as List)
              .map((e) => BallHistoryEntry.fromJson(e as Map<dynamic, dynamic>))
              .toList()
          : [],
      lastUpdated: (json['lastUpdated'] as num?)?.toInt() ?? 0,
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
  };
}

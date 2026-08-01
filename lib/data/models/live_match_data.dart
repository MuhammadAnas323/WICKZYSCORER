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

  const LiveBatter({
    required this.playerId,
    required this.name,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
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

  const LiveBowler({
    required this.playerId,
    required this.name,
    required this.legalBalls,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.wides,
    required this.noBalls,
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
  });

  factory LiveMatchData.fromJson(Map<dynamic, dynamic> json) {
    final scoreMap = json['score'] as Map<dynamic, dynamic>?;
    final thisOver = (json['thisOverBalls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final historyRaw = (json['ballHistory'] as List<dynamic>?) ?? const [];
    final history = historyRaw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => LiveBallEvent.fromJson(e))
        .toList();

    return LiveMatchData(
      status: json['status'] as String? ?? 'live',
      currentInnings: (json['currentInnings'] as num?)?.toInt() ?? 1,
      battingTeamId: json['battingTeamId'] as String? ?? '',
      bowlingTeamId: json['bowlingTeamId'] as String? ?? '',
      score: LiveMatchScore.fromJson(scoreMap),
      target: (json['target'] as num?)?.toInt(),
      requiredRunRate: (json['requiredRunRate'] as num?)?.toDouble(),
      striker: LiveBatter.fromJson(json['striker'] as Map<dynamic, dynamic>?),
      nonStriker: LiveBatter.fromJson(json['nonStriker'] as Map<dynamic, dynamic>?),
      currentBowler: LiveBowler.fromJson(json['currentBowler'] as Map<dynamic, dynamic>?),
      thisOverBalls: thisOver,
      ballHistory: history,
      lastUpdated: (json['lastUpdated'] as num?)?.toInt(),
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
      };

  double get currentRunRate {
    final balls = score.totalBalls;
    if (balls == 0) return 0;
    return score.runs / (balls / 6);
  }
}

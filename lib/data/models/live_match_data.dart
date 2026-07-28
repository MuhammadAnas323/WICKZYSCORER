class LiveMatchData {
  final int runs;
  final int wickets;
  final double overs;
  final double currentRunRate;
  final int? target;
  final String striker;
  final String nonStriker;
  final String bowler;
  final String lastBall;
  final String status;
  final String? stream;
  final String commentary;
  final int viewers;

  const LiveMatchData({
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.currentRunRate,
    this.target,
    required this.striker,
    required this.nonStriker,
    required this.bowler,
    required this.lastBall,
    required this.status,
    this.stream,
    required this.commentary,
    this.viewers = 0,
  });

  factory LiveMatchData.fromJson(Map<dynamic, dynamic> json) {
    return LiveMatchData(
      runs: (json['runs'] as num?)?.toInt() ?? 0,
      wickets: (json['wickets'] as num?)?.toInt() ?? 0,
      overs: (json['overs'] as num?)?.toDouble() ?? 0.0,
      currentRunRate: (json['currentRunRate'] as num?)?.toDouble() ?? 0.0,
      target: (json['target'] as num?)?.toInt(),
      striker: json['striker'] as String? ?? '',
      nonStriker: json['nonStriker'] as String? ?? '',
      bowler: json['bowler'] as String? ?? '',
      lastBall: json['lastBall'] as String? ?? '',
      status: json['status'] as String? ?? '',
      stream: json['stream'] as String?,
      commentary: json['commentary'] as String? ?? '',
      viewers: (json['viewers'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'runs': runs,
    'wickets': wickets,
    'overs': overs,
    'currentRunRate': currentRunRate,
    'target': target,
    'striker': striker,
    'nonStriker': nonStriker,
    'bowler': bowler,
    'lastBall': lastBall,
    'status': status,
    'stream': stream,
    'commentary': commentary,
    'viewers': viewers,
  };
}

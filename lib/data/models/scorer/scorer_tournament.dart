enum MatchFormat { t20, odi, test, custom }

class PointsRules {
  final int win;
  final int loss;
  final int tie;
  final int noResult;
  final bool nrrAsTiebreaker;
  
  const PointsRules({
    this.win = 2,
    this.loss = 0,
    this.tie = 1,
    this.noResult = 1,
    this.nrrAsTiebreaker = true,
  });
}

class ScorerTournament {
  final String id;
  final String name;
  final String ownerId;
  final MatchFormat format;
  final int customOvers;
  final DateTime startDate;
  final DateTime endDate;
  final String venue;
  final int numTeams;
  final List<String> teamIds;
  final PointsRules pointsRules;
  final String? logoUrl;
  final double? entryFee;
  final double? winnerPrize;
  final double? runnerUpPrize;

  const ScorerTournament({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.format,
    required this.customOvers,
    required this.startDate,
    required this.endDate,
    required this.venue,
    required this.numTeams,
    required this.teamIds,
    required this.pointsRules,
    this.logoUrl,
    this.entryFee,
    this.winnerPrize,
    this.runnerUpPrize,
  });

  int get numberOfTeams => numTeams;
  List<String> get teamsIds => teamIds;
  List<String> get matchesIds => const [];

  ScorerTournament copyWith({
    String? id,
    String? name,
    String? ownerId,
    MatchFormat? format,
    int? customOvers,
    DateTime? startDate,
    DateTime? endDate,
    String? venue,
    int? numTeams,
    List<String>? teamIds,
    PointsRules? pointsRules,
    String? logoUrl,
    double? entryFee,
    double? winnerPrize,
    double? runnerUpPrize,
  }) {
    return ScorerTournament(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      format: format ?? this.format,
      customOvers: customOvers ?? this.customOvers,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      venue: venue ?? this.venue,
      numTeams: numTeams ?? this.numTeams,
      teamIds: teamIds ?? this.teamIds,
      pointsRules: pointsRules ?? this.pointsRules,
      logoUrl: logoUrl ?? this.logoUrl,
      entryFee: entryFee ?? this.entryFee,
      winnerPrize: winnerPrize ?? this.winnerPrize,
      runnerUpPrize: runnerUpPrize ?? this.runnerUpPrize,
    );
  }
}

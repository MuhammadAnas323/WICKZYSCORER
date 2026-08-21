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
  final int? maxOversPerBowler;
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
  final String? securityCode;
  final String? description;
  final String? tournamentRules;
  final String? tournamentRequirements;

  /// UID of the user who created this tournament (set once).
  final String createdBy;

  /// Display name of the tournament organizer.
  final String organizer;

  const ScorerTournament({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.format,
    required this.customOvers,
    this.maxOversPerBowler,
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
    this.securityCode,
    this.description,
    this.tournamentRules,
    this.tournamentRequirements,
    this.createdBy = '',
    this.organizer = '',
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
    int? maxOversPerBowler,
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
    String? securityCode,
    String? description,
    String? tournamentRules,
    String? tournamentRequirements,
    String? createdBy,
    String? organizer,
  }) {
    return ScorerTournament(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      format: format ?? this.format,
      customOvers: customOvers ?? this.customOvers,
      maxOversPerBowler: maxOversPerBowler ?? this.maxOversPerBowler,
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
      securityCode: securityCode ?? this.securityCode,
      description: description ?? this.description,
      tournamentRules: tournamentRules ?? this.tournamentRules,
      tournamentRequirements: tournamentRequirements ?? this.tournamentRequirements,
      createdBy: createdBy ?? this.createdBy,
      organizer: organizer ?? this.organizer,
    );
  }
}

import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';

enum TossDecision { bat, bowl }

enum MatchStatus { live, scheduled, upcoming, inProgress, completed, abandoned }

class ScorerMatch {
  final String id;
  final String tournamentId;
  final String team1Id;
  final String team2Id;
  final String venue;
  final DateTime dateTime;
  final MatchFormat format;
  final int overs;
  final MatchStatus status;
  final String? tossWinnerId;
  final TossDecision? tossDecision;
  final List<String> playingXI1;
  final List<String> playingXI2;
  final String? openingStrikerId;
  final String? openingNonStrikerId;
  final String? openingBowlerId;
  final Innings? innings1;
  final Innings? innings2;
  final int currentInnings;
  final String? winnerTeamId;
  final String? resultSummary;
  final String? specialInstructions;

  /// UID of the user who created this match (set once).
  final String createdBy;

  final String? playerOfTheMatchId;
  final String? bestBatsmanId;
  final String? bestBowlerId;

  /// Optional free-text prize/note for each award (shown with the award).
  final String? playerOfTheMatchPrize;
  final String? bestBatsmanPrize;
  final String? bestBowlerPrize;

  /// Custom award categories chosen by the scorer (category → player id).
  /// An empty-string value means the category exists but no winner is picked.
  final Map<String, String> customAwards;

  /// Optional prize text for each custom award category.
  final Map<String, String> customAwardsPrizes;

  /// Optional note captured when creating a friendly match.
  final String? note;

  /// Super over tie-breaker state. When the main innings tie, the scorer can
  /// opt into a 1-over-per-side decider stored in [superOverInnings1]/[superOverInnings2]
  /// (scored as `currentInnings` 3 and 4).
  final bool superOverPlayed;
  final Innings? superOverInnings1;
  final Innings? superOverInnings2;

  const ScorerMatch({
    required this.id,
    required this.tournamentId,
    required this.team1Id,
    required this.team2Id,
    required this.venue,
    required this.dateTime,
    required this.format,
    required this.overs,
    required this.status,
    this.tossWinnerId,
    this.tossDecision,
    required this.playingXI1,
    required this.playingXI2,
    this.openingStrikerId,
    this.openingNonStrikerId,
    this.openingBowlerId,
    this.innings1,
    this.innings2,
    required this.currentInnings,
    this.winnerTeamId,
    this.resultSummary,
    this.specialInstructions,
    this.createdBy = '',
    this.playerOfTheMatchId,
    this.bestBatsmanId,
    this.bestBowlerId,
    this.playerOfTheMatchPrize,
    this.bestBatsmanPrize,
    this.bestBowlerPrize,
    this.customAwards = const {},
    this.customAwardsPrizes = const {},
    this.note,
    this.superOverPlayed = false,
    this.superOverInnings1,
    this.superOverInnings2,
  });

  String? get battingTeamId {
    if (currentInnings <= 2) {
      return currentInnings == 1 ? innings1?.battingTeamId : innings2?.battingTeamId;
    }
    return currentInnings == 3
        ? superOverInnings1?.battingTeamId
        : superOverInnings2?.battingTeamId;
  }

  Innings? get currentInningsData {
    if (currentInnings == 1) return innings1;
    if (currentInnings == 2) return innings2;
    if (currentInnings == 3) return superOverInnings1;
    if (currentInnings == 4) return superOverInnings2;
    return null;
  }

  /// True while the super-over decider is being scored (innings 3 or 4).
  bool get isSuperOverInnings => currentInnings >= 3;

  /// True when the main two innings have finished on equal totals.
  bool get isTie {
    final i1 = innings1;
    final i2 = innings2;
    if (i1 == null || i2 == null) return false;
    return i1.isComplete && i2.isComplete && i1.totalRuns == i2.totalRuns;
  }

  DateTime get scheduledDate => dateTime;
  int get totalOvers => overs;
  Innings? get firstInnings => innings1;
  Innings? get secondInnings => innings2;

  ScorerMatch copyWith({
    String? id,
    String? tournamentId,
    String? team1Id,
    String? team2Id,
    String? venue,
    DateTime? dateTime,
    MatchFormat? format,
    int? overs,
    MatchStatus? status,
    String? tossWinnerId,
    TossDecision? tossDecision,
    List<String>? playingXI1,
    List<String>? playingXI2,
    String? openingStrikerId,
    String? openingNonStrikerId,
    String? openingBowlerId,
    Innings? innings1,
    Innings? innings2,
    int? currentInnings,
    String? winnerTeamId,
    String? resultSummary,
    String? specialInstructions,
    String? createdBy,
    String? playerOfTheMatchId,
    String? bestBatsmanId,
    String? bestBowlerId,
    String? playerOfTheMatchPrize,
    String? bestBatsmanPrize,
    String? bestBowlerPrize,
    Map<String, String>? customAwards,
    Map<String, String>? customAwardsPrizes,
    String? note,
    bool? superOverPlayed,
    Innings? superOverInnings1,
    Innings? superOverInnings2,
  }) {
    return ScorerMatch(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      team1Id: team1Id ?? this.team1Id,
      team2Id: team2Id ?? this.team2Id,
      venue: venue ?? this.venue,
      dateTime: dateTime ?? this.dateTime,
      format: format ?? this.format,
      overs: overs ?? this.overs,
      status: status ?? this.status,
      tossWinnerId: tossWinnerId ?? this.tossWinnerId,
      tossDecision: tossDecision ?? this.tossDecision,
      playingXI1: playingXI1 ?? this.playingXI1,
      playingXI2: playingXI2 ?? this.playingXI2,
      openingStrikerId: openingStrikerId ?? this.openingStrikerId,
      openingNonStrikerId: openingNonStrikerId ?? this.openingNonStrikerId,
      openingBowlerId: openingBowlerId ?? this.openingBowlerId,
      innings1: innings1 ?? this.innings1,
      innings2: innings2 ?? this.innings2,
      currentInnings: currentInnings ?? this.currentInnings,
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
      resultSummary: resultSummary ?? this.resultSummary,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      createdBy: createdBy ?? this.createdBy,
      playerOfTheMatchId: playerOfTheMatchId ?? this.playerOfTheMatchId,
      bestBatsmanId: bestBatsmanId ?? this.bestBatsmanId,
      bestBowlerId: bestBowlerId ?? this.bestBowlerId,
      playerOfTheMatchPrize: playerOfTheMatchPrize ?? this.playerOfTheMatchPrize,
      bestBatsmanPrize: bestBatsmanPrize ?? this.bestBatsmanPrize,
      bestBowlerPrize: bestBowlerPrize ?? this.bestBowlerPrize,
      customAwards: customAwards ?? this.customAwards,
      customAwardsPrizes: customAwardsPrizes ?? this.customAwardsPrizes,
      note: note ?? this.note,
      superOverPlayed: superOverPlayed ?? this.superOverPlayed,
      superOverInnings1: superOverInnings1 ?? this.superOverInnings1,
      superOverInnings2: superOverInnings2 ?? this.superOverInnings2,
    );
  }
}

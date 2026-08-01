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
  });

  String? get battingTeamId {
    if (currentInnings == 1) return innings1?.battingTeamId;
    if (currentInnings == 2) return innings2?.battingTeamId;
    return null;
  }
  
  Innings? get currentInningsData {
    return currentInnings == 1 ? innings1 : innings2;
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
    );
  }
}

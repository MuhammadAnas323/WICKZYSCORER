// lib/data/models/scorer/scorer_serializers.dart
// JSON (de)serialization for all scorer-domain models so live scoring
// can be persisted locally as a safe draft.

import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/dismissal.dart';

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  return values.where((v) => v.name == name).firstOrNull ?? fallback;
}

// ─── Dismissal ─────────────────────────────────────────────────────────────

Map<String, dynamic> dismissalToJson(Dismissal d) => {
      'type': d.type.name,
      'batsmanId': d.batsmanId,
      'bowlerId': d.bowlerId,
      'fielderId': d.fielderId,
      'runOutEnd': d.runOutEnd,
    };

Dismissal dismissalFromJson(Map<String, dynamic> json) => Dismissal(
      type: _enumByName(DismissalType.values, json['type'], DismissalType.bowled),
      batsmanId: json['batsmanId'] ?? '',
      bowlerId: json['bowlerId'],
      fielderId: json['fielderId'],
      runOutEnd: json['runOutEnd'],
    );

// ─── BallEvent ─────────────────────────────────────────────────────────────

Map<String, dynamic> ballEventToJson(BallEvent b) => {
      'overNumber': b.overNumber,
      'ballInOver': b.ballInOver,
      'batsmanId': b.batsmanId,
      'bowlerId': b.bowlerId,
      'runs': b.runs,
      'extrasType': b.extrasType.name,
      'extrasRuns': b.extrasRuns,
      'isWicket': b.isWicket,
      'dismissal': b.dismissal == null ? null : dismissalToJson(b.dismissal!),
      'isBoundary': b.isBoundary,
      'isSix': b.isSix,
      'timestamp': b.timestamp.toIso8601String(),
    };

BallEvent ballEventFromJson(Map<String, dynamic> json) => BallEvent(
      overNumber: (json['overNumber'] as num?)?.toInt() ?? 1,
      ballInOver: (json['ballInOver'] as num?)?.toInt() ?? 1,
      batsmanId: json['batsmanId'] ?? '',
      bowlerId: json['bowlerId'] ?? '',
      runs: (json['runs'] as num?)?.toInt() ?? 0,
      extrasType: _enumByName(ExtrasType.values, json['extrasType'], ExtrasType.none),
      extrasRuns: (json['extrasRuns'] as num?)?.toInt() ?? 0,
      isWicket: json['isWicket'] ?? false,
      dismissal: json['dismissal'] == null
          ? null
          : dismissalFromJson(json['dismissal'] as Map<String, dynamic>),
      isBoundary: json['isBoundary'] ?? false,
      isSix: json['isSix'] ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );

// ─── Innings ───────────────────────────────────────────────────────────────

Map<String, dynamic> inningsToJson(Innings i) => {
      'id': i.id,
      'battingTeamId': i.battingTeamId,
      'bowlingTeamId': i.bowlingTeamId,
      'inningsNumber': i.inningsNumber,
      'balls': i.balls.map(ballEventToJson).toList(),
      'battingOrder': i.battingOrder,
      'bowlingOrder': i.bowlingOrder,
      'isComplete': i.isComplete,
      'strikerId': i.strikerId,
      'nonStrikerId': i.nonStrikerId,
      'currentBowlerId': i.currentBowlerId,
    };

Innings inningsFromJson(Map<String, dynamic> json) => Innings(
      id: json['id'] ?? '',
      battingTeamId: json['battingTeamId'] ?? '',
      bowlingTeamId: json['bowlingTeamId'] ?? '',
      inningsNumber: (json['inningsNumber'] as num?)?.toInt() ?? 1,
      balls: (json['balls'] as List? ?? [])
          .map((e) => ballEventFromJson(e as Map<String, dynamic>))
          .toList(),
      battingOrder: (json['battingOrder'] as List? ?? []).cast<String>(),
      bowlingOrder: (json['bowlingOrder'] as List? ?? []).cast<String>(),
      isComplete: json['isComplete'] ?? false,
      strikerId: json['strikerId'],
      nonStrikerId: json['nonStrikerId'],
      currentBowlerId: json['currentBowlerId'],
    );

// ─── ScorerMatch ───────────────────────────────────────────────────────────

Map<String, dynamic> scorerMatchToJson(ScorerMatch m) => {
      'id': m.id,
      'tournamentId': m.tournamentId,
      'team1Id': m.team1Id,
      'team2Id': m.team2Id,
      'venue': m.venue,
      'dateTime': m.dateTime.toIso8601String(),
      'format': m.format.name,
      'overs': m.overs,
      'status': m.status.name,
      'tossWinnerId': m.tossWinnerId,
      'tossDecision': m.tossDecision?.name,
      'playingXI1': m.playingXI1,
      'playingXI2': m.playingXI2,
      'openingStrikerId': m.openingStrikerId,
      'openingNonStrikerId': m.openingNonStrikerId,
      'openingBowlerId': m.openingBowlerId,
      'innings1': m.innings1 == null ? null : inningsToJson(m.innings1!),
      'innings2': m.innings2 == null ? null : inningsToJson(m.innings2!),
      'currentInnings': m.currentInnings,
      'winnerTeamId': m.winnerTeamId,
      'resultSummary': m.resultSummary,
      'specialInstructions': m.specialInstructions,
    };

ScorerMatch scorerMatchFromJson(Map<String, dynamic> json) => ScorerMatch(
      id: json['id'] ?? '',
      tournamentId: json['tournamentId'] ?? '',
      team1Id: json['team1Id'] ?? '',
      team2Id: json['team2Id'] ?? '',
      venue: json['venue'] ?? '',
      dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
      format: _enumByName(MatchFormat.values, json['format'], MatchFormat.t20),
      overs: (json['overs'] as num?)?.toInt() ?? 20,
      status: _enumByName(MatchStatus.values, json['status'], MatchStatus.scheduled),
      tossWinnerId: json['tossWinnerId'],
      tossDecision: json['tossDecision'] == null
          ? null
          : _enumByName(TossDecision.values, json['tossDecision'], TossDecision.bat),
      playingXI1: (json['playingXI1'] as List? ?? []).cast<String>(),
      playingXI2: (json['playingXI2'] as List? ?? []).cast<String>(),
      openingStrikerId: json['openingStrikerId'],
      openingNonStrikerId: json['openingNonStrikerId'],
      openingBowlerId: json['openingBowlerId'],
      innings1: json['innings1'] == null
          ? null
          : inningsFromJson(json['innings1'] as Map<String, dynamic>),
      innings2: json['innings2'] == null
          ? null
          : inningsFromJson(json['innings2'] as Map<String, dynamic>),
      currentInnings: (json['currentInnings'] as num?)?.toInt() ?? 1,
      winnerTeamId: json['winnerTeamId'],
      resultSummary: json['resultSummary'],
      specialInstructions: json['specialInstructions'],
    );

// ─── ScorerTournament ──────────────────────────────────────────────────────

Map<String, dynamic> scorerTournamentToJson(ScorerTournament t) => {
      'id': t.id,
      'name': t.name,
      'ownerId': t.ownerId,
      'format': t.format.name,
      'customOvers': t.customOvers,
      'startDate': t.startDate.toIso8601String(),
      'endDate': t.endDate.toIso8601String(),
      'venue': t.venue,
      'numTeams': t.numTeams,
      'teamIds': t.teamIds,
      'pointsRules': {
        'win': t.pointsRules.win,
        'loss': t.pointsRules.loss,
        'tie': t.pointsRules.tie,
        'noResult': t.pointsRules.noResult,
        'nrrAsTiebreaker': t.pointsRules.nrrAsTiebreaker,
      },
      'logoUrl': t.logoUrl,
      'entryFee': t.entryFee,
      'winnerPrize': t.winnerPrize,
      'runnerUpPrize': t.runnerUpPrize,
      'securityCode': t.securityCode,
    };

ScorerTournament scorerTournamentFromJson(Map<String, dynamic> json) {
  final rules = json['pointsRules'] as Map<String, dynamic>? ?? const {};
  return ScorerTournament(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    ownerId: json['ownerId'] ?? '',
    format: _enumByName(MatchFormat.values, json['format'], MatchFormat.t20),
    customOvers: (json['customOvers'] as num?)?.toInt() ?? 20,
    startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
    endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now(),
    venue: json['venue'] ?? '',
    numTeams: (json['numTeams'] as num?)?.toInt() ?? 0,
    teamIds: (json['teamIds'] as List? ?? []).cast<String>(),
    pointsRules: PointsRules(
      win: (rules['win'] as num?)?.toInt() ?? 2,
      loss: (rules['loss'] as num?)?.toInt() ?? 0,
      tie: (rules['tie'] as num?)?.toInt() ?? 1,
      noResult: (rules['noResult'] as num?)?.toInt() ?? 1,
      nrrAsTiebreaker: rules['nrrAsTiebreaker'] ?? true,
    ),
    logoUrl: json['logoUrl'],
    entryFee: (json['entryFee'] as num?)?.toDouble(),
    winnerPrize: (json['winnerPrize'] as num?)?.toDouble(),
    runnerUpPrize: (json['runnerUpPrize'] as num?)?.toDouble(),
    securityCode: json['securityCode'],
  );
}

// ─── ScorerTeam ────────────────────────────────────────────────────────────

Map<String, dynamic> scorerTeamToJson(ScorerTeam t) => {
      'id': t.id,
      'name': t.name,
      'shortCode': t.shortCode,
      'tournamentId': t.tournamentId,
      'playerIds': t.playerIds,
      'logoUrl': t.logoUrl,
      'isEntryFeePaid': t.isEntryFeePaid,
      'ownerName': t.ownerName,
      'whatsappNumber': t.whatsappNumber,
      'isEliminated': t.isEliminated,
    };

ScorerTeam scorerTeamFromJson(Map<String, dynamic> json) => ScorerTeam(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      shortCode: json['shortCode'] ?? '',
      tournamentId: json['tournamentId'] ?? '',
      playerIds: (json['playerIds'] as List? ?? []).cast<String>(),
      logoUrl: json['logoUrl'],
      isEntryFeePaid: json['isEntryFeePaid'] ?? false,
      ownerName: json['ownerName'],
      whatsappNumber: json['whatsappNumber'],
      isEliminated: json['isEliminated'] ?? false,
    );

// ─── ScorerPlayer ──────────────────────────────────────────────────────────

Map<String, dynamic> scorerPlayerToJson(ScorerPlayer p) => {
      'id': p.id,
      'name': p.name,
      'teamId': p.teamId,
      'tournamentId': p.tournamentId,
      'role': p.role.name,
      'battingStyle': p.battingStyle.name,
      'bowlingStyle': p.bowlingStyle.name,
      'jerseyNumber': p.jerseyNumber,
      'photoUrl': p.photoUrl,
    };

ScorerPlayer scorerPlayerFromJson(Map<String, dynamic> json) => ScorerPlayer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      teamId: json['teamId'] ?? '',
      tournamentId: json['tournamentId'] ?? '',
      role: _enumByName(PlayerRole.values, json['role'], PlayerRole.batsman),
      battingStyle:
          _enumByName(BattingStyle.values, json['battingStyle'], BattingStyle.rightHand),
      bowlingStyle:
          _enumByName(BowlingStyle.values, json['bowlingStyle'], BowlingStyle.none),
      jerseyNumber: (json['jerseyNumber'] as num?)?.toInt(),
      photoUrl: json['photoUrl'],
    );

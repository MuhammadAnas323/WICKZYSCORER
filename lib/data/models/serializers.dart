import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/team_model.dart';

// ─── TeamModel serialization helpers ─────────────────────────────────────────

Map<String, dynamic> teamModelToJson(TeamModel t) => {
      'id': t.id,
      'name': t.name,
      'shortName': t.shortName,
      'flagEmoji': t.flagEmoji,
      'logoUrl': t.logoUrl,
      'country': t.country,
      'teamType': t.teamType,
      'ranking': t.ranking,
    };

TeamModel teamModelFromJson(Map<String, dynamic> json) => TeamModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      shortName: json['shortName'] ?? '',
      flagEmoji: json['flagEmoji'] ?? '',
      logoUrl: json['logoUrl'] ?? '',
      country: json['country'] ?? '',
      teamType: json['teamType'] ?? '',
      ranking: (json['ranking'] as num?)?.toInt() ?? 0,
      squad: [],
      playingXI: [],
      teamStats: const MatchStats(
          matches: 0, wins: 0, losses: 0, draws: 0, winPercent: 0),
    );

// ─── MatchModel serialization helpers ────────────────────────────────────────

extension MatchModelExt on MatchModel {
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'seriesName': seriesName,
        'seriesId': seriesId,
        'format': format.name,
        'status': status.name,
        'teamA': teamModelToJson(teamA),
        'teamB': teamModelToJson(teamB),
        'scheduledAt': scheduledAt.toIso8601String(),
        'venue': venue,
        'city': city,
        'umpires': umpires,
        'isLive': isLive,
        'thumbnailUrl': thumbnailUrl,
        'tossWinner': tossWinner,
        'tossDecision': tossDecision,
      };
}

MatchModel matchModelFromJson(Map<String, dynamic> json) => MatchModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      seriesName: json['seriesName'] ?? '',
      seriesId: json['seriesId'] ?? '',
      format: MatchFormat.values.firstWhere(
        (e) => e.name == json['format'],
        orElse: () => MatchFormat.t20,
      ),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MatchStatus.upcoming,
      ),
      teamA: teamModelFromJson(
          (json['teamA'] as Map<String, dynamic>?) ?? {}),
      teamB: teamModelFromJson(
          (json['teamB'] as Map<String, dynamic>?) ?? {}),
      scheduledAt:
          DateTime.tryParse(json['scheduledAt'] ?? '') ?? DateTime.now(),
      venue: json['venue'] ?? '',
      city: json['city'] ?? '',
      umpires: json['umpires'] ?? '',
      innings: [],
      isLive: json['isLive'] ?? false,
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      tossWinner: json['tossWinner'],
      tossDecision: json['tossDecision'],
    );

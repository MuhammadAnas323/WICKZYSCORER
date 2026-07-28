// lib/data/models/team_model.dart
// Team and squad data model.

import 'player_model.dart';
export 'player_model.dart';

/// Represents a cricket team.
class TeamModel {
  final String id;
  final String name;
  final String shortName; // e.g. "PAK"
  final String flagEmoji; // e.g. "🇵🇰"
  final String logoUrl;
  final String country;
  final String teamType; // 'national' | 'franchise' | 'women' | 'u19'
  final int ranking;
  final List<PlayerModel> squad;
  final List<PlayerModel> playingXI;
  final MatchStats teamStats;

  const TeamModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.flagEmoji,
    required this.logoUrl,
    required this.country,
    required this.teamType,
    required this.ranking,
    required this.squad,
    required this.playingXI,
    required this.teamStats,
  });
}

/// Aggregate match stats for a team.
class MatchStats {
  final int matches;
  final int wins;
  final int losses;
  final int draws;
  final double winPercent;

  const MatchStats({
    required this.matches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winPercent,
  });
}

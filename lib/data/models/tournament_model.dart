// lib/data/models/tournament_model.dart
// Tournament / series and points table models.

/// Tournament category.
enum TournamentCategory { international, league, domestic, womens, u19 }

/// Points table entry per team.
class PointsTableEntry {
  final String teamId;
  final String teamName;
  final String teamShortName;
  final String teamFlag;
  final int matches;
  final int wins;
  final int losses;
  final int noResult;
  final int points;
  final double netRunRate;
  final int position;
  final bool isQualified;
  final bool isEliminated;

  const PointsTableEntry({
    required this.teamId,
    required this.teamName,
    required this.teamShortName,
    required this.teamFlag,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.noResult,
    required this.points,
    required this.netRunRate,
    required this.position,
    this.isQualified = false,
    this.isEliminated = false,
  });
}

/// Tournament / Series model.
class TournamentModel {
  final String id;
  final String name;
  final String shortName;
  final String logoUrl;
  final TournamentCategory category;
  final String host;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'live' | 'upcoming' | 'completed'
  final List<String> teamIds;
  final List<PointsTableEntry> pointsTable;
  final int totalMatches;
  final int completedMatches;
  final String description;

  const TournamentModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.logoUrl,
    required this.category,
    required this.host,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.teamIds,
    required this.pointsTable,
    required this.totalMatches,
    required this.completedMatches,
    required this.description,
  });
}

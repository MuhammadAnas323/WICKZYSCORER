// lib/data/models/player_model.dart
// Player data model.

/// Player role type.
enum PlayerRole { batsman, bowler, allRounder, wicketKeeper }

/// Represents a cricket player.
class PlayerModel {
  final String id;
  final String name;
  final String shortName;
  final String teamId;
  final String teamName;
  final String teamFlag; // emoji flag
  final String imageUrl;
  final PlayerRole role;
  final String battingStyle; // e.g. "Right-hand bat"
  final String bowlingStyle; // e.g. "Right-arm fast"
  final String nationality;
  final DateTime dateOfBirth;
  final int jerseyNumber;
  final bool isCaptain;
  final bool isWicketKeeper;
  final BattingStats battingStats;
  final BowlingStats bowlingStats;
  final bool isInPlayingXI;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.teamId,
    required this.teamName,
    required this.teamFlag,
    required this.imageUrl,
    required this.role,
    required this.battingStyle,
    required this.bowlingStyle,
    required this.nationality,
    required this.dateOfBirth,
    required this.jerseyNumber,
    required this.isCaptain,
    required this.isWicketKeeper,
    required this.battingStats,
    required this.bowlingStats,
    this.isInPlayingXI = true,
  });
}

/// Career batting statistics.
class BattingStats {
  final int matches;
  final int innings;
  final int runs;
  final int highScore;
  final double average;
  final double strikeRate;
  final int hundreds;
  final int fifties;
  final int fours;
  final int sixes;

  const BattingStats({
    required this.matches,
    required this.innings,
    required this.runs,
    required this.highScore,
    required this.average,
    required this.strikeRate,
    required this.hundreds,
    required this.fifties,
    required this.fours,
    required this.sixes,
  });
}

/// Career bowling statistics.
class BowlingStats {
  final int matches;
  final int innings;
  final double overs;
  final int wickets;
  final int runs;
  final double average;
  final double economy;
  final double strikeRate;
  final int fiveWickets;
  final String bestBowling; // e.g. "5/20"

  const BowlingStats({
    required this.matches,
    required this.innings,
    required this.overs,
    required this.wickets,
    required this.runs,
    required this.average,
    required this.economy,
    required this.strikeRate,
    required this.fiveWickets,
    required this.bestBowling,
  });
}

enum PlayerRole { batsman, bowler, allRounder, wicketKeeper }
enum BattingStyle { rightHand, leftHand }
enum BowlingStyle { rightArmPace, leftArmPace, rightArmSpin, leftArmSpin, none }

class ScorerPlayer {
  final String id;
  final String name;
  final String teamId;
  final String tournamentId;
  final PlayerRole role;
  final BattingStyle battingStyle;
  final BowlingStyle bowlingStyle;
  final int? jerseyNumber;
  final String? photoUrl;

  const ScorerPlayer({
    required this.id,
    required this.name,
    required this.teamId,
    required this.tournamentId,
    required this.role,
    required this.battingStyle,
    required this.bowlingStyle,
    this.jerseyNumber,
    this.photoUrl,
  });

  String get userId => id;

  ScorerPlayer copyWith({
    String? id,
    String? name,
    String? teamId,
    String? tournamentId,
    PlayerRole? role,
    BattingStyle? battingStyle,
    BowlingStyle? bowlingStyle,
    int? jerseyNumber,
    String? photoUrl,
  }) {
    return ScorerPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      teamId: teamId ?? this.teamId,
      tournamentId: tournamentId ?? this.tournamentId,
      role: role ?? this.role,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

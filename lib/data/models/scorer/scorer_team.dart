class ScorerTeam {
  final String id;
  final String name;
  final String shortCode;
  final String tournamentId;
  final List<String> playerIds;
  final String? logoUrl;
  final bool isEntryFeePaid;
  final String? ownerName;
  final String? whatsappNumber;

  const ScorerTeam({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.tournamentId,
    required this.playerIds,
    this.logoUrl,
    this.isEntryFeePaid = false,
    this.ownerName,
    this.whatsappNumber,
  });

  String get shortName => shortCode;
  List<String> get playersIds => playerIds;

  ScorerTeam copyWith({
    String? id,
    String? name,
    String? shortCode,
    String? tournamentId,
    List<String>? playerIds,
    String? logoUrl,
    bool? isEntryFeePaid,
    String? ownerName,
    String? whatsappNumber,
  }) {
    return ScorerTeam(
      id: id ?? this.id,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      tournamentId: tournamentId ?? this.tournamentId,
      playerIds: playerIds ?? this.playerIds,
      logoUrl: logoUrl ?? this.logoUrl,
      isEntryFeePaid: isEntryFeePaid ?? this.isEntryFeePaid,
      ownerName: ownerName ?? this.ownerName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
    );
  }
}


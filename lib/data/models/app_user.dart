enum AppUserRole { spectator, scorer }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final AppUserRole role;
  final String? organization;
  final String? favoriteTournamentId;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    this.organization,
    this.favoriteTournamentId,
    required this.createdAt,
  });

  bool get isScorer => role == AppUserRole.scorer;
  bool get isSpectator => role == AppUserRole.spectator;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    AppUserRole? role,
    String? organization,
    String? favoriteTournamentId,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      organization: organization ?? this.organization,
      favoriteTournamentId: favoriteTournamentId ?? this.favoriteTournamentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'role': role.name,
    'organization': organization,
    'favoriteTournamentId': favoriteTournamentId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String? ?? '',
    address: json['address'] as String? ?? '',
    role: AppUserRole.values.firstWhere((r) => r.name == json['role']),
    organization: json['organization'] as String?,
    favoriteTournamentId: json['favoriteTournamentId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

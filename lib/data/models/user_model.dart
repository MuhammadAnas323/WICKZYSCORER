class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? favoriteTeamId;
  final String role;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool notificationsEnabled;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.favoriteTeamId,
    this.role = 'user',
    required this.createdAt,
    required this.lastActive,
    this.notificationsEnabled = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      favoriteTeamId: json['favoriteTeamId'] as String?,
      role: json['role'] as String? ?? 'user',
      createdAt: (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      lastActive: (json['lastActive'] as dynamic)?.toDate() ?? DateTime.now(),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'favoriteTeamId': favoriteTeamId,
    'role': role,
    'createdAt': createdAt,
    'lastActive': lastActive,
    'notificationsEnabled': notificationsEnabled,
  };

  bool get isAdmin => role == 'admin';
}

class AdminSettings {
  final String apiBaseUrl;
  final String apiKey;
  final String apiHost;
  final String videoUrl;
  final String videoMatchName;
  final DateTime? updatedAt;

  const AdminSettings({
    this.apiBaseUrl = '',
    this.apiKey = '',
    this.apiHost = '',
    this.videoUrl = '',
    this.videoMatchName = '',
    this.updatedAt,
  });

  AdminSettings copyWith({
    String? apiBaseUrl,
    String? apiKey,
    String? apiHost,
    String? videoUrl,
    String? videoMatchName,
    DateTime? updatedAt,
  }) => AdminSettings(
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    apiKey: apiKey ?? this.apiKey,
    apiHost: apiHost ?? this.apiHost,
    videoUrl: videoUrl ?? this.videoUrl,
    videoMatchName: videoMatchName ?? this.videoMatchName,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'apiBaseUrl': apiBaseUrl,
    'apiKey': apiKey,
    'apiHost': apiHost,
    'videoUrl': videoUrl,
    'videoMatchName': videoMatchName,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory AdminSettings.fromJson(Map<String, dynamic> json) => AdminSettings(
    apiBaseUrl: (json['apiBaseUrl'] as String?) ?? '',
    apiKey: (json['apiKey'] as String?) ?? '',
    apiHost: (json['apiHost'] as String?) ?? '',
    videoUrl: (json['videoUrl'] as String?) ?? '',
    videoMatchName: (json['videoMatchName'] as String?) ?? '',
    updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
  );

  static const String prefKey = 'admin_settings';
}

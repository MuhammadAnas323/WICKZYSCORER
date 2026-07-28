class IptvSettings {
  final String playlistUrl;
  final DateTime? lastUpdated;
  final int channelCount;

  const IptvSettings({
    this.playlistUrl = '',
    this.lastUpdated,
    this.channelCount = 0,
  });

  IptvSettings copyWith({
    String? playlistUrl,
    DateTime? lastUpdated,
    int? channelCount,
  }) => IptvSettings(
    playlistUrl: playlistUrl ?? this.playlistUrl,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    channelCount: channelCount ?? this.channelCount,
  );

  Map<String, dynamic> toJson() => {
    'playlistUrl': playlistUrl,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'channelCount': channelCount,
  };

  factory IptvSettings.fromJson(Map<String, dynamic> json) => IptvSettings(
    playlistUrl: (json['playlistUrl'] as String?) ?? '',
    lastUpdated: json['lastUpdated'] != null
        ? (json['lastUpdated'] is DateTime
            ? json['lastUpdated'] as DateTime
            : DateTime.tryParse(json['lastUpdated'] as String))
        : null,
    channelCount: (json['channelCount'] as num?)?.toInt() ?? 0,
  );

  static const String firestorePath = 'settings/iptv';
  static const String prefKey = 'iptv_settings';
}

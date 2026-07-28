class IptvChannel {
  final String channelId;
  final String channelName;
  final String? tvgName;
  final String? logo;
  final String? group;
  final String? country;
  final String streamUrl;
  final String playlistUrl;
  final DateTime createdAt;
  final bool isAvailable;

  const IptvChannel({
    required this.channelId,
    required this.channelName,
    this.tvgName,
    this.logo,
    this.group,
    this.country,
    required this.streamUrl,
    required this.playlistUrl,
    required this.createdAt,
    this.isAvailable = true,
  });

  IptvChannel copyWith({bool? isAvailable}) => IptvChannel(
    channelId: channelId,
    channelName: channelName,
    tvgName: tvgName,
    logo: logo,
    group: group,
    country: country,
    streamUrl: streamUrl,
    playlistUrl: playlistUrl,
    createdAt: createdAt,
    isAvailable: isAvailable ?? this.isAvailable,
  );

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'channelName': channelName,
    'tvgName': tvgName,
    'logo': logo,
    'group': group,
    'country': country,
    'streamUrl': streamUrl,
    'playlistUrl': playlistUrl,
    'createdAt': createdAt.toIso8601String(),
    'isAvailable': isAvailable,
  };

  Map<String, dynamic> toFirestore() => {
    'channelId': channelId,
    'channelName': channelName,
    'tvgName': tvgName ?? '',
    'logo': logo ?? '',
    'group': group ?? '',
    'country': country ?? '',
    'streamUrl': streamUrl,
    'playlistUrl': playlistUrl,
    'createdAt': createdAt.toIso8601String(),
    'isAvailable': isAvailable,
  };

  factory IptvChannel.fromJson(Map<String, dynamic> json) => IptvChannel(
    channelId: (json['channelId'] as String?) ?? '',
    channelName: (json['channelName'] as String?) ?? '',
    tvgName: json['tvgName'] as String?,
    logo: json['logo'] as String?,
    group: json['group'] as String?,
    country: json['country'] as String?,
    streamUrl: (json['streamUrl'] as String?) ?? '',
    playlistUrl: (json['playlistUrl'] as String?) ?? '',
    createdAt: json['createdAt'] != null
        ? (json['createdAt'] is DateTime
            ? json['createdAt'] as DateTime
            : DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
        : DateTime.now(),
    isAvailable: (json['isAvailable'] as bool?) ?? true,
  );
}

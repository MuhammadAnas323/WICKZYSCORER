class M3uChannel {
  final String name;
  final String? logo;
  final String? group;
  final String url;
  final bool isAvailable;

  const M3uChannel({
    required this.name,
    this.logo,
    this.group,
    required this.url,
    this.isAvailable = true,
  });

  M3uChannel copyWith({bool? isAvailable}) => M3uChannel(
    name: name,
    logo: logo,
    group: group,
    url: url,
    isAvailable: isAvailable ?? this.isAvailable,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'logo': logo,
    'group': group,
    'url': url,
    'isAvailable': isAvailable,
  };

  factory M3uChannel.fromJson(Map<String, dynamic> json) => M3uChannel(
    name: (json['name'] as String?) ?? '',
    logo: json['logo'] as String?,
    group: json['group'] as String?,
    url: (json['url'] as String?) ?? '',
    isAvailable: (json['isAvailable'] as bool?) ?? true,
  );
}

class M3uPlaylist {
  final String sourceUrl;
  final String title;
  final List<M3uChannel> channels;
  final DateTime parsedAt;
  final int totalChannels;
  final int availableChannels;

  const M3uPlaylist({
    required this.sourceUrl,
    this.title = '',
    required this.channels,
    required this.parsedAt,
    this.totalChannels = 0,
    this.availableChannels = 0,
  });

  List<String> get groups => channels
      .map((c) => c.group)
      .where((g) => g != null && g!.isNotEmpty)
      .toSet()
      .map((g) => g!)
      .toList()
    ..sort();

  Map<String, dynamic> toJson() => {
    'sourceUrl': sourceUrl,
    'title': title,
    'parsedAt': parsedAt.toIso8601String(),
    'totalChannels': totalChannels,
    'availableChannels': availableChannels,
    'channels': channels.map((c) => c.toJson()).toList(),
  };

  factory M3uPlaylist.fromJson(Map<String, dynamic> json) => M3uPlaylist(
    sourceUrl: (json['sourceUrl'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    parsedAt: json['parsedAt'] != null ? DateTime.parse(json['parsedAt'] as String) : DateTime.now(),
    totalChannels: (json['totalChannels'] as num?)?.toInt() ?? 0,
    availableChannels: (json['availableChannels'] as num?)?.toInt() ?? 0,
    channels: (json['channels'] as List<dynamic>?)
        ?.map((e) => M3uChannel.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );

  static const String prefKey = 'm3u_playlist';
}

class ResolvedStream {
  final String url;
  final String format;

  const ResolvedStream({required this.url, required this.format});

  factory ResolvedStream.fromJson(Map<String, dynamic> json) => ResolvedStream(
    url: (json['url'] as String?) ?? '',
    format: (json['format'] as String?) ?? 'unknown',
  );

  Map<String, dynamic> toJson() => {'url': url, 'format': format};
}

class VideoSourceResult {
  final bool success;
  final String message;
  final String? detail;
  final List<ResolvedStream> streams;

  const VideoSourceResult({
    required this.success,
    required this.message,
    this.detail,
    this.streams = const [],
  });

  factory VideoSourceResult.fromJson(Map<String, dynamic> json) => VideoSourceResult(
    success: (json['success'] as bool?) ?? false,
    message: (json['message'] as String?) ?? '',
    detail: json['detail'] as String?,
    streams: (json['streams'] as List<dynamic>?)
        ?.map((e) => ResolvedStream.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'detail': detail,
    'streams': streams.map((e) => e.toJson()).toList(),
  };
}

class VideoSourceSettings {
  final String userUrl;
  final String? resolvedStreamUrl;
  final String? resolvedFormat;
  final DateTime? lastResolvedAt;

  const VideoSourceSettings({
    this.userUrl = '',
    this.resolvedStreamUrl,
    this.resolvedFormat,
    this.lastResolvedAt,
  });

  VideoSourceSettings copyWith({
    String? userUrl,
    String? resolvedStreamUrl,
    String? resolvedFormat,
    DateTime? lastResolvedAt,
  }) => VideoSourceSettings(
    userUrl: userUrl ?? this.userUrl,
    resolvedStreamUrl: resolvedStreamUrl ?? this.resolvedStreamUrl,
    resolvedFormat: resolvedFormat ?? this.resolvedFormat,
    lastResolvedAt: lastResolvedAt ?? this.lastResolvedAt,
  );

  Map<String, dynamic> toJson() => {
    'userUrl': userUrl,
    'resolvedStreamUrl': resolvedStreamUrl,
    'resolvedFormat': resolvedFormat,
    'lastResolvedAt': lastResolvedAt?.toIso8601String(),
  };

  factory VideoSourceSettings.fromJson(Map<String, dynamic> json) => VideoSourceSettings(
    userUrl: (json['userUrl'] as String?) ?? '',
    resolvedStreamUrl: json['resolvedStreamUrl'] as String?,
    resolvedFormat: json['resolvedFormat'] as String?,
    lastResolvedAt: json['lastResolvedAt'] != null ? DateTime.tryParse(json['lastResolvedAt'] as String) : null,
  );

  static const String prefKey = 'video_source_settings';
}

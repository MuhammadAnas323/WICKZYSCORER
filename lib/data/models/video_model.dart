class VideoModel {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String category;
  final String? matchId;
  final String? tournamentId;
  final DateTime publishedAt;
  final int views;
  final Duration duration;

  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.category,
    this.matchId,
    this.tournamentId,
    required this.publishedAt,
    this.views = 0,
    this.duration = Duration.zero,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      category: json['category'] as String? ?? '',
      matchId: json['matchId'] as String?,
      tournamentId: json['tournamentId'] as String?,
      publishedAt: (json['publishedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      views: (json['views'] as num?)?.toInt() ?? 0,
      duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'videoUrl': videoUrl,
    'category': category,
    'matchId': matchId,
    'tournamentId': tournamentId,
    'publishedAt': publishedAt,
    'views': views,
    'duration': duration.inSeconds,
  };
}

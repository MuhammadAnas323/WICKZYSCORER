// lib/data/models/stream_model.dart
// Live stream model for broadcaster / viewer screens.

/// Status of a live stream.
enum StreamStatus { idle, preparing, live, ended }

/// A user-owned live stream (broadcaster's own camera feed).
enum VideoSourceTypeEnum { camera, screen }

class StreamModel {
  final String id;
  final String title;
  final String description;
  final String broadcasterId;
  final String broadcasterName;
  final String broadcasterAvatar;
  final String? matchId; // linked match if tagged
  final String? matchTitle;
  final String thumbnailUrl;
  final StreamStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int viewerCount;
  final int peakViewers;
  final int totalComments;
  final bool saveReplay; // user's choice to save their own feed
  final String? channelName; // Agora channel for live video
  final VideoSourceTypeEnum videoSourceType; // camera or screen

  const StreamModel({
    required this.id,
    required this.title,
    required this.description,
    required this.broadcasterId,
    required this.broadcasterName,
    required this.broadcasterAvatar,
    this.matchId,
    this.matchTitle,
    required this.thumbnailUrl,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.viewerCount = 0,
    this.peakViewers = 0,
    this.totalComments = 0,
    this.saveReplay = false,
    this.channelName,
    this.videoSourceType = VideoSourceTypeEnum.camera,
  });

  StreamModel copyWith({
    StreamStatus? status,
    int? viewerCount,
    int? peakViewers,
    int? totalComments,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? saveReplay,
    String? channelName,
    VideoSourceTypeEnum? videoSourceType,
  }) {
    return StreamModel(
      id: id,
      title: title,
      description: description,
      broadcasterId: broadcasterId,
      broadcasterName: broadcasterName,
      broadcasterAvatar: broadcasterAvatar,
      matchId: matchId,
      matchTitle: matchTitle,
      thumbnailUrl: thumbnailUrl,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      viewerCount: viewerCount ?? this.viewerCount,
      peakViewers: peakViewers ?? this.peakViewers,
      totalComments: totalComments ?? this.totalComments,
      saveReplay: saveReplay ?? this.saveReplay,
      channelName: channelName ?? this.channelName,
      videoSourceType: videoSourceType ?? this.videoSourceType,
    );
  }
}

/// News / highlight feed item.
class NewsItem {
  final String id;
  final String headline;
  final String source;
  final String thumbnailUrl;
  final DateTime publishedAt;
  final String category;
  final String url;

  const NewsItem({
    required this.id,
    required this.headline,
    required this.source,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.category,
    required this.url,
  });
}

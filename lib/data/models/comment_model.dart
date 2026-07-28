// lib/data/models/comment_model.dart
// Live comment and notification models.

/// A single live comment in a stream or match chat.
class CommentModel {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String text;
  final DateTime timestamp;
  final bool isHighlighted; // pinned / moderator comment

  const CommentModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.text,
    required this.timestamp,
    this.isHighlighted = false,
  });
}

/// App notification model.
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'match_start' | 'wicket' | 'boundary' | 'result' | 'news' | 'stream'
  final DateTime timestamp;
  final bool isRead;
  final String? matchId;
  final String? deepLink;
  final String iconEmoji;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.matchId,
    this.deepLink,
    required this.iconEmoji,
  });
}

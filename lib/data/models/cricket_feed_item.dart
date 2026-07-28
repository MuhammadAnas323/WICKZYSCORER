import 'dart:convert';

class CricketFeedItem {
  final String id;
  final String title;
  final String subtitle;
  final String? score;
  final String status; // 'LIVE', 'UPCOMING', 'CHANNEL', 'COMPLETED'
  final String? streamUrl;
  final String? imageUrl;
  final String apiSourceId;
  final String apiSourceName;
  final String? format;
  final Map<String, dynamic>? extraData;

  const CricketFeedItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.score,
    required this.status,
    this.streamUrl,
    this.imageUrl,
    required this.apiSourceId,
    required this.apiSourceName,
    this.format,
    this.extraData,
  });

  CricketFeedItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? score,
    String? status,
    String? streamUrl,
    String? imageUrl,
    String? apiSourceId,
    String? apiSourceName,
    String? format,
    Map<String, dynamic>? extraData,
  }) {
    return CricketFeedItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      score: score ?? this.score,
      status: status ?? this.status,
      streamUrl: streamUrl ?? this.streamUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      apiSourceId: apiSourceId ?? this.apiSourceId,
      apiSourceName: apiSourceName ?? this.apiSourceName,
      format: format ?? this.format,
      extraData: extraData ?? this.extraData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'score': score,
      'status': status,
      'streamUrl': streamUrl,
      'imageUrl': imageUrl,
      'apiSourceId': apiSourceId,
      'apiSourceName': apiSourceName,
      'format': format,
      'extraData': extraData,
    };
  }

  factory CricketFeedItem.fromMap(Map<String, dynamic> map, {required String apiSourceId, required String apiSourceName}) {
    return CricketFeedItem(
      id: map['id']?.toString() ?? map['match_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? map['name'] ?? map['match_title'] ?? map['teams'] ?? 'Cricket Match',
      subtitle: map['subtitle'] ?? map['description'] ?? map['series'] ?? map['venue'] ?? 'Cricket Feed',
      score: map['score'] ?? map['live_score'] ?? map['runs'],
      status: (map['status'] ?? 'LIVE').toString().toUpperCase(),
      streamUrl: map['streamUrl'] ?? map['stream_url'] ?? map['url'] ?? map['link'],
      imageUrl: map['imageUrl'] ?? map['image_url'] ?? map['banner'] ?? map['logo'],
      apiSourceId: apiSourceId,
      apiSourceName: apiSourceName,
      format: map['format'] ?? map['match_type'] ?? 'T20',
      extraData: map['extraData'] is Map<String, dynamic> ? map['extraData'] : null,
    );
  }

  String toJson() => json.encode(toMap());
}

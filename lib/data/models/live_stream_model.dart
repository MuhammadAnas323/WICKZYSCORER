import 'package:cloud_firestore/cloud_firestore.dart';

class LiveStreamModel {
  final String id;
  final String channelId;
  final int hostUid;
  final String hostId;
  final String hostName;
  final String hostAvatar;
  final String? title;
  final bool isLive;
  final int viewerCount;
  final DateTime createdAt;
  final DateTime? endedAt;

  const LiveStreamModel({
    required this.id,
    required this.channelId,
    required this.hostUid,
    required this.hostId,
    required this.hostName,
    required this.hostAvatar,
    this.title,
    this.isLive = true,
    this.viewerCount = 0,
    required this.createdAt,
    this.endedAt,
  });
}

LiveStreamModel liveStreamModelFromJson(Map<String, dynamic> json, String id) {
  return LiveStreamModel(
    id: id,
    channelId: json['channelId'] as String? ?? '',
    hostUid: json['hostUid'] as int? ?? 0,
    hostId: json['hostId'] as String? ?? '',
    hostName: json['hostName'] as String? ?? '',
    hostAvatar: json['hostAvatar'] as String? ?? '',
    title: json['title'] as String?,
    isLive: json['isLive'] as bool? ?? false,
    viewerCount: json['viewerCount'] as int? ?? 0,
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    endedAt: (json['endedAt'] as Timestamp?)?.toDate(),
  );
}

extension LiveStreamModelJson on LiveStreamModel {
  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'hostUid': hostUid,
    'hostId': hostId,
    'hostName': hostName,
    'hostAvatar': hostAvatar,
    'title': title,
    'isLive': isLive,
    'viewerCount': viewerCount,
    'createdAt': Timestamp.fromDate(createdAt),
    if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
  };
}

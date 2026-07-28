import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stream_model.dart';
import '../models/comment_model.dart';

abstract class StreamingRepository {
  Future<List<StreamModel>> getActiveStreams();
  Future<StreamModel?> getStreamById(String id);
  Future<List<CommentModel>> getCommentsForStream(String streamId);
  Stream<CommentModel> watchComments(String streamId);
  Stream<int> watchViewerCount(String streamId);
  Future<void> postComment(String streamId, String text);

  Future<void> addStream(StreamModel stream);
  Future<void> removeStream(String id);
  Stream<List<StreamModel>> watchActiveStreams();
}

class FirestoreStreamingRepository implements StreamingRepository {
  final FirebaseFirestore _firestore;

  final Map<String, StreamController<CommentModel>> _commentControllers = {};
  final Map<String, StreamController<int>> _viewerControllers = {};

  FirestoreStreamingRepository(this._firestore);

  @override
  Future<List<StreamModel>> getActiveStreams() async {
    try {
      final snapshot = await _firestore
          .collection('streams')
          .where('isLive', isEqualTo: true)
          .orderBy('startedAt', descending: true)
          .get();
      return _streamsFromSnapshot(snapshot);
    } on FirebaseException {
      // Composite index missing — fall back to unordered query
      try {
        final snapshot = await _firestore
            .collection('streams')
            .where('isLive', isEqualTo: true)
            .get();
        return _streamsFromSnapshot(snapshot);
      } on FirebaseException {
        return [];
      }
    }
  }

  @override
  Future<StreamModel?> getStreamById(String id) async {
    try {
      final doc = await _firestore.collection('streams').doc(id).get();
      if (!doc.exists) return null;
      return _streamFromDoc(doc);
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<List<CommentModel>> getCommentsForStream(String streamId) async {
    try {
      final snapshot = await _firestore
          .collection('streams')
          .doc(streamId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CommentModel(
          id: doc.id,
          userId: data['userId'] as String? ?? '',
          username: data['username'] as String? ?? '',
          avatarUrl: data['avatarUrl'] as String? ?? '',
          text: data['text'] as String? ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isHighlighted: data['isHighlighted'] as bool? ?? false,
        );
      }).toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Stream<CommentModel> watchComments(String streamId) {
    if (!_commentControllers.containsKey(streamId)) {
      _commentControllers[streamId] = StreamController<CommentModel>.broadcast();
      _firestore
          .collection('streams')
          .doc(streamId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data()!;
            final comment = CommentModel(
              id: change.doc.id,
              userId: data['userId'] as String? ?? '',
              username: data['username'] as String? ?? '',
              avatarUrl: data['avatarUrl'] as String? ?? '',
              text: data['text'] as String? ?? '',
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isHighlighted: data['isHighlighted'] as bool? ?? false,
            );
            _commentControllers[streamId]?.add(comment);
          }
        }
      });
    }
    return _commentControllers[streamId]!.stream;
  }

  @override
  Stream<int> watchViewerCount(String streamId) {
    if (!_viewerControllers.containsKey(streamId)) {
      _viewerControllers[streamId] = StreamController<int>.broadcast();
      _firestore
          .collection('streams')
          .doc(streamId)
          .snapshots()
          .listen((doc) {
        if (!doc.exists) return;
        final count = doc.data()?['viewerCount'] as int? ?? 0;
        _viewerControllers[streamId]?.add(count);
      });
    }
    return _viewerControllers[streamId]!.stream;
  }

  @override
  Future<void> postComment(String streamId, String text) async {
    try {
      await _firestore
          .collection('streams')
          .doc(streamId)
          .collection('comments')
          .add({
        'userId': 'local_user',
        'username': 'You',
        'avatarUrl': 'https://ui-avatars.com/api/?name=You&background=random',
        'text': text,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'isHighlighted': false,
      });
    } on FirebaseException {
      // silently fail
    }
  }

  @override
  Future<void> addStream(StreamModel stream) async {
    try {
      await _firestore.collection('streams').doc(stream.id).set({
        'title': stream.title,
        'description': stream.description,
        'broadcasterId': stream.broadcasterId,
        'broadcasterName': stream.broadcasterName,
        'broadcasterAvatar': stream.broadcasterAvatar,
        'thumbnailUrl': stream.thumbnailUrl,
        'matchId': stream.matchId,
        'matchTitle': stream.matchTitle,
        'channelName': stream.channelName,
        'status': 'live',
        'isLive': true,
        'viewerCount': 1,
        'peakViewers': 0,
        'totalComments': 0,
        'saveReplay': stream.saveReplay,
        'videoSourceType': stream.videoSourceType.name,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'startedAt': Timestamp.fromDate(stream.startedAt ?? DateTime.now()),
      });
    } on FirebaseException {
      // silently fail
    }
  }

  @override
  Future<void> removeStream(String id) async {
    try {
      await _firestore.collection('streams').doc(id).update({
        'isLive': false,
        'status': 'ended',
        'endedAt': Timestamp.fromDate(DateTime.now()),
      });
    } on FirebaseException {
      // silently fail
    }
    _commentControllers[id]?.close();
    _commentControllers.remove(id);
    _viewerControllers[id]?.close();
    _viewerControllers.remove(id);
  }

  @override
  Stream<List<StreamModel>> watchActiveStreams() {
    final controller = StreamController<List<StreamModel>>.broadcast();
    StreamSubscription? firestoreSub;
    Timer? pollTimer;

    void startPolling() {
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        try {
          final snapshot = await _firestore
              .collection('streams')
              .where('isLive', isEqualTo: true)
              .get();
          final streams = snapshot.docs.map((doc) => _streamFromDoc(doc)).toList();
          if (!controller.isClosed) controller.add(streams);
        } catch (_) {}
      });
    }

    firestoreSub = _firestore
        .collection('streams')
        .where('isLive', isEqualTo: true)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (!controller.isClosed) controller.add(_streamsFromSnapshot(snapshot));
          },
          onError: (_) {
            startPolling();
          },
        );

    controller.onCancel = () {
      firestoreSub?.cancel();
      pollTimer?.cancel();
    };

    return controller.stream;
  }

  List<StreamModel> _streamsFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) => _streamFromDoc(doc)).toList();
  }

  StreamModel _streamFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sourceTypeStr = data['videoSourceType'] as String? ?? 'camera';
    return StreamModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      broadcasterId: data['broadcasterId'] as String? ?? '',
      broadcasterName: data['broadcasterName'] as String? ?? '',
      broadcasterAvatar: data['broadcasterAvatar'] as String? ?? '',
      matchId: data['matchId'] as String?,
      matchTitle: data['matchTitle'] as String?,
      channelName: data['channelName'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      status: (data['status'] as String?) == 'live'
          ? StreamStatus.live
          : StreamStatus.ended,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      viewerCount: data['viewerCount'] as int? ?? 0,
      peakViewers: data['peakViewers'] as int? ?? 0,
      totalComments: data['totalComments'] as int? ?? 0,
      saveReplay: data['saveReplay'] as bool? ?? false,
      videoSourceType: sourceTypeStr == 'screen'
          ? VideoSourceTypeEnum.screen
          : VideoSourceTypeEnum.camera,
    );
  }

  void dispose() {
    for (final c in _commentControllers.values) {
      c.close();
    }
    for (final c in _viewerControllers.values) {
      c.close();
    }
  }
}

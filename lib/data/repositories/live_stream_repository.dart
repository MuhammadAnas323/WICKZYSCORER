import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportyapp/data/models/live_stream_model.dart';

abstract class LiveStreamRepository {
  Future<void> createStream(LiveStreamModel stream);
  Future<void> endStream(String streamId);
  Future<LiveStreamModel?> getStreamById(String streamId);
  Stream<LiveStreamModel?> watchStream(String streamId);
  Stream<List<LiveStreamModel>> watchActiveStreams();
}

class FirestoreLiveStreamRepository implements LiveStreamRepository {
  final FirebaseFirestore _firestore;

  FirestoreLiveStreamRepository(this._firestore);

  CollectionReference get _liveStreams =>
      _firestore.collection('live_streams');

  @override
  Future<void> createStream(LiveStreamModel stream) async {
    await _liveStreams.doc(stream.id).set(stream.toJson());
  }

  @override
  Future<void> endStream(String streamId) async {
    await _liveStreams.doc(streamId).update({
      'isLive': false,
      'endedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<LiveStreamModel?> getStreamById(String streamId) async {
    try {
      final doc = await _liveStreams.doc(streamId).get();
      if (!doc.exists || doc.data() == null) return null;
      return liveStreamModelFromJson(doc.data()! as Map<String, dynamic>, doc.id);
    } on FirebaseException {
      return null;
    }
  }

  /// Real-time snapshot of a single stream document.
  /// Emits null when the document is deleted.
  @override
  Stream<LiveStreamModel?> watchStream(String streamId) {
    return _liveStreams
        .doc(streamId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return liveStreamModelFromJson(
              doc.data()! as Map<String, dynamic>, doc.id);
        });
  }

  /// Reactive query of all streams where isLive == true.
  /// Cards disappear from the feed the instant the backend flips isLive to false.
  @override
  Stream<List<LiveStreamModel>> watchActiveStreams() {
    return _liveStreams
        .where('isLive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => liveStreamModelFromJson(
                d.data() as Map<String, dynamic>, d.id))
            .toList())
        .handleError((_) => <LiveStreamModel>[]);
  }
}

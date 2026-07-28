import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportyapp/data/models/video_model.dart';

abstract class VideoRepository {
  Future<List<VideoModel>> getAllVideos();
  Future<List<VideoModel>> getVideosByCategory(String category);
  Future<VideoModel?> getVideoById(String id);
  Future<void> addVideo(VideoModel video);
}

class FirestoreVideoRepository implements VideoRepository {
  final FirebaseFirestore _firestore;

  FirestoreVideoRepository(this._firestore);

  @override
  Future<List<VideoModel>> getAllVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('publishedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => VideoModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<List<VideoModel>> getVideosByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('category', isEqualTo: category)
          .orderBy('publishedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => VideoModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<VideoModel?> getVideoById(String id) async {
    try {
      final doc = await _firestore.collection('videos').doc(id).get();
      if (!doc.exists) return null;
      return VideoModel.fromJson({...doc.data()!, 'id': doc.id});
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<void> addVideo(VideoModel video) async {
    try {
      await _firestore.collection('videos').doc(video.id).set(video.toJson());
    } on FirebaseException {
      // silently fail
    }
  }
}

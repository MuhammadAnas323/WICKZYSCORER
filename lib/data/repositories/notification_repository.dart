import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}

class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _firestore;

  FirestoreNotificationRepository(this._firestore);

  @override
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final snap = await _firestore
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        return NotificationModel(
          id: doc.id,
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          type: data['type'] as String? ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isRead: data['isRead'] as bool? ?? false,
          matchId: data['matchId'] as String?,
          deepLink: data['deepLink'] as String?,
          iconEmoji: data['iconEmoji'] as String? ?? '',
        );
      }).toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await _firestore.collection('notifications').doc(id).update({'isRead': true});
    } on FirebaseException {
      // silently fail
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      final snap = await _firestore
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } on FirebaseException {
      // silently fail
    }
  }
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/iptv_channel.dart';
import 'package:sportyapp/data/models/iptv_settings.dart';

class IptvRepository {
  final FirebaseFirestore _firestore;

  IptvRepository(this._firestore);

  static const String _channelsCollection = 'iptv_channels';

  Future<void> saveChannels(List<IptvChannel> channels) async {
    final batch = _firestore.batch();
    for (final channel in channels) {
      final docRef = _firestore.collection(_channelsCollection).doc(channel.channelId);
      batch.set(docRef, channel.toFirestore());
    }
    await batch.commit();
  }

  Future<void> saveChannel(IptvChannel channel) async {
    await _firestore
        .collection(_channelsCollection)
        .doc(channel.channelId)
        .set(channel.toFirestore());
  }

  Future<List<IptvChannel>> loadChannels() async {
    final snapshot = await _firestore
        .collection(_channelsCollection)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IptvChannel.fromJson(doc.data()))
        .toList();
  }

  Stream<List<IptvChannel>> watchChannels() {
    return _firestore
        .collection(_channelsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IptvChannel.fromJson(doc.data()))
            .toList());
  }

  Future<void> deleteChannel(String channelId) async {
    await _firestore.collection(_channelsCollection).doc(channelId).delete();
  }

  Future<void> clearAllChannels() async {
    final snapshot = await _firestore.collection(_channelsCollection).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<int> channelCount() async {
    final snapshot = await _firestore.collection(_channelsCollection).count().get();
    return snapshot.count ?? 0;
  }

  Future<IptvSettings> loadSettings() async {
    try {
      final doc = await _firestore.doc(IptvSettings.firestorePath).get();
      if (doc.exists) {
        final data = doc.data()!;
        return IptvSettings(
          playlistUrl: (data['playlistUrl'] as String?) ?? '',
          lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
          channelCount: (data['channelCount'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return const IptvSettings();
  }

  Future<void> saveSettings(IptvSettings settings) async {
    await _firestore.doc(IptvSettings.firestorePath).set({
      'playlistUrl': settings.playlistUrl,
      'lastUpdated': settings.lastUpdated != null
          ? Timestamp.fromDate(settings.lastUpdated!)
          : FieldValue.serverTimestamp(),
      'channelCount': settings.channelCount,
    });
  }

  Future<void> clearSettings() async {
    await _firestore.doc(IptvSettings.firestorePath).delete();
  }

  Future<void> cacheChannelsLocally(List<IptvChannel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = channels.map((c) => c.toJson()).toList();
    await prefs.setString('iptv_channels_cache', jsonEncode(jsonList));
  }

  Future<List<IptvChannel>?> loadCachedChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('iptv_channels_cache');
    if (cached == null) return null;
    try {
      final list = jsonDecode(cached) as List<dynamic>;
      return list.map((e) => IptvChannel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('iptv_channels_cache');
  }
}

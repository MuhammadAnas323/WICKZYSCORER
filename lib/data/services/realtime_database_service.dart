import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _db;

  RealtimeDatabaseService(this._db);

  DatabaseReference get _liveMatchesRef => _db.ref('liveMatches');

  Future<void> createLiveMatch(String matchId, Map<String, dynamic> data) async {
    await _liveMatchesRef.child(matchId).set(data);
  }

  Future<void> updateLiveMatch(String matchId, Map<String, dynamic> data) async {
    await _liveMatchesRef.child(matchId).update(data);
  }

  Future<void> deleteLiveMatch(String matchId) async {
    await _liveMatchesRef.child(matchId).remove();
  }

  Future<Map<String, dynamic>?> getLiveMatch(String matchId) async {
    final snap = await _liveMatchesRef.child(matchId).get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<Map<String, Map<String, dynamic>>> getAllLiveMatches() async {
    final snap = await _liveMatchesRef.get();
    if (!snap.exists || snap.value == null) return {};
    final map = snap.value as Map<dynamic, dynamic>;
    return map.map((key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value as Map)));
  }

  Stream<Map<String, dynamic>?> watchLiveMatch(String matchId) {
    return _liveMatchesRef.child(matchId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Stream<Map<String, Map<String, dynamic>>> watchAllLiveMatches() {
    return _liveMatchesRef.onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return <String, Map<String, dynamic>>{};
      final map = event.snapshot.value as Map;
      final result = <String, Map<String, dynamic>>{};
      for (final entry in map.entries) {
        try {
          result[entry.key.toString()] = _deepConvert(entry.value);
        } catch (_) {
          // Skip entries that can't be converted
        }
      }
      return result;
    });
  }

  /// Recursively converts RTDB's Map<Object?, Object?> into Map<String, dynamic>.
  static Map<String, dynamic> _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map((k, v) {
        if (v is Map) return MapEntry(k.toString(), _deepConvert(v));
        if (v is List) return MapEntry(k.toString(), _deepConvertList(v));
        return MapEntry(k.toString(), v);
      });
    }
    return <String, dynamic>{};
  }

  static List<dynamic> _deepConvertList(List list) {
    return list.map((v) {
      if (v is Map) return _deepConvert(v);
      if (v is List) return _deepConvertList(v);
      return v;
    }).toList();
  }

  Stream<DatabaseEvent> get rawOnValue => _liveMatchesRef.onValue;
}

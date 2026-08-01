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
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.map((key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value as Map)));
    });
  }

  Stream<DatabaseEvent> get rawOnValue => _liveMatchesRef.onValue;
}

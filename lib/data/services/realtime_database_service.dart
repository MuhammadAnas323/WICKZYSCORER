import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:sportyapp/data/models/live_match_data.dart';

abstract class IRealtimeDatabaseService {
  Future<void> createLiveMatchNode(String matchId);
  Future<void> updateLiveMatchData(String matchId, Map<String, dynamic> data);
  Future<void> removeLiveMatch(String matchId);
  Future<LiveMatchData?> getLiveMatchData(String matchId);
  Stream<LiveMatchData> watchLiveMatch(String matchId);
  Stream<DatabaseEvent> watchLiveMatchRaw(String matchId);
  Future<List<String>> getAllLiveMatchIds();
}

class RealtimeDatabaseService implements IRealtimeDatabaseService {
  final FirebaseDatabase _database;

  final Map<String, StreamSubscription<DatabaseEvent>> _subscriptions = {};

  RealtimeDatabaseService(this._database);

  DatabaseReference get _liveMatchesRef => _database.ref('live_matches');

  @override
  Future<void> createLiveMatchNode(String matchId) async {
    await _liveMatchesRef.child(matchId).set({
      'runs': 0,
      'wickets': 0,
      'overs': 0.0,
      'currentRunRate': 0.0,
      'target': null,
      'striker': '',
      'nonStriker': '',
      'bowler': '',
      'lastBall': '',
      'status': 'live',
      'stream': null,
      'commentary': 'Match started',
      'viewers': 0,
    });
  }

  @override
  Future<void> updateLiveMatchData(
      String matchId, Map<String, dynamic> data) async {
    await _liveMatchesRef.child(matchId).update(data);
  }

  @override
  Future<void> removeLiveMatch(String matchId) async {
    await _liveMatchesRef.child(matchId).remove();
    _subscriptions[matchId]?.cancel();
    _subscriptions.remove(matchId);
  }

  @override
  Future<LiveMatchData?> getLiveMatchData(String matchId) async {
    final snapshot = await _liveMatchesRef.child(matchId).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return LiveMatchData.fromJson(
        snapshot.value as Map<dynamic, dynamic>);
  }

  @override
  Stream<LiveMatchData> watchLiveMatch(String matchId) {
    return _liveMatchesRef.child(matchId).onValue.map((event) {
      if (event.snapshot.value == null) {
        throw Exception('Live match data not found');
      }
      return LiveMatchData.fromJson(
          event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  @override
  Stream<DatabaseEvent> watchLiveMatchRaw(String matchId) {
    return _liveMatchesRef.child(matchId).onValue;
  }

  @override
  Future<List<String>> getAllLiveMatchIds() async {
    final snapshot = await _liveMatchesRef.get();
    if (!snapshot.exists || snapshot.value == null) return [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    return map.keys.cast<String>().toList();
  }

  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}

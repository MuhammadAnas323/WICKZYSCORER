import 'dart:async';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/services/realtime_database_service.dart';

abstract class LiveMatchRepository {
  Future<void> createLiveMatch(String matchId);
  Future<void> updateLiveMatch(String matchId, Map<String, dynamic> data);
  Future<void> deleteLiveMatch(String matchId);
  Future<LiveMatchData?> getLiveData(String matchId);
  Stream<LiveMatchData> watchLiveMatch(String matchId);
  Future<List<String>> getAllLiveMatchIds();
}

class RealtimeLiveMatchRepository implements LiveMatchRepository {
  final IRealtimeDatabaseService _rtdb;

  RealtimeLiveMatchRepository(this._rtdb);

  @override
  Future<void> createLiveMatch(String matchId) async {
    await _rtdb.createLiveMatchNode(matchId);
  }

  @override
  Future<void> updateLiveMatch(String matchId, Map<String, dynamic> data) async {
    await _rtdb.updateLiveMatchData(matchId, data);
  }

  @override
  Future<void> deleteLiveMatch(String matchId) async {
    await _rtdb.removeLiveMatch(matchId);
  }

  @override
  Future<LiveMatchData?> getLiveData(String matchId) async {
    return await _rtdb.getLiveMatchData(matchId);
  }

  @override
  Stream<LiveMatchData> watchLiveMatch(String matchId) {
    return _rtdb.watchLiveMatch(matchId);
  }

  @override
  Future<List<String>> getAllLiveMatchIds() async {
    return await _rtdb.getAllLiveMatchIds();
  }
}

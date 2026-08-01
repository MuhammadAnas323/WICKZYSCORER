import 'package:sportyapp/data/services/realtime_database_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/live_match_data.dart';

abstract class LiveMatchRepository {
  Stream<LiveMatchData> watchLiveMatch(String matchId);
  Future<void> createLiveMatch(String matchId);
  Future<void> updateLiveMatch(String matchId, Map<String, dynamic> data);
  Future<List<String>> getAllLiveMatchIds();
  void dispose();
}

class RealtimeLiveMatchRepository implements LiveMatchRepository {
  final RealtimeDatabaseService _rtdb;

  RealtimeLiveMatchRepository(this._rtdb);

  @override
  Stream<LiveMatchData> watchLiveMatch(String matchId) {
    return _rtdb
        .watchLiveMatch(matchId)
        .where((data) => data != null)
        .map((data) => LiveMatchData.fromJson(data!));
  }

  @override
  Future<void> createLiveMatch(String matchId) async {
    await _rtdb.createLiveMatch(matchId, {
      'status': 'live',
      'currentInnings': 1,
      'battingTeamId': '',
      'bowlingTeamId': '',
      'score': {'runs': 0, 'wickets': 0, 'overs': 0, 'balls': 0},
      'target': null,
      'requiredRunRate': null,
      'striker': {
        'playerId': '',
        'name': '',
        'runs': 0,
        'balls': 0,
        'fours': 0,
        'sixes': 0
      },
      'nonStriker': {
        'playerId': '',
        'name': '',
        'runs': 0,
        'balls': 0,
        'fours': 0,
        'sixes': 0
      },
      'currentBowler': {
        'playerId': '',
        'name': '',
        'legalBalls': 0,
        'maidens': 0,
        'runs': 0,
        'wickets': 0,
        'wides': 0,
        'noBalls': 0
      },
      'thisOverBalls': [],
      'ballHistory': [],
      'lastUpdated': ServerValue.timestamp,
    });
  }

  @override
  Future<void> updateLiveMatch(
      String matchId, Map<String, dynamic> data) async {
    await _rtdb.updateLiveMatch(matchId, data);
  }

  @override
  Future<List<String>> getAllLiveMatchIds() async {
    final all = await _rtdb.getAllLiveMatches();
    return all.keys.toList();
  }

  @override
  void dispose() {}
}

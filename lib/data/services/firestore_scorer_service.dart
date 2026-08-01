import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/services/realtime_database_service.dart';

class FirestoreScorerService {
  final FirebaseFirestore _firestore;
  final RealtimeDatabaseService _rtdb;

  FirestoreScorerService(this._firestore, this._rtdb);

  CollectionReference get _matches => _firestore.collection('matches');

  Future<void> createMatchDoc(ScorerMatch match) async {
    await _matches.doc(match.id).set({
      'id': match.id,
      'tournamentId': match.tournamentId,
      'team1Id': match.team1Id,
      'team2Id': match.team2Id,
      'venue': match.venue,
      'dateTime': match.dateTime.toIso8601String(),
      'format': match.format.name,
      'overs': match.overs,
      'status': 'upcoming',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startMatch(ScorerMatch match) async {
    final inn1Batting = match.innings1?.battingTeamId;
    final inn1Bowling = match.innings1?.bowlingTeamId;

    await _matches.doc(match.id).update({
      'status': 'live',
      'tossWinnerId': match.tossWinnerId,
      'tossDecision': match.tossDecision?.name,
      'playingXI1': match.playingXI1,
      'playingXI2': match.playingXI2,
      'openingStrikerId': match.openingStrikerId,
      'openingNonStrikerId': match.openingNonStrikerId,
      'openingBowlerId': match.openingBowlerId,
    });

    await _rtdb.createLiveMatch(match.id, {
      'status': 'live',
      'currentInnings': 1,
      'battingTeamId': inn1Batting ?? match.team1Id,
      'bowlingTeamId': inn1Bowling ?? match.team2Id,
      'score': {'runs': 0, 'wickets': 0, 'overs': 0, 'balls': 0},
      'target': null,
      'requiredRunRate': null,
      'striker': {
        'playerId': match.openingStrikerId ?? '',
        'name': '',
        'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0,
      },
      'nonStriker': {
        'playerId': match.openingNonStrikerId ?? '',
        'name': '',
        'runs': 0, 'balls': 0, 'fours': 0, 'sixes': 0,
      },
      'currentBowler': {
        'playerId': match.openingBowlerId ?? '',
        'name': '',
        'legalBalls': 0, 'maidens': 0, 'runs': 0,
        'wickets': 0, 'wides': 0, 'noBalls': 0,
      },
      'thisOverBalls': [],
      'ballHistory': [],
      'lastUpdated': ServerValue.timestamp,
    });
  }

  Future<void> updateRtdb(String matchId, Map<String, dynamic> updates) async {
    await _rtdb.updateLiveMatch(matchId, updates);
  }

  Future<void> endMatch({
    required String matchId,
    required String winnerTeamId,
    required String resultSummary,
    required String? manOfTheMatch,
    required Map<String, dynamic> scorecards,
  }) async {
    await _matches.doc(matchId).update({
      'status': 'completed',
      'result': {
        'winnerTeamId': winnerTeamId,
        'summary': resultSummary,
        'manOfTheMatch': manOfTheMatch,
      },
      'scorecards': scorecards,
    });
    await _rtdb.deleteLiveMatch(matchId);
  }

  Future<List<ScorerMatch>> getScorerMatches() async {
    final snap = await _matches.get();
    return snap.docs
        .map((doc) => _scorerMatchFromDoc(doc))
        .toList();
  }

  Future<ScorerMatch?> getScorerMatch(String id) async {
    final doc = await _matches.doc(id).get();
    if (!doc.exists) return null;
    return _scorerMatchFromDoc(doc);
  }

  ScorerMatch _scorerMatchFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final result = data['result'] as Map<String, dynamic>?;
    return ScorerMatch(
      id: doc.id,
      tournamentId: data['tournamentId'] as String? ?? '',
      team1Id: data['team1Id'] as String? ?? '',
      team2Id: data['team2Id'] as String? ?? '',
      venue: data['venue'] as String? ?? '',
      dateTime: data['dateTime'] != null
          ? DateTime.parse(data['dateTime'] as String)
          : DateTime.now(),
      format: MatchFormat.values.firstWhere(
        (f) => f.name == data['format'],
        orElse: () => MatchFormat.t20,
      ),
      overs: data['overs'] as int? ?? 20,
      status: _statusFromString(data['status'] as String? ?? 'scheduled'),
      tossWinnerId: data['tossWinnerId'] as String?,
      tossDecision: data['tossDecision'] != null
          ? TossDecision.values.firstWhere((d) => d.name == data['tossDecision'])
          : null,
      playingXI1: (data['playingXI1'] as List<dynamic>?)?.cast<String>() ?? [],
      playingXI2: (data['playingXI2'] as List<dynamic>?)?.cast<String>() ?? [],
      openingStrikerId: data['openingStrikerId'] as String?,
      openingNonStrikerId: data['openingNonStrikerId'] as String?,
      openingBowlerId: data['openingBowlerId'] as String?,
      innings1: null,
      innings2: null,
      currentInnings: 1,
      winnerTeamId: result?['winnerTeamId'] as String?,
      resultSummary: result?['summary'] as String?,
    );
  }

  MatchStatus _statusFromString(String s) {
    switch (s) {
      case 'live':
        return MatchStatus.live;
      case 'completed':
        return MatchStatus.completed;
      case 'upcoming':
        return MatchStatus.scheduled;
      default:
        return MatchStatus.scheduled;
    }
  }
}

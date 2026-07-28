import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/serializers.dart';
import 'package:sportyapp/data/models/team_model.dart';

abstract class MatchRepository {
  Future<List<MatchModel>> getLiveMatches();
  Future<List<MatchModel>> getUpcomingMatches();
  Future<List<MatchModel>> getCompletedMatches();
  Future<MatchModel?> getMatchById(String id);
  Future<List<MatchModel>> searchMatches(String query);
  Future<MatchModel> createMatch({
    required String title,
    required String seriesName,
    required String seriesId,
    required MatchFormat format,
    required TeamModel teamA,
    required TeamModel teamB,
    required DateTime scheduledAt,
    required String venue,
    required String city,
    required String umpires,
    int? totalOvers,
    String? tossWinner,
    String? tossDecision,
  });
  Stream<List<MatchModel>> watchUpcomingMatches();
  Stream<List<MatchModel>> watchCompletedMatches();
}

class FirestoreMatchRepository implements MatchRepository {
  final FirebaseFirestore _firestore;

  FirestoreMatchRepository(this._firestore);

  Future<List<MatchModel>> _safeGet(Query query) async {
    try {
      final snap = await query.get();
      return snap.docs.map((d) => matchModelFromJson(d.data() as Map<String, dynamic>)).toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<List<MatchModel>> getLiveMatches() async {
    return _safeGet(
      _firestore.collection('matches').where('status', isEqualTo: 'live'),
    );
  }

  @override
  Future<List<MatchModel>> getUpcomingMatches() async {
    return _safeGet(
      _firestore
          .collection('matches')
          .where('status', isEqualTo: 'upcoming')
          .orderBy('scheduledAt', descending: false),
    );
  }

  @override
  Future<List<MatchModel>> getCompletedMatches() async {
    return _safeGet(
      _firestore
          .collection('matches')
          .where('status', isEqualTo: 'completed')
          .orderBy('scheduledAt', descending: true),
    );
  }

  @override
  Stream<List<MatchModel>> watchUpcomingMatches() {
    return _firestore
        .collection('matches')
        .where('status', isEqualTo: 'upcoming')
        .orderBy('scheduledAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => matchModelFromJson(d.data())).toList())
        .handleError((_) => <MatchModel>[]);
  }

  @override
  Stream<List<MatchModel>> watchCompletedMatches() {
    return _firestore
        .collection('matches')
        .where('status', isEqualTo: 'completed')
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => matchModelFromJson(d.data())).toList())
        .handleError((_) => <MatchModel>[]);
  }

  @override
  Future<MatchModel?> getMatchById(String id) async {
    try {
      final doc = await _firestore.collection('matches').doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return matchModelFromJson(doc.data()!);
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<List<MatchModel>> searchMatches(String query) async {
    try {
      final snap = await _firestore.collection('matches').get();
      final q = query.toLowerCase();
      return snap.docs
          .map((d) => matchModelFromJson(d.data()))
          .where((m) =>
              m.title.toLowerCase().contains(q) ||
              m.seriesName.toLowerCase().contains(q))
          .toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<MatchModel> createMatch({
    required String title,
    required String seriesName,
    required String seriesId,
    required MatchFormat format,
    required TeamModel teamA,
    required TeamModel teamB,
    required DateTime scheduledAt,
    required String venue,
    required String city,
    required String umpires,
    int? totalOvers,
    String? tossWinner,
    String? tossDecision,
  }) async {
    final matchId = _firestore.collection('matches').doc().id;
    final match = MatchModel(
      id: matchId,
      title: title,
      seriesName: seriesName,
      seriesId: seriesId,
      format: format,
      status: MatchStatus.upcoming,
      teamA: teamA,
      teamB: teamB,
      scheduledAt: scheduledAt,
      venue: venue,
      city: city,
      umpires: umpires,
      totalOvers: totalOvers ?? (format == MatchFormat.t20 ? 20 : format == MatchFormat.odi ? 50 : null),
      innings: [],
      isLive: false,
      thumbnailUrl: '',
    );
    try {
      await _firestore.collection('matches').doc(matchId).set(match.toJson());
    } on FirebaseException {
      // silently fail
    }
    return match;
  }
}

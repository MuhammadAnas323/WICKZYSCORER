import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/serializers.dart';

abstract class FixtureRepository {
  Future<List<MatchModel>> getAllFixtures();
  Future<List<MatchModel>> getFixturesByTournament(String tournamentId);
  Future<List<MatchModel>> getFixturesByDateRange(DateTime start, DateTime end);
}

class FirestoreFixtureRepository implements FixtureRepository {
  final FirebaseFirestore _firestore;

  FirestoreFixtureRepository(this._firestore);

  @override
  Future<List<MatchModel>> getAllFixtures() async {
    try {
      final snapshot = await _firestore
          .collection('fixtures')
          .orderBy('scheduledAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => matchModelFromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<List<MatchModel>> getFixturesByTournament(String tournamentId) async {
    try {
      final snapshot = await _firestore
          .collection('fixtures')
          .where('seriesId', isEqualTo: tournamentId)
          .orderBy('scheduledAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => matchModelFromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } on FirebaseException {
      return [];
    }
  }

  @override
  Future<List<MatchModel>> getFixturesByDateRange(
      DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('fixtures')
          .where('scheduledAt', isGreaterThanOrEqualTo: start)
          .where('scheduledAt', isLessThanOrEqualTo: end)
          .orderBy('scheduledAt')
          .get();
      return snapshot.docs
          .map((doc) => matchModelFromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } on FirebaseException {
      return [];
    }
  }
}

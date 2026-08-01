import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament_model.dart';
import '../models/scorer/scorer_tournament.dart';

abstract class TournamentRepository {
  Future<List<TournamentModel>> getAllTournaments();
  Future<TournamentModel?> getTournamentById(String id);
  Future<List<TournamentModel>> searchTournaments(String query);

  Future<void> createTournament(ScorerTournament tournament);
  Future<void> updateTournament(ScorerTournament tournament);
  Future<void> deleteTournament(String id);
  Future<List<ScorerTournament>> getAllScorerTournaments();
}

class FirestoreTournamentRepository implements TournamentRepository {
  final FirebaseFirestore _firestore;

  FirestoreTournamentRepository(this._firestore);

  @override
  Future<List<TournamentModel>> getAllTournaments() async {
    final snap = await _firestore.collection('tournaments').get();
    return snap.docs.map((doc) => _tournamentFromDoc(doc)).toList();
  }

  @override
  Future<TournamentModel?> getTournamentById(String id) async {
    final doc = await _firestore.collection('tournaments').doc(id).get();
    if (!doc.exists) return null;
    return _tournamentFromDoc(doc);
  }

  @override
  Future<List<TournamentModel>> searchTournaments(String query) async {
    final snap = await _firestore.collection('tournaments').get();
    final q = query.toLowerCase();
    return snap.docs
        .map((doc) => _tournamentFromDoc(doc))
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.shortName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<ScorerTournament>> getAllScorerTournaments() async {
    final snap = await _firestore.collection('tournaments').get();
    return snap.docs.map((doc) => _scorerTournamentFromDoc(doc)).toList();
  }

  @override
  Future<void> createTournament(ScorerTournament tournament) async {
    await _firestore.collection('tournaments').doc(tournament.id).set({
      'id': tournament.id,
      'name': tournament.name,
      'ownerId': tournament.ownerId,
      'format': tournament.format.name,
      'customOvers': tournament.customOvers,
      'startDate': tournament.startDate.toIso8601String(),
      'endDate': tournament.endDate.toIso8601String(),
      'venue': tournament.venue,
      'numTeams': tournament.numTeams,
      'teamIds': tournament.teamIds,
      'pointsRules': {
        'win': tournament.pointsRules.win,
        'loss': tournament.pointsRules.loss,
        'tie': tournament.pointsRules.tie,
        'noResult': tournament.pointsRules.noResult,
        'nrrAsTiebreaker': tournament.pointsRules.nrrAsTiebreaker,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateTournament(ScorerTournament tournament) async {
    await _firestore.collection('tournaments').doc(tournament.id).update({
      'name': tournament.name,
      'format': tournament.format.name,
      'customOvers': tournament.customOvers,
      'startDate': tournament.startDate.toIso8601String(),
      'endDate': tournament.endDate.toIso8601String(),
      'venue': tournament.venue,
      'numTeams': tournament.numTeams,
      'teamIds': tournament.teamIds,
      'pointsRules': {
        'win': tournament.pointsRules.win,
        'loss': tournament.pointsRules.loss,
        'tie': tournament.pointsRules.tie,
        'noResult': tournament.pointsRules.noResult,
        'nrrAsTiebreaker': tournament.pointsRules.nrrAsTiebreaker,
      },
    });
  }

  @override
  Future<void> deleteTournament(String id) async {
    await _firestore.collection('tournaments').doc(id).delete();
  }

  TournamentModel _tournamentFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TournamentModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      shortName: data['shortName'] as String? ?? '',
      logoUrl: data['logoUrl'] as String? ?? '',
      category: TournamentCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => TournamentCategory.international,
      ),
      host: data['host'] as String? ?? '',
      startDate: data['startDate'] != null
          ? DateTime.parse(data['startDate'] as String)
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? DateTime.parse(data['endDate'] as String)
          : DateTime.now(),
      status: data['status'] as String? ?? '',
      teamIds: (data['teamIds'] as List<dynamic>?)?.cast<String>() ?? [],
      pointsTable: [],
      totalMatches: data['totalMatches'] as int? ?? 0,
      completedMatches: data['completedMatches'] as int? ?? 0,
      description: data['description'] as String? ?? '',
    );
  }

  ScorerTournament _scorerTournamentFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final pointsRulesData = data['pointsRules'] as Map<String, dynamic>?;
    return ScorerTournament(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      format: MatchFormat.values.firstWhere(
        (f) => f.name == data['format'],
        orElse: () => MatchFormat.t20,
      ),
      customOvers: data['customOvers'] as int? ?? 0,
      startDate: data['startDate'] != null
          ? DateTime.parse(data['startDate'] as String)
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? DateTime.parse(data['endDate'] as String)
          : DateTime.now(),
      venue: data['venue'] as String? ?? '',
      numTeams: data['numTeams'] as int? ?? 4,
      teamIds: (data['teamIds'] as List<dynamic>?)?.cast<String>() ?? [],
      pointsRules: PointsRules(
        win: pointsRulesData?['win'] as int? ?? 2,
        loss: pointsRulesData?['loss'] as int? ?? 0,
        tie: pointsRulesData?['tie'] as int? ?? 1,
        noResult: pointsRulesData?['noResult'] as int? ?? 1,
        nrrAsTiebreaker: pointsRulesData?['nrrAsTiebreaker'] as bool? ?? true,
      ),
      logoUrl: data['logoUrl'] as String?,
    );
  }
}

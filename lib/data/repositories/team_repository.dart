import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';
import '../models/scorer/scorer_team.dart';

abstract class TeamRepository {
  Future<List<TeamModel>> getAllTeams();
  Future<TeamModel?> getTeamById(String id);
  Future<List<TeamModel>> searchTeams(String query);

  Future<void> createTeam(ScorerTeam team);
  Future<void> updateTeam(ScorerTeam team);
  Future<void> deleteTeam(String id);
  Future<List<ScorerTeam>> getTeamsByTournament(String tournamentId);
}

class FirestoreTeamRepository implements TeamRepository {
  final FirebaseFirestore _firestore;

  FirestoreTeamRepository(this._firestore);

  @override
  Future<List<TeamModel>> getAllTeams() async {
    final snap = await _firestore.collection('teams').get();
    return snap.docs.map((doc) => _teamFromDoc(doc)).toList();
  }

  @override
  Future<TeamModel?> getTeamById(String id) async {
    final doc = await _firestore.collection('teams').doc(id).get();
    if (!doc.exists) return null;
    return _teamFromDoc(doc);
  }

  @override
  Future<List<TeamModel>> searchTeams(String query) async {
    final snap = await _firestore.collection('teams').get();
    final q = query.toLowerCase();
    return snap.docs
        .map((doc) => _teamFromDoc(doc))
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.shortName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<ScorerTeam>> getTeamsByTournament(String tournamentId) async {
    final snap = await _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('teams')
        .get();
    return snap.docs.map((doc) => _scorerTeamFromDoc(doc)).toList();
  }

  @override
  Future<void> createTeam(ScorerTeam team) async {
    await _firestore
        .collection('tournaments')
        .doc(team.tournamentId)
        .collection('teams')
        .doc(team.id)
        .set({
      'id': team.id,
      'name': team.name,
      'shortCode': team.shortCode,
      'tournamentId': team.tournamentId,
      'playerIds': team.playerIds,
      'logoUrl': team.logoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateTeam(ScorerTeam team) async {
    await _firestore
        .collection('tournaments')
        .doc(team.tournamentId)
        .collection('teams')
        .doc(team.id)
        .update({
      'name': team.name,
      'shortCode': team.shortCode,
      'playerIds': team.playerIds,
      'logoUrl': team.logoUrl,
    });
  }

  @override
  Future<void> deleteTeam(String id) async {
    await _firestore.collection('teams').doc(id).delete();
  }

  TeamModel _teamFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TeamModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      shortName: data['shortName'] as String? ?? '',
      flagEmoji: data['flagEmoji'] as String? ?? '',
      logoUrl: data['logoUrl'] as String? ?? '',
      country: data['country'] as String? ?? '',
      teamType: data['teamType'] as String? ?? '',
      ranking: data['ranking'] as int? ?? 0,
      squad: [],
      playingXI: [],
      teamStats: const MatchStats(
        matches: 0, wins: 0, losses: 0, draws: 0, winPercent: 0,
      ),
    );
  }

  ScorerTeam _scorerTeamFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ScorerTeam(
      id: doc.id,
      name: data['name'] as String? ?? '',
      shortCode: data['shortCode'] as String? ?? '',
      tournamentId: data['tournamentId'] as String? ?? '',
      playerIds: (data['playerIds'] as List<dynamic>?)?.cast<String>() ?? [],
      logoUrl: data['logoUrl'] as String?,
    );
  }
}

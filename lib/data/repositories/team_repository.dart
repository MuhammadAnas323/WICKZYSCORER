import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';

abstract class TeamRepository {
  Future<List<TeamModel>> getAllTeams();
  Future<TeamModel?> getTeamById(String id);
  Future<List<TeamModel>> searchTeams(String query);
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
}

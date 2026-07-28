import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament_model.dart';

abstract class TournamentRepository {
  Future<List<TournamentModel>> getAllTournaments();
  Future<TournamentModel?> getTournamentById(String id);
  Future<List<TournamentModel>> searchTournaments(String query);
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
}

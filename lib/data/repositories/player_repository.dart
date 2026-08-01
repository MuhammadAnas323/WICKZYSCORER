import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';
import '../models/scorer/scorer_player.dart' as scorer;

abstract class PlayerRepository {
  Future<List<PlayerModel>> getAllPlayers();
  Future<PlayerModel?> getPlayerById(String id);
  Future<List<PlayerModel>> getPlayersByTeam(String teamId);
  Future<List<PlayerModel>> searchPlayers(String query);

  Future<void> createPlayer(scorer.ScorerPlayer player);
  Future<void> updatePlayer(scorer.ScorerPlayer player);
  Future<void> deletePlayer(String id);
  Future<List<scorer.ScorerPlayer>> getScorerPlayersByTeam(String teamId);
}

class FirestorePlayerRepository implements PlayerRepository {
  final FirebaseFirestore _firestore;

  FirestorePlayerRepository(this._firestore);

  @override
  Future<List<PlayerModel>> getAllPlayers() async {
    final snap = await _firestore.collection('players').get();
    return snap.docs.map((doc) => _playerFromDoc(doc)).toList();
  }

  @override
  Future<PlayerModel?> getPlayerById(String id) async {
    final doc = await _firestore.collection('players').doc(id).get();
    if (!doc.exists) return null;
    return _playerFromDoc(doc);
  }

  @override
  Future<List<PlayerModel>> getPlayersByTeam(String teamId) async {
    final snap = await _firestore
        .collection('players')
        .where('teamId', isEqualTo: teamId)
        .get();
    return snap.docs.map((doc) => _playerFromDoc(doc)).toList();
  }

  @override
  Future<List<PlayerModel>> searchPlayers(String query) async {
    final snap = await _firestore.collection('players').get();
    final q = query.toLowerCase();
    return snap.docs
        .map((doc) => _playerFromDoc(doc))
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.teamName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<scorer.ScorerPlayer>> getScorerPlayersByTeam(String teamId) async {
    final snap = await _firestore
        .collection('players')
        .where('teamId', isEqualTo: teamId)
        .get();
    return snap.docs.map((doc) => _scorerPlayerFromDoc(doc)).toList();
  }

  @override
  Future<void> createPlayer(scorer.ScorerPlayer player) async {
    await _firestore.collection('players').doc(player.id).set({
      'id': player.id,
      'name': player.name,
      'teamId': player.teamId,
      'tournamentId': player.tournamentId,
      'role': player.role.name,
      'battingStyle': player.battingStyle.name,
      'bowlingStyle': player.bowlingStyle.name,
      'jerseyNumber': player.jerseyNumber,
      'photoUrl': player.photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updatePlayer(scorer.ScorerPlayer player) async {
    await _firestore.collection('players').doc(player.id).update({
      'name': player.name,
      'role': player.role.name,
      'battingStyle': player.battingStyle.name,
      'bowlingStyle': player.bowlingStyle.name,
      'jerseyNumber': player.jerseyNumber,
      'photoUrl': player.photoUrl,
    });
  }

  @override
  Future<void> deletePlayer(String id) async {
    await _firestore.collection('players').doc(id).delete();
  }

  PlayerModel _playerFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final dobStr = data['dateOfBirth'] as String?;
    return PlayerModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      shortName: data['shortName'] as String? ?? '',
      teamId: data['teamId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      teamFlag: data['teamFlag'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      role: PlayerRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => PlayerRole.batsman,
      ),
      battingStyle: data['battingStyle'] as String? ?? '',
      bowlingStyle: data['bowlingStyle'] as String? ?? '',
      nationality: data['nationality'] as String? ?? '',
      dateOfBirth: dobStr != null ? DateTime.parse(dobStr) : DateTime(2000, 1, 1),
      jerseyNumber: data['jerseyNumber'] as int? ?? 0,
      isCaptain: data['isCaptain'] as bool? ?? false,
      isWicketKeeper: data['isWicketKeeper'] as bool? ?? false,
      battingStats: const BattingStats(
        matches: 0, innings: 0, runs: 0, highScore: 0,
        average: 0, strikeRate: 0, hundreds: 0, fifties: 0, fours: 0, sixes: 0,
      ),
      bowlingStats: const BowlingStats(
        matches: 0, innings: 0, overs: 0, wickets: 0, runs: 0,
        average: 0, economy: 0, strikeRate: 0, fiveWickets: 0, bestBowling: '',
      ),
    );
  }

  scorer.ScorerPlayer _scorerPlayerFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return scorer.ScorerPlayer(
      id: doc.id,
      name: data['name'] as String? ?? '',
      teamId: data['teamId'] as String? ?? '',
      tournamentId: data['tournamentId'] as String? ?? '',
      role: scorer.PlayerRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => scorer.PlayerRole.batsman,
      ),
      battingStyle: scorer.BattingStyle.values.firstWhere(
        (b) => b.name == data['battingStyle'],
        orElse: () => scorer.BattingStyle.rightHand,
      ),
      bowlingStyle: scorer.BowlingStyle.values.firstWhere(
        (b) => b.name == data['bowlingStyle'],
        orElse: () => scorer.BowlingStyle.none,
      ),
      jerseyNumber: data['jerseyNumber'] as int?,
      photoUrl: data['photoUrl'] as String?,
    );
  }
}

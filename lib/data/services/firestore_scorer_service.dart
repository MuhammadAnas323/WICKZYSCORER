import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule_serializers.dart';
import 'package:sportyapp/data/models/scorer/scorer_serializers.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/services/realtime_database_service.dart';

/// Cloud mirror of all scorer-created data.
///
/// This service is the durable store that lets tournaments, teams, players,
/// matches and schedules be created, deleted and updated easily, and shared
/// across the scorer and spectator portions.
class FirestoreScorerService {
  final FirebaseFirestore _firestore;
  final RealtimeDatabaseService _rtdb;

  FirestoreScorerService(this._firestore, this._rtdb);

  CollectionReference get _tournaments => _firestore.collection('tournaments');
  CollectionReference get _teams => _firestore.collection('teams');
  CollectionReference get _players => _firestore.collection('players');
  CollectionReference get _matches => _firestore.collection('matches');
  CollectionReference get _schedules => _firestore.collection('scorer_schedules');

  // ── Hydrate (read everything once) ──────────────────────────────────────

  /// Reads the full scorer data set back out of Firestore.
  Future<ScorerDataSnapshot> hydrate() async {
    final tournamentDocs = await _tournaments.get();
    final teamDocs = await _teams.get();
    final playerDocs = await _players.get();
    final matchDocs = await _matches.get();
    final scheduleDocs = await _schedules.get();

    final tournaments = tournamentDocs.docs
        .map((d) => scorerTournamentFromJson(d.data() as Map<String, dynamic>))
        .toList();
    final teams = teamDocs.docs
        .map((d) => scorerTeamFromJson(d.data() as Map<String, dynamic>))
        .toList();
    final players = playerDocs.docs
        .map((d) => scorerPlayerFromJson(d.data() as Map<String, dynamic>))
        .toList();
    final matches = matchDocs.docs
        .map((d) => scorerMatchFromJson(d.data() as Map<String, dynamic>))
        .toList();
    final schedules = <String, List<ScheduleStage>>{};
    for (final d in scheduleDocs.docs) {
      final data = d.data() as Map<String, dynamic>;
      try {
        final stages = ((data['stages'] as List? ?? []))
            .map((e) => scheduleStageFromJson(e as Map<String, dynamic>))
            .toList();
        schedules[d.id] = stages;
      } catch (_) {}
    }
    return ScorerDataSnapshot(
      tournaments: tournaments,
      teams: teams,
      players: players,
      matches: matches,
      schedules: schedules,
    );
  }

  /// Writes the entire scorer state to Firestore in one batch.
  Future<void> syncAll(ScorerDataSnapshot snapshot) async {
    final batch = _firestore.batch();
    for (final t in snapshot.tournaments) {
      batch.set(_tournaments.doc(t.id), scorerTournamentToJson(t));
    }
    for (final t in snapshot.teams) {
      batch.set(_teams.doc(t.id), scorerTeamToJson(t));
    }
    for (final p in snapshot.players) {
      batch.set(_players.doc(p.id), scorerPlayerToJson(p));
    }
    for (final m in snapshot.matches) {
      batch.set(_matches.doc(m.id), scorerMatchToJson(m));
    }
    for (final e in snapshot.schedules.entries) {
      batch.set(_schedules.doc(e.key), {
        'stages': e.value.map(scheduleStageToJson).toList(),
      });
    }
    await batch.commit();
  }

  // ── Point deletes (cascade-friendly) ───────────────────────────────────

  Future<void> deleteTournament(String tournamentId) async {
    final batch = _firestore.batch();
    final teamDocs = await _teams.where('tournamentId', isEqualTo: tournamentId).get();
    for (final team in teamDocs.docs) {
      final playerDocs = await _players.where('teamId', isEqualTo: team.id).get();
      for (final p in playerDocs.docs) {
        batch.delete(_players.doc(p.id));
      }
      batch.delete(_teams.doc(team.id));
    }
    final matchDocs = await _matches.where('tournamentId', isEqualTo: tournamentId).get();
    for (final m in matchDocs.docs) {
      batch.delete(_matches.doc(m.id));
    }
    batch.delete(_tournaments.doc(tournamentId));
    batch.delete(_schedules.doc(tournamentId));
    await batch.commit();
  }

  Future<void> deleteTeam(String teamId) async {
    final batch = _firestore.batch();
    final playerDocs = await _players.where('teamId', isEqualTo: teamId).get();
    for (final p in playerDocs.docs) {
      batch.delete(_players.doc(p.id));
    }
    batch.delete(_teams.doc(teamId));
    await batch.commit();
  }

  Future<void> deletePlayer(String playerId) async {
    await _players.doc(playerId).delete();
  }

  Future<void> deleteMatch(String matchId) async {
    await _matches.doc(matchId).delete();
  }

  /// Deletes every scorer document from all collections. Used by the
  /// "Clear all data" developer utility.
  Future<void> clearAll() async {
    final batch = _firestore.batch();
    for (final ref in [
      _tournaments, _teams, _players, _matches, _schedules,
    ]) {
      final snap = await ref.get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  // ── Live scoring helpers (Realtime Database broadcast) ─────────────────

  Future<void> startMatch(ScorerMatch match) async {
    final inn1Batting = match.innings1?.battingTeamId;
    final inn1Bowling = match.innings1?.bowlingTeamId;
    await _rtdb.createLiveMatch(match.id, {
      'status': 'live',
      'currentInnings': 1,
      'battingTeamId': inn1Batting ?? match.team1Id,
      'bowlingTeamId': inn1Bowling ?? match.team2Id,
      'score': {'runs': 0, 'wickets': 0, 'overs': 0, 'balls': 0},
      'target': null,
      'requiredRunRate': null,
    });
  }

  Future<void> updateRtdb(String matchId, Map<String, dynamic> updates) async {
    await _rtdb.updateLiveMatch(matchId, updates);
  }

  Future<void> endMatch(String matchId) async {
    await _rtdb.deleteLiveMatch(matchId);
  }

  // ── Per-document helpers ────────────────────────────────────────────────

  Future<void> saveMatchDoc(ScorerMatch match) async {
    await _matches.doc(match.id).set(scorerMatchToJson(match));
  }

  Future<void> endMatchDoc(
    String matchId,
    Map<String, dynamic> result,
  ) async {
    await _matches.doc(matchId).update({'result': result});
  }

}

/// Immutable snapshot of the full scorer data pulled from Firestore.
class ScorerDataSnapshot {
  final List<ScorerTournament> tournaments;
  final List<ScorerTeam> teams;
  final List<ScorerPlayer> players;
  final List<ScorerMatch> matches;
  final Map<String, List<ScheduleStage>> schedules;

  const ScorerDataSnapshot({
    this.tournaments = const [],
    this.teams = const [],
    this.players = const [],
    this.matches = const [],
    this.schedules = const {},
  });

  bool get isEmpty =>
      tournaments.isEmpty && teams.isEmpty && players.isEmpty && matches.isEmpty;
}
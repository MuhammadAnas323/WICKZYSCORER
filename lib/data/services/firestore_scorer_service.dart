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

  /// Writes the entire scorer state to Firestore.
  ///
  /// Firestore batches are capped at 500 writes per commit, so the snapshot is
  /// committed in chunks of at most 400 writes. This keeps large data sets
  /// (many tournaments/teams/players/matches) from failing the whole upload.
  Future<void> syncAll(ScorerDataSnapshot snapshot) async {
    final writes = <(DocumentReference, Map<String, dynamic>)>[];
    for (final t in snapshot.tournaments) {
      writes.add((_tournaments.doc(t.id), scorerTournamentToJson(t)));
    }
    for (final t in snapshot.teams) {
      writes.add((_teams.doc(t.id), scorerTeamToJson(t)));
    }
    for (final p in snapshot.players) {
      writes.add((_players.doc(p.id), scorerPlayerToJson(p)));
    }
    for (final m in snapshot.matches) {
      writes.add((_matches.doc(m.id), scorerMatchToJson(m)));
    }
    for (final e in snapshot.schedules.entries) {
      writes.add((_schedules.doc(e.key), {
        'stages': e.value.map(scheduleStageToJson).toList(),
      }));
    }

    const chunkSize = 400;
    for (var i = 0; i < writes.length; i += chunkSize) {
      final batch = _firestore.batch();
      final chunk = writes.skip(i).take(chunkSize);
      for (final (ref, data) in chunk) {
        batch.set(ref, data);
      }
      await batch.commit();
    }
  }

  // ── Granular per-document writes ───────────────────────────────────────
  //
  // These let the repository persist a single entity (instead of re-uploading
  // the entire state on every change). They are used for every save during
  // normal operation so a large dataset never breaks the write, and so a
  // single document failure cannot wipe the rest of the sync.

  Future<void> saveTournament(ScorerTournament tournament) async {
    await _tournaments.doc(tournament.id).set(scorerTournamentToJson(tournament));
  }

  Future<void> saveTeam(ScorerTeam team) async {
    await _teams.doc(team.id).set(scorerTeamToJson(team));
  }

  Future<void> savePlayer(ScorerPlayer player) async {
    await _players.doc(player.id).set(scorerPlayerToJson(player));
  }

  Future<void> saveMatch(ScorerMatch match) async {
    await _matches.doc(match.id).set(scorerMatchToJson(match));
  }

  Future<void> saveSchedule(String tournamentId, List<ScheduleStage> stages) async {
    await _schedules.doc(tournamentId).set({
      'stages': stages.map(scheduleStageToJson).toList(),
    });
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
      // Cascade: drop any live broadcast node for this match too.
      await _rtdb.deleteLiveMatch(m.id).catchError((_) {});
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

  /// Deletes a match document and cascades into every related subcollection
  /// (balls, innings, players-in-match) plus the live broadcast node.
  ///
  /// The scorer stores balls/innings inside the match document today, so the
  /// Firestore delete is a single document; the RTDB live node is removed here
  /// as well so a deleted match can never linger as "live" for spectators.
  Future<void> deleteMatch(String matchId) async {
    final batch = _firestore.batch();
    final matchRef = _matches.doc(matchId);

    // If the match ever uses subcollections, wipe them so no orphaned data
    // survives the parent deletion. Subcollections may not exist yet, so a
    // failed read (e.g. rules) is treated as "no documents".
    for (final sub in ['balls', 'innings', 'players']) {
      try {
        final snap = await matchRef.collection(sub).get();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
      } catch (_) {
        // No subcollection or read denied — nothing to cascade.
      }
    }

    batch.delete(matchRef);
    await batch.commit();

    // Cascade: drop the live broadcast node too.
    await _rtdb.deleteLiveMatch(matchId).catchError((_) {});
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
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/tournament_progression.dart';
import 'package:sportyapp/data/engines/tournament_progression_engine.dart';
import 'package:sportyapp/data/services/firestore_scorer_service.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class ScorerRepository {
  final List<ScorerTournament> _tournaments = [];
  final List<ScorerTeam> _teams = [];
  final List<ScorerPlayer> _players = [];
  final List<ScorerMatch> _matches = [];
  final Map<String, List<ScheduleStage>> _schedules = {};

  final FirestoreScorerService? _cloud;

  /// Bumped after every scorer mutation so screens (Matches tab, Home) can
  /// watch it and refresh their lists when data changes elsewhere in the app.
  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  /// Holds the last Firestore write failure message (if any) so silent
  /// failures become visible. Screens (e.g. the scorer shell) can listen to
  /// this and surface a toast/snackbar.
  final ValueNotifier<String?> lastCloudError = ValueNotifier<String?>(null);

  /// Cleared by whoever shows the error toast, so the same failure is not
  /// re-toasted on every rebuild.
  void clearCloudError() => lastCloudError.value = null;

  Future<void>? _loading;

  /// Serializes Firestore writes so full-document `.set()` calls (one per ball
  /// during live scoring) can never complete out of order. Without this a
  /// fire-and-forget save from earlier in the innings could land AFTER the
  /// final completed-match write and leave spectators with a stale/empty copy.
  Future<void> _writeQueue = Future.value();

  ScorerRepository([this._cloud]);

  String? get currentUserId {
    try {
      return fa.FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserEmail {
    try {
      return fa.FirebaseAuth.instance.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the write succeeded (or the cloud is not configured).
  /// On failure it logs the error and stores it in [lastCloudError] so the UI
  /// can toast "could not sync to cloud — check your connection / sign-in".
  Future<bool> _cloudWrite(Future<void> Function(FirestoreScorerService cloud) op) async {
    final cloud = _cloud;
    if (cloud == null) return true;
    try {
      await op(cloud);
      return true;
    } catch (e) {
      debugPrint('[ScorerRepository] Firestore write failed: $e');
      lastCloudError.value = '$e';
      return false;
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> _ensureLoaded() => _loading ??= _loadFromCloud();

  /// Re-reads the full scorer data set from Firestore and applies it to the
  /// in-memory lists.
  ///
  /// The spectator side calls this on every load/refresh so tournaments,
  /// teams, players, matches and live results created or edited by OTHER
  /// users become visible. It intentionally reads everything (no
  /// currentUserId filter) so spectators see all users' data.
  Future<void> refreshFromCloud() async {
    await _ensureLoaded();
    _loading = null;
    await _ensureLoaded();
  }

  /// Loads the scorer data purely from Firestore — the single source of truth.
  /// When the cloud is unavailable or not configured the lists simply stay
  /// empty; there is no local cache to fall back on.
  Future<void> _loadFromCloud() async {
    final cloud = _cloud;
    if (cloud == null) return;
    try {
      final snap = await cloud.hydrate();
      _applySnapshot(snap);
    } catch (_) {
      // Offline or unconfigured Firestore — start empty.
    }
  }

  void _applySnapshot(ScorerDataSnapshot snap) {
    void fill<T>(List<T> target, List<T> source) {
      target
        ..clear()
        ..addAll(source);
    }

    fill(_tournaments, snap.tournaments);
    fill(_teams, snap.teams);
    fill(_players, snap.players);
    fill(_matches, snap.matches);
    _schedules
      ..clear()
      ..addAll(snap.schedules);
  }

  void _bumpVersion() => dataVersion.value++;

  /// Persists a single entity to Firestore (best-effort). Granular writes keep
  /// a failure on one document from blocking the rest of the data from reaching
  /// the cloud.
  ///
  /// Failures are surfaced via [lastCloudError] (and logged) instead of being
  /// silently swallowed, so a Firestore security-rule denial or network error
  /// is visible in the UI.
  Future<void> _persistToCloud(
      Future<void> Function(FirestoreScorerService cloud) op) async {
    _writeQueue = _writeQueue.then((_) async {
      final cloud = _cloud;
      if (cloud != null) {
        await _cloudWrite(op);
      }
    });
    await _writeQueue;
  }

  // ── Public Repository Methods ─────────────────────────────────────────────

  /// Removes every tournament whose name contains [nameFragment] (case
  /// insensitive), cascading teams/players/matches/schedule + Firestore.
  /// Returns how many tournaments were deleted.
  Future<int> purgeTournamentsByName(String nameFragment) async {
    await _ensureLoaded();
    final fragment = nameFragment.trim().toLowerCase();
    if (fragment.isEmpty) return 0;
    final ids = _tournaments
        .where((t) => t.name.toLowerCase().contains(fragment))
        .map((t) => t.id)
        .toList();
    // Delete from a copy because deleteTournament mutates the list.
    for (final id in ids) {
      await deleteTournament(id);
    }
    return ids.length;
  }

  Future<List<ScorerTournament>> getTournaments() async {
    await _ensureLoaded();
    return _tournaments;
  }

  Future<ScorerTournament?> getTournament(String id) async {
    await _ensureLoaded();
    return _tournaments.where((t) => t.id == id).firstOrNull;
  }

  Future<void> saveTournament(ScorerTournament tournament) async {
    await _ensureLoaded();
    final index = _tournaments.indexWhere((t) => t.id == tournament.id);
    if (index >= 0) {
      // Never let an edit wipe the original owner: the form can't always
      // resolve the profile uid, so keep the stored createdBy/ownerId when the
      // incoming copy doesn't carry one. Otherwise the tournament would be
      // filtered out of "My Tournaments" after being edited.
      var updated = tournament;
      final existing = _tournaments[index];
      if (updated.createdBy.isEmpty && existing.createdBy.isNotEmpty) {
        updated = updated.copyWith(
          createdBy: existing.createdBy,
          ownerId: existing.ownerId,
        );
      }
      _tournaments[index] = updated;
    } else {
      // Ownership: newly created tournaments are bound to the signed-in user.
      // Never overwrite createdBy on subsequent edits.
      var t = tournament;
      if (t.createdBy.isEmpty) {
        t = t.copyWith(
          createdBy: currentUserId ?? '',
          ownerId: currentUserId ?? t.ownerId,
        );
      }
      _tournaments.add(t);
      await _cloudWrite((cloud) => cloud.saveTournament(t));
      _bumpVersion();
      return;
    }
    await _persistToCloud((cloud) => cloud.saveTournament(tournament));
    _bumpVersion();
  }

  /// Deletes a tournament and everything that belongs to it (teams, their
  /// players, matches and schedule).
  Future<void> deleteTournament(String tournamentId) async {
    await _ensureLoaded();
    final teamIds = _teams.where((t) => t.tournamentId == tournamentId).map((t) => t.id).toSet();
    _players.removeWhere((p) => teamIds.contains(p.teamId));
    _teams.removeWhere((t) => t.tournamentId == tournamentId);
    _matches.removeWhere((m) => m.tournamentId == tournamentId);
    _schedules.remove(tournamentId);
    _tournaments.removeWhere((t) => t.id == tournamentId);
    await _cloudWrite((cloud) => cloud.deleteTournament(tournamentId));
    _bumpVersion();
  }

  Future<List<ScorerTeam>> getTeamsByTournament(String tournamentId) async {
    await _ensureLoaded();
    return _teams.where((t) => t.tournamentId == tournamentId).toList();
  }

  Future<List<ScorerTeam>> getAllTeams() async {
    await _ensureLoaded();
    return _teams;
  }

  Future<ScorerTeam?> getTeam(String id) async {
    await _ensureLoaded();
    return _teams.where((t) => t.id == id).firstOrNull;
  }

  Future<void> saveTeam(ScorerTeam team) async {
    await _ensureLoaded();
    final index = _teams.indexWhere((t) => t.id == team.id);
    if (index >= 0) {
      _teams[index] = team;
    } else {
      _teams.add(team);
      // Link team to tournament if team.tournamentId is set
      final tournament = _tournaments.where((t) => t.id == team.tournamentId).firstOrNull;
      if (tournament != null && !tournament.teamIds.contains(team.id)) {
        await saveTournament(tournament.copyWith(
          teamIds: [...tournament.teamIds, team.id],
          numTeams: tournament.teamIds.length + 1,
        ));
      }
    }
    await _persistToCloud((cloud) => cloud.saveTeam(team));
    _bumpVersion();
  }

  Future<void> toggleTeamPaymentStatus(String teamId) async {
    await _ensureLoaded();
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index >= 0) {
      _teams[index] = _teams[index].copyWith(
        isEntryFeePaid: !_teams[index].isEntryFeePaid);
      await _persistToCloud((cloud) => cloud.saveTeam(_teams[index]));
      _bumpVersion();
    }
  }

  Future<void> deleteTeam(String teamId) async {
    await _ensureLoaded();
    _teams.removeWhere((t) => t.id == teamId);
    _players.removeWhere((p) => p.teamId == teamId);
    ScorerTournament? updatedTournament;
    for (int i = 0; i < _tournaments.length; i++) {
      if (_tournaments[i].teamIds.contains(teamId)) {
        final updatedIds = List<String>.from(_tournaments[i].teamIds)..remove(teamId);
        _tournaments[i] = _tournaments[i].copyWith(
          teamIds: updatedIds,
          numTeams: updatedIds.length,
        );
        updatedTournament = _tournaments[i];
      }
    }
    try {
      await _cloudWrite((cloud) => cloud.deleteTeam(teamId));
      final t = updatedTournament;
      if (t != null) {
        await _cloudWrite((cloud) => cloud.saveTournament(t));
      }
    } catch (_) {}
    _bumpVersion();
  }

  Future<List<ScorerPlayer>> getPlayersByTeam(String teamId) async {
    await _ensureLoaded();
    return _players.where((p) => p.teamId == teamId).toList();
  }

  Future<List<ScorerPlayer>> getAllPlayers() async {
    await _ensureLoaded();
    return _players;
  }

  Future<ScorerPlayer?> getPlayer(String id) async {
    await _ensureLoaded();
    return _players.where((p) => p.id == id).firstOrNull;
  }

  Future<void> savePlayer(ScorerPlayer player) async {
    await _ensureLoaded();
    final index = _players.indexWhere((p) => p.id == player.id);
    if (index >= 0) {
      _players[index] = player;
    } else {
      _players.add(player);
      // Ensure team has player ID registered
      final team = _teams.where((t) => t.id == player.teamId).firstOrNull;
      if (team != null && !team.playerIds.contains(player.id)) {
        await saveTeam(team.copyWith(playerIds: [...team.playerIds, player.id]));
      }
    }
    await _persistToCloud((cloud) => cloud.savePlayer(player));
    _bumpVersion();
  }

  Future<void> deletePlayer(String playerId) async {
    await _ensureLoaded();
    _players.removeWhere((p) => p.id == playerId);
    ScorerTeam? updatedTeam;
    for (int i = 0; i < _teams.length; i++) {
      if (_teams[i].playerIds.contains(playerId)) {
        final updatedIds = List<String>.from(_teams[i].playerIds)..remove(playerId);
        _teams[i] = _teams[i].copyWith(playerIds: updatedIds);
        updatedTeam = _teams[i];
      }
    }
    try {
      await _cloudWrite((cloud) => cloud.deletePlayer(playerId));
      final t = updatedTeam;
      if (t != null) {
        await _cloudWrite((cloud) => cloud.saveTeam(t));
      }
    } catch (_) {}
    _bumpVersion();
  }

  Future<List<ScorerMatch>> getMatches() async {
    await _ensureLoaded();
    return _matches;
  }

  Future<List<ScorerMatch>> getMatchesByTournament(String tournamentId) async {
    await _ensureLoaded();
    return _matches.where((m) => m.tournamentId == tournamentId).toList();
  }

  Future<ScorerMatch?> getMatch(String id) async {
    await _ensureLoaded();
    return _matches.where((m) => m.id == id).firstOrNull;
  }

  /// Streams a single match document from Firestore so spectators can watch
  /// live, ball-by-ball scoring updates. Emits nothing when no cloud is
  /// configured (offline scorer-only mode).
  Stream<ScorerMatch?> watchMatch(String matchId) {
    final cloud = _cloud;
    if (cloud == null) return const Stream.empty();
    return cloud.watchMatch(matchId);
  }

  Future<void> saveMatch(ScorerMatch match) async {
    await _ensureLoaded();
    final index = _matches.indexWhere((m) => m.id == match.id);
    if (index >= 0) {
      _matches[index] = match;
    } else {
      // Ownership: newly created matches are bound to the signed-in user.
      // Never overwrite createdBy on subsequent edits.
      var m = match;
      if (m.createdBy.isEmpty) {
        m = m.copyWith(createdBy: currentUserId ?? '');
      }
      _matches.add(m);
      await _cloudWrite((cloud) => cloud.saveMatch(m));
      _bumpVersion();
      return;
    }
    await _persistToCloud((cloud) => cloud.saveMatch(match));
    _bumpVersion();
  }

  Future<void> deleteMatch(String matchId) async {
    await _ensureLoaded();
    _matches.removeWhere((m) => m.id == matchId);
    await _cloudWrite((cloud) => cloud.deleteMatch(matchId));
    _bumpVersion();
  }

  Future<ScorerMatch?> firstInProgressMatch() async {
    await _ensureLoaded();
    return _matches.where((m) => m.status == MatchStatus.inProgress).firstOrNull;
  }

  Future<List<ScorerMatch>> getUpcomingMatchesByTournament(String tournamentId) async {
    await _ensureLoaded();
    return _matches
        .where((m) =>
            m.tournamentId == tournamentId &&
            (m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled))
        .toList();
  }

  Future<ScorerMatch?> findMatchById(String id) async {
    await _ensureLoaded();
    return _matches.where((m) => m.id == id).firstOrNull;
  }

  // ── Schedule (stages & fixtures) ────────────────────────────────────────

  Future<List<ScheduleStage>> getSchedule(String tournamentId) async {
    await _ensureLoaded();
    final stages = _schedules[tournamentId];
    if (stages == null) return [];
    final sorted = List<ScheduleStage>.from(stages)
      ..sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  Future<void> saveSchedule(String tournamentId, List<ScheduleStage> stages) async {
    await _ensureLoaded();
    final sortedStages = List<ScheduleStage>.from(stages)
      ..sort((a, b) => a.order.compareTo(b.order));
    _schedules[tournamentId] = sortedStages;
    await _persistToCloud((cloud) => cloud.saveSchedule(tournamentId, sortedStages));
    _bumpVersion();
  }

  /// Returns the [ScorerMatch] backing a schedule [fixture] — either an
  /// existing one (linked by id, or matching the two resolved teams) or a newly
  /// created one.
  ///
  /// Creating a match from a fixture is the "start scoring" entry point for a
  /// scheduled fixture: it snapshots the resolved teams, venue and date into a
  /// real match and links the fixture so a completed result can auto-advance
  /// the schedule. Returns null when the fixture's teams are not yet resolved.
  Future<ScorerMatch?> findOrCreateMatchForFixture({
    required String tournamentId,
    required ScheduleFixture fixture,
  }) async {
    await _ensureLoaded();
    if (fixture.linkedMatchId != null) {
      final linked = _matches.where((m) => m.id == fixture.linkedMatchId).firstOrNull;
      if (linked != null) return linked;
    }
    final teamA = fixture.resolvedTeamAId;
    final teamB = fixture.resolvedTeamBId;
    if (teamA == null || teamB == null) return null;
    for (final m in _matches) {
      if (m.tournamentId == tournamentId &&
          ((m.team1Id == teamA && m.team2Id == teamB) ||
              (m.team1Id == teamB && m.team2Id == teamA))) {
        return m;
      }
    }
    final tournament = _tournaments.where((t) => t.id == tournamentId).firstOrNull;
    final match = ScorerMatch(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      tournamentId: tournamentId,
      team1Id: teamA,
      team2Id: teamB,
      venue: fixture.venue ?? tournament?.venue ?? 'TBD',
      dateTime: fixture.scheduledDateTime ?? DateTime.now(),
      format: tournament?.format ?? MatchFormat.t20,
      overs: tournament == null
          ? 20
          : tournament.format == MatchFormat.t20
              ? 20
              : tournament.format == MatchFormat.odi
                  ? 50
                  : tournament.customOvers,
      status: MatchStatus.scheduled,
      playingXI1: const [],
      playingXI2: const [],
      currentInnings: 1,
    );
    await saveMatch(match);
    await _linkFixtureToMatch(tournamentId, fixture.id, match.id);
    return match;
  }

  /// Records that a match was created from a schedule fixture so future lookups
  /// reuse it instead of creating duplicates.
  Future<void> _linkFixtureToMatch(
    String tournamentId,
    String fixtureId,
    String matchId,
  ) async {
    final stages = _schedules[tournamentId];
    if (stages == null) return;
    for (var s = 0; s < stages.length; s++) {
      final stage = stages[s];
      final fxIndex = stage.fixtures.indexWhere((fx) => fx.id == fixtureId);
      if (fxIndex < 0) continue;
      final fx = stage.fixtures[fxIndex];
      if (fx.linkedMatchId == matchId) return;
      final fixtures = List<ScheduleFixture>.from(stage.fixtures);
      fixtures[fxIndex] = fx.copyWith(linkedMatchId: matchId);
      final updated = List<ScheduleStage>.from(stages);
      updated[s] = stage.copyWith(fixtures: fixtures);
      await saveSchedule(tournamentId, updated);
      return;
    }
  }

  /// Auto-advancement: called after a match is completed.
  ///
  /// Finds the fixture and:
  ///  - marks it completed,
  ///  - resolves every downstream destination (push model) or source (pull model),
  ///  - flips destination fixtures to `ready` once both sides are known.
  Future<void> applyScheduleResult({
    required String tournamentId,
    required String winnerTeamId,
    required String loserTeamId,
    String? matchTeam1Id,
    String? matchTeam2Id,
    String? linkedFixtureId,
    String? matchId,
  }) async {
    await _ensureLoaded();
    final stages = _schedules[tournamentId];
    if (stages == null) return;

    final outcome = MatchResultOutcome(
      matchId: matchId ?? linkedFixtureId ?? '',
      winnerTeamId: winnerTeamId,
      loserTeamId: loserTeamId,
    );

    final engine = TournamentProgressionEngine();
    final updatedStages = engine.processMatchResult(
      stages,
      outcome,
      onTeamUpdate: (teamId, {eliminated, qualified, champion}) async {
        final team = _teams.where((t) => t.id == teamId).firstOrNull;
        if (team != null) {
          final updatedTeam = team.copyWith(
            isEliminated: eliminated ?? team.isEliminated,
            isQualified: qualified ?? team.isQualified,
            isChampion: champion ?? team.isChampion,
          );
          await saveTeam(updatedTeam);
        }
      },
    );

    await saveSchedule(tournamentId, updatedStages);
  }

  /// Marks the fixture for a tied match ([tournamentId]) as completed.
  ///
  /// A tie produces no winner, so no team advances: the fixture itself shows a
  /// tied decision and every downstream `matchResult` stays unresolved (waiting
  /// for an opponent) until a decider is played.
  Future<void> applyScheduleTie({
    required String tournamentId,
    required String matchTeam1Id,
    required String matchTeam2Id,
    String? linkedFixtureId,
    String? matchId,
  }) async {
    await _ensureLoaded();
    final stages = _schedules[tournamentId];
    if (stages == null) return;

    // For a tie, we mark the source fixture completed but provide no winner/loser to advance.
    final engine = TournamentProgressionResolver(stages);
    final fx = engine.findFixtureByMatchId(matchId ?? linkedFixtureId ?? '') ??
               engine.findFixtureByTeams('', matchTeam1Id, matchTeam2Id);
    
    if (fx != null) {
        final updatedStages = stages.map((s) {
            final idx = s.fixtures.indexWhere((f) => f.id == fx.id);
            if (idx < 0) return s;
            final fixtures = List<ScheduleFixture>.from(s.fixtures);
            fixtures[idx] = fixtures[idx].copyWith(
                status: FixtureStatus.completed,
                clearWinner: true,
            );
            return s.copyWith(fixtures: fixtures);
        }).toList();
        await saveSchedule(tournamentId, updatedStages);
    }
  }
}

final scorerRepositoryProvider = Provider<ScorerRepository>((ref) {
  return ScorerRepository(ref.watch(firestoreScorerServiceProvider));
});

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_serializers.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule_serializers.dart';
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

  static const _kTournaments = 'scorer_tournaments_v1';
  static const _kTeams = 'scorer_teams_v1';
  static const _kPlayers = 'scorer_players_v1';
  static const _kMatches = 'scorer_matches_v1';
  static const _kSchedules = 'scorer_schedules_v1';

  Future<void> _ensureLoaded() => _loading ??= _loadFromDisk();

  Future<void> _loadFromDisk() async {
    // Always read the local cache first so a slow or unavailable network never
    // leaves the scorer staring at a blank screen.
    ScorerDataSnapshot? cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      cached = ScorerDataSnapshot(
        tournaments: _readCacheList(prefs, _kTournaments, scorerTournamentFromJson),
        teams: _readCacheList(prefs, _kTeams, scorerTeamFromJson),
        players: _readCacheList(prefs, _kPlayers, scorerPlayerFromJson),
        matches: _readCacheList(prefs, _kMatches, scorerMatchFromJson),
        schedules: _readCacheSchedules(prefs),
      );
    } catch (_) {
      // Ignore corrupted local data and start fresh.
    }

    final cloud = _cloud;
    if (cloud != null) {
      try {
        final snap = await cloud.hydrate();
        if (!snap.isEmpty) {
          // Cloud has data — treat it as the source of truth.
          _applySnapshot(snap);
          await _saveToCache();
          return;
        }
        // Cloud came back empty. This normally means local drafts never synced
        // (e.g. a Firestore write failed earlier). Never clobber local data with
        // an empty cloud snapshot, otherwise tournaments/teams/players vanish.
        if (cached != null && !cached.isEmpty) {
          _applySnapshot(cached);
          // Best-effort push the local drafts up to the cloud so the next load
          // finds them there too.
          try {
            await cloud.syncAll(cached);
          } catch (_) {}
          await _saveToCache();
          return;
        }
        _applySnapshot(snap);
        return;
      } catch (_) {
        // Offline or unconfigured Firestore — fall through to local cache.
      }
    }

    if (cached != null) {
      _applySnapshot(cached);
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

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kTournaments,
          encodeJsonStringList(_tournaments.map(scorerTournamentToJson).toList()));
      await prefs.setString(
          _kTeams, encodeJsonStringList(_teams.map(scorerTeamToJson).toList()));
      await prefs.setString(
          _kPlayers, encodeJsonStringList(_players.map(scorerPlayerToJson).toList()));
      await prefs.setString(
          _kMatches, encodeJsonStringList(_matches.map(scorerMatchToJson).toList()));
      final scheduleList = _schedules.entries.map((e) => {
            'tournamentId': e.key,
            'stages': e.value.map(scheduleStageToJson).toList(),
          }).toList();
      await prefs.setString(_kSchedules, encodeJsonStringList(scheduleList));
    } catch (_) {
      // Persistence is best-effort; never crash scoring over a disk error.
    }
  }

  List<T> _readCacheList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    final list = decodeJsonStringList(raw);
    final out = <T>[];
    for (final item in list) {
      try {
        out.add(fromJson(item as Map<String, dynamic>));
      } catch (_) {
        // Skip any single corrupt entry.
      }
    }
    return out;
  }

  Map<String, List<ScheduleStage>> _readCacheSchedules(SharedPreferences prefs) {
    final out = <String, List<ScheduleStage>>{};
    final raw = prefs.getString(_kSchedules);
    if (raw != null && raw.isNotEmpty) {
      for (final item in decodeJsonStringList(raw)) {
        try {
          final tId = (item as Map<String, dynamic>)['tournamentId'] as String;
          final stages = ((item['stages'] as List? ?? []))
              .map((e) => scheduleStageFromJson(e as Map<String, dynamic>))
              .toList();
          out[tId] = stages;
        } catch (_) {}
      }
    }
    return out;
  }

  void _bumpVersion() => dataVersion.value++;

  /// Persists a single entity to Firestore (best-effort) and always refreshes
  /// the local cache. Granular writes keep a failure on one document from
  /// blocking the rest of the data from reaching the cloud.
  ///
  /// Failures are surfaced via [lastCloudError] (and logged) instead of being
  /// silently swallowed, so a Firestore security-rule denial or network error
  /// is visible in the UI.
  Future<void> _persistToCloud(
      Future<void> Function(FirestoreScorerService cloud) op) async {
    final cloud = _cloud;
    if (cloud != null) {
      await _cloudWrite(op);
    }
    await _saveToCache();
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

  /// Developer utility: wipes all scorer data from memory, local cache and
  /// Firestore. Intended for a "Clear all data" button.
  Future<void> clearAll() async {
    await _ensureLoaded();
    _tournaments.clear();
    _teams.clear();
    _players.clear();
    _matches.clear();
    _schedules.clear();
    await _cloudWrite((cloud) => cloud.clearAll());
    await _saveToCache();
    _bumpVersion();
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
      _tournaments[index] = tournament;
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
      await _saveToCache();
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
    await _saveToCache();
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
    await _saveToCache();
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
    await _saveToCache();
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
      await _saveToCache();
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
    await _saveToCache();
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

  /// Auto-advancement: called after a match is completed.
  ///
  /// Finds the fixture (matched by link, or by the two team ids) and:
  ///  - marks it completed,
  ///  - resolves every downstream `matchResult` source referencing it,
  ///  - re-resolves `tablePosition` sources when a stage's RR fixtures finish,
  ///  - flips each fixture to `ready` once both sides are known.
  Future<void> applyScheduleResult({
    required String tournamentId,
    required String winnerTeamId,
    required String loserTeamId,
    String? matchTeam1Id,
    String? matchTeam2Id,
    String? linkedFixtureId,
  }) async {
    await _ensureLoaded();
    List<ScheduleStage>? stages = _schedules[tournamentId];
    if (stages == null) return;

    // Identify the fixture that was just completed.
    int completedStage = -1;
    int completedFixture = -1;
    for (var s = 0; s < stages.length; s++) {
      for (var f = 0; f < stages[s].fixtures.length; f++) {
        final fx = stages[s].fixtures[f];
        final matchesLink = linkedFixtureId != null && fx.id == linkedFixtureId;
        final matchesTeams = matchTeam1Id != null && fx.resolvedTeamAId == matchTeam1Id
            && fx.resolvedTeamBId == matchTeam2Id; // ignore order
        final matchesTeamsReversed = matchTeam1Id != null && fx.resolvedTeamAId == matchTeam2Id
            && fx.resolvedTeamBId == matchTeam1Id;
        if (matchesLink || matchesTeams || matchesTeamsReversed) {
          completedStage = s;
          completedFixture = f;
          break;
        }
      }
      if (completedStage >= 0) break;
    }

    if (completedStage >= 0) {
      final fixtures = List<ScheduleFixture>.from(stages[completedStage].fixtures);
      fixtures[completedFixture] = fixtures[completedFixture].copyWith(
        status: FixtureStatus.completed,
        linkedMatchId: fixtures[completedFixture].linkedMatchId,
      );
      stages[completedStage] = stages[completedStage].copyWith(fixtures: fixtures);
    }

    // Resolve all fixtures across all stages using known results.
    stages = _resolveAll(stages,
        winnerTeamId: winnerTeamId,
        loserTeamId: loserTeamId,
        completedFixtureId: completedFixture >= 0
            ? stages[completedStage].fixtures[completedFixture].id
            : null);
    _schedules[tournamentId] = stages;
    final resolvedStages = stages;
    await _persistToCloud((cloud) => cloud.saveSchedule(tournamentId, resolvedStages));
    _bumpVersion();
  }

  List<ScheduleStage> _resolveAll(
    List<ScheduleStage> stages, {
    required String winnerTeamId,
    required String loserTeamId,
    String? completedFixtureId,
  }) {
    // Build a lookup of team id -> (fixtureId -> winner loser) per stage that
    // is a completed round-robin we can compute the table for.
    var result = List<ScheduleStage>.from(stages);

    // Pass 1: resolve fixed-team sources and matchResult references.
    // Multiple passes because winners chain to later rounds.
    for (var pass = 0; pass < result.length + 2; pass++) {
      var changed = false;
      for (var s = 0; s < result.length; s++) {
        final stage = result[s];
        final fixtures = List<ScheduleFixture>.from(stage.fixtures);
        for (var f = 0; f < fixtures.length; f++) {
          final fx = fixtures[f];
          if (fx.status == FixtureStatus.completed) continue;
          final resolvedA = _resolveSource(stage, result, fx.teamASource,
              winnerTeamId: winnerTeamId, loserTeamId: loserTeamId);
          final resolvedB = _resolveSource(stage, result, fx.teamBSource,
              winnerTeamId: winnerTeamId, loserTeamId: loserTeamId);
          if (resolvedA != null && resolvedA != fx.resolvedTeamAId ||
              resolvedB != null && resolvedB != fx.resolvedTeamBId) {
            changed = true;
          }
          fixtures[f] = fx.copyWith(
            resolvedTeamAId: resolvedA,
            resolvedTeamBId: resolvedB,
            status: (resolvedA != null && resolvedB != null &&
                    fx.status != FixtureStatus.completed)
                ? FixtureStatus.ready
                : fx.status,
          );
        }
        result[s] = stage.copyWith(fixtures: fixtures);
      }
      if (!changed) break;
    }
    return result;
  }

  String? _resolveSource(
    ScheduleStage stage,
    List<ScheduleStage> stages,
    Source source, {
    required String winnerTeamId,
    required String loserTeamId,
  }) {
    switch (source.type) {
      case FixtureSourceType.team:
        return source.teamId;
      case FixtureSourceType.tbd:
        return null; // leaves unresolved
      case FixtureSourceType.matchResult:
        final ref = _findFixture(stages, source.fixtureId!);
        if (ref == null) return null;
        if (ref.status != FixtureStatus.completed) return null;
        // The completed fixture fed its resolved winner/loser into the resolver.
        return source.outcome == 'winner'
            ? _winnerOfCompleted(ref, winnerTeamId)
            : _loserOfCompleted(ref, loserTeamId);
      case FixtureSourceType.tablePosition:
        // Resolve Nth place using the stage's completed RR fixtures.
        return _resolveTablePosition(stages, source.stageId, source.position!);
    }
  }

  String? _winnerOfCompleted(ScheduleFixture ref, String winnerTeamId) {
    // If this ref corresponds to the just-completed match fed in via winnerTeamId.
    return winnerTeamId;
  }

  String? _loserOfCompleted(ScheduleFixture ref, String loserTeamId) {
    return loserTeamId;
  }

  ScheduleFixture? _findFixture(List<ScheduleStage> stages, String fixtureId) {
    for (final s in stages) {
      for (final f in s.fixtures) {
        if (f.id == fixtureId) return f;
      }
    }
    return null;
  }

  String? _resolveTablePosition(List<ScheduleStage> stages, String? stageId, int position) {
    final stage = stages.where((s) => s.id == stageId).firstOrNull;
    if (stage == null) return null;
    final completed = stage.fixtures.where((f) => f.status == FixtureStatus.completed).toList();
    final allDone = completed.length == stage.fixtures.length;
    if (!allDone) return null;
    // Naive standings: count wins per team among completed RR fixtures.
    final points = <String, int>{};
    for (final fx in completed) {
      final w = fx.resolvedTeamAId; // placeholder — real table needs results
      if (w != null) points[w] = (points[w] ?? 0) + 1;
    }
    final sorted = points.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (position <= sorted.length) return sorted[position - 1].key;
    return null;
  }

  /// One-time cleanup used by [main] at startup: removes every tournament
  /// (cascading into teams/players/matches/schedule) and every standalone
  /// match so old demo/test data never reaches the spectator side.
  Future<void> purgeAllForCleanup() async {
    await _ensureLoaded();
    for (final t in List.of(_tournaments)) {
      await deleteTournament(t.id);
    }
    for (final m in List.of(_matches)) {
      await deleteMatch(m.id);
    }
    await _saveToCache();
    _bumpVersion();
  }
}

// ── JSON helpers ────────────────────────────────────────────────────────────

List<dynamic> decodeJsonStringList(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : [];
  } catch (_) {
    return [];
  }
}

String encodeJsonStringList(List<dynamic> list) {
  try {
    return jsonEncode(list);
  } catch (_) {
    return '[]';
  }
}

final scorerRepositoryProvider = Provider<ScorerRepository>((ref) {
  return ScorerRepository(ref.watch(firestoreScorerServiceProvider));
});

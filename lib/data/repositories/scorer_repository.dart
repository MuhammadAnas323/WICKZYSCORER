import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_serializers.dart';

class ScorerRepository {
  final List<ScorerTournament> _tournaments = [];
  final List<ScorerTeam> _teams = [];
  final List<ScorerPlayer> _players = [];
  final List<ScorerMatch> _matches = [];

  Future<void>? _loading;

  ScorerRepository();

  // ── Persistence ─────────────────────────────────────────────────────────

  static const _kTournaments = 'scorer_tournaments_v1';
  static const _kTeams = 'scorer_teams_v1';
  static const _kPlayers = 'scorer_players_v1';
  static const _kMatches = 'scorer_matches_v1';

  Future<void> _ensureLoaded() => _loading ??= _loadFromDisk();

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _loadList<ScorerTournament>(
        prefs, _kTournaments, scorerTournamentFromJson, _tournaments);
      _loadList<ScorerTeam>(prefs, _kTeams, scorerTeamFromJson, _teams);
      _loadList<ScorerPlayer>(prefs, _kPlayers, scorerPlayerFromJson, _players);
      _loadList<ScorerMatch>(prefs, _kMatches, scorerMatchFromJson, _matches);
    } catch (_) {
      // Ignore corrupted local data and start fresh.
    }
  }

  void _loadList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
    List<T> target,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    final list = decodeJsonStringList(raw);
    for (final item in list) {
      try {
        target.add(fromJson(item as Map<String, dynamic>));
      } catch (_) {
        // Skip any single corrupt entry.
      }
    }
  }

  Future<void> _saveToDisk() async {
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
    } catch (_) {
      // Persistence is best-effort; never crash scoring over a disk error.
    }
  }

  // ── Public Repository Methods ─────────────────────────────────────────────

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
      _tournaments.add(tournament);
    }
    await _saveToDisk();
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
    await _saveToDisk();
  }

  Future<void> toggleTeamPaymentStatus(String teamId) async {
    await _ensureLoaded();
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index >= 0) {
      _teams[index] = _teams[index].copyWith(
        isEntryFeePaid: !_teams[index].isEntryFeePaid);
      await _saveToDisk();
    }
  }

  Future<void> deleteTeam(String teamId) async {
    await _ensureLoaded();
    _teams.removeWhere((t) => t.id == teamId);
    _players.removeWhere((p) => p.teamId == teamId);
    for (int i = 0; i < _tournaments.length; i++) {
      if (_tournaments[i].teamIds.contains(teamId)) {
        final updatedIds = List<String>.from(_tournaments[i].teamIds)..remove(teamId);
        _tournaments[i] = _tournaments[i].copyWith(
          teamIds: updatedIds,
          numTeams: updatedIds.length,
        );
      }
    }
    await _saveToDisk();
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
    await _saveToDisk();
  }

  Future<void> deletePlayer(String playerId) async {
    await _ensureLoaded();
    _players.removeWhere((p) => p.id == playerId);
    for (int i = 0; i < _teams.length; i++) {
      if (_teams[i].playerIds.contains(playerId)) {
        final updatedIds = List<String>.from(_teams[i].playerIds)..remove(playerId);
        _teams[i] = _teams[i].copyWith(playerIds: updatedIds);
      }
    }
    await _saveToDisk();
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
      _matches.add(match);
    }
    await _saveToDisk();
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
  return ScorerRepository();
});

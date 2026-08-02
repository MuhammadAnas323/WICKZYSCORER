import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

/// Data state for the spectator side of CRIXORA.
///
/// Everything the spectator sees (tournaments, teams, squads, matches) is
/// driven by data created in the scorer portion via [ScorerRepository].
class SpectatorHomeState {
  final bool isLoading;
  final String? error;
  final List<ScorerTournament> tournaments;
  final List<ScorerTeam> teams;
  final List<ScorerPlayer> players;
  final List<ScorerMatch> matches;
  final Map<String, LiveMatchData> liveMatchData;

  const SpectatorHomeState({
    this.isLoading = true,
    this.error,
    this.tournaments = const [],
    this.teams = const [],
    this.players = const [],
    this.matches = const [],
    this.liveMatchData = const {},
  });

  List<ScorerMatch> get liveMatches => matches
      .where((m) =>
          m.status == MatchStatus.inProgress ||
          m.status == MatchStatus.live ||
          liveMatchData.containsKey(m.id))
      .toList();

  List<ScorerMatch> get upcomingMatches => matches
      .where((m) =>
          m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled)
      .toList();

  List<ScorerMatch> get completedMatches =>
      matches.where((m) => m.status == MatchStatus.completed).toList();

  ScorerTournament? tournamentById(String id) =>
      tournaments.where((t) => t.id == id).firstOrNull;

  List<ScorerTeam> teamsForTournament(String tournamentId) =>
      teams.where((t) => t.tournamentId == tournamentId).toList();

  List<ScorerPlayer> playersForTeam(String teamId) =>
      players.where((p) => p.teamId == teamId).toList();

  List<ScorerMatch> matchesForTournament(String tournamentId) =>
      matches.where((m) => m.tournamentId == tournamentId).toList();

  String teamName(String teamId) {
    for (final t in teams) {
      if (t.id == teamId) return t.name;
    }
    return teamId.replaceAll('team_', '').replaceAll('t_', '').toUpperCase();
  }

  String teamShort(String teamId) {
    for (final t in teams) {
      if (t.id == teamId) {
        return t.shortCode.isNotEmpty ? t.shortCode : t.name;
      }
    }
    return teamId.replaceAll('team_', '').replaceAll('t_', '').toUpperCase();
  }

  String playerName(String playerId) {
    for (final p in players) {
      if (p.id == playerId) return p.name;
    }
    return playerId.replaceAll('player_', '').replaceAll('p_', '');
  }

  LiveMatchData? liveDataFor(String matchId) => liveMatchData[matchId];

  SpectatorHomeState copyWith({
    bool? isLoading,
    String? error,
    List<ScorerTournament>? tournaments,
    List<ScorerTeam>? teams,
    List<ScorerPlayer>? players,
    List<ScorerMatch>? matches,
    Map<String, LiveMatchData>? liveMatchData,
  }) {
    return SpectatorHomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      tournaments: tournaments ?? this.tournaments,
      teams: teams ?? this.teams,
      players: players ?? this.players,
      matches: matches ?? this.matches,
      liveMatchData: liveMatchData ?? this.liveMatchData,
    );
  }
}

class SpectatorHomeViewModel extends StateNotifier<SpectatorHomeState> {
  final Ref ref;
  StreamSubscription? _liveSubscription;

  SpectatorHomeViewModel(this.ref) : super(const SpectatorHomeState()) {
    _listenToLiveMatches();
    load();
  }

  void _listenToLiveMatches() {
    _liveSubscription?.cancel();
    _liveSubscription =
        ref.read(realtimeDatabaseProvider).watchAllLiveMatches().listen((raw) {
      if (!mounted) return;
      final liveMatchData = raw.map(
          (matchId, data) => MapEntry(matchId, LiveMatchData.fromJson(data)));
      state = state.copyWith(liveMatchData: liveMatchData);
    });
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(scorerRepositoryProvider);
      final tournaments = await repo.getTournaments();
      final teams = await repo.getAllTeams();
      final players = await repo.getAllPlayers();
      final matches = await repo.getMatches();
      state = SpectatorHomeState(
        isLoading: false,
        tournaments: tournaments,
        teams: teams,
        players: players,
        matches: matches,
        liveMatchData: state.liveMatchData,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load data.');
    }
  }

  Future<void> refresh() => load();

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }
}

final spectatorHomeViewModelProvider =
    StateNotifierProvider<SpectatorHomeViewModel, SpectatorHomeState>((ref) {
  return SpectatorHomeViewModel(ref);
});

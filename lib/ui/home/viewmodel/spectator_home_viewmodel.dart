import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
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
  final Map<String, List<ScheduleStage>> schedules;
  final Map<String, LiveMatchData> liveMatchData;
  final int topTab; // 0 = Tournaments, 1 = Friendly Matches
  final String tournamentSubFilter; // 'all', 'live', 'upcoming', 'completed'
  final String friendlySubFilter; // 'all', 'live', 'upcoming', 'completed'
  final String searchQuery;

  const SpectatorHomeState({
    this.isLoading = true,
    this.error,
    this.tournaments = const [],
    this.teams = const [],
    this.players = const [],
    this.matches = const [],
    this.schedules = const {},
    this.liveMatchData = const {},
    this.topTab = 0,
    this.tournamentSubFilter = 'all',
    this.friendlySubFilter = 'all',
    this.searchQuery = '',
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

  // ── Spectator Filtered Tournaments ─────────────────────────────────────
  List<ScorerTournament> get filteredTournaments {
    var list = tournaments;
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((t) => t.name.toLowerCase().contains(q) || (t.venue?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (tournamentSubFilter == 'all') return list;

    return list.where((t) {
      final tourneyMatches = matches.where((m) => m.tournamentId == t.id).toList();
      if (tournamentSubFilter == 'live') {
        return tourneyMatches.any((m) => m.status == MatchStatus.inProgress || m.status == MatchStatus.live || liveMatchData.containsKey(m.id));
      } else if (tournamentSubFilter == 'upcoming') {
        return tourneyMatches.any((m) => m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled);
      } else if (tournamentSubFilter == 'completed') {
        return tourneyMatches.any((m) => m.status == MatchStatus.completed);
      }
      return true;
    }).toList();
  }

  // ── Spectator Filtered Friendly Matches ────────────────────────────────
  List<ScorerMatch> get filteredFriendlyMatches {
    // Friendly/local matches are stored under the pseudo-tournament 't_custom'
    // (see scorer create-local-match), so treat it as a friendly match too.
    var list = matches
        .where((m) =>
            m.tournamentId == null ||
            m.tournamentId!.isEmpty ||
            m.tournamentId == 't_custom')
        .toList();

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((m) {
        final t1 = teamName(m.team1Id).toLowerCase();
        final t2 = teamName(m.team2Id).toLowerCase();
        final venue = m.venue.toLowerCase();
        return t1.contains(q) || t2.contains(q) || venue.contains(q);
      }).toList();
    }

    if (friendlySubFilter == 'live') {
      return list.where((m) => m.status == MatchStatus.inProgress || m.status == MatchStatus.live || liveMatchData.containsKey(m.id)).toList();
    } else if (friendlySubFilter == 'upcoming') {
      return list.where((m) => m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled).toList();
    } else if (friendlySubFilter == 'completed') {
      return list.where((m) => m.status == MatchStatus.completed).toList();
    }
    return list;
  }

  ScorerTournament? tournamentById(String id) =>
      tournaments.where((t) => t.id == id).firstOrNull;

  List<ScorerTeam> teamsForTournament(String tournamentId) =>
      teams.where((t) => t.tournamentId == tournamentId).toList();

  List<ScorerPlayer> playersForTeam(String teamId) =>
      players.where((p) => p.teamId == teamId).toList();

  List<ScorerMatch> matchesForTournament(String tournamentId) =>
      matches.where((m) => m.tournamentId == tournamentId).toList();

  /// Stage-wise schedule for a tournament (empty when none was built).
  List<ScheduleStage> scheduleForTournament(String tournamentId) =>
      schedules[tournamentId] ?? const [];

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
    Map<String, List<ScheduleStage>>? schedules,
    Map<String, LiveMatchData>? liveMatchData,
    int? topTab,
    String? tournamentSubFilter,
    String? friendlySubFilter,
    String? searchQuery,
  }) {
    return SpectatorHomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      tournaments: tournaments ?? this.tournaments,
      teams: teams ?? this.teams,
      players: players ?? this.players,
      matches: matches ?? this.matches,
      schedules: schedules ?? this.schedules,
      liveMatchData: liveMatchData ?? this.liveMatchData,
      topTab: topTab ?? this.topTab,
      tournamentSubFilter: tournamentSubFilter ?? this.tournamentSubFilter,
      friendlySubFilter: friendlySubFilter ?? this.friendlySubFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class SpectatorHomeViewModel extends StateNotifier<SpectatorHomeState> {
  final Ref ref;
  StreamSubscription? _liveSubscription;

  SpectatorHomeViewModel(this.ref) : super(const SpectatorHomeState()) {
    _listenToLiveMatches();
    load();
    ref.listen(currentUserProvider, (_, next) {
      if (next != null) load();
    });
  }

  void setTopTab(int index) {
    state = state.copyWith(topTab: index);
  }

  void setTournamentSubFilter(String filter) {
    state = state.copyWith(tournamentSubFilter: filter);
  }

  void setFriendlySubFilter(String filter) {
    state = state.copyWith(friendlySubFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void _listenToLiveMatches() {
    _liveSubscription?.cancel();
    _liveSubscription =
        ref.read(realtimeDatabaseProvider).watchAllLiveMatches().listen((raw) {
      if (!mounted) return;
      final liveMatchData = raw.map(
          (matchId, data) => MapEntry(matchId, LiveMatchData.fromJson(data)));
      state = state.copyWith(liveMatchData: liveMatchData);

      // A brand-new match went live (created by another user after our last
      // Firestore sync) — pull its document so it appears for every spectator.
      // This only fires when an unknown match id shows up, so constant score
      // updates during a match never trigger a reload.
      final known = state.matches.map((m) => m.id).toSet();
      if (raw.keys.any((id) => !known.contains(id))) {
        load(showLoading: false);
      }
    });
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final repo = ref.read(scorerRepositoryProvider);
      // Pull the freshest data from Firestore so matches/tournaments created
      // or edited by other users (new players, live sessions, results) show up
      // for every spectator. No currentUserId filtering — spectators see all.
      await repo.refreshFromCloud();
      final tournaments = await repo.getTournaments();
      final teams = await repo.getAllTeams();
      final players = await repo.getAllPlayers();
      final matches = await repo.getMatches();
      final schedules = <String, List<ScheduleStage>>{};
      for (final t in tournaments) {
        schedules[t.id] = await repo.getSchedule(t.id);
      }
      state = state.copyWith(
        isLoading: false,
        tournaments: tournaments,
        teams: teams,
        players: players,
        matches: matches,
        schedules: schedules,
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

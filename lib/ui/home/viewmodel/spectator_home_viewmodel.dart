import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/providers/live_match_providers.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

/// Data state for the spectator side of WICKZYSCORER.
class SpectatorHomeState {
  final bool isLoading;
  final bool isLoadingMoreTournaments;
  final bool isLoadingMoreFriendly;
  final String? error;
  final List<ScorerTournament> tournaments;
  final List<ScorerTeam> teams;
  final List<ScorerPlayer> players;
  final List<ScorerMatch> matches;
  final Map<String, List<ScheduleStage>> schedules;
  final int topTab; // 0 = Tournaments, 1 = Friendly Matches
  final String tournamentSubFilter; // 'all', 'live', 'upcoming', 'completed'
  final String friendlySubFilter; // 'all', 'live', 'upcoming', 'completed'
  final String searchQuery;
  final int tournamentLimit;
  final int friendlyLimit;

  /// RTDB live payloads keyed by matchId.
  final Map<String, LiveMatchData> rtdbLiveMatches;

  const SpectatorHomeState({
    this.isLoading = true,
    this.isLoadingMoreTournaments = false,
    this.isLoadingMoreFriendly = false,
    this.error,
    this.tournaments = const [],
    this.teams = const [],
    this.players = const [],
    this.matches = const [],
    this.schedules = const {},
    this.topTab = 0,
    this.tournamentSubFilter = 'all',
    this.friendlySubFilter = 'all',
    this.searchQuery = '',
    this.tournamentLimit = 6,
    this.friendlyLimit = 6,
    this.rtdbLiveMatches = const {},
  });

  List<ScorerMatch> get liveMatches => matches
      .where((m) =>
          m.status == MatchStatus.inProgress || m.status == MatchStatus.live)
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
      list = list.where((t) => t.name.toLowerCase().contains(q) || t.venue.toLowerCase().contains(q)).toList();
    }
    if (tournamentSubFilter != 'all') {
      list = list.where((t) {
        final tourneyMatches = matches.where((m) => m.tournamentId == t.id).toList();
        if (tournamentSubFilter == 'live') {
          return tourneyMatches.any((m) => m.status == MatchStatus.inProgress || m.status == MatchStatus.live);
        } else if (tournamentSubFilter == 'upcoming') {
          return tourneyMatches.any((m) => m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled);
        } else if (tournamentSubFilter == 'completed') {
          return tourneyMatches.any((m) => m.status == MatchStatus.completed);
        }
        return true;
      }).toList();
    }
    return list;
  }

  List<ScorerTournament> get displayedTournaments =>
      filteredTournaments.take(tournamentLimit).toList();

  bool get hasMoreTournaments => tournamentLimit < filteredTournaments.length;

  // ── Spectator Filtered Friendly Matches ────────────────────────────────
  List<ScorerMatch> get filteredFriendlyMatches {
    var list = matches
        .where((m) =>
            m.tournamentId.isEmpty ||
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
      list = list.where((m) => m.status == MatchStatus.inProgress || m.status == MatchStatus.live).toList();
    } else if (friendlySubFilter == 'upcoming') {
      list = list.where((m) => m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled).toList();
    } else if (friendlySubFilter == 'completed') {
      list = list.where((m) => m.status == MatchStatus.completed).toList();
    }
    return list;
  }

  List<ScorerMatch> get displayedFriendlyMatches =>
      filteredFriendlyMatches.take(friendlyLimit).toList();

  bool get hasMoreFriendly => friendlyLimit < filteredFriendlyMatches.length;

  ScorerTournament? tournamentById(String id) =>
      tournaments.where((t) => t.id == id).firstOrNull;

  List<ScorerTeam> teamsForTournament(String tournamentId) =>
      teams.where((t) => t.tournamentId == tournamentId).toList();

  List<ScorerPlayer> playersForTeam(String teamId) =>
      players.where((p) => p.teamId == teamId).toList();

  List<ScorerMatch> matchesForTournament(String tournamentId) =>
      matches.where((m) => m.tournamentId == tournamentId).toList();

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

  SpectatorHomeState copyWith({
    bool? isLoading,
    bool? isLoadingMoreTournaments,
    bool? isLoadingMoreFriendly,
    String? error,
    List<ScorerTournament>? tournaments,
    List<ScorerTeam>? teams,
    List<ScorerPlayer>? players,
    List<ScorerMatch>? matches,
    Map<String, List<ScheduleStage>>? schedules,
    int? topTab,
    String? tournamentSubFilter,
    String? friendlySubFilter,
    String? searchQuery,
    int? tournamentLimit,
    int? friendlyLimit,
    Map<String, LiveMatchData>? rtdbLiveMatches,
  }) {
    return SpectatorHomeState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMoreTournaments: isLoadingMoreTournaments ?? this.isLoadingMoreTournaments,
      isLoadingMoreFriendly: isLoadingMoreFriendly ?? this.isLoadingMoreFriendly,
      error: error,
      tournaments: tournaments ?? this.tournaments,
      teams: teams ?? this.teams,
      players: players ?? this.players,
      matches: matches ?? this.matches,
      schedules: schedules ?? this.schedules,
      topTab: topTab ?? this.topTab,
      tournamentSubFilter: tournamentSubFilter ?? this.tournamentSubFilter,
      friendlySubFilter: friendlySubFilter ?? this.friendlySubFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      tournamentLimit: tournamentLimit ?? this.tournamentLimit,
      friendlyLimit: friendlyLimit ?? this.friendlyLimit,
      rtdbLiveMatches: rtdbLiveMatches ?? this.rtdbLiveMatches,
    );
  }
}

class SpectatorHomeViewModel extends StateNotifier<SpectatorHomeState> {
  final Ref ref;
  StreamSubscription? _liveSubscription;
  ProviderSubscription<AsyncValue<Map<String, LiveMatchData>>>? _rtdbSubscription;
  Timer? _reloadDebounce;

  SpectatorHomeViewModel(this.ref) : super(const SpectatorHomeState()) {
    _listenToLiveMatches();
    _listenToRtdbLive();
    load();
    ref.listen(currentUserProvider, (_, next) {
      if (next != null) load();
    });
    ref.listen(scorerDataVersionProvider, (_, __) => _onScorerDataChanged());
  }

  void _onScorerDataChanged() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      load(showLoading: false);
    });
  }

  void setTopTab(int index) {
    state = state.copyWith(topTab: index);
  }

  void setTournamentSubFilter(String filter) {
    state = state.copyWith(tournamentSubFilter: filter, tournamentLimit: 6);
  }

  void setFriendlySubFilter(String filter) {
    state = state.copyWith(friendlySubFilter: filter, friendlyLimit: 6);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, tournamentLimit: 6, friendlyLimit: 6);
  }

  void loadMoreTournaments() {
    if (state.isLoadingMoreTournaments || !state.hasMoreTournaments) return;
    state = state.copyWith(isLoadingMoreTournaments: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMoreTournaments: false,
        tournamentLimit: state.tournamentLimit + 6,
      );
    });
  }

  void loadMoreFriendly() {
    if (state.isLoadingMoreFriendly || !state.hasMoreFriendly) return;
    state = state.copyWith(isLoadingMoreFriendly: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMoreFriendly: false,
        friendlyLimit: state.friendlyLimit + 6,
      );
    });
  }

  void _listenToLiveMatches() {
    _liveSubscription?.cancel();
    try {
      _liveSubscription =
          ref.read(firestoreScorerServiceProvider).watchLiveMatches().listen(
        (liveMatches) {
          if (!mounted) return;
          final byId = <String, ScorerMatch>{
            for (final m in state.matches) m.id: m,
          };
          for (final m in liveMatches) {
            byId[m.id] = m;
          }
          state = state.copyWith(matches: byId.values.toList());
        },
        onError: (_) {},
      );
    } catch (_) {
      _liveSubscription = null;
    }
  }

  void _listenToRtdbLive() {
    _rtdbSubscription?.close();
    try {
      _rtdbSubscription = ref.listen(allLiveMatchesProvider, (_, next) {
        if (!mounted) return;
        final data = next.valueOrNull;
        if (data != null) {
          state = state.copyWith(rtdbLiveMatches: data);
        }
      });
    } catch (_) {
      _rtdbSubscription = null;
    }
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final repo = ref.read(scorerRepositoryProvider);
      await repo.refreshFromCloud();
      final tournaments = await repo.getTournaments(forCurrentUserOnly: false);
      final teams = await repo.getAllTeams(forCurrentUserOnly: false);
      final players = await repo.getAllPlayers(forCurrentUserOnly: false);
      final matches = await repo.getMatches(forCurrentUserOnly: false);
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
        tournamentLimit: 6,
        friendlyLimit: 6,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load data.');
    }
  }

  Future<void> refresh() => load();

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _liveSubscription?.cancel();
    _rtdbSubscription?.close();
    super.dispose();
  }
}

final spectatorHomeViewModelProvider =
    StateNotifierProvider<SpectatorHomeViewModel, SpectatorHomeState>((ref) {
  return SpectatorHomeViewModel(ref);
});

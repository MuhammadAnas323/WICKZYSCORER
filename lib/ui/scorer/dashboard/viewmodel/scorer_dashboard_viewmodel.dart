import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class ScorerDashboardState {
  final bool isLoading;
  final List<ScorerTournament> tournaments;
  final List<ScorerMatch> matches;
  final List<ScorerTeam> teams;
  final String? userId;
  final String matchFilter; // 'all', 'live', 'upcoming', 'completed'
  final String tournamentFilter; // 'all', 'live', 'upcoming', 'completed'
  final bool myMatchesOnly;

  const ScorerDashboardState({
    this.isLoading = false,
    this.tournaments = const [],
    this.matches = const [],
    this.teams = const [],
    this.userId,
    this.matchFilter = 'all',
    this.tournamentFilter = 'all',
    this.myMatchesOnly = false,
  });

  bool _statusMatches(ScorerMatch m, String filter) {
    switch (filter) {
      case 'live':
        return m.status == MatchStatus.inProgress || m.status == MatchStatus.live;
      case 'upcoming':
        return m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled;
      case 'completed':
        return m.status == MatchStatus.completed;
      default:
        return true;
    }
  }

  bool _isMyMatch(ScorerMatch m) {
    if (!myMatchesOnly || userId == null) return true;
    final t = tournaments.where((t) => t.id == m.tournamentId).firstOrNull;
    if (t == null) return true; // custom match without a tournament = own
    return t.ownerId == userId;
  }

  List<ScorerMatch> get filteredMatches => matches
      .where((m) => _statusMatches(m, matchFilter) && _isMyMatch(m))
      .toList();

  List<ScorerTournament> get filteredTournaments {
    if (tournamentFilter == 'all') return tournaments;
    return tournaments
        .where((t) =>
            matches.any((m) => m.tournamentId == t.id && _statusMatches(m, tournamentFilter)))
        .toList();
  }

  int get liveCount => matches.where((m) => m.status == MatchStatus.inProgress || m.status == MatchStatus.live).length;
  int get scoredCount => matches.where((m) => m.status == MatchStatus.completed).length;

  String teamName(String teamId) {
    for (final t in teams) {
      if (t.id == teamId) return t.name;
    }
    return teamId.replaceAll('team_', '').replaceAll('t_', '').toUpperCase();
  }

  ScorerDashboardState copyWith({
    bool? isLoading,
    List<ScorerTournament>? tournaments,
    List<ScorerMatch>? matches,
    List<ScorerTeam>? teams,
    String? userId,
    String? matchFilter,
    String? tournamentFilter,
    bool? myMatchesOnly,
  }) {
    return ScorerDashboardState(
      isLoading: isLoading ?? this.isLoading,
      tournaments: tournaments ?? this.tournaments,
      matches: matches ?? this.matches,
      teams: teams ?? this.teams,
      userId: userId ?? this.userId,
      matchFilter: matchFilter ?? this.matchFilter,
      tournamentFilter: tournamentFilter ?? this.tournamentFilter,
      myMatchesOnly: myMatchesOnly ?? this.myMatchesOnly,
    );
  }
}

class ScorerDashboardViewModel extends StateNotifier<ScorerDashboardState> {
  final Ref ref;

  ScorerDashboardViewModel(this.ref) : super(const ScorerDashboardState()) {
    loadDashboard();
    // Reload whenever scorer data changes elsewhere in the app (e.g. a match
    // was created from the Matches tab).
    ref.listen(scorerDataVersionProvider, (_, __) => loadDashboard());
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(scorerRepositoryProvider);
    final user = ref.read(currentUserProvider);
    final tournaments = await repo.getTournaments();
    final matches = await repo.getMatches();
    final teams = await repo.getAllTeams();
    state = state.copyWith(
      isLoading: false,
      tournaments: tournaments,
      matches: matches,
      teams: teams,
      userId: user?.id,
    );
  }

  void setMatchFilter(String filter) {
    state = state.copyWith(matchFilter: filter);
  }

  void setTournamentFilter(String filter) {
    state = state.copyWith(tournamentFilter: filter);
  }

  void setMyMatchesOnly(bool value) {
    state = state.copyWith(myMatchesOnly: value);
  }
}

final scorerDashboardViewModelProvider =
    StateNotifierProvider<ScorerDashboardViewModel, ScorerDashboardState>((ref) {
  return ScorerDashboardViewModel(ref);
});

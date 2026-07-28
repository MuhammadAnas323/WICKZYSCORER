import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/repositories/tournament_repository.dart';
import 'package:sportyapp/data/repositories/live_match_repository.dart';
import 'package:sportyapp/data/providers/live_match_providers.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class HomeState {
  final bool isLoading;
  final String? error;
  final List<MatchModel> liveMatches;
  final List<MatchModel> upcomingMatches;
  final List<TournamentModel> tournaments;
  final Map<String, LiveMatchData> liveMatchData;

  const HomeState({
    this.isLoading = true,
    this.error,
    this.liveMatches = const [],
    this.upcomingMatches = const [],
    this.tournaments = const [],
    this.liveMatchData = const {},
  });

  HomeState copyWith({
    bool? isLoading,
    String? error,
    List<MatchModel>? liveMatches,
    List<MatchModel>? upcomingMatches,
    List<TournamentModel>? tournaments,
    Map<String, LiveMatchData>? liveMatchData,
  }) => HomeState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    liveMatches: liveMatches ?? this.liveMatches,
    upcomingMatches: upcomingMatches ?? this.upcomingMatches,
    tournaments: tournaments ?? this.tournaments,
    liveMatchData: liveMatchData ?? this.liveMatchData,
  );
}

class HomeViewModel extends StateNotifier<HomeState> {
  final MatchRepository _matchRepo;
  final TournamentRepository _tournamentRepo;
  final LiveMatchRepository _liveRepo;
  final Map<String, StreamSubscription<LiveMatchData>> _liveSubs = {};

  HomeViewModel(this._matchRepo, this._tournamentRepo, this._liveRepo)
      : super(const HomeState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _matchRepo.getLiveMatches(),
        _matchRepo.getUpcomingMatches(),
        _tournamentRepo.getAllTournaments(),
      ]);
      final liveMatches = results[0] as List<MatchModel>;

      state = state.copyWith(
        isLoading: false,
        liveMatches: liveMatches,
        upcomingMatches: results[1] as List<MatchModel>,
        tournaments: results[2] as List<TournamentModel>,
      );

      _subscribeToLiveData(liveMatches);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: null, liveMatches: [], upcomingMatches: [], tournaments: []);
    }
  }

  void _subscribeToLiveData(List<MatchModel> liveMatches) {
    for (final sub in _liveSubs.values) {
      sub.cancel();
    }
    _liveSubs.clear();

    for (final match in liveMatches) {
      try {
        final sub = _liveRepo.watchLiveMatch(match.id).listen(
          (liveData) {
            if (mounted) {
              final updated = Map<String, LiveMatchData>.from(state.liveMatchData);
              updated[match.id] = liveData;
              state = state.copyWith(liveMatchData: updated);
            }
          },
          onError: (_) {},
        );
        _liveSubs[match.id] = sub;
      } catch (_) {}
    }
  }

  Future<void> refresh() => loadData();

  @override
  void dispose() {
    for (final sub in _liveSubs.values) {
      sub.cancel();
    }
    _liveSubs.clear();
    super.dispose();
  }
}

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final notifier = HomeViewModel(
    ref.read(matchRepositoryProvider),
    ref.read(tournamentRepositoryProvider),
    ref.read(liveMatchRepositoryProvider),
  );

  return notifier;
});

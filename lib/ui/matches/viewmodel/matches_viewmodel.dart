import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class MatchesState {
  final bool isLoading;
  final String? error;
  final List<MatchModel> upcoming;
  final List<MatchModel> completed;
  final int tabIndex;
  const MatchesState({this.isLoading = true, this.error, this.upcoming = const [],
    this.completed = const [], this.tabIndex = 0});
  MatchesState copyWith({bool? isLoading, String? error, List<MatchModel>? upcoming,
    List<MatchModel>? completed, int? tabIndex}) =>
    MatchesState(isLoading: isLoading ?? this.isLoading, error: error,
      upcoming: upcoming ?? this.upcoming, completed: completed ?? this.completed,
      tabIndex: tabIndex ?? this.tabIndex);
}

class MatchesViewModel extends StateNotifier<MatchesState> {
  final MatchRepository _repo;
  StreamSubscription? _upcomingSub;
  StreamSubscription? _completedSub;

  MatchesViewModel(this._repo) : super(const MatchesState()) { _init(); }

  void _init() {
    _upcomingSub = _repo.watchUpcomingMatches().listen((matches) {
      if (mounted) state = state.copyWith(upcoming: matches, isLoading: false);
    }, onError: (e) {
      if (mounted) state = state.copyWith(error: AppErrorHandler.getUserFriendlyMessage(e), isLoading: false);
    });
    _completedSub = _repo.watchCompletedMatches().listen((matches) {
      if (mounted) state = state.copyWith(completed: matches, isLoading: false);
    }, onError: (e) {
      if (mounted) state = state.copyWith(error: AppErrorHandler.getUserFriendlyMessage(e), isLoading: false);
    });
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _repo.getUpcomingMatches(),
        _repo.getCompletedMatches(),
      ]);
      state = state.copyWith(
        isLoading: false,
        upcoming: results[0],
        completed: results[1],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void setTab(int i) => state = state.copyWith(tabIndex: i);

  @override
  void dispose() {
    _upcomingSub?.cancel();
    _completedSub?.cancel();
    super.dispose();
  }
}

final matchesViewModelProvider = StateNotifierProvider<MatchesViewModel, MatchesState>(
  (ref) => MatchesViewModel(ref.read(matchRepositoryProvider)));

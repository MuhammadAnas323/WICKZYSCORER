import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class MatchesState {
  final bool isLoading;
  final bool isLoadingMoreUpcoming;
  final bool isLoadingMoreCompleted;
  final String? error;
  final List<MatchModel> upcoming;
  final List<MatchModel> completed;
  final int upcomingLimit;
  final int completedLimit;
  final int tabIndex;

  const MatchesState({
    this.isLoading = true,
    this.isLoadingMoreUpcoming = false,
    this.isLoadingMoreCompleted = false,
    this.error,
    this.upcoming = const [],
    this.completed = const [],
    this.upcomingLimit = 6,
    this.completedLimit = 6,
    this.tabIndex = 0,
  });

  List<MatchModel> get displayedUpcoming => upcoming.take(upcomingLimit).toList();
  List<MatchModel> get displayedCompleted => completed.take(completedLimit).toList();

  bool get hasMoreUpcoming => upcomingLimit < upcoming.length;
  bool get hasMoreCompleted => completedLimit < completed.length;

  MatchesState copyWith({
    bool? isLoading,
    bool? isLoadingMoreUpcoming,
    bool? isLoadingMoreCompleted,
    String? error,
    List<MatchModel>? upcoming,
    List<MatchModel>? completed,
    int? upcomingLimit,
    int? completedLimit,
    int? tabIndex,
  }) =>
      MatchesState(
        isLoading: isLoading ?? this.isLoading,
        isLoadingMoreUpcoming: isLoadingMoreUpcoming ?? this.isLoadingMoreUpcoming,
        isLoadingMoreCompleted: isLoadingMoreCompleted ?? this.isLoadingMoreCompleted,
        error: error,
        upcoming: upcoming ?? this.upcoming,
        completed: completed ?? this.completed,
        upcomingLimit: upcomingLimit ?? this.upcomingLimit,
        completedLimit: completedLimit ?? this.completedLimit,
        tabIndex: tabIndex ?? this.tabIndex,
      );
}

class MatchesViewModel extends StateNotifier<MatchesState> {
  final MatchRepository _repo;
  StreamSubscription? _upcomingSub;
  StreamSubscription? _completedSub;

  MatchesViewModel(this._repo) : super(const MatchesState()) {
    _init();
  }

  void _init() {
    _upcomingSub = _repo.watchUpcomingMatches().listen((matches) {
      if (mounted) state = state.copyWith(upcoming: matches, isLoading: false);
    }, onError: (e) {
      if (mounted) {
        state = state.copyWith(
            error: AppErrorHandler.getUserFriendlyMessage(e), isLoading: false);
      }
    });
    _completedSub = _repo.watchCompletedMatches().listen((matches) {
      if (mounted) state = state.copyWith(completed: matches, isLoading: false);
    }, onError: (e) {
      if (mounted) {
        state = state.copyWith(
            error: AppErrorHandler.getUserFriendlyMessage(e), isLoading: false);
      }
    });
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, upcomingLimit: 6, completedLimit: 6);
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
      state = state.copyWith(
          isLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void loadMoreUpcoming() {
    if (state.isLoadingMoreUpcoming || !state.hasMoreUpcoming) return;
    state = state.copyWith(isLoadingMoreUpcoming: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMoreUpcoming: false,
        upcomingLimit: state.upcomingLimit + 6,
      );
    });
  }

  void loadMoreCompleted() {
    if (state.isLoadingMoreCompleted || !state.hasMoreCompleted) return;
    state = state.copyWith(isLoadingMoreCompleted: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMoreCompleted: false,
        completedLimit: state.completedLimit + 6,
      );
    });
  }

  void setTab(int i) => state = state.copyWith(tabIndex: i);

  @override
  void dispose() {
    _upcomingSub?.cancel();
    _completedSub?.cancel();
    super.dispose();
  }
}

final matchesViewModelProvider =
    StateNotifierProvider<MatchesViewModel, MatchesState>(
        (ref) => MatchesViewModel(ref.read(matchRepositoryProvider)));

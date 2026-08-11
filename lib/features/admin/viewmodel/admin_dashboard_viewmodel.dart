import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/repositories/live_match_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/data/providers/live_match_providers.dart';

class AdminDashboardState {
  final bool isLoading;
  final String? error;
  final List<MatchModel> liveMatches;
  final List<MatchModel> upcomingMatches;

  const AdminDashboardState({
    this.isLoading = true,
    this.error,
    this.liveMatches = const [],
    this.upcomingMatches = const [],
  });

  AdminDashboardState copyWith({
    bool? isLoading,
    String? error,
    List<MatchModel>? liveMatches,
    List<MatchModel>? upcomingMatches,
  }) => AdminDashboardState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    liveMatches: liveMatches ?? this.liveMatches,
    upcomingMatches: upcomingMatches ?? this.upcomingMatches,
  );
}

class AdminDashboardViewModel extends StateNotifier<AdminDashboardState> {
  final MatchRepository _matchRepo;
  final LiveMatchRepository _liveRepo;

  AdminDashboardViewModel(this._matchRepo, this._liveRepo)
      : super(const AdminDashboardState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _matchRepo.getLiveMatches(),
        _matchRepo.getUpcomingMatches(),
      ]);
      state = state.copyWith(
        isLoading: false,
        liveMatches: results[0],
        upcomingMatches: results[1],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> endMatch(String matchId) async {
    try {
      await _liveRepo.updateLiveMatch(matchId, {'status': 'completed'});
      await load();
    } catch (e) {
      state = state.copyWith(error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }
}

final adminDashboardViewModelProvider =
    StateNotifierProvider<AdminDashboardViewModel, AdminDashboardState>((ref) {
  return AdminDashboardViewModel(
    ref.watch(matchRepositoryProvider),
    ref.watch(liveMatchRepositoryProvider),
  );
});

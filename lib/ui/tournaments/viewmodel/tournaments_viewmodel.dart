import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/data/repositories/tournament_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class TournamentsState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<TournamentModel> tournaments;
  final int displayLimit;
  final TournamentModel? selected;

  const TournamentsState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.tournaments = const [],
    this.displayLimit = 6,
    this.selected,
  });

  List<TournamentModel> get displayedTournaments =>
      tournaments.take(displayLimit).toList();

  bool get hasMore => displayLimit < tournaments.length;

  TournamentsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<TournamentModel>? tournaments,
    int? displayLimit,
    TournamentModel? selected,
  }) =>
      TournamentsState(
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error,
        tournaments: tournaments ?? this.tournaments,
        displayLimit: displayLimit ?? this.displayLimit,
        selected: selected ?? this.selected,
      );
}

class TournamentsViewModel extends StateNotifier<TournamentsState> {
  final TournamentRepository _repo;
  TournamentsViewModel(this._repo) : super(const TournamentsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, displayLimit: 6);
    try {
      final data = await _repo.getAllTournaments();
      state = state.copyWith(isLoading: false, tournaments: data);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void loadMore() {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    // Simulate short network delay for smoothness
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        displayLimit: state.displayLimit + 6,
      );
    });
  }

  Future<void> loadDetail(String id) async {
    try {
      final t = await _repo.getTournamentById(id);
      state = state.copyWith(selected: t);
    } catch (_) {}
  }
}

final tournamentsViewModelProvider =
    StateNotifierProvider<TournamentsViewModel, TournamentsState>(
        (ref) => TournamentsViewModel(ref.read(tournamentRepositoryProvider)));

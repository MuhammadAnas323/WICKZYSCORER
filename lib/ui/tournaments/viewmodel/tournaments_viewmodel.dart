import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/data/repositories/tournament_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class TournamentsState {
  final bool isLoading;
  final String? error;
  final List<TournamentModel> tournaments;
  final TournamentModel? selected;
  const TournamentsState({this.isLoading = true, this.error,
    this.tournaments = const [], this.selected});
  TournamentsState copyWith({bool? isLoading, String? error,
    List<TournamentModel>? tournaments, TournamentModel? selected}) =>
    TournamentsState(isLoading: isLoading ?? this.isLoading, error: error,
      tournaments: tournaments ?? this.tournaments, selected: selected ?? this.selected);
}

class TournamentsViewModel extends StateNotifier<TournamentsState> {
  final TournamentRepository _repo;
  TournamentsViewModel(this._repo) : super(const TournamentsState()) { load(); }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _repo.getAllTournaments();
      state = state.copyWith(isLoading: false, tournaments: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadDetail(String id) async {
    try {
      final t = await _repo.getTournamentById(id);
      state = state.copyWith(selected: t);
    } catch (_) {}
  }
}

final tournamentsViewModelProvider = StateNotifierProvider<TournamentsViewModel, TournamentsState>(
  (ref) => TournamentsViewModel(ref.read(tournamentRepositoryProvider)));

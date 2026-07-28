import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class LiveMatchesState {
  final bool isLoading;
  final String? error;
  final List<MatchModel> matches;
  const LiveMatchesState({this.isLoading = true, this.error, this.matches = const []});
  LiveMatchesState copyWith({bool? isLoading, String? error, List<MatchModel>? matches}) =>
    LiveMatchesState(isLoading: isLoading ?? this.isLoading, error: error, matches: matches ?? this.matches);
}

class LiveMatchesViewModel extends StateNotifier<LiveMatchesState> {
  final MatchRepository _repo;
  StreamSubscription? _sub;

  LiveMatchesViewModel(this._repo) : super(const LiveMatchesState()) {
    _init();
  }

  void _init() {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.getLiveMatches();
      state = state.copyWith(isLoading: false, matches: data);
    } catch (_) {
      state = state.copyWith(isLoading: false, matches: []);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final liveMatchesViewModelProvider = StateNotifierProvider<LiveMatchesViewModel, LiveMatchesState>(
  (ref) => LiveMatchesViewModel(ref.read(matchRepositoryProvider)));

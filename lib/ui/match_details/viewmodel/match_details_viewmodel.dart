import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/repositories/live_match_repository.dart';
import 'package:sportyapp/data/providers/live_match_providers.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class MatchDetailsState {
  final bool isLoading;
  final String? error;
  final MatchModel? match;
  final LiveMatchData? liveData;
  final int tabIndex;
  const MatchDetailsState({
    this.isLoading = true,
    this.error,
    this.match,
    this.liveData,
    this.tabIndex = 0,
  });
  MatchDetailsState copyWith({
    bool? isLoading,
    String? error,
    MatchModel? match,
    LiveMatchData? liveData,
    int? tabIndex,
  }) =>
      MatchDetailsState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        match: match ?? this.match,
        liveData: liveData ?? this.liveData,
        tabIndex: tabIndex ?? this.tabIndex,
      );
}

class MatchDetailsViewModel extends StateNotifier<MatchDetailsState> {
  final MatchRepository _matchRepo;
  final LiveMatchRepository _liveRepo;
  final String matchId;
  StreamSubscription<LiveMatchData>? _liveSub;

  MatchDetailsViewModel(this._matchRepo, this._liveRepo, this.matchId)
      : super(const MatchDetailsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final m = await _matchRepo.getMatchById(matchId);
      if (m == null) throw Exception('Match not found');
      state = state.copyWith(isLoading: false, match: m);
      _listenToLiveData();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _listenToLiveData() {
    _liveSub?.cancel();
    try {
      _liveSub = _liveRepo.watchLiveMatch(matchId).listen(
        (liveData) {
          if (mounted) {
            state = state.copyWith(liveData: liveData);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void setTab(int i) => state = state.copyWith(tabIndex: i);

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}

final matchDetailsViewModelProvider = StateNotifierProvider.family
    <MatchDetailsViewModel, MatchDetailsState, String>(
  (ref, matchId) => MatchDetailsViewModel(
    ref.read(matchRepositoryProvider),
    ref.read(liveMatchRepositoryProvider),
    matchId,
  ));

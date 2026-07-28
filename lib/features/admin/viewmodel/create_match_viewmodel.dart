import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/team_model.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/repositories/team_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class CreateMatchState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final String? matchId;
  final List<TeamModel> teams;

  const CreateMatchState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.matchId,
    this.teams = const [],
  });

  CreateMatchState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    String? matchId,
    List<TeamModel>? teams,
  }) => CreateMatchState(
    isLoading: isLoading ?? this.isLoading,
    isSuccess: isSuccess ?? this.isSuccess,
    error: error,
    matchId: matchId ?? this.matchId,
    teams: teams ?? this.teams,
  );
}

class CreateMatchViewModel extends StateNotifier<CreateMatchState> {
  final MatchRepository _matchRepo;
  final TeamRepository _teamRepo;

  CreateMatchViewModel(this._matchRepo, this._teamRepo)
      : super(const CreateMatchState()) {
    loadTeams();
  }

  Future<void> loadTeams() async {
    try {
      final teams = await _teamRepo.getAllTeams();
      state = state.copyWith(teams: teams);
    } catch (_) {}
  }

  Future<void> createMatch({
    required String title,
    required String seriesName,
    required String seriesId,
    required MatchFormat format,
    required String teamAId,
    required String teamBId,
    required DateTime scheduledAt,
    required String venue,
    required String city,
    required String umpires,
    int? totalOvers,
    String? tossWinner,
    String? tossDecision,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final teamA = state.teams.firstWhere((t) => t.id == teamAId);
      final teamB = state.teams.firstWhere((t) => t.id == teamBId);

      final match = await _matchRepo.createMatch(
        title: title,
        seriesName: seriesName,
        seriesId: seriesId,
        format: format,
        teamA: teamA,
        teamB: teamB,
        scheduledAt: scheduledAt,
        venue: venue,
        city: city,
        umpires: umpires,
        totalOvers: totalOvers,
        tossWinner: tossWinner,
        tossDecision: tossDecision,
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        matchId: match.id,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = const CreateMatchState();
    loadTeams();
  }
}

final createMatchViewModelProvider =
    StateNotifierProvider<CreateMatchViewModel, CreateMatchState>((ref) {
  return CreateMatchViewModel(
    ref.watch(matchRepositoryProvider),
    ref.watch(teamRepositoryProvider),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/player_model.dart';
import 'package:sportyapp/data/models/team_model.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/data/repositories/match_repository.dart';
import 'package:sportyapp/data/repositories/player_repository.dart';
import 'package:sportyapp/data/repositories/team_repository.dart';
import 'package:sportyapp/data/repositories/tournament_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class SearchState {
  final String query;
  final bool isLoading;
  final List<MatchModel> matches;
  final List<PlayerModel> players;
  final List<TeamModel> teams;
  final List<TournamentModel> tournaments;
  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.matches = const [],
    this.players = const [],
    this.teams = const [],
    this.tournaments = const [],
  });
  SearchState copyWith({String? query, bool? isLoading,
    List<MatchModel>? matches, List<PlayerModel>? players,
    List<TeamModel>? teams, List<TournamentModel>? tournaments}) =>
    SearchState(
      query: query ?? this.query, isLoading: isLoading ?? this.isLoading,
      matches: matches ?? this.matches, players: players ?? this.players,
      teams: teams ?? this.teams, tournaments: tournaments ?? this.tournaments,
    );
}

class SearchViewModel extends StateNotifier<SearchState> {
  final MatchRepository _matchRepo;
  final PlayerRepository _playerRepo;
  final TeamRepository _teamRepo;
  final TournamentRepository _tournamentRepo;

  SearchViewModel(this._matchRepo, this._playerRepo, this._teamRepo, this._tournamentRepo)
      : super(const SearchState());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchState();
      return;
    }
    state = state.copyWith(query: query, isLoading: true);
    final results = await Future.wait([
      _matchRepo.searchMatches(query),
      _playerRepo.searchPlayers(query),
      _teamRepo.searchTeams(query),
      _tournamentRepo.searchTournaments(query),
    ]);
    state = state.copyWith(
      isLoading: false,
      matches: results[0] as List<MatchModel>,
      players: results[1] as List<PlayerModel>,
      teams: results[2] as List<TeamModel>,
      tournaments: results[3] as List<TournamentModel>,
    );
  }

  void clear() => state = const SearchState();
}

final searchViewModelProvider = StateNotifierProvider<SearchViewModel, SearchState>(
  (ref) => SearchViewModel(
    ref.read(matchRepositoryProvider),
    ref.read(playerRepositoryProvider),
    ref.read(teamRepositoryProvider),
    ref.read(tournamentRepositoryProvider),
  ));

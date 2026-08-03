// test/scorer_persistence_test.dart
// Guards the scorer persistence contract: tournaments, teams and players added
// by the scorer must survive leaving/re-entering the screen and app restarts
// (i.e. a fresh repository instance must reload them from the local cache).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tournament, team and player survive a repository re-instantiation',
      () async {
    SharedPreferences.setMockInitialValues({});

    // First repository instance = the scorer adding data on a screen.
    final repo1 = ScorerRepository(null);
    await repo1.saveTournament(ScorerTournament(
      id: 't1',
      name: 'Test Cup',
      ownerId: 'owner',
      format: MatchFormat.t20,
      customOvers: 20,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 2, 1),
      venue: 'Ground',
      numTeams: 1,
      teamIds: const ['team1'],
      pointsRules: const PointsRules(),
    ));
    await repo1.saveTeam(ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't1',
      playerIds: const ['p1'],
    ));
    await repo1.savePlayer(ScorerPlayer(
      id: 'p1',
      name: 'Batsman One',
      teamId: 'team1',
      tournamentId: 't1',
      role: PlayerRole.batsman,
      battingStyle: BattingStyle.rightHand,
      bowlingStyle: BowlingStyle.none,
      jerseyNumber: 7,
    ));

    // Second repository instance = user backed out of the screen / restarted.
    final repo2 = ScorerRepository(null);
    final tournaments = await repo2.getTournaments();
    final teams = await repo2.getTeamsByTournament('t1');
    final players = await repo2.getPlayersByTeam('team1');

    expect(tournaments, hasLength(1));
    expect(tournaments.single.name, 'Test Cup');
    expect(teams, hasLength(1));
    expect(teams.single.name, 'Kings XI');
    expect(teams.single.playerIds, ['p1']);
    expect(players, hasLength(1));
    expect(players.single.name, 'Batsman One');
  });
}

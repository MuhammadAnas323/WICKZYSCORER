// test/scorer_persistence_test.dart
// Guards the scorer persistence contract: with the local SharedPreferences
// cache removed, data lives ONLY in Firestore. A repository with no cloud
// source keeps data purely in memory — a fresh instance must start empty.

import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('data does not survive a repository re-instantiation without a cloud',
      () async {
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
    await repo1.saveTeam(const ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't1',
      playerIds: ['p1'],
    ));
    await repo1.savePlayer(const ScorerPlayer(
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
    // With no local cache, a cloud-less repository must start empty.
    final repo2 = ScorerRepository(null);
    final tournaments = await repo2.getTournaments();
    final teams = await repo2.getTeamsByTournament('t1');
    final players = await repo2.getPlayersByTeam('team1');

    expect(tournaments, isEmpty);
    expect(teams, isEmpty);
    expect(players, isEmpty);
  });
}

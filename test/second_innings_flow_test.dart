// test/second_innings_flow_test.dart
// Guards the "Start 2nd Innings" flow: after the 1st innings is complete the
// banner must appear and the innings-break dialog must actually switch to the
// 2nd innings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/live_scoring/view/live_scoring_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Start 2nd Innings banner switches innings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);

    await repo.saveTournament(ScorerTournament(
      id: 't1',
      name: 'Test Cup',
      ownerId: 'owner',
      format: MatchFormat.t20,
      customOvers: 5,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 2, 1),
      venue: 'Ground',
      numTeams: 2,
      teamIds: const ['team1', 'team2'],
      pointsRules: const PointsRules(),
    ));
    await repo.saveTeam(ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't1',
      playerIds: const ['p1', 'p2', 'p3'],
    ));
    await repo.saveTeam(ScorerTeam(
      id: 'team2',
      name: 'Lions',
      shortCode: 'LI',
      tournamentId: 't1',
      playerIds: const ['p4', 'p5', 'p6'],
    ));
    for (final p in const [
      ScorerPlayer(id: 'p1', name: 'Batsman One', teamId: 'team1', tournamentId: 't1', role: PlayerRole.batsman, battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.none),
      ScorerPlayer(id: 'p2', name: 'Batsman Two', teamId: 'team1', tournamentId: 't1', role: PlayerRole.batsman, battingStyle: BattingStyle.leftHand, bowlingStyle: BowlingStyle.none),
      ScorerPlayer(id: 'p3', name: 'All Rounder', teamId: 'team1', tournamentId: 't1', role: PlayerRole.allRounder, battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.rightArmSpin),
      ScorerPlayer(id: 'p4', name: 'Bowler One', teamId: 'team2', tournamentId: 't1', role: PlayerRole.bowler, battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.rightArmSpin),
      ScorerPlayer(id: 'p5', name: 'Bowler Two', teamId: 'team2', tournamentId: 't1', role: PlayerRole.bowler, battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.leftArmSpin),
      ScorerPlayer(id: 'p6', name: 'Batsman Three', teamId: 'team2', tournamentId: 't1', role: PlayerRole.batsman, battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.none),
    ]) {
      await repo.savePlayer(p);
    }

    // 1st innings: batting team1, already complete, a couple of runs on board.
    final inn1 = Innings(
      id: 'inn_1',
      battingTeamId: 'team1',
      bowlingTeamId: 'team2',
      inningsNumber: 1,
      balls: [
        BallEvent(overNumber: 1, ballInOver: 1, batsmanId: 'p1', bowlerId: 'p4', runs: 4, extrasType: ExtrasType.none, extrasRuns: 0, isWicket: false, isBoundary: true, isSix: false, timestamp: DateTime(2026, 1, 1)),
      ],
      battingOrder: ['p1', 'p2'],
      bowlingOrder: ['p4'],
      isComplete: true,
      strikerId: 'p1',
      nonStrikerId: 'p2',
      currentBowlerId: 'p4',
    );

    final match = ScorerMatch(
      id: 'm1',
      tournamentId: 't1',
      team1Id: 'team1',
      team2Id: 'team2',
      venue: 'Ground',
      dateTime: DateTime(2026, 1, 1),
      format: MatchFormat.t20,
      overs: 5,
      status: MatchStatus.inProgress,
      playingXI1: ['p1', 'p2'],
      playingXI2: ['p4', 'p5', 'p6'],
      innings1: inn1,
      currentInnings: 1,
    );

    final container = ProviderContainer(
      overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: LiveScoringScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // 1st innings scoreboard + the "Start 2nd Innings" banner.
    expect(find.text('4/0'), findsOneWidget);
    expect(find.text('1st Innings complete'), findsOneWidget);

    // Open the innings break dialog.
    await tester.ensureVisible(find.text('Start 2nd Innings'));
    await tester.pump();
    await tester.tap(find.text('Start 2nd Innings'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('⏸️ Innings Break'), findsOneWidget);
    // Select striker, non-striker (2nd innings batting = team2) and bowler.
    await tester.tap(find.text('All Rounder'));
    await tester.pump();
    // The batting list uses Strike / Non-S pills.
    final strikePills = find.text('Strike');
    expect(strikePills, findsWidgets);
    await tester.tap(strikePills.first);
    await tester.pump();
    final nonPills = find.text('Non-S');
    await tester.tap(nonPills.at(1));
    await tester.pump();

    await tester.ensureVisible(find.text('Start 2nd Innings').last);
    await tester.pump();
    await tester.tap(find.text('Start 2nd Innings').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Now in the 2nd innings: fresh scoreboard.
    expect(container.read(scorerLiveMatchRepositoryProvider).activeMatch!.currentInnings, 2);
    expect(find.text('0/0'), findsOneWidget);
    expect(find.text('1st Innings complete'), findsNothing);
  });
}

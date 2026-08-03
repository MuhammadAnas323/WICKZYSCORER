// test/live_scoring_undo_ui_test.dart
// Guards the fix where the Undo button did nothing visible: the live scoring
// screen must rebuild from the live-match stream after any repo mutation.

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

  testWidgets('undo button refreshes the scoreboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);

    await repo.saveTournament(ScorerTournament(
      id: 't1',
      name: 'Test Cup',
      ownerId: 'owner',
      format: MatchFormat.t20,
      customOvers: 20,
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
      playerIds: const ['p1', 'p2'],
    ));
    await repo.saveTeam(ScorerTeam(
      id: 'team2',
      name: 'Lions',
      shortCode: 'LI',
      tournamentId: 't1',
      playerIds: const ['p4'],
    ));
    for (final p in const [
      ScorerPlayer(id: 'p1', name: 'Batsman One', teamId: 'team1', tournamentId: 't1', role: PlayerRole.batsman, battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.none),
      ScorerPlayer(id: 'p2', name: 'Batsman Two', teamId: 'team1', tournamentId: 't1', role: PlayerRole.batsman, battingStyle: BattingStyle.leftHand, bowlingStyle: BowlingStyle.none),
      ScorerPlayer(id: 'p4', name: 'Bowler One', teamId: 'team2', tournamentId: 't1', role: PlayerRole.bowler, battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.rightArmSpin),
    ]) {
      await repo.savePlayer(p);
    }

    final match = ScorerMatch(
      id: 'm1',
      tournamentId: 't1',
      team1Id: 'team1',
      team2Id: 'team2',
      venue: 'Ground',
      dateTime: DateTime(2026, 1, 1),
      format: MatchFormat.t20,
      overs: 20,
      status: MatchStatus.inProgress,
      playingXI1: ['p1', 'p2'],
      playingXI2: ['p4'],
      innings1: const Innings(
        id: 'inn_1',
        battingTeamId: 'team1',
        bowlingTeamId: 'team2',
        inningsNumber: 1,
        balls: [],
        battingOrder: ['p1', 'p2'],
        bowlingOrder: ['p4'],
        isComplete: false,
        strikerId: 'p1',
        nonStrikerId: 'p2',
        currentBowlerId: 'p4',
      ),
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
    // The LIVE badge pulses forever, so pumpAndSettle would time out.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // Initial scoreboard.
    expect(find.text('0/0'), findsOneWidget);
    // The Undo control is present on the run pad.
    expect(find.text('↩ Undo'), findsOneWidget);

    // Record 1 run via the same repo call the run button makes -> the screen
    // must rebuild from the live-match stream and show 1/0.
    final liveRepo = container.read(scorerLiveMatchRepositoryProvider);
    liveRepo.recordBall(BallEvent(
      overNumber: 1,
      ballInOver: 1,
      batsmanId: 'p1',
      bowlerId: 'p4',
      runs: 1,
      extrasType: ExtrasType.none,
      extrasRuns: 0,
      isWicket: false,
      isBoundary: false,
      isSix: false,
      timestamp: DateTime.now(),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('1/0'), findsOneWidget);

    // Undo -> scoreboard returns to 0/0 (this used to do nothing).
    liveRepo.undoLastBall();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('0/0'), findsOneWidget);
    expect(find.text('1/0'), findsNothing);
  });
}

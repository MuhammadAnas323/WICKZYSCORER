// test/squad_toss_flow_test.dart
// Guards the match flow fixes: the toss screen resolves real team names (not
// raw ids) and the squad setup screen requires at least one player per team
// before continuing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/squad_setup/view/squad_setup_screen.dart';
import 'package:sportyapp/ui/scorer/start_scoring/view/toss_screen.dart';

Future<ScorerRepository> _seedData() async {
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
    playerIds: const ['p3'],
  ));
  await repo.savePlayer(ScorerPlayer(
    id: 'p1',
    name: 'Batsman One',
    teamId: 'team1',
    tournamentId: 't1',
    role: PlayerRole.batsman,
    battingStyle: BattingStyle.rightHand,
    bowlingStyle: BowlingStyle.none,
  ));
  await repo.savePlayer(ScorerPlayer(
    id: 'p2',
    name: 'Batsman Two',
    teamId: 'team1',
    tournamentId: 't1',
    role: PlayerRole.batsman,
    battingStyle: BattingStyle.leftHand,
    bowlingStyle: BowlingStyle.none,
  ));
  await repo.savePlayer(ScorerPlayer(
    id: 'p3',
    name: 'Bowler One',
    teamId: 'team2',
    tournamentId: 't1',
    role: PlayerRole.bowler,
    battingStyle: BattingStyle.rightHand,
    bowlingStyle: BowlingStyle.rightArmSpin,
  ));
  await repo.saveMatch(ScorerMatch(
    id: 'm1',
    tournamentId: 't1',
    team1Id: 'team1',
    team2Id: 'team2',
    venue: 'Ground',
    dateTime: DateTime.now(),
    format: MatchFormat.t20,
    overs: 20,
    status: MatchStatus.scheduled,
    playingXI1: const [],
    playingXI2: const [],
    currentInnings: 1,
  ));
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toss screen shows real team names, not raw ids', (tester) async {
    final repo = await _seedData();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: TossScreen(matchId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The squad banner uses resolved team names.
    expect(find.textContaining('Kings XI'), findsWidgets);
    expect(find.textContaining('Lions'), findsWidgets);
    expect(find.textContaining('team1'), findsNothing);
    expect(find.textContaining('team2'), findsNothing);

    // Pick the toss winner (Kings XI) and a decision.
    await tester.tap(find.text('Kings XI'));
    await tester.pump();
    await tester.tap(find.text('Bat First'));
    await tester.pump();

    // Batting team section is labelled with the real team name.
    expect(find.text('Kings XI — Opening Batsmen'), findsOneWidget);
    expect(find.text('Lions — Opening Bowler'), findsOneWidget);

    // Starting scoring before openers are picked shows a helpful error.
    await tester.ensureVisible(find.text('Start Live Scoring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Live Scoring'));
    await tester.pump();
    expect(find.text('Select the opening batsmen and the opening bowler'),
        findsOneWidget);
  });

  testWidgets('squad setup requires at least one player per team',
      (tester) async {
    final repo = await _seedData();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: SquadSetupScreen(matchId: 'm1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both teams and their players are shown.
    expect(find.text('Kings XI'), findsOneWidget);
    expect(find.text('Lions'), findsOneWidget);
    expect(find.text('Batsman One'), findsOneWidget);
    expect(find.text('Bowler One'), findsOneWidget);

    // Deselect the two Kings XI players -> one team has an empty squad, so
    // the Start Scoring button becomes disabled with a hint.
    await tester.tap(find.text('Batsman One'));
    await tester.pump();
    await tester.tap(find.text('Batsman Two'));
    await tester.pump();

    // Scroll the ListView so the bottom (button + helper text) is revealed.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();

    final startButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Start Scoring'),
    );
    expect(startButton.onPressed, isNull);
    expect(
      find.text('Select at least one player for each team to start scoring.'),
      findsOneWidget,
    );
  });
}

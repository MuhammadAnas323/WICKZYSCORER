// test/schedule_view_progression_test.dart
// Verifies the read-only Schedule View surfaces bracket progression: winner
// advancing to the next match, loser eliminated, and pending fixtures that are
// waiting for an opponent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/schedule/view/schedule_view_screen.dart';

Future<ScorerRepository> _seed() async {
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
    numTeams: 4,
    teamIds: const ['team1', 'team2', 'team3', 'team4'],
    pointsRules: const PointsRules(),
  ));
  for (final t in const [
    ('team1', 'Kings XI'),
    ('team2', 'Lions'),
    ('team3', 'Tigers'),
    ('team4', 'Bears'),
  ]) {
    await repo.saveTeam(ScorerTeam(
      id: t.$1,
      name: t.$2,
      shortCode: t.$2.substring(0, 2),
      tournamentId: 't1',
      playerIds: const [],
    ));
  }

  await repo.saveSchedule('t1', [
    ScheduleStage(
      id: 'semi',
      name: 'Semi Finals',
      order: 0,
      type: ScheduleStageType.knockout,
      fixtures: [
        ScheduleFixture(
          id: 'sf1',
          order: 1,
          teamASource: const ScheduleSource.team('team1'),
          teamBSource: const ScheduleSource.team('team2'),
          resolvedTeamAId: 'team1',
          resolvedTeamBId: 'team2',
          winnerTeamId: 'team1',
          status: FixtureStatus.completed,
        ),
        ScheduleFixture(
          id: 'sf2',
          order: 2,
          teamASource: const ScheduleSource.team('team3'),
          teamBSource: const ScheduleSource.tbd(),
          resolvedTeamAId: 'team3',
          status: FixtureStatus.pending,
        ),
      ],
      config: const StageConfiguration(
        nextStageId: 'fin',
        winnerAction: StageProgressionAction.advance,
        loserAction: StageProgressionAction.eliminate,
      ),
    ),
    ScheduleStage(
      id: 'fin',
      name: 'Final',
      order: 1,
      type: ScheduleStageType.knockout,
      fixtures: [
        ScheduleFixture(
          id: 'fin',
          order: 1,
          teamASource: ScheduleSource.matchResult('sf1', 'winner'),
          teamBSource: ScheduleSource.matchResult('sf2', 'winner'),
          resolvedTeamAId: 'team1',
          status: FixtureStatus.pending,
        ),
      ],
      config: const StageConfiguration(
        winnerAction: StageProgressionAction.advance,
        loserAction: StageProgressionAction.eliminate,
      ),
    ),
  ]);
  return repo;
}

Future<ScorerRepository> _seedTied() async {
  final repo = await _seed();
  // Override with a bracket where the first semi-final finished TIED (no
  // winnerTeamId) and the other semi is still waiting for an opponent.
  await repo.saveSchedule('t1', [
    ScheduleStage(
      id: 'semi',
      name: 'Semi Finals',
      order: 0,
      type: ScheduleStageType.knockout,
      fixtures: [
        ScheduleFixture(
          id: 'sf1',
          order: 1,
          teamASource: const ScheduleSource.team('team1'),
          teamBSource: const ScheduleSource.team('team2'),
          resolvedTeamAId: 'team1',
          resolvedTeamBId: 'team2',
          winnerTeamId: null,
          status: FixtureStatus.completed,
        ),
        ScheduleFixture(
          id: 'sf2',
          order: 2,
          teamASource: const ScheduleSource.team('team3'),
          teamBSource: const ScheduleSource.tbd(),
          resolvedTeamAId: 'team3',
          status: FixtureStatus.pending,
        ),
      ],
      config: const StageConfiguration(
        nextStageId: 'fin',
        winnerAction: StageProgressionAction.advance,
        loserAction: StageProgressionAction.eliminate,
      ),
    ),
    ScheduleStage(
      id: 'fin',
      name: 'Final',
      order: 1,
      type: ScheduleStageType.knockout,
      fixtures: [
        ScheduleFixture(
          id: 'fin',
          order: 1,
          teamASource: ScheduleSource.matchResult('sf1', 'winner'),
          teamBSource: ScheduleSource.matchResult('sf2', 'winner'),
          status: FixtureStatus.pending,
        ),
      ],
      config: const StageConfiguration(
        winnerAction: StageProgressionAction.advance,
        loserAction: StageProgressionAction.eliminate,
      ),
    ),
  ]);
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('schedule view shows winner advancing and loser eliminated',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repo = await _seed();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', ''), Locale('ur', '')],
          home: const ScheduleViewScreen(tournamentId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Stage cards collapse to a summary; tap to reveal the stage's fixtures.
    expect(find.text('Kings XI → Final'), findsNothing);
    await tester.tap(find.text('Semi Finals'));
    await tester.pumpAndSettle();

    // Winner of sf1 advances to the Final.
    expect(find.text('Kings XI → Final'), findsOneWidget);
    // Loser of sf1 is eliminated.
    expect(find.text('Lions · Eliminated'), findsOneWidget);
    // sf2 and the Final are both waiting for an opponent.
    expect(find.text('Waiting for opponent'), findsWidgets);
  });

  testWidgets('schedule view shows a tied decision for both teams',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repo = await _seedTied();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', ''), Locale('ur', '')],
          home: const ScheduleViewScreen(tournamentId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ties are hidden until the stage card is expanded.
    expect(find.text('Kings XI · Match Tied!'), findsNothing);
    await tester.tap(find.text('Semi Finals'));
    await tester.pumpAndSettle();

    // Both sides of the tied semi-final get an explicit decision.
    expect(find.text('Kings XI · Match Tied!'), findsOneWidget);
    expect(find.text('Lions · Match Tied!'), findsOneWidget);
    // sf2 is still waiting for its opponent.
    expect(find.text('Waiting for opponent'), findsWidgets);
  });

  testWidgets('schedule view stage cards expand and collapse on tap',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repo = await _seed();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', ''), Locale('ur', '')],
          home: const ScheduleViewScreen(tournamentId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Collapsed by default: the header shows the completed/upcoming summary.
    expect(find.text('1 COMPLETED  ·  1 UPCOMING'), findsOneWidget);
    expect(find.text('Kings XI → Final'), findsNothing);

    // Tap the stage card to reveal its fixtures.
    await tester.tap(find.text('Semi Finals'));
    await tester.pumpAndSettle();
    expect(find.text('Kings XI → Final'), findsOneWidget);

    // Tap again to collapse back to the summary.
    await tester.tap(find.text('Semi Finals'));
    await tester.pumpAndSettle();
    expect(find.text('Kings XI → Final'), findsNothing);
  });
}

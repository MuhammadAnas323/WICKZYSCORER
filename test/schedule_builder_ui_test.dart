// test/schedule_builder_ui_test.dart
// Verifies the manual-schedule screen renders long stage names wrapped onto
// multiple lines instead of squeezing them onto a single row.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/schedule/view/schedule_builder_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('long stage name wraps onto multiple lines (no single-row squeeze)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
      numTeams: 0,
      teamIds: const [],
      pointsRules: const PointsRules(),
    ));

    const longName =
        'Group A - This is an extremely long stage name that should wrap '
        'onto multiple lines instead of being crammed into one row';
    await repo.saveSchedule('t1', [
      ScheduleStage(
        id: 's1',
        name: longName,
        order: 0,
        type: ScheduleStageType.custom,
        fixtures: const [],
      ),
    ]);

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
          home: const ScheduleBuilderScreen(tournamentId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No render overflow.
    expect(tester.takeException(), isNull);

    final text = find.text(longName);
    expect(text, findsOneWidget);

    final rp = tester.renderObject<RenderParagraph>(text);
    final painter = TextPainter(
      text: rp.text,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    // The rendered paragraph is taller than a single laid-out line => it wrapped.
    expect(rp.size.height, greaterThan(painter.height));
  });

  testWidgets('fixture winner/loser destinations are configurable and '
      'persist as progression rules', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            status: FixtureStatus.ready,
          ),
        ],
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
            teamASource: const ScheduleSource.tbd(),
            teamBSource: const ScheduleSource.team('team3'),
            resolvedTeamBId: 'team3',
            status: FixtureStatus.pending,
          ),
        ],
      ),
    ]);

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
          home: const ScheduleBuilderScreen(tournamentId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the progression config for the first fixture (alt-route icon).
    await tester.tap(find.byIcon(Icons.alt_route).first);
    await tester.pumpAndSettle();

    // Two "destination" types: winner + loser. Both default to Waiting /
    // Eliminated; configure winner to target the Final fixture.
    expect(find.text('Progression'), findsOneWidget);
    await tester.tap(find.text('Waiting for opponent').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Destination match').last);
    await tester.pumpAndSettle();

    // Select the Final's fixture from the destination-match dropdown.
    await tester.tap(find.text('Destination match').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Final — ').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save').last);
    await tester.pumpAndSettle();

    // After saving the sheet, the fixture tile shows the W → destination chip.
    expect(find.textContaining('W → Final — '), findsOneWidget);

    // And the persisted fixture carries the winner rule.
    final stages = await repo.getSchedule('t1');
    final sf1 = stages.first.fixtures.first;
    expect(sf1.winnerRule, isNotNull);
    expect(sf1.winnerRule!.destinationType, ProgressionDestinationType.fixture);
    expect(sf1.winnerRule!.destinationFixtureId, 'fin');
    // Loser keeps the default eliminated rule.
    expect(sf1.loserRule, isNotNull);
    expect(sf1.loserRule!.destinationType,
        ProgressionDestinationType.eliminated);
  });
}

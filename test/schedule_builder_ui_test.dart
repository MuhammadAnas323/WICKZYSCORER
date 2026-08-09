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
}

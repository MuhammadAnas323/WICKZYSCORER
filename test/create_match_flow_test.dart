// test/create_match_flow_test.dart
// Verifies the create-match flow: creating a local match navigates to the
// squad setup screen, and the matches list auto-refreshes when a match is saved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/create_match/view/create_local_match_screen.dart';
import 'package:sportyapp/ui/scorer/squad_setup/view/squad_setup_screen.dart';
import 'package:sportyapp/ui/scorer/matches/view/scorer_matches_screen.dart';

ScorerMatch _match(String id, String t1, String t2) {
  return ScorerMatch(
    id: id,
    tournamentId: 't_custom',
    team1Id: t1,
    team2Id: t2,
    venue: 'Ground',
    dateTime: DateTime(2026, 1, 1),
    format: MatchFormat.t20,
    overs: 20,
    status: MatchStatus.scheduled,
    playingXI1: const [],
    playingXI2: const [],
    currentInnings: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creating a local match navigates to the squad setup screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: '/scorer/matches/create',
          builder: (_, __) => const CreateLocalMatchScreen(),
        ),
        GoRoute(
          path: '/scorer/matches/:id/squad',
          builder: (_, state) =>
              SquadSetupScreen(matchId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    router.go('/scorer/matches/create');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Team A'), 'India');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Team B'), 'Australia');

    final createButton = find.widgetWithText(ElevatedButton, 'Create Local Match');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    // We should now be on the squad setup screen for the new match.
    expect(find.text('Set Squads'), findsOneWidget);
    expect(find.text('India'), findsOneWidget);
    expect(find.text('Australia'), findsOneWidget);
  });

  testWidgets('matches list refreshes when a match is saved elsewhere',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);
    await repo.saveTeam(ScorerTeam(
      id: 't1',
      name: 'India',
      shortCode: 'IND',
      tournamentId: 't_custom',
      playerIds: const [],
    ));
    await repo.saveTeam(ScorerTeam(
      id: 't2',
      name: 'Australia',
      shortCode: 'AUS',
      tournamentId: 't_custom',
      playerIds: const [],
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ScorerMatchesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No matches yet'), findsOneWidget);

    // Simulate a match being created from another screen.
    await repo.saveMatch(_match('m1', 't1', 't2'));
    await tester.pumpAndSettle();

    expect(find.textContaining('India'), findsWidgets);
    expect(find.textContaining('Australia'), findsWidgets);
  });
}

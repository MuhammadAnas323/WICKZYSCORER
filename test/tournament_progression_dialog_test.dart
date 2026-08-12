// test/tournament_progression_dialog_test.dart
// Verifies the post-completion progression dialog:
//  - appears immediately after a tournament match is completed,
//  - shows the winner advancing to the next stage and the loser eliminated,
//  - declares the Champion after the final,
//  - never appears for friendly/local matches (t_custom).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:sportyapp/ui/scorer/live_scoring/view/live_scoring_screen.dart';
import 'package:sportyapp/ui/scorer/live_scoring/view/match_summary_screen.dart';
import 'package:sportyapp/shared_widgets/tournament_progression_dialog.dart';

class MockAuthService implements AuthService {
  @override
  AppUser? get currentUser => null;

  @override
  Stream<fa.User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> loadCurrentUser() async {}

  @override
  Future<AppUser> signIn(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> signUpScorer({
    required String name,
    required String email,
    required String password,
    String? organization,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> signUpSpectator({
    required String name,
    required String email,
    required String password,
    String? favoriteTournamentId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> signUpWithGoogle({
    required AppUserRole role,
    String? organization,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

/// An in-progress match: innings 1 closed on 10 runs, innings 2 currently on
/// 10 — one more run wins the chase (team2 wins).
ScorerMatch buildInProgressMatch({required String tournamentId}) {
  BallEvent single(String bat, String bowl) => BallEvent(
      overNumber: 1,
      ballInOver: 1,
      batsmanId: bat,
      bowlerId: bowl,
      runs: 1,
      extrasType: ExtrasType.none,
      extrasRuns: 0,
      isWicket: false,
      isBoundary: false,
      isSix: false,
      timestamp: DateTime(2026, 1, 1));

  final inn1 = Innings(
    id: 'inn_1',
    battingTeamId: 'team1',
    bowlingTeamId: 'team2',
    inningsNumber: 1,
    balls: List.generate(10, (i) => single('p1', 'p4')),
    battingOrder: const ['p1', 'p2'],
    bowlingOrder: const ['p4'],
    isComplete: true,
    strikerId: 'p1',
    nonStrikerId: 'p2',
    currentBowlerId: 'p4',
  );

  final inn2 = Innings(
    id: 'inn_2',
    battingTeamId: 'team2',
    bowlingTeamId: 'team1',
    inningsNumber: 2,
    balls: List.generate(10, (i) => single('p4', 'p1')),
    battingOrder: const ['p4', 'p5'],
    bowlingOrder: const ['p1'],
    isComplete: false,
    strikerId: 'p4',
    nonStrikerId: 'p5',
    currentBowlerId: 'p1',
  );

  return ScorerMatch(
    id: 'match_t1',
    tournamentId: tournamentId,
    team1Id: 'team1',
    team2Id: 'team2',
    venue: 'Ground',
    dateTime: DateTime(2026, 1, 1),
    format: MatchFormat.t20,
    overs: 5,
    status: MatchStatus.inProgress,
    playingXI1: const ['p1', 'p2'],
    playingXI2: const ['p4', 'p5'],
    innings1: inn1,
    innings2: inn2,
    currentInnings: 2,
  );
}

/// Seeds a 2-stage bracket: Semi Finals (team1 vs team2) feeding the Final.
Future<ScorerRepository> _seedSemiFinal() async {
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
    teamIds: const ['team1', 'team2'],
    pointsRules: const PointsRules(),
  ));
  await repo.saveTeam(const ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't1',
      playerIds: []));
  await repo.saveTeam(const ScorerTeam(
      id: 'team2',
      name: 'Lions',
      shortCode: 'LN',
      tournamentId: 't1',
      playerIds: []));

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
          status: FixtureStatus.live,
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
          id: 'final',
          order: 1,
          teamASource: ScheduleSource.matchResult('sf1', 'winner'),
          teamBSource: const ScheduleSource.tbd(),
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

/// Seeds a one-stage bracket: a single Final that crowns the champion.
Future<ScorerRepository> _seedFinal() async {
  final repo = ScorerRepository(null);
  await repo.saveTournament(ScorerTournament(
    id: 't2',
    name: 'Cup Final',
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
  await repo.saveTeam(const ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't2',
      playerIds: []));
  await repo.saveTeam(const ScorerTeam(
      id: 'team2',
      name: 'Lions',
      shortCode: 'LN',
      tournamentId: 't2',
      playerIds: []));

  await repo.saveSchedule('t2', [
    ScheduleStage(
      id: 'final',
      name: 'Final',
      order: 0,
      type: ScheduleStageType.knockout,
      fixtures: [
        ScheduleFixture(
          id: 'final',
          order: 1,
          teamASource: const ScheduleSource.team('team1'),
          teamBSource: const ScheduleSource.team('team2'),
          resolvedTeamAId: 'team1',
          resolvedTeamBId: 'team2',
          status: FixtureStatus.live,
          winnerTeamId: 'team2',
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

/// Seeds a 2-stage bracket: Semi Finals (team1 vs team2) feeding the Final.
/// Uses EXPLICIT per-fixture progression rules (winner → final fixture,
/// loser → eliminated) instead of legacy matchResult wiring.
Future<ScorerRepository> _seedSemiFinalRules() async {
  final repo = await _seedSemiFinal();
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
          status: FixtureStatus.live,
          winnerRule: const FixtureProgressionRule(
            sourceFixtureId: 'sf1',
            outcome: 'winner',
            destinationType: ProgressionDestinationType.fixture,
            destinationFixtureId: 'final',
            destinationStageId: 'fin',
          ),
          loserRule: const FixtureProgressionRule(
            sourceFixtureId: 'sf1',
            outcome: 'loser',
            destinationType: ProgressionDestinationType.eliminated,
          ),
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
          id: 'final',
          order: 1,
          teamASource: const ScheduleSource.tbd(),
          teamBSource: const ScheduleSource.team('team3'),
          resolvedTeamBId: 'team3',
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

/// Seeds a single NON-final stage ("Round Robin", one group winner) whose match
/// explicitly routes its winner to Champion — proving champion status comes from
/// the configured rule, not from a stage named Final / positioned last.
Future<ScorerRepository> _seedRuleChampion() async {
  final repo = ScorerRepository(null);
  await repo.saveTournament(ScorerTournament(
    id: 't3',
    name: 'Group Cup',
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
  await repo.saveTeam(const ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't3',
      playerIds: []));
  await repo.saveTeam(const ScorerTeam(
      id: 'team2',
      name: 'Lions',
      shortCode: 'LN',
      tournamentId: 't3',
      playerIds: []));

  await repo.saveSchedule('t3', [
    ScheduleStage(
      id: 'group',
      name: 'Group A',
      order: 0,
      type: ScheduleStageType.roundRobin,
      fixtures: [
        ScheduleFixture(
          id: 'g1',
          order: 1,
          teamASource: const ScheduleSource.team('team1'),
          teamBSource: const ScheduleSource.team('team2'),
          resolvedTeamAId: 'team1',
          resolvedTeamBId: 'team2',
          status: FixtureStatus.live,
          winnerRule: const FixtureProgressionRule(
            sourceFixtureId: 'g1',
            outcome: 'winner',
            destinationType: ProgressionDestinationType.champion,
          ),
          loserRule: const FixtureProgressionRule(
            sourceFixtureId: 'g1',
            outcome: 'loser',
            destinationType: ProgressionDestinationType.eliminated,
          ),
        ),
      ],
      config: const StageConfiguration(
        nextStageId: 'g2',
        winnerAction: StageProgressionAction.advance,
        loserAction: StageProgressionAction.eliminate,
      ),
    ),
  ]);
  return repo;
}

Widget testApp(ProviderContainer container, GoRouter router) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('ur', '')],
      routerConfig: router,
    ),
  );
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/scorer/live-scoring',
    routes: [
      GoRoute(
        path: '/scorer/live-scoring',
        name: 'live',
        builder: (context, state) => const LiveScoringScreen(),
      ),
      GoRoute(
        path: '/scorer/match-summary',
        name: 'summary',
        builder: (context, state) => const MatchSummaryScreen(),
      ),
      GoRoute(
        path: '/scorer/dashboard',
        name: 'dashboard',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('DASHBOARD'))),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'completing a tournament semi-final shows the progression dialog: '
      'winner advances to the final, loser eliminated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seedSemiFinal();

    final router = buildRouter();
    final container = ProviderContainer(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch(tournamentId: 't1');
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Win the chase (10 -> 11) to reach the summary.
    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MatchSummaryScreen), findsOneWidget);

    // Complete the match.
    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Complete Match'),
        100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Match'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The progression dialog appeared before navigating away.
    expect(find.byType(TournamentProgressionDialog), findsOneWidget);
    expect(find.text('Tournament Progress'), findsOneWidget);
    // Winner (Lions) advances to the Final; loser (Kings XI) is eliminated.
    expect(find.text('Winner 🏆'), findsOneWidget);
    expect(find.text('Advances to Final'), findsOneWidget);
    expect(find.text('Eliminated ❌'), findsOneWidget);

    // Dismissing it proceeds to the dashboard.
    await tester.tap(find.widgetWithText(TextButton, 'Continue'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets(
      'completing a rules-configured semi-final routes the winner into the '
      'Final fixture and shows the loser eliminated', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seedSemiFinalRules();

    final router = buildRouter();
    final container = ProviderContainer(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch(tournamentId: 't1');
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MatchSummaryScreen), findsOneWidget);

    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Complete Match'),
        100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Match'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(TournamentProgressionDialog), findsOneWidget);
    // Winner's rule routes into the Final fixture: already has a B team, so
    // the winner is seated and shown as advancing to the Final.
    expect(find.text('Winner 🏆'), findsOneWidget);
    expect(find.text('Eliminated ❌'), findsOneWidget);
  });

  testWidgets(
      'a champion rule on a NON-final stage crowns the winner — no stage-config '
      'assumption needed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seedRuleChampion();

    final router = buildRouter();
    final container = ProviderContainer(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch(tournamentId: 't3');
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MatchSummaryScreen), findsOneWidget);

    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Complete Match'),
        100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Match'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(TournamentProgressionDialog), findsOneWidget);
    // Champion via the explicit winner rule, even though this stage has a
    // nextStageId configured (would have been impossible under the legacy
    // "final = last stage" heuristic).
    expect(find.text('Champion 🏆'), findsOneWidget);
    expect(find.text('Eliminated ❌'), findsOneWidget);
  });

  testWidgets('completing the tournament final crowns the Champion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seedFinal();

    final router = buildRouter();
    final container = ProviderContainer(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch(tournamentId: 't2');
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MatchSummaryScreen), findsOneWidget);

    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Complete Match'),
        100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Match'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(TournamentProgressionDialog), findsOneWidget);
    expect(find.text('Champion 🏆'), findsOneWidget);
  });

  testWidgets('completing a friendly/local match does NOT show the '
      'progression dialog', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);

    final router = buildRouter();
    final container = ProviderContainer(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch(tournamentId: 't_custom');
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MatchSummaryScreen), findsOneWidget);

    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Complete Match'),
        100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Match'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // No dialog: straight to the dashboard.
    expect(find.byType(TournamentProgressionDialog), findsNothing);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });
}
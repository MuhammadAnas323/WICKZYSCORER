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
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:sportyapp/ui/scorer/live_scoring/view/live_scoring_screen.dart';
import 'package:sportyapp/ui/scorer/live_scoring/view/match_summary_screen.dart';
import 'package:sportyapp/ui/scorer/matches/view/scorer_matches_screen.dart';

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

ScorerMatch buildInProgressMatch() {
  final inn1 = Innings(
    id: 'inn_1',
    battingTeamId: 'team1',
    bowlingTeamId: 'team2',
    inningsNumber: 1,
    balls: List.generate(
      10,
      (i) => BallEvent(
          overNumber: (i ~/ 6) + 1,
          ballInOver: (i % 6) + 1,
          batsmanId: 'p1',
          bowlerId: 'p4',
          runs: 1,
          extrasType: ExtrasType.none,
          extrasRuns: 0,
          isWicket: false,
          isBoundary: false,
          isSix: false,
          timestamp: DateTime(2026, 1, 1)),
    ),
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
    balls: List.generate(
      10,
      (i) => BallEvent(
          overNumber: (i ~/ 6) + 1,
          ballInOver: (i % 6) + 1,
          batsmanId: 'p4',
          bowlerId: 'p1',
          runs: 1,
          extrasType: ExtrasType.none,
          extrasRuns: 0,
          isWicket: false,
          isBoundary: false,
          isSix: false,
          timestamp: DateTime(2026, 1, 1)),
    ),
    battingOrder: const ['p4', 'p5'],
    bowlingOrder: const ['p1'],
    isComplete: false,
    strikerId: 'p4',
    nonStrikerId: 'p5',
    currentBowlerId: 'p1',
  );

  return ScorerMatch(
    id: 'm1',
    tournamentId: 't_custom',
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

/// 1-over-per-side match tied at 6 runs each after the 2nd innings.
ScorerMatch buildTiedMatch() {
  final inn1 = Innings(
    id: 'inn_1',
    battingTeamId: 'team1',
    bowlingTeamId: 'team2',
    inningsNumber: 1,
    balls: List.generate(
      6,
      (i) => BallEvent(
          overNumber: 1,
          ballInOver: i + 1,
          batsmanId: 'p1',
          bowlerId: 'p4',
          runs: 1,
          extrasType: ExtrasType.none,
          extrasRuns: 0,
          isWicket: false,
          isBoundary: false,
          isSix: false,
          timestamp: DateTime(2026, 1, 1)),
    ),
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
    balls: List.generate(
      5,
      (i) => BallEvent(
          overNumber: 1,
          ballInOver: i + 1,
          batsmanId: 'p4',
          bowlerId: 'p1',
          runs: 1,
          extrasType: ExtrasType.none,
          extrasRuns: 0,
          isWicket: false,
          isBoundary: false,
          isSix: false,
          timestamp: DateTime(2026, 1, 1)),
    ),
    battingOrder: const ['p4', 'p5'],
    bowlingOrder: const ['p1'],
    isComplete: false,
    strikerId: 'p4',
    nonStrikerId: 'p5',
    currentBowlerId: 'p1',
  );

  return ScorerMatch(
    id: 'm1',
    tournamentId: 't_custom',
    team1Id: 'team1',
    team2Id: 'team2',
    venue: 'Ground',
    dateTime: DateTime(2026, 1, 1),
    format: MatchFormat.t20,
    overs: 1,
    status: MatchStatus.inProgress,
    playingXI1: const ['p1', 'p2'],
    playingXI2: const ['p4', 'p5'],
    innings1: inn1,
    innings2: inn2,
    currentInnings: 2,
  );
}

Future<void> seedPlayers(ScorerRepository repo) async {
  await repo.saveTeam(const ScorerTeam(
      id: 'team1',
      name: 'team1',
      shortCode: 'T1',
      tournamentId: 't_custom',
      playerIds: ['p1', 'p2']));
  await repo.saveTeam(const ScorerTeam(
      id: 'team2',
      name: 'team2',
      shortCode: 'T2',
      tournamentId: 't_custom',
      playerIds: ['p4', 'p5']));
  for (final p in [
    ScorerPlayer(
        id: 'p1',
        name: 'P1',
        teamId: 'team1',
        tournamentId: 't_custom',
        role: PlayerRole.batsman,
        battingStyle: BattingStyle.rightHand,
        bowlingStyle: BowlingStyle.rightArmPace),
    ScorerPlayer(
        id: 'p2',
        name: 'P2',
        teamId: 'team1',
        tournamentId: 't_custom',
        role: PlayerRole.allRounder,
        battingStyle: BattingStyle.rightHand,
        bowlingStyle: BowlingStyle.leftArmSpin),
    ScorerPlayer(
        id: 'p4',
        name: 'P4',
        teamId: 'team2',
        tournamentId: 't_custom',
        role: PlayerRole.batsman,
        battingStyle: BattingStyle.leftHand,
        bowlingStyle: BowlingStyle.none),
    ScorerPlayer(
        id: 'p5',
        name: 'P5',
        teamId: 'team2',
        tournamentId: 't_custom',
        role: PlayerRole.wicketKeeper,
        battingStyle: BattingStyle.rightHand,
        bowlingStyle: BowlingStyle.none),
  ]) {
    await repo.savePlayer(p);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('match summary appears after 2nd innings chase is won', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);

    final router = GoRouter(
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
      ],
    );

    final container = ProviderContainer(
      overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch();
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(
      UncontrolledProviderScope(
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('10/0'), findsOneWidget);

    // Tap the "1" run button to reach 11 -> chase won.
    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(MatchSummaryScreen), findsOneWidget);
  });

  testWidgets('finish match persists completed match hidden from Matches tab',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);

    final router = GoRouter(
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
        GoRoute(
          path: '/scorer/matches',
          name: 'matches',
          builder: (context, state) => const ScorerMatchesScreen(),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch();
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(
      UncontrolledProviderScope(
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Win the chase.
    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MatchSummaryScreen), findsOneWidget);

    // Tap Complete Match.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Match'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Back on the dashboard.
    expect(find.text('DASHBOARD'), findsOneWidget);

    // The match is persisted as completed.
    final saved = await repo.getMatch('m1');
    expect(saved, isNotNull);
    expect(saved!.status, MatchStatus.completed);
    expect(saved.resultSummary, isNotEmpty);

    // The completed match is listed under the "Completed" section of the
    // scorer Matches tab.
    router.go('/scorer/matches');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('team1  vs  team2'), findsOneWidget);
  });

  testWidgets('tied match offers super over, scores it, and reaches summary',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);
    await seedPlayers(repo);

    final router = GoRouter(
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
      ],
    );

    final container = ProviderContainer(
      overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final match = buildTiedMatch();
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(
      UncontrolledProviderScope(
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('5/0'), findsOneWidget);

    // 6th legal ball -> 2nd innings ends tied at 6/6.
    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Tie dialog offers a super over.
    expect(find.textContaining('Match Tied!'), findsOneWidget);
    await tester.tap(find.text('Start Super Over'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Super Over setup dialog.
    expect(find.textContaining('Super Over Setup'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('P4')),
        findsWidgets);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('P5')),
        findsWidgets);

    // Pick the chasing team's openers + a bowler from the bowling team.
    // The chasing team bats first in the super over: Strike = P4, Non-S = P5.
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Strike')).first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Non-S')).at(1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(RadioListTile<String>, 'P1')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Match'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Super over innings 1 (1 over). Score 6 runs -> innings complete.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.descendant(
          of: find.byType(GridView), matching: find.text('1')).first);
      for (var j = 0; j < 6; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(find.text('6/0'), findsOneWidget);

    // Banner to start the super over chase.
    expect(find.textContaining('Super Over'), findsWidgets);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Match'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Innings break dialog for the chase openers.
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('⚡ Super Over')),
        findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Strike')).first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Non-S')).at(1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(RadioListTile<String>, 'P4')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Start Match')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Super over chase: reach the target (6 -> 7 runs).
    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('6 ★')).first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.descendant(
        of: find.byType(GridView), matching: find.text('1')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Super over won by the chasing team -> summary with super over rows.
    expect(find.byType(MatchSummaryScreen), findsOneWidget);
    expect(find.textContaining('Super Over'), findsWidgets);
  });

  testWidgets('award sheet shows top performers, stats, and custom categories',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);
    await seedPlayers(repo);

    final router = GoRouter(
      initialLocation: '/scorer/match-summary',
      routes: [
        GoRoute(
          path: '/scorer/match-summary',
          name: 'summary',
          builder: (context, state) => const MatchSummaryScreen(),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final match = buildInProgressMatch();
    container.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    await tester.pumpWidget(
      UncontrolledProviderScope(
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Open the award sheet.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Award Prizes'));
    await tester.pumpAndSettle();

    // Sections render with top performers and their stat detail.
    expect(find.textContaining('Player of the Match'), findsWidgets);
    expect(find.textContaining('Best Batsman'), findsWidgets);
    expect(find.textContaining('Best Bowler'), findsWidgets);
    // P1 batted 10 balls for 10 runs -> should appear as a top performer.
    expect(find.textContaining('R 10'), findsWidgets);

    // Tap a player card to select it as Player of the Match.
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('P1')).first);
    await tester.pump(const Duration(milliseconds: 100));
    // Selected card shows a check icon.
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);

    // Add a custom category.
    await tester.ensureVisible(find.text('Add Custom Category'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add Custom Category'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Best Fielder');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    // Custom winner picker lists every player.
    expect(find.textContaining('Choose Winner'), findsWidgets);
    // Tap a player in the topmost (picker) bottom sheet, not the sheet below.
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('P4')).last);
    await tester.pumpAndSettle();

    // Back in the sheet the custom card shows the chosen winner.
    expect(find.textContaining('Best Fielder'), findsWidgets);
    expect(find.text('P4'), findsWidgets);

    // Save awards (scroll to the bottom bar).
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save Awards'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Awards'));
    await tester.pumpAndSettle();

    // Complete the match and confirm custom award persisted.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Match'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final saved = await repo.getMatch('m1');
    expect(saved, isNotNull);
    expect(saved!.playerOfTheMatchId, 'p1');
    expect(saved.customAwards['Best Fielder'], 'p4');
  });
}

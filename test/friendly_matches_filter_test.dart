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
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:sportyapp/ui/scorer/all_matches/view/all_matches_screen.dart';
import 'package:sportyapp/ui/scorer/dashboard/view/scorer_dashboard_screen.dart';

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

/// A completed match; [tournamentId] `t_custom` marks a friendly/local match,
/// anything else a tournament match.
ScorerMatch completedMatch({
  required String id,
  required String tournamentId,
  required String teamA,
  required String teamB,
}) {
  return ScorerMatch(
    id: id,
    tournamentId: tournamentId,
    team1Id: teamA,
    team2Id: teamB,
    venue: 'Ground',
    dateTime: DateTime(2026, 1, 1),
    format: MatchFormat.t20,
    overs: 20,
    status: MatchStatus.completed,
    playingXI1: const [],
    playingXI2: const [],
    currentInnings: 1,
  );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'friendly matches list shows local matches but hides completed '
      'tournament matches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);
    await repo.saveMatch(completedMatch(
        id: 'f1', tournamentId: 't_custom', teamA: 'Alpha', teamB: 'Beta'));
    await repo.saveMatch(completedMatch(
        id: 't1', tournamentId: 't_real', teamA: 'Champ', teamB: 'Delta'));

    final router = GoRouter(
      initialLocation: '/scorer/all-matches?onlyFriendly=true',
      routes: [
        GoRoute(
          path: '/scorer/all-matches',
          name: 'all-matches',
          builder: (context, state) {
            final onlyFriendly =
                state.uri.queryParameters['onlyFriendly'] == 'true';
            return AllMatchesScreen(onlyFriendly: onlyFriendly);
          },
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

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // The friendly match is listed; the completed tournament match is not.
    expect(find.text('Alpha  vs  Beta'), findsOneWidget);
    expect(find.text('Champ  vs  Delta'), findsNothing);
  });

  testWidgets(
      'friendly matches list hides a match backed by a tournament schedule '
      'fixture even when its tournamentId is t_custom', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);
    await repo.saveMatch(completedMatch(
        id: 'f1', tournamentId: 't_custom', teamA: 'Alpha', teamB: 'Beta'));
    // A completed match that backs a schedule fixture but was mis-flagged as a
    // local match — it must be treated as a tournament match and hidden.
    await repo.saveMatch(completedMatch(
        id: 'leak', tournamentId: 't_custom', teamA: 'Semi', teamB: 'Final'));
    await repo.saveTournament(ScorerTournament(
      id: 't_real',
      name: 'World Cup',
      ownerId: 'owner',
      format: MatchFormat.t20,
      customOvers: 20,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 2, 1),
      venue: '',
      numTeams: 2,
      teamIds: const ['l_a', 'l_b'],
      pointsRules: const PointsRules(),
    ));
    await repo.saveSchedule('t_real', [
      ScheduleStage(
        id: 'knock',
        name: 'Knockout',
        order: 0,
        type: ScheduleStageType.knockout,
        fixtures: [
          ScheduleFixture(
            id: 'k1',
            order: 1,
            teamASource: const ScheduleSource.team('l_a'),
            teamBSource: const ScheduleSource.team('l_b'),
            resolvedTeamAId: 'l_a',
            resolvedTeamBId: 'l_b',
            status: FixtureStatus.completed,
            winnerTeamId: 'l_a',
            linkedMatchId: 'leak',
          ),
        ],
        config: const StageConfiguration(
            winnerAction: StageProgressionAction.advance,
            loserAction: StageProgressionAction.eliminate),
      ),
    ]);

    final router = GoRouter(
      initialLocation: '/scorer/all-matches?onlyFriendly=true',
      routes: [
        GoRoute(
          path: '/scorer/all-matches',
          name: 'all-matches',
          builder: (context, state) {
            final onlyFriendly =
                state.uri.queryParameters['onlyFriendly'] == 'true';
            return AllMatchesScreen(onlyFriendly: onlyFriendly);
          },
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

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Only the true local match shows; the schedule-backed tournament match is
    // hidden despite carrying the t_custom pseudo id.
    expect(find.text('Alpha  vs  Beta'), findsOneWidget);
    expect(find.text('Semi  vs  Final'), findsNothing);
  });

  testWidgets(
      'dashboard Friendly Matches card opens the friendly-only list '
      '(tournament matches excluded)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);
    await repo.saveMatch(completedMatch(
        id: 'f1', tournamentId: 't_custom', teamA: 'Alpha', teamB: 'Beta'));
    await repo.saveMatch(completedMatch(
        id: 't1', tournamentId: 't_real', teamA: 'Champ', teamB: 'Delta'));

    final router = GoRouter(
      initialLocation: '/scorer/dashboard',
      routes: [
        GoRoute(
          path: '/scorer/dashboard',
          name: 'dashboard',
          builder: (context, state) => const ScorerDashboardScreen(),
        ),
        GoRoute(
          path: '/scorer/all-matches',
          name: 'all-matches',
          builder: (context, state) {
            final onlyFriendly =
                state.uri.queryParameters['onlyFriendly'] == 'true';
            return AllMatchesScreen(onlyFriendly: onlyFriendly);
          },
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

    await tester.pumpWidget(testApp(container, router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.text('Friendly Matches'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Landed on the friendly-only list.
    final screen =
        tester.widget<AllMatchesScreen>(find.byType(AllMatchesScreen));
    expect(screen.onlyFriendly, isTrue);
    expect(find.text('Alpha  vs  Beta'), findsOneWidget);
    expect(find.text('Champ  vs  Delta'), findsNothing);
  });
}

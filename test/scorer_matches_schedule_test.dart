// test/scorer_matches_schedule_test.dart
// Guards that the scorer Matches tab surfaces tournament schedule fixtures,
// dedups against fixtures already backed by a real match, and shows a single
// tile when a schedule exists alongside real matches.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/services/auth_service.dart';
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

Future<ScorerRepository> _seed({
  bool linkedMatch = false,
  bool standaloneMatch = false,
}) async {
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
    playerIds: const [],
  ));
  await repo.saveTeam(ScorerTeam(
    id: 'team2',
    name: 'Lions',
    shortCode: 'LI',
    tournamentId: 't1',
    playerIds: const [],
  ));

  if (standaloneMatch) {
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
  }

  await repo.saveSchedule('t1', [
    ScheduleStage(
      id: 's1',
      name: 'Group A',
      order: 0,
      type: ScheduleStageType.roundRobin,
      fixtures: [
        ScheduleFixture(
          id: 'fx1',
          order: 1,
          teamASource: const ScheduleSource.team('team1'),
          teamBSource: const ScheduleSource.team('team2'),
          resolvedTeamAId: 'team1',
          resolvedTeamBId: 'team2',
          scheduledDateTime: DateTime(2026, 1, 15, 14),
          venue: 'Stadium',
          linkedMatchId: linkedMatch ? 'm1' : null,
          status: FixtureStatus.ready,
        ),
      ],
    ),
  ]);
  return repo;
}

Future<void> _pump(WidgetTester tester, ScorerRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(MockAuthService()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', ''), Locale('ur', '')],
        home: const ScorerMatchesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scheduled tournament fixtures appear in the Matches tab',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seed();

    await _pump(tester, repo);

    expect(find.text('Kings XI  vs  Lions'), findsOneWidget);
    // The tile labels the fixture with its stage (tournament • stage).
    expect(find.textContaining('Test Cup'), findsOneWidget);
    expect(find.textContaining('Group A'), findsOneWidget);
    // Fixture tiles are not deletable (they are not real matches yet).
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('a fixture backed by a real match is not duplicated',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seed(linkedMatch: true, standaloneMatch: true);

    await _pump(tester, repo);

    // Only the real match tile (with delete) shows, not a second fixture tile.
    expect(find.text('Kings XI  vs  Lions'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('completed match tiles hide the delete icon but long-press '
      'opens the delete dialog', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seed(linkedMatch: true, standaloneMatch: true);
    // Complete the standalone match so it shows in the Completed section.
    final existing = await repo.getMatch('m1');
    expect(existing, isNotNull);
    await repo.saveMatch(existing!.copyWith(
      status: MatchStatus.completed,
      winnerTeamId: 'team1',
      loserTeamId: 'team2',
    ));

    await _pump(tester, repo);

    // No delete icon on a completed match card.
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // Long-pressing the card surfaces the delete confirmation dialog.
    await tester.longPress(find.text('Kings XI  vs  Lions'));
    await tester.pumpAndSettle();
    expect(find.text('Delete match?'), findsOneWidget);

    // Silent cancel keeps the match.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Kings XI  vs  Lions'), findsOneWidget);
  });

  test('applyScheduleResult records the winner on the completed fixture',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seed();

    await repo.applyScheduleResult(
      tournamentId: 't1',
      winnerTeamId: 'team1',
      loserTeamId: 'team2',
      matchTeam1Id: 'team1',
      matchTeam2Id: 'team2',
      linkedFixtureId: 'fx1',
      matchId: 'm1',
    );

    final stages = await repo.getSchedule('t1');
    final fx1 = stages.first.fixtures.first;
    expect(fx1.status, FixtureStatus.completed);
    expect(fx1.winnerTeamId, 'team1');
  });

  test('applyScheduleTie marks the fixture completed without a winner and '
      'leaves the next match waiting', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await _seed();

    await repo.saveSchedule('t1', [
      ScheduleStage(
        id: 'sf',
        name: 'Semi',
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
            teamASource: ScheduleSource.matchResult('sf1', 'winner'),
            teamBSource: ScheduleSource.matchResult('sf1', 'loser'),
            status: FixtureStatus.pending,
          ),
        ],
      ),
    ]);

    await repo.applyScheduleTie(
      tournamentId: 't1',
      matchTeam1Id: 'team1',
      matchTeam2Id: 'team2',
      linkedFixtureId: 'sf1',
      matchId: 'm1',
    );

    final stages = await repo.getSchedule('t1');
    final sf1 = stages.first.fixtures.first;
    expect(sf1.status, FixtureStatus.completed);
    expect(sf1.winnerTeamId, isNull);

    // A tie has no winner, so nothing advances: the Final has no resolved
    // teams and stays pending (awaiting a decider).
    final fin = stages[1].fixtures.first;
    expect(fin.status, FixtureStatus.pending);
    expect(fin.resolvedTeamAId, isNull);
    expect(fin.resolvedTeamBId, isNull);
  });
}

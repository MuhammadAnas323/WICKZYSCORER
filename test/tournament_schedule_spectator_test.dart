// test/tournament_schedule_spectator_test.dart
// Verifies the read-only spectator Match Schedule surfaces bracket progression:
// winner → next match, loser eliminated, waiting for opponent, and champion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:sportyapp/ui/events/view/tournament_schedule_screen.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';

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

class _FakeSpectatorHomeViewModel extends SpectatorHomeViewModel {
  _FakeSpectatorHomeViewModel(Ref ref, SpectatorHomeState initialState)
      : super(ref) {
    state = initialState;
  }

  @override
  Future<void> load({bool showLoading = true}) async {}
}

ScorerTournament _tournament() => ScorerTournament(
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
    );

List<ScorerTeam> _teams() => [
      ScorerTeam(
          id: 'team1',
          name: 'Kings XI',
          shortCode: 'KX',
          tournamentId: 't1',
          playerIds: const []),
      ScorerTeam(
          id: 'team2',
          name: 'Lions',
          shortCode: 'LI',
          tournamentId: 't1',
          playerIds: const []),
      ScorerTeam(
          id: 'team3',
          name: 'Tigers',
          shortCode: 'TG',
          tournamentId: 't1',
          playerIds: const []),
      ScorerTeam(
          id: 'team4',
          name: 'Bears',
          shortCode: 'BE',
          tournamentId: 't1',
          playerIds: const []),
    ];

List<ScheduleStage> _bracket() => [
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
    ];

Future<void> _pump(WidgetTester tester, SpectatorHomeState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(MockAuthService()),
        scorerDataVersionProvider.overrideWith((ref) => const Stream<int>.empty()),
        spectatorHomeViewModelProvider.overrideWith(
            (ref) => _FakeSpectatorHomeViewModel(ref, state)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', ''), Locale('ur', '')],
        home: const TournamentScheduleScreen(tournamentId: 't1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('spectator schedule shows winner advancing and loser eliminated',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = SpectatorHomeState(
      isLoading: false,
      tournaments: [_tournament()],
      teams: _teams(),
      matches: const [],
      schedules: {'t1': _bracket()},
    );

    await _pump(tester, state);

    // Winner of sf1 advances to the Final.
    expect(find.text('Kings XI → Final'), findsOneWidget);
    // Loser of sf1 is eliminated.
    expect(find.text('Lions · Eliminated'), findsOneWidget);
    // sf2 and the Final are both waiting for an opponent.
    expect(find.text('Waiting for opponent'), findsWidgets);
  });

  testWidgets('spectator schedule shows Champion for the final winner',
      (tester) async {
    final state = SpectatorHomeState(
      isLoading: false,
      tournaments: [_tournament()],
      teams: _teams(),
      matches: const [],
      schedules: {
        't1': [
          ScheduleStage(
            id: 'fin',
            name: 'Final',
            order: 0,
            type: ScheduleStageType.knockout,
            fixtures: [
              ScheduleFixture(
                id: 'fin',
                order: 1,
                teamASource: const ScheduleSource.team('team1'),
                teamBSource: const ScheduleSource.team('team3'),
                resolvedTeamAId: 'team1',
                resolvedTeamBId: 'team3',
                winnerTeamId: 'team1',
                status: FixtureStatus.completed,
              ),
            ],
            config: const StageConfiguration(
              winnerAction: StageProgressionAction.advance,
              loserAction: StageProgressionAction.eliminate,
            ),
          ),
        ],
      },
    );

    await _pump(tester, state);

    expect(find.text('Kings XI · Champion'), findsOneWidget);
    expect(find.text('Tigers · Eliminated'), findsOneWidget);
  });
}

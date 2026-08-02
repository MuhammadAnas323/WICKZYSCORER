// test/team_save_navigation_test.dart
// Reproduces the "team saves but does not navigate back" report.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:sportyapp/ui/scorer/teams/view/team_setup_screen.dart';

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
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saving a team pops back to the previous screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('HOME')),
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/scorer/teams?tournamentId=t1'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/scorer/teams',
          builder: (context, state) => TeamSetupScreen(
            tournamentId: state.uri.queryParameters['tournamentId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scorerRepositoryProvider.overrideWithValue(ScorerRepository(null)),
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData.dark(),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Create Team'), findsOneWidget);

    // Fill in the team name + short code so validation passes.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Team Name'), 'Kings XI');
    await tester.enterText(find.widgetWithText(TextFormField, 'Code'), 'KX');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // After save we should be back on the home screen.
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Create Team'), findsNothing);
  });
}

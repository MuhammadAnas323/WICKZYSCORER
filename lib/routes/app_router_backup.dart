// lib/routes/app_router.dart
// go_router configuration for CRIXORA.
// ShellRoute manages the 5-tab bottom navigation.
// All routes are named and deep-link ready.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/shared_widgets/live_mini_banner.dart';

// Screen imports
import 'package:sportyapp/ui/splash/view/splash_screen.dart';
import 'package:sportyapp/ui/onboarding/view/onboarding_screen.dart';
import 'package:sportyapp/ui/auth/view/sign_up_screen.dart';
import 'package:sportyapp/ui/home/view/home_screen.dart';
import 'package:sportyapp/ui/live_matches/view/live_matches_screen.dart';
import 'package:sportyapp/ui/matches/view/matches_screen.dart';
import 'package:sportyapp/ui/tournaments/view/tournaments_screen.dart';
import 'package:sportyapp/ui/tournaments/view/tournament_detail_screen.dart';
import 'package:sportyapp/ui/profile/view/profile_screen.dart';
import 'package:sportyapp/ui/match_details/view/match_details_screen.dart';
import 'package:sportyapp/ui/teams/view/team_profile_screen.dart';
import 'package:sportyapp/ui/players/view/player_profile_screen.dart';
import 'package:sportyapp/ui/points_table/view/points_table_screen.dart';
import 'package:sportyapp/ui/search/view/search_screen.dart';
import 'package:sportyapp/ui/notifications/view/notifications_screen.dart';
import 'package:sportyapp/ui/streaming/go_live/view/go_live_screen.dart';
import 'package:sportyapp/ui/streaming/live_viewer/view/live_viewer_screen.dart';
import 'package:sportyapp/ui/settings/view/settings_screen.dart';
import 'package:sportyapp/ui/about/view/about_screen.dart';
import 'package:sportyapp/ui/support/view/support_screen.dart';

/// Provider for the active bottom nav tab index.
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// The app's GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      // ── Auth (no shell) ──────────────────────────────────────────────
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      // ── Splash (no shell) ──────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      // ── Onboarding (no shell) ─────────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // ── Full-screen routes (no shell) ─────────────────────────────────
      GoRoute(
        path: '/match/:id',
        name: 'match-details',
        builder: (context, state) =>
            MatchDetailsScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/team/:id',
        name: 'team-profile',
        builder: (context, state) =>
            TeamProfileScreen(teamId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/player/:id',
        name: 'player-profile',
        builder: (context, state) =>
            PlayerProfileScreen(playerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/points-table/:tournamentId',
        name: 'points-table',
        builder: (context, state) =>
            PointsTableScreen(tournamentId: state.pathParameters['tournamentId']!),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/go-live',
        name: 'go-live',
        builder: (context, state) => const GoLiveScreen(),
      ),
      GoRoute(
        path: '/live-viewer/:streamId',
        name: 'live-viewer',
        builder: (context, state) =>
            LiveViewerScreen(streamId: state.pathParameters['streamId']!),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/support',
        name: 'support',
        builder: (context, state) => const SupportScreen(),
      ),
      // ── Shell: 5-tab bottom navigation ────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/live',
            name: 'live',
            builder: (context, state) => const LiveMatchesScreen(),
          ),
          GoRoute(
            path: '/matches',
            name: 'matches',
            builder: (context, state) => const MatchesScreen(),
          ),
          GoRoute(
            path: '/tournaments',
            name: 'tournaments',
            builder: (context, state) => const TournamentsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'tournament-detail',
                builder: (context, state) =>
                    TournamentDetailScreen(tournamentId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

/// The persistent bottom-navigation shell.
class _AppShell extends ConsumerWidget {
  final Widget child;
  const _AppShell({required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.home_rounded, label: 'Home', path: '/home'),
    _TabItem(icon: Icons.wifi_tethering_rounded, label: 'Live', path: '/live'),
    _TabItem(icon: Icons.sports_cricket_rounded, label: 'Matches', path: '/matches'),
    _TabItem(icon: Icons.emoji_events_rounded, label: 'Tournaments', path: '/tournaments'),
    _TabItem(icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
  ];

  int _indexFromPath(String location) {
    if (location.startsWith('/live')) return 1;
    if (location.startsWith('/matches')) return 2;
    if (location.startsWith('/tournaments')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _indexFromPath(location);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          const LiveMiniBanner(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: idx,
          backgroundColor: cs.surface,
          indicatorColor: cs.primary.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            context.go(_tabs[i].path);
          },
          destinations: _tabs.map((t) {
            final isSelected = _tabs.indexOf(t) == idx;
            // Live tab gets a special pulsing red icon
            if (t.label == 'Live') {
              return NavigationDestination(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(t.icon,
                      color: isSelected
                          ? cs.primary
                          : cs.onSurfaceVariant),
                    if (true) // always show red dot for live
                      Positioned(
                        top: -2, right: -4,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.liveRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: t.label,
              );
            }
            return NavigationDestination(
              icon: Icon(t.icon),
              label: t.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String path;
  const _TabItem({required this.icon, required this.label, required this.path});
}

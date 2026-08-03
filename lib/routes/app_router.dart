// lib/routes/app_router.dart
// go_router configuration for CRIXORA.
// Spectator shell: 4-tab bottom navigation (Home, Live, Events, Profile).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Screen imports
import 'package:sportyapp/ui/splash/view/splash_screen.dart';
import 'package:sportyapp/ui/onboarding/view/onboarding_screen.dart';
import 'package:sportyapp/ui/auth/view/sign_up_screen.dart';
import 'package:sportyapp/ui/auth/sign_in/view/sign_in_screen.dart';
import 'package:sportyapp/ui/auth/role_selection/view/role_selection_screen.dart';
import 'package:sportyapp/ui/auth/spectator_signup/view/spectator_signup_screen.dart';
import 'package:sportyapp/ui/auth/scorer_signup/view/scorer_signup_screen.dart';
import 'package:sportyapp/ui/auth/forgot_password/view/forgot_password_screen.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/ui/home/view/home_screen.dart';
import 'package:sportyapp/ui/live_matches/view/live_matches_screen.dart';
import 'package:sportyapp/ui/live_matches/view/live_video_player_screen.dart';
import 'package:sportyapp/ui/live_matches/view/test_video_page.dart';
import 'package:sportyapp/ui/live_matches/view/m3u_channels_screen.dart';
import 'package:sportyapp/ui/events/view/events_screen.dart';
import 'package:sportyapp/ui/events/view/event_detail_screen.dart';
import 'package:sportyapp/ui/spectator/match_detail/view/spectator_match_detail_screen.dart';
import 'package:sportyapp/ui/shell/spectator_shell.dart';
import 'package:sportyapp/ui/matches/view/matches_screen.dart';
import 'package:sportyapp/ui/tournaments/view/tournaments_screen.dart';
import 'package:sportyapp/ui/tournaments/view/tournament_detail_screen.dart';
import 'package:sportyapp/ui/profile/view/profile_screen.dart';
import 'package:sportyapp/ui/profile/view/video_source_settings_screen.dart';
import 'package:sportyapp/ui/profile/view/iptv_management_screen.dart';
import 'package:sportyapp/ui/match_details/view/match_details_screen.dart';
import 'package:sportyapp/ui/teams/view/team_profile_screen.dart';
import 'package:sportyapp/ui/players/view/player_profile_screen.dart';
import 'package:sportyapp/ui/points_table/view/points_table_screen.dart';
import 'package:sportyapp/ui/search/view/search_screen.dart';
import 'package:sportyapp/ui/notifications/view/notifications_screen.dart';
import 'package:sportyapp/ui/streaming/go_live/view/go_live_screen.dart';
import 'package:sportyapp/ui/streaming/live_viewer/view/live_viewer_screen.dart';
import 'package:sportyapp/ui/settings/view/settings_screen.dart';
import 'package:sportyapp/ui/settings/view/cricket_api_settings_screen.dart';
import 'package:sportyapp/ui/settings/admin_settings_screen.dart';
import 'package:sportyapp/ui/about/view/about_screen.dart';
import 'package:sportyapp/ui/support/view/support_screen.dart';
import 'package:sportyapp/features/admin/view/admin_dashboard_screen.dart';
import 'package:sportyapp/features/admin/view/create_match_screen.dart';
// Scorer screens
import 'package:sportyapp/ui/scorer/dashboard/view/scorer_dashboard_screen.dart';
import 'package:sportyapp/ui/scorer/shell/scorer_shell.dart';
import 'package:sportyapp/ui/scorer/tournaments/view/tournament_management_screen.dart';
import 'package:sportyapp/ui/scorer/tournaments/view/tournament_detail_view_screen.dart';
import 'package:sportyapp/ui/scorer/tournaments/view/scorer_tournaments_screen.dart';
import 'package:sportyapp/ui/scorer/teams/view/team_setup_screen.dart';
import 'package:sportyapp/ui/scorer/teams/view/team_players_view_screen.dart';
import 'package:sportyapp/ui/scorer/match_setup/view/match_setup_screen.dart';
import 'package:sportyapp/ui/scorer/live_scoring/view/live_scoring_screen.dart';
import 'package:sportyapp/ui/scorer/start_scoring/view/start_scoring_screen.dart';
import 'package:sportyapp/ui/scorer/start_scoring/view/schedule_match_screen.dart';
import 'package:sportyapp/ui/scorer/start_scoring/view/toss_screen.dart';
import 'package:sportyapp/ui/scorer/create_match/view/create_local_match_screen.dart';
import 'package:sportyapp/ui/scorer/all_matches/view/all_matches_screen.dart';
import 'package:sportyapp/ui/scorer/matches/view/scorer_matches_screen.dart';
import 'package:sportyapp/ui/scorer/squad_setup/view/squad_setup_screen.dart';
import 'package:sportyapp/ui/scorer/schedule/view/schedule_builder_screen.dart';
import 'package:sportyapp/ui/scorer/schedule/view/schedule_view_screen.dart';

/// The app's GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  // The router instance is created ONCE. A plain Provider that returns a new
  // GoRouter every time auth changes would reset to [initialLocation]
  // (`/splash`) on every login/sign-out/role-switch. Instead we ping a
  // `refreshListenable` so go_router re-runs the redirect while keeping the
  // same instance and current location.
  final authHeartbeat = ValueNotifier(0);
  ref.onDispose(authHeartbeat.dispose);
  ref.listen<AppUser?>(currentUserProvider, (_, __) => authHeartbeat.value++);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: authHeartbeat,
    redirect: (context, state) {
      final currentUser = ref.read(currentUserProvider);
      final location = state.uri.toString();

      final publicRoutes = [
        '/splash', '/onboarding', '/signup',
        '/signin', '/role-selection',
        '/spectator-signup', '/scorer-signup',
        '/forgot-password',
      ];
      final isPublic = publicRoutes.any(location.startsWith);

      if (currentUser == null) {
        if (!isPublic) return '/signin';
        return null;
      }

      if (isPublic) {
        return currentUser.isScorer ? '/scorer/dashboard' : '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/signin',
        name: 'signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        name: 'role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/spectator-signup',
        name: 'spectator-signup',
        builder: (context, state) => const SpectatorSignupScreen(),
      ),
      GoRoute(
        path: '/scorer-signup',
        name: 'scorer-signup',
        builder: (context, state) => const ScorerSignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // â”€â”€ Full-screen routes (no shell) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        builder: (context, state) => PointsTableScreen(
            tournamentId: state.pathParameters['tournamentId']!),
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
        path: '/admin-video',
        name: 'admin-video',
        builder: (context, state) {
          // Prefer extra map (raw, unencoded) over query params
          String? url;
          String? title;

          if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            url = map['url'] as String?;
            title = map['title'] as String?;
          } else if (state.extra is String) {
            url = state.extra as String;
          }

          // Fallback to query parameters (handles deep-link / web refresh)
          url ??= state.uri.queryParameters['url'];
          title ??= state.uri.queryParameters['title'];

          return LiveVideoPlayerScreen(
            url: url,
            title: title,
          );
        },
      ),
      GoRoute(
        path: '/test-video',
        name: 'test-video',
        builder: (context, state) => const TestVideoPage(),
      ),
      GoRoute(
        path: '/m3u-channels',
        name: 'm3u-channels',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          return M3uChannelsScreen(playlistUrl: url);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/cricket-api-settings',
        name: 'cricket-api-settings',
        builder: (context, state) => const CricketApiSettingsScreen(),
      ),
      GoRoute(
        path: '/admin-settings',
        name: 'admin-settings',
        builder: (context, state) => const AdminSettingsScreen(),
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
      GoRoute(
        path: '/video-source-settings',
        name: 'video-source-settings',
        builder: (context, state) => const VideoSourceSettingsScreen(),
      ),
      GoRoute(
        path: '/iptv-management',
        name: 'iptv-management',
        builder: (context, state) => const IptvManagementScreen(),
      ),
      // â”€â”€ Admin routes (no shell) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: '/admin',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/create-match',
        name: 'create-match',
        builder: (context, state) => const CreateMatchScreen(),
      ),
      // â”€â”€ Standalone routes for push navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: '/events/:id',
        name: 'event-detail',
        builder: (context, state) => EventDetailScreen(
            tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/spectator/match/:id',
        name: 'spectator-match-detail',
        builder: (context, state) => SpectatorMatchDetailScreen(
            matchId: state.pathParameters['id']!),
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
            builder: (context, state) => TournamentDetailScreen(
                tournamentId: state.pathParameters['id']!),
          ),
        ],
      ),
      // â”€â”€ Scorer full-screen routes (no shell) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: '/scorer/match-setup',
        name: 'scorer-match-setup',
        builder: (context, state) => const MatchSetupScreen(),
      ),
      GoRoute(
        path: '/scorer/live-scoring',
        name: 'scorer-live-scoring',
        builder: (context, state) => const LiveScoringScreen(),
      ),
      GoRoute(
        path: '/scorer/tournaments/create',
        name: 'scorer-tournament-create',
        builder: (context, state) => const TournamentManagementScreen(),
      ),
      GoRoute(
        path: '/scorer/tournaments/:id',
        name: 'scorer-tournament-detail',
        builder: (context, state) => TournamentDetailViewScreen(
          tournamentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/scorer/tournaments/:id/edit',
        name: 'scorer-tournament-edit',
        builder: (context, state) =>
            TournamentManagementScreen(tournamentId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/scorer/tournaments/:id/schedule',
        name: 'scorer-tournament-schedule',
        builder: (context, state) => ScheduleViewScreen(
          tournamentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/scorer/tournaments/:id/schedule-builder',
        name: 'scorer-tournament-schedule-builder',
        builder: (context, state) => ScheduleBuilderScreen(
          tournamentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/scorer/teams',
        name: 'scorer-teams',
        builder: (context, state) => TeamSetupScreen(
          tournamentId: state.uri.queryParameters['tournamentId'],
        ),
      ),
      GoRoute(
        path: '/scorer/teams/:id/edit',
        name: 'scorer-team-edit',
        builder: (context, state) => TeamSetupScreen(
          teamId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/scorer/teams/:id/players',
        name: 'scorer-team-players',
        builder: (context, state) => TeamPlayersViewScreen(
          teamId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/scorer/matches/create',
        name: 'scorer-match-create',
        builder: (context, state) => const CreateLocalMatchScreen(),
      ),
      GoRoute(
        path: '/scorer/matches/:id/squad',
        name: 'scorer-match-squad',
        builder: (context, state) =>
            SquadSetupScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/scorer/start-scoring',
        name: 'scorer-start-scoring',
        builder: (context, state) => const StartScoringScreen(),
      ),
      GoRoute(
        path: '/scorer/schedule-match',
        name: 'scorer-schedule-match',
        builder: (context, state) =>
            ScheduleMatchScreen(tournamentId: state.uri.queryParameters['tournamentId']),
      ),
      GoRoute(
        path: '/scorer/toss',
        name: 'scorer-toss',
        builder: (context, state) =>
            TossScreen(matchId: state.uri.queryParameters['matchId'] ?? ''),
      ),
      // â”€â”€ Shell: Spectator bottom navigation (Home Â· Live Â· Events Â· Profile) â”€â”€
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            SpectatorShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                name: 'live',
                builder: (context, state) => const LiveMatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                name: 'events',
                builder: (context, state) => const EventsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // â”€â”€ Shell: Scorer bottom navigation (Home Â· Tournaments Â· Profile) â”€â”€
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScorerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scorer/dashboard',
                name: 'scorer-dashboard',
                builder: (context, state) => const ScorerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scorer/tournaments',
                name: 'scorer-tournaments',
                builder: (context, state) => const ScorerTournamentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scorer/all-matches',
                name: 'scorer-all-matches',
                builder: (context, state) => const AllMatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scorer/matches',
                name: 'scorer-matches',
                builder: (context, state) => const ScorerMatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scorer/profile',
                name: 'scorer-profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});


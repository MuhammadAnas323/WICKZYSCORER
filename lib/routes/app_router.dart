// lib/routes/app_router.dart
// go_router configuration for SPORTYAPP.
// ShellRoute manages the 3-tab bottom navigation (Home, Start Live, Profile).
// NO FloatingActionButton — center item is a standard nav destination inside the bar.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/live_mini_banner.dart';

// Screen imports
import 'package:sportyapp/ui/splash/view/splash_screen.dart';
import 'package:sportyapp/ui/onboarding/view/onboarding_screen.dart';
import 'package:sportyapp/ui/auth/view/sign_up_screen.dart';
import 'package:sportyapp/ui/home/view/home_screen.dart';
import 'package:sportyapp/ui/live_matches/view/live_matches_screen.dart';
import 'package:sportyapp/ui/live_matches/view/live_video_player_screen.dart';
import 'package:sportyapp/ui/live_matches/view/test_video_page.dart';
import 'package:sportyapp/ui/live_matches/view/m3u_channels_screen.dart';
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

/// Provider for the active bottom nav tab index.
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// The app's GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
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
      // ── Admin routes (no shell) ────────────────────────────────────────────
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
      // ── Standalone routes for push navigation ───────────────────────────────
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
      // ── Shell: 3-tab bottom navigation ────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
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

// ---------------------------------------------------------------------------
// Premium App Shell — 3-tab bottom navigation with NO FloatingActionButton
// ---------------------------------------------------------------------------

class _AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  // Map a GoRouter path prefix to a display index:
  //   0 = Home, 1 = Start Live (no route — opens sheet), 2 = Profile
  int _indexFromPath(String location) {
    if (location.startsWith('/profile')) return 2;
    return 0; // default to home; index 1 never navigates
  }

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.90,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _onCenterTap(BuildContext context) async {
    // Brief bounce animation
    await _scaleController.reverse();
    await _scaleController.forward();
    if (!context.mounted) return;
    _showStartLiveSheet(context);
  }

  // ── Start Live bottom sheet ────────────────────────────────────────────
  void _showStartLiveSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StartLiveSheet(
        onStartLive: () => _requestPermissionsAndGoLive(context),
      ),
    );
  }

  Future<void> _requestPermissionsAndGoLive(BuildContext context) async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();

    if (!context.mounted) return;

    if (!cam.isGranted || !mic.isGranted) {
      _showPermissionDeniedDialog(context);
      return;
    }

    context.push('/go-live');
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Permissions Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Camera and microphone access are required to go live. '
          'Please grant these permissions in your device settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreenLight,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Settings',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromPath(location);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: widget.child),
          const LiveMiniBanner(),
        ],
      ),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: currentIndex,
        isDark: isDark,
        colorScheme: cs,
        scaleController: _scaleController,
        onHomeTap: () => context.go('/home'),
        onCenterTap: () => _onCenterTap(context),
        onProfileTap: () => context.go('/profile'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium Bottom Navigation Bar — 3 equal items, NO FAB, NO notch
// ---------------------------------------------------------------------------

class _PremiumBottomNav extends StatefulWidget {
  final int currentIndex;
  final bool isDark;
  final ColorScheme colorScheme;
  final AnimationController scaleController;
  final VoidCallback onHomeTap;
  final VoidCallback onCenterTap;
  final VoidCallback onProfileTap;

  const _PremiumBottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.colorScheme,
    required this.scaleController,
    required this.onHomeTap,
    required this.onCenterTap,
    required this.onProfileTap,
  });

  @override
  State<_PremiumBottomNav> createState() => _PremiumBottomNavState();
}

class _PremiumBottomNavState extends State<_PremiumBottomNav>
    with TickerProviderStateMixin {
  late List<AnimationController> _itemControllers;
  late List<Animation<double>> _itemScales;

  @override
  void initState() {
    super.initState();
    _itemControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        value: i == widget.currentIndex ? 1.0 : 0.0,
      ),
    );
    _itemScales = _itemControllers
        .map((c) => Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOutBack),
            ))
        .toList();

    // Start the initially selected item at full scale
    if (widget.currentIndex < _itemControllers.length) {
      _itemControllers[widget.currentIndex].value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_PremiumBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Only animate left/right tabs (index 0 and 2); center (index 1) never navigates
      if (oldWidget.currentIndex != 1) {
        _itemControllers[oldWidget.currentIndex].reverse();
      }
      if (widget.currentIndex != 1) {
        _itemControllers[widget.currentIndex].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final selectedColor = AppColors.pitchGreenLight;
    final unselectedColor = isDark ? Colors.white38 : Colors.black38;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              // ── Home (index 0) ──────────────────────────────────────────
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: widget.currentIndex == 0,
                  scaleAnimation: _itemScales[0],
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  onTap: () {
                    _itemControllers[0].forward();
                    if (widget.currentIndex == 2) _itemControllers[2].reverse();
                    widget.onHomeTap();
                  },
                ),
              ),

              // ── Start Live (index 1 — center) ─────────────────────────
              Expanded(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(
                      parent: widget.scaleController,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: _CenterNavItem(onTap: widget.onCenterTap),
                ),
              ),

              // ── Profile (index 2) ────────────────────────────────────────
              Expanded(
                child: _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: widget.currentIndex == 2,
                  scaleAnimation: _itemScales[2],
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  onTap: () {
                    _itemControllers[2].forward();
                    if (widget.currentIndex == 0) _itemControllers[0].reverse();
                    widget.onProfileTap();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard left/right nav item with scale + color animation.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Animation<double> scaleAnimation;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.scaleAnimation,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;
    return InkWell(
      onTap: onTap,
      splashColor: selectedColor.withOpacity(0.1),
      highlightColor: selectedColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Center "Start Live" nav item — circular green icon inside the bar.
/// This is NOT a FloatingActionButton. It's a regular Row child inside the nav.
class _CenterNavItem extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.pitchGreenLight.withOpacity(0.15),
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular green container with + icon — stays INSIDE the bar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2ECC71),
                  Color(0xFF1A7A3E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pitchGreenLight.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Start Live',
            style: TextStyle(
              color: AppColors.pitchGreenLight,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Start Live Bottom Sheet — Material 3 design
// ---------------------------------------------------------------------------

class _StartLiveSheet extends StatelessWidget {
  final VoidCallback onStartLive;
  const _StartLiveSheet({required this.onStartLive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon + title
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2ECC71), Color(0xFF1A7A3E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pitchGreenLight.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Go Live',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Broadcast live to all your viewers in real time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),

              // Start Live Streaming option
              _SheetOption(
                icon: Icons.videocam_rounded,
                iconColor: const Color(0xFF2ECC71),
                iconBg: const Color(0xFF2ECC71),
                title: 'Start Live Streaming',
                subtitle: 'Broadcast your camera live to viewers',
                onTap: () {
                  Navigator.pop(context);
                  onStartLive();
                },
              ),

              const SizedBox(height: 12),

              // Cancel
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconBg.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [iconBg, iconBg.withOpacity(0.7)],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark ? Colors.white24 : Colors.black26,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/profile/viewmodel/profile_viewmodel.dart';
import 'package:sportyapp/ui/profile/widgets/iptv_playlist_card.dart';
import 'package:sportyapp/ui/auth/viewmodel/auth_viewmodel.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _avatarTapCount = 0;
  bool _developerModeUnlocked = false;

  void _handleAvatarTap() {
    setState(() {
      _avatarTapCount++;
      if (_avatarTapCount == 7) {
        _developerModeUnlocked = !_developerModeUnlocked;
        _avatarTapCount = 0;
        final msg = _developerModeUnlocked
            ? '🚀 Developer / Admin mode unlocked!'
            : '🔒 Developer / Admin mode hidden.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.pitchGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileViewModelProvider);
    final fbUser = ref.watch(userDetailProvider);
    final appUser = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = fbUser?.displayName ?? (state.displayName.isNotEmpty ? state.displayName : (appUser?.name ?? 'User'));
    final email = fbUser?.email ?? (appUser?.email.isNotEmpty == true ? appUser!.email : 'user@crixora.com');
    final isScorer = appUser?.role == AppUserRole.scorer;
    final switchTarget = isScorer ? 'Spectator' : 'Scorer';
    final switchSubtitle = isScorer
        ? 'Switch to watching matches'
        : 'Switch to scoring matches';

    return Scaffold(
      backgroundColor: cs.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: isDark ? const Color(0xFF141414) : AppColors.pitchGreenDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A7A3E), Color(0xFF0D2818)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: isScorer ? _handleAvatarTap : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '👤',
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isScorer && _developerModeUnlocked)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.code, size: 14, color: Colors.black),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: AppTextStyles.headlineSmall(Colors.white),
                      ),
                      Text(
                        email,
                        style: AppTextStyles.bodySmall(Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Mode Switch Tile ─────────────────────────────────────
                  Text('Mode', style: AppTextStyles.titleLarge(cs.onBackground)),
                  const SizedBox(height: 8),
                  _actionTile(
                    context,
                    Icons.swap_horiz_rounded,
                    'Switch to $switchTarget',
                    switchSubtitle,
                    AppColors.pitchGreen,
                    () async {
                      final notifier = ref.read(currentUserProvider.notifier);
                      final targetRole = isScorer ? AppUserRole.spectator : AppUserRole.scorer;
                      final hasTargetAccount = isScorer
                          ? await notifier.hasSpectatorAccount()
                          : await notifier.hasScorerAccount();

                      if (hasTargetAccount) {
                        await notifier.switchRole(targetRole);
                        if (context.mounted) {
                          context.go(targetRole == AppUserRole.scorer
                              ? '/scorer/dashboard'
                              : '/home');
                        }
                      } else {
                        await notifier.signOut();
                        if (context.mounted) {
                          context.go('/signin');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Hidden Developer / Admin Section (Scorer only with 7-tap unlock) ──
                  if (isScorer && _developerModeUnlocked) ...[
                    Row(
                      children: [
                        const Icon(Icons.developer_mode, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text('Developer Options', style: AppTextStyles.titleLarge(cs.onBackground)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const IptvPlaylistCard(),
                    const SizedBox(height: 8),
                    _navTile(context, Icons.tune_rounded, 'Admin Settings', '/admin-settings'),
                    _navTile(context, Icons.api_rounded, 'Cricket API Settings', '/cricket-api-settings'),
                    const SizedBox(height: 24),
                  ],

                  // ── Main Settings & Info Section ─────────────────────────
                  Text('Settings & Info', style: AppTextStyles.titleLarge(cs.onBackground)),
                  const SizedBox(height: 12),
                  _navTile(context, Icons.settings_rounded, 'Settings', '/settings'),
                  _navTile(context, Icons.info_rounded, 'About CRIXORA', '/about'),
                  _navTile(context, Icons.support_agent_rounded, 'Contact Support', '/support'),
                  const SizedBox(height: 16),

                  // ── Sign Out Button ─────────────────────────────────────
                  InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF222222) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          title: Text('Sign Out', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                          content: Text('Are you sure you want to sign out?', style: TextStyle(color: cs.onSurfaceVariant)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(currentUserProvider.notifier).signOut();
                        if (context.mounted) context.go('/signin');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(5), // 5px border radius as required
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                Text('Log out and return to sign in', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(5), // 5px border radius as required
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium(cs.onBackground)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(subtitle, style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String title, String route) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(5), // 5px border radius as required
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        leading: Icon(icon, color: AppColors.pitchGreen),
        title: Text(title, style: AppTextStyles.bodyMedium(cs.onBackground).copyWith(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push(route),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/ui/profile/viewmodel/profile_viewmodel.dart';
import 'package:sportyapp/ui/auth/viewmodel/auth_viewmodel.dart';
import 'package:sportyapp/ui/profile/widgets/iptv_playlist_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);
    final user = ref.watch(userDetailProvider);
    final cs = Theme.of(context).colorScheme;

    final displayName = user?.displayName ?? state.displayName;
    final email = user?.email ?? 'Guest Profile';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A7A3E), Color(0xFF0D2818)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white24,
                        child: Text(
                          user != null
                              ? displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?'
                              : '\u{1F464}',
                          style: TextStyle(
                            fontSize: user != null ? 32 : 40,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(displayName,
                        style: AppTextStyles.headlineSmall(Colors.white)),
                      Text(email,
                        style: AppTextStyles.bodySmall(Colors.white70)),
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
                  Row(
                    children: [
                      _statTile(cs, '\u{1F4CA}', 'Saved\nMatches', state.savedMatches.toString()),
                      _statTile(cs, '\u{1F4E1}', 'Live\nStreams', '2'),
                      _statTile(cs, '\u{1F3C6}', 'Fav\nTeam', 'PAK'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text('Quick Actions', style: AppTextStyles.titleLarge(cs.onBackground)),
                  const SizedBox(height: 12),
                  _actionTile(context, Icons.search_rounded,
                    'Search', 'Find matches, players & teams', cs.primary,
                    () => context.push('/search')),
                  const SizedBox(height: 24),

                  const IptvPlaylistCard(),
                  const SizedBox(height: 12),

                  Text('Settings & Info', style: AppTextStyles.titleLarge(cs.onBackground)),
                  const SizedBox(height: 12),
                  _navTile(context, Icons.settings_rounded, 'Settings', '/settings'),
                  _navTile(context, Icons.tune_rounded, 'Admin Settings', '/admin-settings'),
                  _navTile(context, Icons.info_rounded, 'About SPORTYAPP', '/about'),
                  _navTile(context, Icons.support_agent_rounded, 'Contact / Support', '/support'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(ColorScheme cs, String emoji, String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.titleLarge(cs.onBackground)),
            Text(label, style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context, IconData icon, String title,
      String subtitle, Color color, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: cs.outline.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium(cs.onBackground)
                  .copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
              ],
            )),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String title, String route) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(title, style: AppTextStyles.bodyMedium(cs.onBackground)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
      contentPadding: EdgeInsets.zero,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/profile/viewmodel/profile_viewmodel.dart';
import 'package:sportyapp/ui/auth/viewmodel/auth_viewmodel.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileViewModelProvider);
    final fbUser = ref.watch(userDetailProvider);
    final appUser = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = fbUser?.displayName ??
        (state.displayName.isNotEmpty
            ? state.displayName
            : (appUser?.name ?? 'User'));
    final email = fbUser?.email ??
        (appUser?.email.isNotEmpty == true
            ? appUser!.email
            : 'user@wickzyscorer.com');
    final isScorer = appUser?.role == AppUserRole.scorer;
    final l10n = AppLocalizations.of(context);
    final switchTarget =
        isScorer ? l10n.translate('spectator') : l10n.translate('scorer');
    final switchSubtitle = isScorer
        ? l10n.translate('switch_to_spectator_subtitle')
        : l10n.translate('switch_to_scorer_subtitle');

    return Scaffold(
      backgroundColor: cs.background,
      body: CustomScrollView(
        slivers: [
          // ── Header Card ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: isDark ? const Color(0xFF0D1B2A) : AppColors.pitchGreen,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.heroCardGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isScorer ? Icons.sports_score : Icons.sports_cricket,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isScorer ? 'Scorer Account' : 'Spectator Account',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: AppTextStyles.headlineMedium(Colors.white).copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                email,
                                style: AppTextStyles.bodyMedium(Colors.white.withValues(alpha: 0.85)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                  Text(l10n.translate('mode'),
                      style: AppTextStyles.titleLarge(cs.onBackground)),
                  const SizedBox(height: 8),
                  _actionTile(
                    context,
                    Icons.swap_horiz_rounded,
                    '${l10n.translate('switch_to')} $switchTarget',
                    switchSubtitle,
                    AppColors.pitchGreen,
                    () async {
                      final notifier = ref.read(currentUserProvider.notifier);
                      final targetRole =
                          isScorer ? AppUserRole.spectator : AppUserRole.scorer;
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
                          context.go('/role-selection');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Main Settings & Info Section ─────────────────────────
                  Text(l10n.translate('settings_and_info'),
                      style: AppTextStyles.titleLarge(cs.onBackground)),
                  const SizedBox(height: 12),
                  _navTile(context, Icons.settings_rounded,
                      l10n.translate('settings'), '/settings'),
                  _navTile(context, Icons.info_rounded,
                      l10n.translate('about_app'), '/about'),
                  _navTile(context, Icons.support_agent_rounded,
                      l10n.translate('contact_support'), '/support'),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(
            color: AppColors.pitchGreen.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
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
                      Text(subtitle,
                          style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTile(
      BuildContext context, IconData icon, String title, String route) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(
            color: AppColors.pitchGreen.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        leading: Icon(icon, color: AppColors.pitchGreen),
        title: Text(title,
            style: AppTextStyles.bodyMedium(cs.onBackground)
                .copyWith(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push(route),
      ),
    );
  }
}

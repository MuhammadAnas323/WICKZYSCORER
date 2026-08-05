import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

const double _cardRadius = 5;

class ScorerDashboardScreen extends ConsumerWidget {
  const ScorerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Scorer';

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.floodlightGold, Colors.orangeAccent],
                ),
              ),
              child: const Icon(Icons.sports_score, color: Colors.black, size: 22),
            ),
            const Gap(10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('scorer_dashboard'),
                  style: AppTextStyles.titleMedium(cs.onBackground)
                      .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${l10n.translate('welcome')}, $displayName',
                  style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.95,
                  children: [
                    // 1. Tournaments Card
                    _LargeNavCard(
                      title: l10n.translate('tournaments'),
                      subtitle: l10n.translate('manage_score_tournaments'),
                      icon: Icons.emoji_events_rounded,
                      gradientColors: isDark
                          ? const [Color(0xFF1E3A8A), Color(0xFF1E1B4B)]
                          : const [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                      iconColor: isDark ? Colors.amber : const Color(0xFF1D4ED8),
                      textColor: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      onTap: () => context.push('/scorer/tournaments'),
                    ),

                    // 2. Friendly Matches Card
                    _LargeNavCard(
                      title: l10n.translate('friendly_matches'),
                      subtitle: l10n.translate('individual_matches'),
                      icon: Icons.sports_cricket_rounded,
                      gradientColors: isDark
                          ? const [Color(0xFF065F46), Color(0xFF064E3B)]
                          : const [Color(0xFFD1FAE5), Color(0xA110B981)],
                      iconColor: isDark ? AppColors.pitchGreenLight : const Color(0xFF047857),
                      textColor: isDark ? Colors.white : const Color(0xFF065F46),
                      onTap: () => context.push('/scorer/all-matches'),
                    ),

                    // 3. Profile Card
                    _LargeNavCard(
                      title: l10n.translate('profile'),
                      subtitle: l10n.translate('account_settings'),
                      icon: Icons.person_rounded,
                      gradientColors: isDark
                          ? const [Color(0xFF5B21B6), Color(0xFF4C1D95)]
                          : const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
                      iconColor: isDark ? Colors.purpleAccent : const Color(0xFF6D28D9),
                      textColor: isDark ? Colors.white : const Color(0xFF5B21B6),
                      onTap: () => context.push('/scorer/profile'),
                    ),

                    // 4. Start Scoring Card
                    _LargeNavCard(
                      title: l10n.translate('start_scoring'),
                      subtitle: l10n.translate('quick_session'),
                      icon: Icons.play_circle_fill_rounded,
                      gradientColors: isDark
                          ? const [Color(0xFF991B1B), Color(0xFF7F1D1D)]
                          : const [Color(0xFFFEE2E2), Color(0xFFFCA5A5)],
                      iconColor: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                      textColor: isDark ? Colors.white : const Color(0xFF991B1B),
                      onTap: () => context.push('/scorer/start-scoring'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LargeNavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _LargeNavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius), // Exactly 5px border radius as required
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor.withOpacity(0.75),
                    fontSize: 11,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


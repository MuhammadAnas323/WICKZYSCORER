import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class FriendlyMatchesHubScreen extends StatelessWidget {
  const FriendlyMatchesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.pitchGreen, Color(0xFF1A7A3E)],
                ),
              ),
              child: const Icon(Icons.sports_cricket_rounded,
                  color: Colors.white, size: 20),
            ),
            const Gap(10),
            Text(
              l10n.translate('friendly_matches'),
              style: AppTextStyles.titleMedium(colorScheme.onBackground)
                  .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate('scoring_choice'),
              style: TextStyle(color: colorScheme.onBackground, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(6),
            Text(
              l10n.translate('match_card_subtitle'),
              style: TextStyle(color: colorScheme.onBackground.withOpacity(0.54), fontSize: 13),
            ),
            const Gap(24),

            // ── Create Friendly Match card ─────────────────────────────
            _HubCard(
              icon: Icons.add_circle_outline_rounded,
              iconBg: AppColors.pitchGreen,
              title: l10n.translate('create_local_match'),
              subtitle: 'Create a new friendly match and set up the squads',
              onTap: () => context.push('/scorer/matches/create'),
              context: context,
            ),
            const Gap(16),

            // ── Select Friendly Match card ─────────────────────────────
            _HubCard(
              icon: Icons.list_alt_rounded,
              iconBg: AppColors.floodlightGold,
              title: 'Select Friendly Match',
              subtitle: 'View and manage your created friendly matches',
              onTap: () => context.push('/scorer/all-matches?onlyFriendly=true'),
              context: context,
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final BuildContext context;

  const _HubCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(this.context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: iconBg.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [iconBg, iconBg.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(color: iconBg.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const Gap(2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.54),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface.withOpacity(0.38), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

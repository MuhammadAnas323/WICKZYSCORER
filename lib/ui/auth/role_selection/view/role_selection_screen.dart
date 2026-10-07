import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'dart:ui';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D1B2A), theme.scaffoldBackgroundColor]
                : [const Color(0xFFE3F2FD), theme.scaffoldBackgroundColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'WICKZY SCORER',
                    style: AppTextStyles.displayLarge(cs.onBackground),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    l10n.translate('choose_your_role'),
                    style: AppTextStyles.titleLarge(cs.onSurfaceVariant),
                  ),
                ),
                const Spacer(),
                _RoleCard(
                  title: l10n.translate('watch_as_spectator'),
                  subtitle: l10n.translate('watch_as_spectator_sub'),
                  icon: Icons.sports_cricket,
                  gradient: AppColors.heroCardGradient,
                  onTap: () => context.push('/spectator-signup'),
                ),
                const SizedBox(height: 24),
                _RoleCard(
                  title: l10n.translate('score_a_match'),
                  subtitle: l10n.translate('score_a_match_sub'),
                  icon: Icons.sports_score,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0288D1), Color(0xFF00ACC1)],
                  ),
                  onTap: () => context.push('/scorer-signup'),
                ),
                const Spacer(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.glassFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.titleLarge(cs.onSurface)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

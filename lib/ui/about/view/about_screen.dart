import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/extensions/string_extensions.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('about').toTitleCase, style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Logo section
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      AppColors.pitchGreen,
                      AppColors.pitchGreenDark
                    ]),
                  ),
                  child: const Icon(Icons.sports_cricket,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 16),
                Text('WICKZY SCORER',
                    style: AppTextStyles.headlineLarge(cs.onSurface)
                        .copyWith(letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('${l10n.translate('version').toTitleCase} 1.0.0',
                    style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(l10n.translate('premium_cricket_companion').toTitleCase,
              style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 12),
          Text(
            l10n.translate('about_description'),
            style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)
                .copyWith(height: 1.7),
          ),
          const SizedBox(height: 32),
          Text(l10n.translate('features').toTitleCase, style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 12),
          ...[
            ('🔴', l10n.translate('feat_live_scores').toTitleCase),
            ('📅', l10n.translate('feat_fixtures').toTitleCase),
            ('🏆', l10n.translate('feat_tournaments').toTitleCase),
            ('📊', l10n.translate('feat_stats').toTitleCase),
            ('📡', l10n.translate('feat_go_live')),
          ].map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(item.$2,
                        style: AppTextStyles.bodyMedium(cs.onSurface)),
                  ],
                ),
              )),
          const SizedBox(height: 32),
          Text(l10n.translate('legal').toTitleCase, style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 8),
          Text(
            l10n.translate('legal_description'),
            style: AppTextStyles.bodySmall(cs.onSurfaceVariant)
                .copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

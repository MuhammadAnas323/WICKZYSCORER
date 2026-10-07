import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/extensions/string_extensions.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final faqs = [
      (l10n.translate('faq_1_q'), l10n.translate('faq_1_a')),
      (l10n.translate('faq_2_q'), l10n.translate('faq_2_a')),
      (l10n.translate('faq_3_q'), l10n.translate('faq_3_a')),
      (l10n.translate('faq_4_q'), l10n.translate('faq_4_a')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('contact_support').toTitleCase,
            style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.translate('get_in_touch').toTitleCase,
              style: AppTextStyles.headlineMedium(cs.onSurface)),
          const SizedBox(height: 8),
          Text(
              l10n.translate('support_subtitle'),
              style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          // FAQs
          Text(l10n.translate('common_questions').toTitleCase,
              style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 12),
          ...faqs.map((faq) => ExpansionTile(
                title: Text(faq.$1,
                    style: AppTextStyles.bodyMedium(cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(faq.$2,
                        style: AppTextStyles.bodyMedium(
                            cs.onSurfaceVariant)),
                  )
                ],
              )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

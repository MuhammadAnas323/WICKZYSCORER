import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact / Support',
            style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Get in Touch',
              style: AppTextStyles.headlineMedium(cs.onSurface)),
          const SizedBox(height: 8),
          Text(
              'Have a question or feedback regarding text scoring and tournaments? We\'d love to hear from you.',
              style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          // FAQs
          Text('Common Questions',
              style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => ExpansionTile(
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

const _faqs = [
  (
    'How do I score a match?',
    'Tap the Scorer option from the role selection or dashboard, create or select a tournament or friendly match, set up your teams and squads, and start scoring ball-by-ball.'
  ),
  (
    'Is my data saved?',
    'Wickzy Scorer saves your tournaments, teams, players, and match records securely in cloud storage so you can access them anytime.'
  ),
  (
    'How often do scores update?',
    'Scores and ball-by-ball updates are recorded in real-time as you score.'
  ),
  (
    'Can spectators view live scores?',
    'Yes! Spectators can follow live scores, fixtures, and points tables in real-time.'
  ),
];

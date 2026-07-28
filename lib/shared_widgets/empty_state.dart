import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

/// Empty state widget with emoji illustration, title, subtitle, and optional CTA.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(title,
              style: AppTextStyles.headlineSmall(cs.onSurface),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
              style: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
              textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...
              [const SizedBox(height: 24),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!))],
          ],
        ),
      ),
    );
  }
}

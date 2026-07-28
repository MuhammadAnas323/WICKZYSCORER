import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

/// Section title row with optional "See All" trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
              style: AppTextStyles.titleLarge(cs.onSurface)),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text('See All',
                style: AppTextStyles.labelMedium(cs.primary)
                    .copyWith(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

/// A small colored pill showing a stat label + value.
class StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final Color? textColor;

  const StatPill({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.pitchGreen.withValues(alpha: 0.12);
    final fg = textColor ?? AppColors.pitchGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.labelSmall(fg)),
          const SizedBox(width: 4),
          Text(value,
            style: AppTextStyles.labelSmall(fg).copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

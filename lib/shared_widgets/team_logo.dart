import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

/// Team logo with fallback to flag emoji.
class TeamLogo extends StatelessWidget {
  final String logoUrl;
  final String flagEmoji;
  final String shortName;
  final double size;

  const TeamLogo({
    super.key,
    required this.logoUrl,
    required this.flagEmoji,
    required this.shortName,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.pitchGreen.withValues(alpha: 0.1),
      ),
      child: ClipOval(
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(flagEmoji, style: TextStyle(fontSize: size * 0.5)),
          ),
          loadingBuilder: (_, child, progress) =>
            progress == null ? child : Center(
              child: Text(flagEmoji, style: TextStyle(fontSize: size * 0.5))),
        ),
      ),
    );
  }
}

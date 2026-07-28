import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

/// Displays the last 6 balls of an innings as colored circles.
class BallStrip extends StatelessWidget {
  final List<String> balls; // e.g. ['4','1','W','0','6','1']

  const BallStrip({super.key, required this.balls});

  Color _bgColor(String b) {
    switch (b.toUpperCase()) {
      case 'W': return AppColors.ballRed;
      case '4': return AppColors.pitchGreen;
      case '6': return AppColors.floodlightGold;
      case 'WD': return AppColors.charcoal400;
      case 'NB': return AppColors.info;
      default: return AppColors.charcoal600;
    }
  }

  Color _textColor(String b) {
    if (b == '6') return Colors.black;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: balls.map((b) {
        return Container(
          width: 28, height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _bgColor(b),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: Center(
            child: Text(b,
              style: AppTextStyles.labelSmall(_textColor(b))
                  .copyWith(fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        );
      }).toList(),
    );
  }
}

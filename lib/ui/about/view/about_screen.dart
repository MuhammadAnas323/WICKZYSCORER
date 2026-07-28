import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('About', style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Logo section
          Center(
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.pitchGreen, AppColors.pitchGreenDark]),
                  ),
                  child: const Icon(Icons.sports_cricket, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 16),
                Text('SPORTYAPP', style: AppTextStyles.headlineLarge(cs.onSurface)
                  .copyWith(letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('Version 1.0.0', style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Your Premium Cricket Companion',
            style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 12),
          Text(
            'SPORTYAPP brings you live cricket scores, ball-by-ball commentary, match fixtures, player profiles, tournament standings, and the ability to broadcast your own matches live — all in one beautifully designed app.\n\nBuilt for cricket fans. By cricket fans. 🏑',
            style: AppTextStyles.bodyMedium(cs.onSurfaceVariant).copyWith(height: 1.7),
          ),
          const SizedBox(height: 32),
          Text('Features', style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 12),
          ...[
            ('🔴', 'Live Scores & Commentary'),
            ('📅', 'Fixtures & Results'),
            ('🏆', 'Tournaments & Points Tables'),
            ('📊', 'Player & Team Stats'),
            ('📡', 'Go Live — Stream Your Own Match'),
          ].map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Text(item.$2, style: AppTextStyles.bodyMedium(cs.onSurface)),
              ],
            ),
          )),
          const SizedBox(height: 32),
          Text('Legal', style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 8),
          Text(
            'The live streaming feature allows you to broadcast only from your own camera or sources you have rights to. Capturing or rebroadcasting third-party broadcast feeds is not permitted.',
            style: AppTextStyles.bodySmall(cs.onSurfaceVariant).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

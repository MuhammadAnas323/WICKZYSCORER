import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'dart:ui';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.charcoal900, AppColors.darkBackground],
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
                    'CRIXORA',
                    style: AppTextStyles.displayLarge(Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Choose your role',
                    style: AppTextStyles.titleLarge(AppColors.charcoal200),
                  ),
                ),
                const Spacer(),
                _RoleCard(
                  title: 'Watch as Spectator',
                  subtitle: 'Follow live scores, matches & tournaments',
                  icon: Icons.sports_cricket,
                  gradient: AppColors.heroCardGradient,
                  onTap: () => context.push('/spectator-signup'),
                ),
                const SizedBox(height: 24),
                _RoleCard(
                  title: 'Score a Match',
                  subtitle: 'Manage matches & score ball-by-ball',
                  icon: Icons.sports_score,
                  gradient: LinearGradient(
                    colors: [AppColors.floodlightGold, Colors.orangeAccent],
                  ),
                  onTap: () => context.push('/scorer-signup'),
                ),
                const Spacer(),
                Center(
                  child: GestureDetector(
                    onTap: () => context.push('/signin'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: AppTextStyles.bodyMedium(AppColors.charcoal200),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: AppTextStyles.titleMedium(AppColors.pitchGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
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
                      Text(title, style: AppTextStyles.titleLarge(Colors.white)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTextStyles.bodySmall(AppColors.charcoal200)),
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

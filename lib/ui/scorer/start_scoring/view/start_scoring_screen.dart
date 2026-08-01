// lib/ui/scorer/start_scoring/view/start_scoring_screen.dart
// Start Scoring hub: two cards — Tournaments and Matches.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class StartScoringScreen extends StatelessWidget {
  const StartScoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.pitchGreen, Color(0xFF1A7A3E)],
                ),
              ),
              child: const Icon(Icons.sports_cricket_rounded,
                  color: Colors.white, size: 20),
            ),
            const Gap(10),
            Text(
              'Start Scoring',
              style: AppTextStyles.titleMedium(Colors.white)
                  .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What would you like to do?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(6),
            const Text(
              'Pick a tournament to manage teams & fixtures, or set up an individual match.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const Gap(24),

            // ── Tournaments card ──────────────────────────────────────────
            _HubCard(
              icon: Icons.emoji_events_rounded,
              iconBg: AppColors.floodlightGold,
              title: 'Tournaments',
              subtitle: 'Manage tournaments, teams, players & fixtures',
              onTap: () => context.go('/scorer/tournaments'),
            ),
            const Gap(16),

            // ── Matches card ──────────────────────────────────────────────
            _HubCard(
              icon: Icons.sports_cricket_rounded,
              iconBg: AppColors.pitchGreen,
              title: 'Matches',
              subtitle: 'Set up an individual match — venue, teams & players',
              onTap: () => context.push('/scorer/match-setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: iconBg.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [iconBg, iconBg.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(color: iconBg.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Gap(4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

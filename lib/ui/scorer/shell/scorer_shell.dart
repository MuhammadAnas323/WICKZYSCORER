// lib/ui/scorer/shell/scorer_shell.dart
// Bottom navigation shell for the scorer area of CRIXORA.
// Tabs: Home · Tournaments · [Start Scoring] · Profile

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';

class ScorerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScorerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: navigationShell,
      bottomNavigationBar: _ScorerBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        onStartScoring: () => context.push('/scorer/start-scoring'),
      ),
    );
  }
}

class _ScorerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onStartScoring;

  const _ScorerBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onStartScoring,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.emoji_events_rounded, 'Tournaments'),
      (Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              // Home + Tournaments tabs
              ...items.take(2).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final isSelected = currentIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    splashColor: AppColors.pitchGreenLight.withOpacity(0.1),
                    highlightColor: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.pitchGreen.withOpacity(0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            entry.value.$1,
                            color: isSelected
                                ? AppColors.pitchGreenLight
                                : Colors.white38,
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.value.$2,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.pitchGreenLight
                                  : Colors.white38,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // ── Center "Start Scoring" button (raised, non-navigating) ──
              InkWell(
                onTap: onStartScoring,
                splashColor: AppColors.pitchGreenLight.withOpacity(0.2),
                highlightColor: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 84,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2ECC71), Color(0xFF1A7A3E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pitchGreenLight.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_cricket_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Start Scoring',
                        style: TextStyle(
                          color: AppColors.pitchGreenLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Profile tab
              Expanded(
                child: InkWell(
                  onTap: () => onTap(2),
                  splashColor: AppColors.pitchGreenLight.withOpacity(0.1),
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: currentIndex == 2
                          ? AppColors.pitchGreen.withOpacity(0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: currentIndex == 2
                              ? AppColors.pitchGreenLight
                              : Colors.white38,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Profile',
                          style: TextStyle(
                            color: currentIndex == 2
                                ? AppColors.pitchGreenLight
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: currentIndex == 2
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/ui/scorer/shell/scorer_shell.dart
// Bottom navigation shell for the scorer area of CRIXORA.
// Tabs: Home · Tournaments · Create Match (center) · Settings · Profile

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
      ),
    );
  }
}

class _ScorerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ScorerBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // (icon, label, isCenterHighlight)
    final items = <(IconData, String, bool)>[
      (Icons.home_rounded, 'Home', false),
      (Icons.emoji_events_rounded, 'Tournaments', false),
      (Icons.sports_cricket_rounded, 'Start Scoring', true),
      (Icons.add_circle_rounded, 'Matches', false),
      (Icons.person_rounded, 'Profile', false),
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
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isSelected = currentIndex == i;
              final Color activeColor = item.$3
                  ? AppColors.pitchGreenLight
                  : AppColors.pitchGreenLight;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: AppColors.pitchGreenLight.withOpacity(0.1),
                  highlightColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.$3
                              ? (isSelected
                                  ? AppColors.pitchGreen.withOpacity(0.25)
                                  : AppColors.pitchGreen)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          item.$1,
                          color: isSelected
                              ? activeColor
                              : item.$3
                                  ? Colors.white
                                  : Colors.white38,
                          size: item.$3 ? 24 : 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: isSelected ? activeColor : Colors.white38,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
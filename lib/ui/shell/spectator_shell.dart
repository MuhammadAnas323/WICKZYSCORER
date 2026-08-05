// lib/ui/shell/spectator_shell.dart
// Bottom navigation shell for the spectator area of CRIXORA.
// Tabs: Home · Live · Events · Profile

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/shared_widgets/live_mini_banner.dart';
import 'package:sportyapp/theme/app_colors.dart';

class SpectatorShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const SpectatorShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      body: Column(
        children: [
          Expanded(child: navigationShell),
          const LiveMiniBanner(),
        ],
      ),
      bottomNavigationBar: _SpectatorBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _SpectatorBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SpectatorBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF141414) : Colors.white;
    final unselectedColor = isDark ? Colors.white38 : Colors.black45;

    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.sports_cricket_rounded, 'Live'),
      (Icons.emoji_events_rounded, 'Events'),
      (Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 20,
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
              final isSelected = currentIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: AppColors.pitchGreen.withOpacity(0.1),
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [AppColors.pitchGreen, AppColors.pitchGreenDark],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(5), // 5px border radius as required
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.pitchGreen.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          entry.value.$1,
                          color: isSelected ? Colors.white : unselectedColor,
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected ? Colors.white : unselectedColor,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                          child: Text(entry.value.$2),
                        ),
                      ],
                    ),
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

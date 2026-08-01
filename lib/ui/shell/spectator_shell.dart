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
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    const selectedColor = AppColors.pitchGreenLight;
    final unselectedColor = isDark ? Colors.white38 : Colors.black38;

    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.sports_cricket_rounded, 'Live'),
      (Icons.emoji_events_rounded, 'Events'),
      (Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
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
              final isSelected = currentIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: selectedColor.withOpacity(0.1),
                  highlightColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedColor.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          entry.value.$1,
                          color: isSelected ? selectedColor : unselectedColor,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected ? selectedColor : unselectedColor,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
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

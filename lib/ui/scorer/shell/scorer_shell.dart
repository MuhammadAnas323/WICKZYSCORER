// lib/ui/scorer/shell/scorer_shell.dart
// Bottom navigation shell for the scorer area of WICKZYSCORER.
// Tabs: Home · Tournaments · Create Match (center) · Settings · Profile

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class ScorerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScorerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
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

/// Bottom navigation bar for the scorer shell.
class _ScorerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ScorerBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).colorScheme.surface;
    final unselectedColor = isDark ? Colors.white38 : Colors.black45;
    final l10n = AppLocalizations.of(context);

    final items = <(IconData, String, bool)>[
      (Icons.home_rounded, l10n.translate('home'), false),
      (Icons.emoji_events_rounded, l10n.translate('tournaments'), false),
      (Icons.sports_cricket_rounded, l10n.translate('scoring'), true),
      (Icons.add_circle_rounded, l10n.translate('matches'), false),
      (Icons.person_rounded, l10n.translate('profile'), false),
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
              final item = entry.value;
              final isSelected = currentIndex == i;
              final isCenter = item.$3;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: AppColors.pitchGreen.withOpacity(0.1),
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected || isCenter
                          ? LinearGradient(
                              colors: isCenter
                                  ? const [AppColors.floodlightGold, Colors.orangeAccent]
                                  : const [AppColors.pitchGreen, AppColors.pitchGreenDark],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(5), // 5px border radius as required
                      boxShadow: (isSelected || isCenter)
                          ? [
                              BoxShadow(
                                color: (isCenter ? Colors.orangeAccent : AppColors.pitchGreen).withOpacity(0.3),
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
                          item.$1,
                          color: (isSelected || isCenter)
                              ? (isCenter ? Colors.black : Colors.white)
                              : unselectedColor,
                          size: isCenter ? 24 : 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: (isSelected || isCenter)
                                ? (isCenter ? Colors.black : Colors.white)
                                : unselectedColor,
                            fontSize: 10,
                            fontWeight: (isSelected || isCenter) ? FontWeight.bold : FontWeight.w500,
                          ),
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
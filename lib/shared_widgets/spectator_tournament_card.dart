// lib/shared_widgets/spectator_tournament_card.dart
// Spectator-facing tournament card (browse/fan style). Uses a corner accent
// gradient plus a trophy block and stat strip (dates / teams / matches) so it
// is visually distinct from the scorer's TournamentCard (left accent bar +
// organizer footer). Points to the spectator event detail, not management.

import 'package:flutter/material.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/shared_widgets/corner_accent.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class SpectatorTournamentCard extends StatelessWidget {
  final ScorerTournament tournament;
  final VoidCallback onTap;

  /// Number of teams/matches to show in the stat strip. When null the count is
  /// derived from [tournament] where possible.
  final int? teamCount;
  final int? matchCount;

  const SpectatorTournamentCard({
    super.key,
    required this.tournament,
    required this.onTap,
    this.teamCount,
    this.matchCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradient = AppColors.tournamentGradientFor(tournament.id);
    final teams = teamCount ?? tournament.teamIds.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            CornerAccent(gradient: gradient),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: trophy block + name + format pill.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tournament.name,
                                style: AppTextStyles.titleLarge(cs.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              tournament.venue.isNotEmpty
                                  ? tournament.venue
                                  : 'Venue TBA',
                              style:
                                  AppTextStyles.bodySmall(cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Stat strip: dates / teams / matches.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statItem(
                            cs, '📅',
                            '${tournament.startDate.day}/${tournament.startDate.month} — ${tournament.endDate.day}/${tournament.endDate.month}'),
                      ),
                      Expanded(
                        child:
                            _statItem(cs, '🏑', '$teams'),
                      ),
                      Expanded(
                        child: _statItem(
                            cs, '🏏', '${matchCount ?? '–'}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(ColorScheme cs, String emoji, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 3),
        Text(value,
            style: AppTextStyles.labelSmall(cs.onSurfaceVariant)
                .copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

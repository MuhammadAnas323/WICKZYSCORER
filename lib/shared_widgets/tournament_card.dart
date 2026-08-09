// lib/shared_widgets/tournament_card.dart
// Scorer-facing tournament card (management style). Uses a full-height left
// gradient accent bar so it is visually distinct from the spectator's
// spectator_tournament_card (which uses a corner accent instead). Renders
// organizer + schedule/status affordances relevant to the scorer.

import 'package:flutter/material.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/shared_widgets/alert_options_sheet.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class TournamentCard extends StatelessWidget {
  final ScorerTournament tournament;
  final VoidCallback onTap;

  /// Optional chip shown in the header row (e.g. a schedule status badge).
  final Widget? headerBadge;

  const TournamentCard({
    super.key,
    required this.tournament,
    required this.onTap,
    this.headerBadge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradient = AppColors.tournamentGradientFor(tournament.id);

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
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left gradient accent bar — scorer management identity.
            Container(
              width: 6,
              decoration: BoxDecoration(gradient: gradient),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header: Teams badge.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
child: Row(
                    children: [
                      const Spacer(),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.groups_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${tournament.teamIds.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (headerBadge != null) ...[
                          const SizedBox(width: 8),
                          headerBadge!,
                        ],
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.notifications_none_rounded,
                              size: 18, color: cs.onSurfaceVariant),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => TournamentAlertsSheet(
                                tournamentId: tournament.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Middle Content: Name & Details.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name,
                          style: AppTextStyles.titleMedium(cs.onSurface)
                              .copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tournament.venue.isNotEmpty
                                    ? tournament.venue
                                    : 'Venue TBA',
                                style:
                                    AppTextStyles.bodySmall(cs.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.calendar_today_outlined,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${tournament.startDate.month}/${tournament.startDate.day}',
                              style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Footer: Organizer info.
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      border: Border(top: BorderSide(color: cs.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tournament.organizer.isNotEmpty
                                ? 'Organizer: ${tournament.organizer}'
                                : 'Official Tournament',
                            style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

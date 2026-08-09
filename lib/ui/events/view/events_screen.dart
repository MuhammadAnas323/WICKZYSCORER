import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/shared_widgets/corner_accent.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(spectatorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('events'), style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: state.isLoading
          ? const MatchListSkeleton()
          : state.tournaments.isEmpty
              ? const EmptyState(
                  emoji: '🏆',
                  title: 'No tournaments yet',
                  subtitle:
                      'Tournaments, teams and matches created by scorers will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(spectatorHomeViewModelProvider.notifier)
                      .refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.tournaments.length,
                    itemBuilder: (_, i) => _EventCard(
                      tournament: state.tournaments[i],
                      teamCount:
                          state.teamsForTournament(state.tournaments[i].id).length,
                      matchCount:
                          state.matchesForTournament(state.tournaments[i].id).length,
                      onTap: () =>
                          context.push('/events/${state.tournaments[i].id}'),
                    ),
                  ),
                ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final ScorerTournament tournament;
  final int teamCount;
  final int matchCount;
  final VoidCallback onTap;

  const _EventCard({
    required this.tournament,
    required this.teamCount,
    required this.matchCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradient = AppColors.tournamentGradientFor(tournament.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
              children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.transparent,
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
                        color: AppColors.floodlightGold, size: 26),
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
                          style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _statItem('📅 Dates',
                        '${tournament.startDate.day}/${tournament.startDate.month} — ${tournament.endDate.day}/${tournament.endDate.month}', cs),
                  ),
                  Expanded(
                    child: _statItem('🏑 Teams', '$teamCount', cs),
                  ),
                  Expanded(
                    child: _statItem('🏏 Matches', '$matchCount', cs),
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

  Widget _statItem(String label, String value, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            style: AppTextStyles.bodySmall(cs.onSurface)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

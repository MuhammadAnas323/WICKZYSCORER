import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
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

  String get _formatLabel {
    switch (tournament.format) {
      case MatchFormat.t20:
        return 'T20';
      case MatchFormat.odi:
        return 'ODI';
      case MatchFormat.test:
        return 'TEST';
      case MatchFormat.custom:
        return '${tournament.customOvers}-OVER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: AppColors.heroCardGradient,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white24,
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
                            style: AppTextStyles.titleLarge(Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '$_formatLabel • ${tournament.venue}',
                          style: AppTextStyles.bodySmall(Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _formatLabel,
                      style: AppTextStyles.labelSmall(Colors.white),
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
                    child: _statItem(cs, '📅 Dates',
                        '${tournament.startDate.day}/${tournament.startDate.month} — ${tournament.endDate.day}/${tournament.endDate.month}'),
                  ),
                  Expanded(
                    child: _statItem(cs, '🏑 Teams', '$teamCount'),
                  ),
                  Expanded(
                    child: _statItem(cs, '🏏 Matches', '$matchCount'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(ColorScheme cs, String label, String value) {
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

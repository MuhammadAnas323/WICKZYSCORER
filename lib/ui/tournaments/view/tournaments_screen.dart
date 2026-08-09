import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/core/extensions/datetime_extensions.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/shared_widgets/corner_accent.dart';
import 'package:sportyapp/ui/tournaments/viewmodel/tournaments_viewmodel.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tournamentsViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tournaments', style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: state.isLoading
        ? const MatchListSkeleton(count: 3)
        : state.error != null
            ? ErrorState(onRetry: () => ref.read(tournamentsViewModelProvider.notifier).load())
            : state.tournaments.isEmpty
                ? const EmptyState(emoji: '🏆', title: 'No Tournaments',
                    subtitle: 'No tournaments found at this time.')
                : RefreshIndicator(
                    onRefresh: () => ref.read(tournamentsViewModelProvider.notifier).load(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.tournaments.length,
                      itemBuilder: (_, i) => _TournamentCard(
                        tournament: state.tournaments[i],
                        onTap: () => context.push('/tournaments/${state.tournaments[i].id}'),
                      ),
                    ),
                  ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;
  const _TournamentCard({required this.tournament, required this.onTap});

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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            CornerAccent(gradient: gradient),
            Column(
              children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.transparent,
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tournament.name,
                          style: AppTextStyles.titleLarge(cs.onSurface)),
                        Text(tournament.host,
                          style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tournament.status == 'live' ? AppColors.liveRed
                        : tournament.status == 'upcoming' ? AppColors.floodlightGold
                        : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      tournament.status.toUpperCase(),
                      style: AppTextStyles.liveBadge(
                        tournament.status == 'completed'
                            ? cs.onSurfaceVariant
                            : Colors.white)),
                  ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _statItem('📅 Dates',
                      '${tournament.startDate.formattedDate} — ${tournament.endDate.formattedDate}', cs),
                  ),
                  Expanded(
                    child: _statItem('🏑 Matches',
                      '${tournament.completedMatches}/${tournament.totalMatches} played', cs),
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
        Text(value, style: AppTextStyles.bodySmall(cs.onSurface)
          .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

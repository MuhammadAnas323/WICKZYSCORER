import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/features/admin/viewmodel/admin_dashboard_viewmodel.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/ball_strip.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push('/admin/create-match'),
          ),
        ],
      ),
      body: state.isLoading
          ? const MatchListSkeleton()
          : state.error != null
              ? ErrorState(
                  message: state.error!,
                  onRetry: () => ref.read(adminDashboardViewModelProvider.notifier).load(),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(adminDashboardViewModelProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SectionHeader(title: 'Live Matches', count: state.liveMatches.length),
                      const SizedBox(height: 12),
                      if (state.liveMatches.isEmpty)
                        _EmptySection(message: 'No live matches')
                      else
                        ...state.liveMatches.map(
                          (m) => _AdminMatchCard(
                            match: m,
                            isLive: true,
                            onEnd: () => ref.read(adminDashboardViewModelProvider.notifier).endMatch(m.id),
                          ),
                        ),
                      const SizedBox(height: 32),
                      _SectionHeader(title: 'Upcoming Matches', count: state.upcomingMatches.length),
                      const SizedBox(height: 12),
                      if (state.upcomingMatches.isEmpty)
                        _EmptySection(message: 'No upcoming matches')
                      else
                        ...state.upcomingMatches.map(
                          (m) => _AdminMatchCard(match: m, isLive: false),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.titleLarge(Theme.of(context).colorScheme.onSurface)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text('$count', style: AppTextStyles.labelMedium(Theme.of(context).colorScheme.primary)),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      ),
      child: Center(
        child: Text(message, style: AppTextStyles.bodyMedium(Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _AdminMatchCard extends StatelessWidget {
  final MatchModel match;
  final bool isLive;
  final VoidCallback? onEnd;

  const _AdminMatchCard({required this.match, required this.isLive, this.onEnd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLive) const LiveBadge(),
                if (isLive) const SizedBox(width: 8),
                Expanded(
                  child: Text(match.title,
                    style: AppTextStyles.titleMedium(cs.onSurface),
                    overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(match.format.name.toUpperCase(),
                    style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('${match.teamA.flagEmoji} ${match.teamA.shortName}',
                    style: AppTextStyles.bodyMedium(cs.onSurface)),
                ),
                const SizedBox(width: 8),
                Text('vs', style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${match.teamB.flagEmoji} ${match.teamB.shortName}',
                    style: AppTextStyles.bodyMedium(cs.onSurface),
                    textAlign: TextAlign.right),
                ),
              ],
            ),
            if (isLive && match.currentInnings != null) ...[
              const SizedBox(height: 4),
              BallStrip(balls: match.currentInnings!.lastSixBalls),
            ],
            if (onEnd != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onEnd,
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('End Match'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.liveRed,
                    side: const BorderSide(color: AppColors.liveRed),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

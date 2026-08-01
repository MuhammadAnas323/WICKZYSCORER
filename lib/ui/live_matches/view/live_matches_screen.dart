import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/ui/spectator/widgets/spectator_match_card.dart';

class LiveMatchesScreen extends ConsumerWidget {
  const LiveMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spectatorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;
    final liveMatches = state.liveMatches;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Live', style: AppTextStyles.headlineSmall(cs.onBackground)),
            const SizedBox(width: 8),
            if (liveMatches.isNotEmpty) const LiveBadge(),
          ],
        ),
      ),
      body: state.isLoading
          ? const MatchListSkeleton()
          : liveMatches.isEmpty
              ? RefreshIndicator(
                  onRefresh: () =>
                      ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                        emoji: '🔴',
                        title: 'No live matches right now',
                        subtitle:
                            'Matches being scored live will appear here in real time.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    children: liveMatches.map((m) => SpectatorMatchCard(
                          match: m,
                          teamName: state.teamName,
                          teamShort: state.teamShort,
                          tournamentName: (id) =>
                              state.tournamentById(id)?.name ?? 'Custom Match',
                          onTap: () =>
                              context.push('/spectator/match/${m.id}'),
                        )).toList(),
                  ),
                ),
    );
  }
}

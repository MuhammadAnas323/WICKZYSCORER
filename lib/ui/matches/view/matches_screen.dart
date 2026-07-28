import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/ui/matches/viewmodel/matches_viewmodel.dart';
import 'package:sportyapp/shared_widgets/match_card.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchesViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Matches', style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: state.isLoading
        ? const MatchListSkeleton()
        : state.error != null
            ? ErrorState(onRetry: () => ref.read(matchesViewModelProvider.notifier).load())
            : RefreshIndicator(
                onRefresh: () => ref.read(matchesViewModelProvider.notifier).load(),
                child: ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  children: [
                    // Upcoming Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Text('📅', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text('Upcoming Matches',
                            style: AppTextStyles.titleLarge(cs.onSurface)),
                        ],
                      ),
                    ),
                    if (state.upcoming.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: EmptyState(emoji: '📅', title: 'No Upcoming Matches',
                          subtitle: 'Check back soon for scheduled fixtures.'),
                      )
                    else
                      ...state.upcoming.map((m) => MatchCard(
                        match: m,
                        onTap: () => context.push('/match/${m.id}'),
                      )),

                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 1,
                      color: cs.outline.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),

                    // Completed Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Text('🏁', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text('Completed Matches',
                            style: AppTextStyles.titleLarge(cs.onSurface)),
                        ],
                      ),
                    ),
                    if (state.completed.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: EmptyState(emoji: '🏁', title: 'No Results Yet',
                          subtitle: 'Completed match results will appear here.'),
                      )
                    else
                      ...state.completed.map((m) => MatchCard(
                        match: m,
                        onTap: () => context.push('/match/${m.id}'),
                      )),
                  ],
                ),
              ),
    );
  }
}
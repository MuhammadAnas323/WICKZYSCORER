import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/matches/viewmodel/matches_viewmodel.dart';
import 'package:sportyapp/shared_widgets/match_card.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      ref.read(matchesViewModelProvider.notifier).loadMoreUpcoming();
      ref.read(matchesViewModelProvider.notifier).loadMoreCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchesViewModelProvider);
    final cs = Theme.of(context).colorScheme;
    final displayedUpcoming = state.displayedUpcoming;
    final displayedCompleted = state.displayedCompleted;

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
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  children: [
                    // Upcoming Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 20)),
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
                    else ...[
                      ...displayedUpcoming.map((m) => MatchCard(
                        match: m,
                        onTap: () => context.push('/match/${m.id}'),
                      )),
                      if (state.hasMoreUpcoming || state.isLoadingMoreUpcoming)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.pitchGreen),
                            ),
                          ),
                        ),
                    ],

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
                          const Text('🏁', style: TextStyle(fontSize: 20)),
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
                    else ...[
                      ...displayedCompleted.map((m) => MatchCard(
                        match: m,
                        onTap: () => context.push('/match/${m.id}'),
                      )),
                      if (state.hasMoreCompleted || state.isLoadingMoreCompleted)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.pitchGreen),
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

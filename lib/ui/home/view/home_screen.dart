import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/spectator_tournament_card.dart';
import 'package:sportyapp/ui/spectator/widgets/spectator_match_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spectatorHomeViewModelProvider);
    final notifier = ref.read(spectatorHomeViewModelProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.pitchGreen, AppColors.pitchGreenDark],
                ),
              ),
              child: const Icon(Icons.sports_cricket, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'CRIXORA',
              style: AppTextStyles.titleLarge(cs.onBackground)
                  .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Level Filter Tabs (Tournaments / Friendly Matches) ──────
            _buildTopTabs(context, state, notifier, isDark),

            // ── Search Bar & Sub-Filters Header ─────────────────────────────
            _buildHeaderControls(context, state, notifier, isDark),

            // ── Main Content Area ───────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const MatchListSkeleton()
                  : state.error != null
                      ? _ErrorState(onRetry: () => notifier.refresh())
                      : RefreshIndicator(
                          onRefresh: () => notifier.refresh(),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: state.topTab == 0
                                ? _buildTournamentsList(context, state)
                                : _buildFriendlyMatchesList(context, state),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Top Level Filter Tabs ─────────────────────────────────────────────
  Widget _buildTopTabs(
    BuildContext context,
    SpectatorHomeState state,
    SpectatorHomeViewModel notifier,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              title: '🏆 Tournaments',
              isSelected: state.topTab == 0,
              onTap: () => notifier.setTopTab(0),
            ),
          ),
          Expanded(
            child: _tabButton(
              title: '🏏 Friendly Matches',
              isSelected: state.topTab == 1,
              onTap: () => notifier.setTopTab(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.pitchGreen, Color(0xFF166534)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.pitchGreen.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── 2. Search Bar & Sub-Filters ──────────────────────────────────────────
  Widget _buildHeaderControls(
    BuildContext context,
    SpectatorHomeState state,
    SpectatorHomeViewModel notifier,
    bool isDark,
  ) {
    final cs = Theme.of(context).colorScheme;
    final currentSubFilter =
        state.topTab == 0 ? state.tournamentSubFilter : state.friendlySubFilter;

    final subFilterOptions = [
      ('all', 'All'),
      ('live', '🔴 Live'),
      ('upcoming', '📅 Upcoming'),
      ('completed', '🏁 Completed'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => notifier.setSearchQuery(val),
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: state.topTab == 0
                    ? 'Search tournaments by name...'
                    : 'Search matches by team or venue...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearchQuery('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Sub-filters Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subFilterOptions.map((f) {
                final isSelected = currentSubFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (state.topTab == 0) {
                        notifier.setTournamentSubFilter(f.$1);
                      } else {
                        notifier.setFriendlySubFilter(f.$1);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [AppColors.pitchGreen, AppColors.pitchGreenDark],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.pitchGreen
                              : (isDark ? Colors.white10 : Colors.black12),
                        ),
                      ),
                      child: Text(
                        f.$2,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── 3. Tournaments List View ─────────────────────────────────────────────
  Widget _buildTournamentsList(BuildContext context, SpectatorHomeState state) {
    final list = state.filteredTournaments;
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            emoji: '🏆',
            title: 'No Tournaments Found',
            subtitle: 'No tournaments match your filter criteria.',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final t = list[i];
        return SpectatorTournamentCard(
          tournament: t,
          teamCount: state.teamsForTournament(t.id).length,
          matchCount: state.matchesForTournament(t.id).length,
          onTap: () => context.push('/events/${t.id}'),
        );
      },
    );
  }

  // ── 4. Friendly Matches List View ────────────────────────────────────────
  Widget _buildFriendlyMatchesList(
      BuildContext context, SpectatorHomeState state) {
    final list = state.filteredFriendlyMatches;
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            emoji: '🏏',
            title: 'No Friendly Matches Found',
            subtitle: 'No non-tournament matches match your criteria.',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        return SpectatorMatchCard(
          match: m,
          teamName: state.teamName,
          teamShort: state.teamShort,
          tournamentName: (id) => 'Friendly Match',
          live: state.rtdbLiveMatches[m.id],
          onTap: () => context.push('/spectator/match/${m.id}'),
        );
      },
    );
  }
}

// ── Tournament Card (5px border radius with full details) ───────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        emoji: '⚠️',
        title: 'Something went wrong',
        subtitle: 'Unable to load matches or tournaments.',
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
    );
  }
}


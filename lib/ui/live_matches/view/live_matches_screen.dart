import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/ui/spectator/widgets/spectator_match_card.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';

class LiveMatchesScreen extends ConsumerStatefulWidget {
  const LiveMatchesScreen({super.key});

  @override
  ConsumerState<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends ConsumerState<LiveMatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(spectatorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    final friendlyLive = state.liveFriendlyMatches;
    final tournamentLive = state.liveTournamentMatches;
    final totalLiveCount = state.liveMatches.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.translate('live'), style: AppTextStyles.headlineSmall(cs.onBackground)),
            const SizedBox(width: 8),
            if (totalLiveCount > 0) const LiveBadge(),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.pitchGreen, width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: AppColors.pitchGreen,
                ),
                indicatorColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: '${l10n.translate('friendly_matches')} (${friendlyLive.length})'),
                  Tab(text: '${l10n.translate('tournament_matches')} (${tournamentLive.length})'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const MatchListSkeleton()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMatchList(friendlyLive, state, l10n.translate('no_live_friendly'), l10n),
                _buildMatchList(tournamentLive, state, l10n.translate('no_live_tournament'), l10n),
              ],
            ),
    );
  }

  Widget _buildMatchList(
    List<ScorerMatch> matches,
    SpectatorHomeState state,
    String emptyMsg,
    AppLocalizations l10n,
  ) {
    if (matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            EmptyState(
              emoji: '🔴',
              title: emptyMsg,
              subtitle: l10n.translate('live_matches_appear_here'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: matches.map((m) => SpectatorMatchCard(
              match: m,
              teamName: state.teamName,
              teamShort: state.teamShort,
              tournamentName: (id) =>
                  state.tournamentById(id)?.name ?? l10n.translate('custom_match'),
              live: state.rtdbLiveMatches[m.id],
              onTap: () => context.push('/spectator/match/${m.id}'),
            )).toList(),
      ),
    );
  }
}

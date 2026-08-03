import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';

const double _cardRadius = 5;

class ScorerDashboardScreen extends ConsumerWidget {
  const ScorerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scorerDashboardViewModelProvider);
    final user = ref.watch(currentUserProvider);

    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Pro Scorer';

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.floodlightGold, Colors.orangeAccent],
                ),
              ),
              child: const Icon(Icons.sports_score, color: Colors.black, size: 20),
            ),
            const Gap(10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRIXORA',
                  style: AppTextStyles.titleMedium(Colors.white)
                      .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Welcome, $displayName',
                  style: AppTextStyles.bodySmall(AppColors.charcoal200),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: AppColors.pitchGreenLight),
            onPressed: () => context.go('/scorer/profile'),
          ),
          const Gap(8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.pitchGreen,
        onRefresh: () async {
          await ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _welcomeCard(context, state),
            const Gap(16),
            _sectionHeader('Tournaments'),
            const Gap(8),
            _tournamentsCard(context, ref, state),
            const Gap(16),
            _sectionHeader('Matches'),
            const Gap(8),
            _matchesCard(context, ref, state),
            const Gap(80),
          ],
        ),
      ),
    );
  }

  // ── Welcome / info card ────────────────────────────────────────────────
  Widget _welcomeCard(BuildContext context, ScorerDashboardState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.pitchGreen, Color(0xFF1A7A3E)],
                  ),
                ),
                child: const Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 22),
              ),
              const Gap(10),
              Text(
                'Welcome to CRIXORA!',
                style: AppTextStyles.titleLarge(Colors.white),
              ),
            ],
          ),
          const Gap(12),
          const Text(
            'The pitch is ready. The crowd is waiting.\n'
            'Hit "Start Session" for live, ball-by-ball updates for all fans!',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pitchGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Start Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => context.push('/scorer/start-scoring'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.pitchGreenLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Text(title, style: AppTextStyles.titleLarge(Colors.white)),
      ],
    );
  }

  // ── Tournaments card ───────────────────────────────────────────────────
  Widget _tournamentsCard(BuildContext context, WidgetRef ref, ScorerDashboardState state) {
    final filters = [
      ('all', 'All'),
      ('live', 'Live'),
      ('upcoming', 'Upcoming'),
      ('completed', 'Completed'),
    ];
    final tournaments = state.filteredTournaments;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.floodlightGold, size: 20),
              const Gap(8),
              Expanded(
                child: Text(
                  'Tournaments',
                  style: AppTextStyles.titleMedium(Colors.white).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text('${tournaments.length}', style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(
                    label: f.$2,
                    selected: state.tournamentFilter == f.$1,
                    onTap: () => ref.read(scorerDashboardViewModelProvider.notifier).setTournamentFilter(f.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          const Gap(10),
          if (tournaments.isEmpty)
            _emptyHint('No tournaments')
          else
            ...tournaments.map((t) => _tournamentTile(context, t)),
        ],
      ),
    );
  }

  Widget _tournamentTile(BuildContext context, ScorerTournament t) {
    return InkWell(
      onTap: () => context.push('/scorer/tournaments/${t.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.floodlightGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.floodlightGold, size: 20),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${t.format.name.toUpperCase()} • ${t.numTeams} teams',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  // ── Matches card ───────────────────────────────────────────────────────
  Widget _matchesCard(BuildContext context, WidgetRef ref, ScorerDashboardState state) {
    final filters = [
      ('all', 'All'),
      ('live', 'Live'),
      ('upcoming', 'Upcoming'),
      ('completed', 'Completed'),
    ];
    final matches = state.filteredMatches;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_score_rounded, color: AppColors.pitchGreenLight, size: 20),
              const Gap(8),
              Expanded(
                child: Text(
                  'Matches',
                  style: AppTextStyles.titleMedium(Colors.white).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text('${matches.length}', style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(
                    label: f.$2,
                    selected: state.matchFilter == f.$1,
                    onTap: () => ref.read(scorerDashboardViewModelProvider.notifier).setMatchFilter(f.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          const Gap(6),
          // My matches only toggle
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: Colors.white54, size: 16),
              const Gap(6),
              const Expanded(
                child: Text('My matches only', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              Switch(
                value: state.myMatchesOnly,
                activeTrackColor: AppColors.pitchGreen,
                onChanged: (v) => ref.read(scorerDashboardViewModelProvider.notifier).setMyMatchesOnly(v),
              ),
            ],
          ),
          const Gap(6),
          if (matches.isEmpty)
            _emptyHint('No matches')
          else
            ...matches.map((m) => _matchTile(context, ref, m, state)),
        ],
      ),
    );
  }

  Widget _matchTile(BuildContext context, WidgetRef ref, ScorerMatch match, ScorerDashboardState state) {
    final isLive = match.status == MatchStatus.inProgress || match.status == MatchStatus.live;
    final isCompleted = match.status == MatchStatus.completed;

    return InkWell(
      onTap: () {
        if (isLive || isCompleted) {
          ref.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);
          context.push('/scorer/live-scoring');
        } else {
          context.push('/scorer/matches/${match.id}/squad');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: isLive ? AppColors.liveRed.withOpacity(0.6) : Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLive ? AppColors.liveRed : Colors.white12,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isLive ? 'LIVE' : match.status.name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                Text(match.venue, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.teamName(match.team1Id), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (match.innings1 != null)
                      Text('${match.innings1!.totalRuns}/${match.innings1!.wickets} (${match.innings1!.overs.toStringAsFixed(1)} ov)',
                          style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const Text('VS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(state.teamName(match.team2Id), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (match.innings2 != null)
                      Text('${match.innings2!.totalRuns}/${match.innings2!.wickets} (${match.innings2!.overs.toStringAsFixed(1)} ov)',
                          style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.pitchGreen : Colors.white10,
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }
}

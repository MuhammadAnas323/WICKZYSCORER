import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/core/extensions/datetime_extensions.dart';
import 'package:sportyapp/core/extensions/int_extensions.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/player_model.dart';
import 'package:sportyapp/ui/match_details/viewmodel/match_details_viewmodel.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';
import 'package:sportyapp/shared_widgets/ball_strip.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';

class MatchDetailsScreen extends ConsumerStatefulWidget {
  final String matchId;
  const MatchDetailsScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends ConsumerState<MatchDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = ['Info', 'Scorecard', 'Commentary', 'Squads', 'Stats'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(matchDetailsViewModelProvider(widget.matchId).notifier)
          .setTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchDetailsViewModelProvider(widget.matchId));
    final cs = Theme.of(context).colorScheme;

    if (state.isLoading) return Scaffold(appBar: AppBar(), body: const MatchListSkeleton());
    if (state.error != null) {
      return Scaffold(
      appBar: AppBar(),
      body: ErrorState(
        message: state.error!,
        onRetry: () => ref.read(matchDetailsViewModelProvider(widget.matchId).notifier).load()));
    }

    final match = state.match!;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: _MatchHeader(match: match, liveData: state.liveData),
              collapseMode: CollapseMode.parallax,
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _InfoTab(match: match),
            _ScorecardTab(match: match, liveData: state.liveData),
            _CommentaryTab(match: match),
            _SquadsTab(match: match),
            _StatsTab(match: match),
          ],
        ),
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  final MatchModel match;
  final LiveMatchData? liveData;
  const _MatchHeader({required this.match, this.liveData});

  @override
  Widget build(BuildContext context) {
    final inn = match.currentInnings;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D2818), Color(0xFF1A7A3E)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (match.isLive || liveData != null) const LiveBadge(),
                  if (match.isLive || liveData != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(match.seriesName,
                      style: AppTextStyles.labelMedium(Colors.white70),
                      overflow: TextOverflow.ellipsis)),
                  if (liveData != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(liveData!.viewers.abbreviated,
                            style: AppTextStyles.labelSmall(Colors.white70)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${match.teamA.flagEmoji} ${match.teamA.shortName}',
                          style: AppTextStyles.titleLarge(Colors.white)),
                        Text(
                          liveData != null
                              ? '${liveData!.runs}/${liveData!.wickets} (${liveData!.overs.toStringAsFixed(1)})'
                              : match.teamAScore,
                          style: AppTextStyles.scoreMedium(Colors.white)),
                      ],
                    ),
                  ),
                  Text('vs', style: AppTextStyles.bodySmall(Colors.white54)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${match.teamB.shortName} ${match.teamB.flagEmoji}',
                          style: AppTextStyles.titleLarge(Colors.white)),
                        Text(
                          liveData != null
                              ? '${liveData!.runs}/${liveData!.wickets} (${liveData!.overs.toStringAsFixed(1)})'
                              : match.teamBScore,
                          style: AppTextStyles.scoreMedium(Colors.white),
                          textAlign: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (liveData != null) ...[
                Row(
                  children: [
                    if (liveData!.target != null)
                      Text('TARGET: ${liveData!.target}',
                        style: AppTextStyles.labelMedium(AppColors.floodlightGold)),
                    const SizedBox(width: 12),
                    Text('RR: ${liveData!.currentRunRate.toStringAsFixed(2)}',
                      style: AppTextStyles.labelMedium(Colors.white70)),
                    const Spacer(),
                    Text(liveData!.lastBall.isNotEmpty ? 'Last: ${liveData!.lastBall}' : '',
                      style: AppTextStyles.labelMedium(Colors.white70)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Striker: ${liveData!.striker}  |  Non-striker: ${liveData!.nonStriker}  |  Bowler: ${liveData!.bowler}',
                  style: AppTextStyles.labelSmall(Colors.white54)),
              ] else ...[
                if (inn != null && inn.lastSixBalls.isNotEmpty)
                  BallStrip(balls: inn.lastSixBalls),
              ],
              if (match.resultSummary != null)
                Text(match.resultSummary!,
                  style: AppTextStyles.labelMedium(AppColors.floodlightGold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final MatchModel match;
  const _InfoTab({required this.match});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120,
            child: Text(label, style: AppTextStyles.labelMedium(cs.onSurfaceVariant))),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium(cs.onSurface))),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        row('Format', match.format.name.toUpperCase()),
        const Divider(),
        row('Series', match.seriesName),
        const Divider(),
        row('Date', match.scheduledAt.formattedDatetime),
        const Divider(),
        row('Venue', match.venue),
        const Divider(),
        row('City', match.city),
        const Divider(),
        row('Umpires', match.umpires),
        if (match.tossWinner != null) ...[const Divider(),
          row('Toss', '${match.tossWinner} won, elected to ${match.tossDecision}')],
        if (match.manOfMatch != null) ...[const Divider(),
          row('Player of Match', match.manOfMatch!)],
        if (match.totalOvers != null) ...[const Divider(),
          row('Total Overs', match.totalOvers.toString())],
      ],
    );
  }
}

class _ScorecardTab extends StatelessWidget {
  final MatchModel match;
  final LiveMatchData? liveData;
  const _ScorecardTab({required this.match, this.liveData});

  @override
  Widget build(BuildContext context) {
    if (match.innings.isEmpty && liveData == null) {
      return const EmptyState(emoji: '📊', title: 'No Scorecard Yet',
        subtitle: 'Scorecard will appear once the match starts.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: match.innings.map((inn) => _InningsCard(innings: inn)).toList(),
    );
  }
}

class _InningsCard extends StatelessWidget {
  final InningsModel innings;
  const _InningsCard({required this.innings});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Innings header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.pitchGreen,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
          child: Row(
            children: [
              Text('${innings.battingTeam.shortName} Innings ${innings.inningsNumber}',
                style: AppTextStyles.titleMedium(Colors.white)),
              const Spacer(),
              Text('${innings.runs}/${innings.wickets} (${innings.overs.toStringAsFixed(1)})',
                style: AppTextStyles.scoreMedium(Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Batting table
        if (innings.batters.isNotEmpty) ...[_tableHeader(cs, ['Batsman', 'R', 'B', '4s', '6s', 'SR']),
          ...innings.batters.map((b) => _batterRow(cs, b))],
        const SizedBox(height: 12),
        // Bowling table
        if (innings.bowlers.isNotEmpty) ...[_tableHeader(cs, ['Bowler', 'O', 'M', 'R', 'W', 'Econ']),
          ...innings.bowlers.map((b) => _bowlerRow(cs, b))],
        const SizedBox(height: 24),
        // Fall of wickets
        if (innings.fallOfWickets.isNotEmpty) ...[Text('Fall of Wickets',
          style: AppTextStyles.titleSmall(cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: innings.fallOfWickets.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${f.wicketNumber}-${f.runs}(${f.batsmanName})',
                style: AppTextStyles.labelSmall(cs.onSurface)),
            )).toList(),
          )],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _tableHeader(ColorScheme cs, List<String> cols) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: e.key == 0 ? 4 : 1,
            child: Text(e.value,
              style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
              textAlign: e.key == 0 ? TextAlign.left : TextAlign.center),
          );
        }).toList(),
      ),
    );
  }

  Widget _batterRow(ColorScheme cs, BatterScore b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant ?? cs.outline, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(b.batsman.name, style: AppTextStyles.labelMedium(cs.onSurface)
                  .copyWith(fontWeight: b.isOnCrease ? FontWeight.w700 : FontWeight.w500)),
                if (b.isOnCrease) const Padding(padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.sports_cricket, size: 10, color: AppColors.floodlightGold)),
              ]),
              Text(b.dismissal, style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis),
            ],
          )),
          ...[
            b.runs.toString(), b.balls.toString(), b.fours.toString(),
            b.sixes.toString(), b.strikeRate.toStringAsFixed(1),
          ].map((v) => Expanded(child: Text(v,
            style: AppTextStyles.labelMedium(cs.onSurface).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center))),
        ],
      ),
    );
  }

  Widget _bowlerRow(ColorScheme cs, BowlerScore b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant ?? cs.outline, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(b.bowler.name,
            style: AppTextStyles.labelMedium(cs.onSurface))),
          ...[
            b.overs.toStringAsFixed(1), b.maidens.toString(), b.runs.toString(),
            b.wickets.toString(), b.economy.toStringAsFixed(2),
          ].map((v) => Expanded(child: Text(v,
            style: AppTextStyles.labelMedium(
              v == b.wickets.toString() && b.wickets >= 3
                ? AppColors.ballRed : cs.onSurface)
            .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center))),
        ],
      ),
    );
  }
}

class _CommentaryTab extends StatelessWidget {
  final MatchModel match;
  const _CommentaryTab({required this.match});

  Color _eventColor(String e, ColorScheme cs) {
    switch (e.toUpperCase()) {
      case 'W': return AppColors.ballRed;
      case '4': return AppColors.pitchGreen;
      case '6': return AppColors.floodlightGold;
      default: return cs.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final events = match.innings
      .expand((inn) => inn.ballEvents.reversed)
      .toList();

    if (events.isEmpty) {
      return const EmptyState(emoji: '🎤', title: 'No Commentary Yet',
        subtitle: 'Ball-by-ball commentary will appear here during the match.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = events[i];
        final isHighlight = e.isBoundary || e.isSix || e.isWicket;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: isHighlight ? _eventColor(e.event, cs).withValues(alpha: 0.08) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _eventColor(e.event, cs),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(e.event,
                    style: AppTextStyles.labelSmall(Colors.white)
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 10))),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Over ${e.over}.${e.ball}',
                      style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(e.commentary,
                      style: AppTextStyles.bodySmall(cs.onSurface).copyWith(
                        fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SquadsTab extends StatelessWidget {
  final MatchModel match;
  const _SquadsTab({required this.match});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget playerRow(PlayerModel p) => ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.pitchGreen.withValues(alpha: 0.1),
        child: Text(p.teamFlag, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(p.name, style: AppTextStyles.bodyMedium(cs.onSurface)
        .copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(p.role.name, style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
      trailing: p.isCaptain
        ? Text('(C)', style: AppTextStyles.labelSmall(cs.primary))
        : p.isWicketKeeper
          ? Text('(WK)', style: AppTextStyles.labelSmall(AppColors.willowBrown))
          : null,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Team A
        Text('${match.teamA.flagEmoji} ${match.teamA.name} Playing XI',
          style: AppTextStyles.titleLarge(cs.onSurface)),
        const SizedBox(height: 8),
        ...match.teamA.playingXI.map(playerRow),
        const Divider(height: 32),
        // Team B
        Text('${match.teamB.flagEmoji} ${match.teamB.name} Playing XI',
          style: AppTextStyles.titleLarge(cs.onSurface)),
        const SizedBox(height: 8),
        ...match.teamB.playingXI.map(playerRow),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  final MatchModel match;
  const _StatsTab({required this.match});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget placeholder(String title, String icon) => Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.titleSmall(cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Chart will appear here', style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        placeholder('Wagon Wheel', '🗻'),
        placeholder('Run Rate Worm', '📈'),
        placeholder('Partnership Graph', '📊'),
      ],
    );
  }
}

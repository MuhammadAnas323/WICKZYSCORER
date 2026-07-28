import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/player_model.dart';
import 'package:sportyapp/ui/players/viewmodel/player_viewmodel.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';
import 'package:sportyapp/shared_widgets/stat_pill.dart';

class PlayerProfileScreen extends ConsumerStatefulWidget {
  final String playerId;
  const PlayerProfileScreen({super.key, required this.playerId});
  @override
  ConsumerState<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(playerDetailProvider(widget.playerId));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const MatchListSkeleton()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorState(message: e.toString())),
      data: (player) {
        if (player == null) {
          return Scaffold(appBar: AppBar(),
          body: const ErrorState(message: 'Player not found'));
        }

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 280,
                flexibleSpace: FlexibleSpaceBar(
                  background: _PlayerHeader(player: player),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.floodlightGold,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [Tab(text: 'Batting'), Tab(text: 'Bowling')],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _BattingStatsTab(stats: player.battingStats),
                _BowlingStatsTab(stats: player.bowlingStats),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final PlayerModel player;
  const _PlayerHeader({required this.player});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(player.dateOfBirth).inDays ~/ 365;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1B2838), Color(0xFF0D5C2E)]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.pitchGreen.withValues(alpha: 0.3),
                backgroundImage: NetworkImage(player.imageUrl),
                onBackgroundImageError: (_, __) {},
                child: Text(player.shortName[0],
                  style: AppTextStyles.headlineLarge(Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(player.name, style: AppTextStyles.headlineSmall(Colors.white)),
                      if (player.isCaptain) Text(' (C)',
                        style: AppTextStyles.labelMedium(AppColors.floodlightGold)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${player.teamFlag} ${player.teamName}',
                      style: AppTextStyles.bodyMedium(Colors.white70)),
                    const SizedBox(height: 4),
                    Text('Age $age • #${player.jerseyNumber}',
                      style: AppTextStyles.labelMedium(Colors.white54)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: [
                        StatPill(label: 'ROLE', value: player.role.name,
                          color: Colors.white24, textColor: Colors.white),
                        StatPill(label: 'BAT', value: player.battingStyle.split(' ').first,
                          color: Colors.white24, textColor: Colors.white),
                        if (player.bowlingStyle != 'N/A')
                          StatPill(label: 'BOWL', value: player.bowlingStyle.split(' ').first,
                            color: Colors.white24, textColor: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BattingStatsTab extends StatelessWidget {
  final BattingStats stats;
  const _BattingStatsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('Matches', stats.matches.toString()),
      ('Innings', stats.innings.toString()),
      ('Runs', stats.runs.toString()),
      ('High Score', stats.highScore.toString()),
      ('Average', stats.average.toStringAsFixed(2)),
      ('Strike Rate', stats.strikeRate.toStringAsFixed(2)),
      ('100s', stats.hundreds.toString()),
      ('50s', stats.fifties.toString()),
      ('4s', stats.fours.toString()),
      ('6s', stats.sixes.toString()),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Career Batting', style: AppTextStyles.titleLarge(cs.onSurface)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: items.map((item) => _StatCard(label: item.$1, value: item.$2)).toList(),
        ),
      ],
    );
  }
}

class _BowlingStatsTab extends StatelessWidget {
  final BowlingStats stats;
  const _BowlingStatsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (stats.wickets == 0 && stats.overs == 0) {
      return Center(child: Text('No bowling stats available.',
        style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)));
    }
    final items = [
      ('Matches', stats.matches.toString()),
      ('Innings', stats.innings.toString()),
      ('Wickets', stats.wickets.toString()),
      ('Best', stats.bestBowling),
      ('Average', stats.average.toStringAsFixed(2)),
      ('Economy', stats.economy.toStringAsFixed(2)),
      ('Strike Rate', stats.strikeRate.toStringAsFixed(2)),
      ('5-fers', stats.fiveWickets.toString()),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Career Bowling', style: AppTextStyles.titleLarge(cs.onSurface)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: items.map((item) => _StatCard(label: item.$1, value: item.$2)).toList(),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.scoreMedium(cs.onSurface)
            .copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

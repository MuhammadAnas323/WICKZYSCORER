import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/team_model.dart';
import 'package:sportyapp/data/models/player_model.dart';
import 'package:sportyapp/ui/teams/viewmodel/team_viewmodel.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';
import 'package:sportyapp/shared_widgets/stat_pill.dart';

class TeamProfileScreen extends ConsumerWidget {
  final String teamId;
  const TeamProfileScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamDetailProvider(teamId));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const MatchListSkeleton()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorState(message: AppErrorHandler.getUserFriendlyMessage(e))),
      data: (team) {
        if (team == null) {
          return Scaffold(appBar: AppBar(),
          body: const ErrorState(message: 'Team not found'));
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(gradient: AppColors.heroCardGradient),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Text(team.flagEmoji, style: const TextStyle(fontSize: 60)),
                          const SizedBox(height: 8),
                          Text(team.name, style: AppTextStyles.headlineMedium(Colors.white)),
                          Text('Ranked #${team.ranking} • ${team.teamType.toUpperCase()}',
                            style: AppTextStyles.bodySmall(Colors.white70)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StatPill(label: 'M', value: team.teamStats.matches.toString(),
                                color: Colors.white24, textColor: Colors.white),
                              const SizedBox(width: 8),
                              StatPill(label: 'W', value: team.teamStats.wins.toString(),
                                color: Colors.white24, textColor: Colors.white),
                              const SizedBox(width: 8),
                              StatPill(label: 'Win%', value: '${team.teamStats.winPercent.toStringAsFixed(1)}%',
                                color: Colors.white24, textColor: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Playing XI', style: AppTextStyles.titleLarge(cs.onSurface)),
                      const SizedBox(height: 12),
                      ...team.playingXI.map((p) => _PlayerRow(player: p)),
                      if (team.squad.length > team.playingXI.length) ...
                        [const SizedBox(height: 16),
                        Text('Squad', style: AppTextStyles.titleLarge(cs.onSurface)),
                        const SizedBox(height: 12),
                        ...team.squad.where((p) => !team.playingXI.any((xi) => xi.id == p.id))
                          .map((p) => _PlayerRow(player: p, isBench: true))],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerModel player;
  final bool isBench;
  const _PlayerRow({required this.player, this.isBench = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/player/${player.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBench ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.pitchGreen.withValues(alpha: 0.1),
              child: Text(player.teamFlag, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(player.name, style: AppTextStyles.bodyMedium(cs.onSurface)
                      .copyWith(fontWeight: FontWeight.w600)),
                    if (player.isCaptain) Text(' (C)',
                      style: AppTextStyles.labelSmall(cs.primary)),
                    if (player.isWicketKeeper) Text(' (WK)',
                      style: AppTextStyles.labelSmall(AppColors.willowBrown)),
                  ]),
                  Text(player.battingStyle, style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(_roleLabel(player.role),
                style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(PlayerRole r) {
    switch (r) {
      case PlayerRole.batsman: return 'BAT';
      case PlayerRole.bowler: return 'BOWL';
      case PlayerRole.allRounder: return 'AR';
      case PlayerRole.wicketKeeper: return 'WK';
    }
  }
}

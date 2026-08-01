import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';

class SpectatorMatchDetailScreen extends ConsumerWidget {
  final String matchId;
  const SpectatorMatchDetailScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spectatorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    final match = state.matches.where((m) => m.id == matchId).firstOrNull;

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const MatchListSkeleton(),
      );
    }

    if (match == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Match not found')),
      );
    }

    final isLive = match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.live;
    final tournament = state.tournamentById(match.tournamentId);

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: Text(
          tournament?.name ?? 'Match Details',
          style: AppTextStyles.headlineSmall(cs.onSurface),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scoreboard hero
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.heroCardGradient,
                borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLive) ...[
                        const LiveBadge(),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatLabel(match),
                        style: AppTextStyles.labelMedium(Colors.white70),
                      ),
                    ],
                  ),
                  const Gap(20),
                  Row(
                    children: [
                      Expanded(
                        child: _heroTeam(
                          short: state.teamShort(match.team1Id),
                          name: state.teamName(match.team1Id),
                          score: _scoreLine(match.innings1),
                          isBatting:
                              isLive && match.battingTeamId == match.team1Id,
                          isRight: false,
                        ),
                      ),
                      Text('vs',
                          style: AppTextStyles.bodyMedium(Colors.white54)),
                      Expanded(
                        child: _heroTeam(
                          short: state.teamShort(match.team2Id),
                          name: state.teamName(match.team2Id),
                          score: _scoreLine(match.innings2),
                          isBatting:
                              isLive && match.battingTeamId == match.team2Id,
                          isRight: true,
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            match.venue,
                            style: AppTextStyles.bodySmall(Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),

            // Match info
            _infoCard(context, match, state, tournament?.name),
            const Gap(16),

            // Innings breakdown
            if (match.innings1 != null || match.innings2 != null) ...[
              Text('Scorecard', style: AppTextStyles.titleLarge(cs.onSurface)),
              const Gap(8),
              if (match.innings1 != null)
                _inningsCard(context, state, match.innings1!, '1st Innings'),
              if (match.innings2 != null)
                _inningsCard(context, state, match.innings2!, '2nd Innings'),
              const Gap(16),
            ],

            // Result
            if (match.status == MatchStatus.completed &&
                match.resultSummary != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: AppColors.success, size: 22),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        match.resultSummary!,
                        style: AppTextStyles.bodyMedium(cs.onSurface)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  String _formatLabel(ScorerMatch match) {
    switch (match.format) {
      case MatchFormat.t20:
        return 'T20 • ${match.overs} overs';
      case MatchFormat.odi:
        return 'ODI • ${match.overs} overs';
      case MatchFormat.test:
        return 'TEST';
      case MatchFormat.custom:
        return '${match.overs}-OVER';
    }
  }

  String _scoreLine(Innings? inn) {
    if (inn == null) return '—';
    return '${inn.totalRuns}/${inn.wickets} (${inn.overs.toStringAsFixed(1)} ov)';
  }

  Widget _heroTeam({
    required String short,
    required String name,
    required String score,
    required bool isBatting,
    required bool isRight,
  }) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isRight) ...[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                alignment: Alignment.center,
                child: Text(
                  short.length > 3
                      ? short.substring(0, 3).toUpperCase()
                      : short.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                isBatting ? '$name ▸' : name,
                style: AppTextStyles.titleMedium(Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRight) ...[
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                alignment: Alignment.center,
                child: Text(
                  short.length > 3
                      ? short.substring(0, 3).toUpperCase()
                      : short.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          score,
          style: AppTextStyles.scoreMedium(
              isBatting ? AppColors.floodlightGold : Colors.white),
        ),
      ],
    );
  }

  Widget _infoCard(BuildContext context, ScorerMatch match,
      SpectatorHomeState state, String? tournamentName) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        children: [
          _infoRow(cs, Icons.emoji_events_rounded,
              'Tournament', tournamentName ?? 'Custom Match'),
          _infoRow(cs, Icons.calendar_today_rounded, 'Scheduled',
              '${match.dateTime.day}/${match.dateTime.month}/${match.dateTime.year}'),
          _infoRow(cs, Icons.access_time_rounded, 'Status',
              match.status.name.toUpperCase()),
          if (match.tossWinnerId != null)
            _infoRow(cs, Icons.adjust_rounded, 'Toss',
                '${state.teamName(match.tossWinnerId!)} won the toss'),
        ],
      ),
    );
  }

  Widget _infoRow(
      ColorScheme cs, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.pitchGreenLight, size: 18),
          const Gap(10),
          Text(label,
              style: AppTextStyles.labelMedium(cs.onSurfaceVariant)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium(cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inningsCard(BuildContext context, SpectatorHomeState state,
      Innings inn, String title) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: AppTextStyles.titleSmall(cs.onSurfaceVariant)),
              const Spacer(),
              Text(
                '${state.teamShort(inn.battingTeamId)} '
                '${inn.totalRuns}/${inn.wickets}',
                style: AppTextStyles.titleMedium(cs.onSurface)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Gap(6),
          Text(
            'Overs: ${inn.overs.toStringAsFixed(1)} • '
            'Balls: ${inn.legalBallsDelivered}',
            style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

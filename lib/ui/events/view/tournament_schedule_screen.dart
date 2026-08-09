// lib/ui/events/view/tournament_schedule_screen.dart
// Spectator "Match Schedule" screen: stage-wise fixtures plus any standalone
// scheduled matches for a tournament. Opened from the Match Schedule button on
// the event detail screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class TournamentScheduleScreen extends ConsumerWidget {
  final String tournamentId;
  const TournamentScheduleScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(spectatorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;
    final tournament = state.tournamentById(tournamentId);

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const MatchListSkeleton(),
      );
    }
    if (tournament == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.translate('tournament_not_found'))),
      );
    }

    final scheduleStages = state.scheduleForTournament(tournamentId)
        .where((s) => s.fixtures.isNotEmpty)
        .toList();
    final linkedMatchIds = <String>{
      for (final s in scheduleStages)
        for (final fx in s.fixtures)
          if (fx.linkedMatchId != null) fx.linkedMatchId!,
    };
    final standalone = state
        .matchesForTournament(tournamentId)
        .where((m) =>
            (m.status == MatchStatus.upcoming ||
                m.status == MatchStatus.scheduled) &&
            !linkedMatchIds.contains(m.id))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final hasContent = scheduleStages.isNotEmpty || standalone.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('match_schedule'),
              style: AppTextStyles.titleMedium(cs.onSurface)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              tournament.name,
              style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
        child: !hasContent
            ? _empty(cs, l10n)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final stage in scheduleStages)
                    _buildStageSection(stage, state, cs, l10n),
                  if (standalone.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        l10n.translate('other_upcoming'),
                        style: AppTextStyles.titleSmall(cs.onSurface)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...standalone.asMap().entries.map((e) => _ScheduleMatchCard(
                          matchNumber: e.key + 1,
                          match: e.value,
                          state: state,
                        )),
                  ],
                  const Gap(32),
                ],
              ),
      ),
    );
  }

  Widget _empty(ColorScheme cs, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 64, color: AppColors.charcoal400),
          const Gap(16),
          Text(
            l10n.translate('no_schedule_yet'),
            style: AppTextStyles.titleMedium(cs.onSurface)
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.translate('organizer_no_schedule'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSection(
      ScheduleStage stage, SpectatorHomeState state, ColorScheme cs, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              stage.type == ScheduleStageType.knockout
                  ? Icons.emoji_events_outlined
                  : stage.type == ScheduleStageType.roundRobin
                      ? Icons.repeat_rounded
                      : Icons.more_horiz,
              color: AppColors.pitchGreen,
              size: 16,
            ),
            const Gap(6),
            Expanded(
              child: Text(
                stage.name,
                style: AppTextStyles.titleSmall(cs.onSurface)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text('${stage.fixtures.length} ${l10n.translate('matches')}',
                style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
          ],
        ),
        const Gap(6),
        for (final fx in stage.fixtures)
          _ScheduleFixtureCard(fixture: fx, state: state, cs: cs),
        const Gap(12),
      ],
    );
  }
}

class _ScheduleFixtureCard extends StatelessWidget {
  final ScheduleFixture fixture;
  final SpectatorHomeState state;
  final ColorScheme cs;

  const _ScheduleFixtureCard({
    required this.fixture,
    required this.state,
    required this.cs,
  });

  String _teamLabel(String? id, AppLocalizations l10n) =>
      id == null ? l10n.translate('awaiting_result') : state.teamName(id);

  String _statusText(AppLocalizations l10n) {
    switch (fixture.status) {
      case FixtureStatus.pending:
        return l10n.translate('awaiting');
      case FixtureStatus.ready:
        return l10n.translate('upcoming');
      case FixtureStatus.live:
        return l10n.translate('live');
      case FixtureStatus.completed:
        return l10n.translate('completed');
    }
  }

  Color _statusColor() {
    switch (fixture.status) {
      case FixtureStatus.ready:
        return AppColors.pitchGreen;
      case FixtureStatus.live:
        return AppColors.liveRed;
      case FixtureStatus.completed:
        return cs.onSurfaceVariant;
      case FixtureStatus.pending:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final local = fixture.scheduledDateTime?.toLocal();
    final linked = fixture.linkedMatchId;
    String? result;
    if (linked != null) {
      for (final m in state.matches) {
        if (m.id == linked && m.status == MatchStatus.completed) {
          result = m.resultSummary;
          break;
        }
      }
    }

    return GestureDetector(
      onTap: linked != null
          ? () => context.push('/spectator/match/$linked')
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: AppColors.pitchGreen.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.floodlightGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${l10n.translate('match_number')} #${fixture.order}',
                    style: AppTextStyles.labelSmall(AppColors.floodlightGold),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _statusText(l10n),
                    style: AppTextStyles.labelSmall(_statusColor()),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_teamLabel(fixture.resolvedTeamAId, l10n)} vs '
                    '${_teamLabel(fixture.resolvedTeamBId, l10n)}',
                    style: AppTextStyles.titleSmall(cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (linked != null) ...[
                  const Gap(6),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey, size: 18),
                ],
              ],
            ),
          if (local != null || fixture.venue != null) ...[
            const Gap(6),
            Row(
              children: [
                if (local != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.grey, size: 13),
                  const Gap(4),
                  Text('${local.day}/${local.month}/${local.year}',
                      style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                  const Gap(12),
                  const Icon(Icons.schedule, color: Colors.grey, size: 13),
                  const Gap(4),
                  Text(
                      '${local.hour.toString().padLeft(2, '0')}:'
                      '${local.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                  const Gap(12),
                ],
                if (fixture.venue != null) ...[
                  const Icon(Icons.location_on, color: Colors.grey, size: 13),
                  const Gap(4),
                  Expanded(
                    child: Text(
                      fixture.venue!,
                      style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (result != null) ...[
            const Gap(6),
            Row(
              children: [
                const Icon(Icons.emoji_events,
                    color: AppColors.floodlightGold, size: 13),
                const Gap(4),
                Expanded(
                  child: Text(
                    result,
                    style: AppTextStyles.labelSmall(AppColors.floodlightGold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _ScheduleMatchCard extends StatelessWidget {
  final int matchNumber;
  final ScorerMatch match;
  final SpectatorHomeState state;

  const _ScheduleMatchCard({
    required this.matchNumber,
    required this.match,
    required this.state,
  });

  String _statusText(AppLocalizations l10n) {
    if (match.status == MatchStatus.upcoming) return l10n.translate('upcoming');
    if (match.status == MatchStatus.scheduled) return l10n.translate('scheduled');
    return match.status.name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final local = match.dateTime.toLocal();
    return GestureDetector(
      onTap: () => context.push('/spectator/match/${match.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradientFor(match.id),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${l10n.translate('match_number')} #$matchNumber',
                    style: AppTextStyles.labelSmall(Colors.white),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _statusText(l10n),
                    style: AppTextStyles.labelSmall(Colors.white),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.teamName(match.team1Id)} vs ${state.teamName(match.team2Id)}',
                    style: AppTextStyles.titleSmall(Colors.white)
                        .copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(6),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white70, size: 18),
              ],
            ),
            const Gap(6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white70, size: 13),
                const Gap(4),
                Text('${local.day}/${local.month}/${local.year}',
                    style: AppTextStyles.labelSmall(Colors.white70)),
                const Gap(12),
                const Icon(Icons.schedule, color: Colors.white70, size: 13),
                const Gap(4),
                Text(
                    '${local.hour.toString().padLeft(2, '0')}:'
                    '${local.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.labelSmall(Colors.white70)),
                const Gap(12),
                const Icon(Icons.location_on, color: Colors.white70, size: 13),
                const Gap(4),
                Expanded(
                  child: Text(match.venue,
                      style: AppTextStyles.labelSmall(Colors.white70),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

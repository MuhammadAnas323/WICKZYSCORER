// lib/ui/scorer/schedule/view/schedule_view_screen.dart
// Schedule View — read-only overview of a tournament's stages & fixtures.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/engines/tournament_progression_engine.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/shared_widgets/fixture_progression_view.dart';

class ScheduleViewScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const ScheduleViewScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<ScheduleViewScreen> createState() => _ScheduleViewScreenState();
}

class _ScheduleViewScreenState extends ConsumerState<ScheduleViewScreen> {
  List<ScheduleStage> _stages = [];
  List<ScorerTeam> _teams = [];
  TournamentProgressionResolver? _progression;
  bool _isLoading = true;
  bool _opening = false;
  final Set<String> _expandedStages = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final stages = await repo.getSchedule(widget.tournamentId);
    final teams = await repo.getTeamsByTournament(widget.tournamentId);
    if (!mounted) return;
    setState(() {
      _stages = stages;
      _teams = teams;
      _progression = TournamentProgressionResolver(stages);
      _isLoading = false;
    });
  }

  String _teamName(String? id) =>
      id == null ? 'TBD' : (_teams.where((t) => t.id == id).firstOrNull?.name ?? id);

  /// Tapping "Start Scoring" on a ready fixture creates/finds its match and
  /// jumps into the scoring workflow (squad setup → toss → live scoring).
  Future<void> _startScoring(ScheduleFixture fx) async {
    if (_opening) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _opening = true);
    try {
      final match = await ref.read(scorerRepositoryProvider).findOrCreateMatchForFixture(
            tournamentId: widget.tournamentId,
            fixture: fx,
          );
      if (!mounted) return;
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('awaiting_result'))),
        );
        return;
      }
      if (match.status == MatchStatus.completed) {
        context.push('/scorer/match-summary?matchId=${match.id}');
      } else if (match.status == MatchStatus.inProgress ||
          match.status == MatchStatus.live) {
        context.push('/scorer/live-scoring');
      } else {
        context.push('/scorer/matches/${match.id}/squad');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: Text(l10n.translate('matches'), style: AppTextStyles.headlineSmall(theme.colorScheme.onSurface)),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await context.push('/scorer/tournaments/${widget.tournamentId}/schedule-builder');
              _load();
            },
            icon: const Icon(Icons.edit_outlined, color: AppColors.pitchGreenLight, size: 18),
            label: Text(l10n.translate('update'), style: const TextStyle(color: AppColors.pitchGreenLight)),
          ),
          const Gap(8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : RefreshIndicator(
              color: AppColors.pitchGreen,
              onRefresh: _load,
              child: _stages.isEmpty ? _empty() : _list(),
            ),
    );
  }

  Widget _empty() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      children: [
        const SizedBox(height: 60),
        Icon(Icons.calendar_month_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38), size: 56),
        const Gap(12),
        Text(
          l10n.translate('no_matches'),
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Gap(4),
        Text(
          l10n.translate('create_match_squads'),
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12),
        ),
        const Gap(20),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.pitchGreen, foregroundColor: Colors.white),
            onPressed: () async {
              await context.push('/scorer/tournaments/${widget.tournamentId}/schedule-builder');
              _load();
            },
            icon: const Icon(Icons.auto_fix_high),
            label: Text(l10n.translate('manual_schedule')),
          ),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var s = 0; s < _stages.length; s++) _stageCard(_stages[s]),
      ],
    );
  }

  Widget _stageCard(ScheduleStage stage) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final expanded = _expandedStages.contains(stage.id);
    final completed = stage.fixtures
        .where((f) => f.status == FixtureStatus.completed)
        .length;
    final upcoming = stage.fixtures
        .where((f) => f.status != FixtureStatus.completed)
        .length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              if (!_expandedStages.add(stage.id)) {
                _expandedStages.remove(stage.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(
                    stage.type == ScheduleStageType.knockout
                        ? Icons.emoji_events_outlined
                        : stage.type == ScheduleStageType.roundRobin
                            ? Icons.repeat_rounded
                            : Icons.more_horiz,
                    color: AppColors.pitchGreenLight,
                    size: 18,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stage.name,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const Gap(2),
                        Text(
                          stage.fixtures.isEmpty
                              ? l10n.translate('no_data')
                              : '$completed ${l10n.translate('completed')}  ·  '
                                  '$upcoming ${l10n.translate('upcoming')}',
                          style: TextStyle(
                              color:
                                  theme.colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.6),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),
          if (expanded)
            stage.fixtures.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        l10n.translate('no_data'),
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.38),
                            fontSize: 12)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: stage.fixtures.map((f) => _fixtureRow(f)).toList(),
                  ),
        ],
      ),
    );
  }

  Widget _fixtureRow(ScheduleFixture fx) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final ready = fx.isReady && fx.resolvedTeamAId != null && fx.resolvedTeamBId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _teamDot(fx.resolvedTeamAId != null),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _teamName(fx.resolvedTeamAId),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Text(l10n.translate('vs'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38), fontSize: 11)),
                  ),
                  Row(
                    children: [
                      _teamDot(fx.resolvedTeamBId != null),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _teamName(fx.resolvedTeamBId),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (fx.venue != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 7, top: 4),
                      child: Row(children: [
                        Icon(Icons.location_on, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38), size: 12),
                        const SizedBox(width: 4),
                        Text(fx.venue!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10)),
                      ]),
                    ),
                  if (_progression != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 7, top: 2),
                      child: FixtureProgressionView(
                        progression: _progression!.resolve(fx),
                        teamName: _teamName,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusChip(fx.status),
                if (ready)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 28,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.pitchGreenLight,
                          backgroundColor: AppColors.pitchGreen.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _startScoring(fx),
                        child: Text(l10n.translate('start_scoring'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamDot(bool resolved) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: resolved ? AppColors.pitchGreenLight : Theme.of(context).dividerColor,
      ),
    );
  }

  Widget _statusChip(FixtureStatus status) {
    final l10n = AppLocalizations.of(context);
    final (labelKey, color) = switch (status) {
      FixtureStatus.pending => ('loading', AppColors.charcoal200),
      FixtureStatus.ready => ('upcoming', AppColors.pitchGreenLight),
      FixtureStatus.live => ('live', AppColors.liveRed),
      FixtureStatus.completed => ('completed', Colors.white54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(l10n.translate(labelKey), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
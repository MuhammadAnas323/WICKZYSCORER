// lib/shared_widgets/tournament_progression_dialog.dart
// Post-completion dialog shown when a tournament match finishes. It surfaces
// the bracket path for BOTH teams using the shared TournamentProgressionResolver
// data (never re-derives progression): the winner's next match/stage, the
// loser's elimination or lower match, waiting-for-opponent when the next slot
// is not ready yet, and Champion for a final.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/engines/tournament_progression_engine.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

import 'package:go_router/go_router.dart';

/// Shows the progression dialog for a just-completed tournament fixture.
Future<void> showTournamentProgressionDialog({
  required BuildContext context,
  required FixtureProgression progression,
  required String Function(String?) teamName,
  String? tournamentId,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => TournamentProgressionDialog(
      progression: progression,
      teamName: teamName,
      tournamentId: tournamentId,
    ),
  );
}

class TournamentProgressionDialog extends StatelessWidget {
  final FixtureProgression progression;
  final String Function(String?) teamName;
  final String? tournamentId;

  const TournamentProgressionDialog({
    super.key,
    required this.progression,
    required this.teamName,
    this.tournamentId,
  });

  bool get _winnerIsChampion => progression.winnerFate.champion;
  bool get _loserIsChampion => progression.loserFate.champion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final winner = progression.winnerTeamId;
    final loser = progression.loserTeamId;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppColors.floodlightGold),
          const Gap(8),
          Expanded(
            child: Text(
              l10n.translate('tournament_progress'),
              style: AppTextStyles.titleMedium(theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              progression.stage.name,
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            const Gap(12),
            if (winner != null) ...[
              _TeamSection(
                header: '${l10n.translate('winner')} 🏆',
                headerColor: AppColors.pitchGreenLight,
                teamName: teamName(winner),
                fate: progression.winnerFate,
                champion: _winnerIsChampion,
                l10n: l10n,
              ),
              const Gap(10),
            ],
            if (loser != null && loser != winner) ...[
              _TeamSection(
                header: progression.loserFate.isEliminated
                    ? '${l10n.translate('eliminated')} ❌'
                    : '${l10n.translate('loser_fate')} ⬇',
                headerColor: progression.loserFate.isEliminated
                    ? Colors.redAccent
                    : _loserIsChampion
                        ? AppColors.floodlightGold
                        : Colors.amber,
                teamName: teamName(loser),
                fate: progression.loserFate,
                champion: _loserIsChampion,
                l10n: l10n,
              ),
            ],
            const Gap(12),
            Text(
              l10n.translate('progression_hint'),
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        if (tournamentId != null && tournamentId!.isNotEmpty) ...[
          TextButton.icon(
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: const Text('Schedule / Stages'),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/scorer/tournaments/$tournamentId/schedule');
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.sports_cricket_rounded, size: 16),
            label: const Text('Upcoming Matches'),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/scorer/matches');
            },
          ),
        ],
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/scorer/dashboard');
          },
          child: Text(l10n.translate('continue'),
              style: const TextStyle(color: AppColors.pitchGreenLight)),
        ),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  final String header;
  final Color headerColor;
  final String teamName;
  final TeamFate fate;
  final bool champion;
  final AppLocalizations l10n;

  const _TeamSection({
    required this.header,
    required this.headerColor,
    required this.teamName,
    required this.fate,
    required this.champion,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header,
              style: TextStyle(
                  color: headerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const Gap(6),
          Text(teamName,
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const Gap(6),
          _PathLine(fate: fate, champion: champion, l10n: l10n),
        ],
      ),
    );
  }
}

class _PathLine extends StatelessWidget {
  final TeamFate fate;
  final bool champion;
  final AppLocalizations l10n;

  const _PathLine({
    required this.fate,
    required this.champion,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (champion) {
      return Row(
        children: [
          const Icon(Icons.emoji_events,
              color: AppColors.floodlightGold, size: 16),
          const SizedBox(width: 6),
          Text('${l10n.translate('champion')} 🏆',
              style: const TextStyle(
                  color: AppColors.floodlightGold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }
    if (fate.qualify) {
      return Row(
        children: [
          const Icon(Icons.verified, color: AppColors.pitchGreenLight, size: 16),
          const SizedBox(width: 6),
          Text(l10n.translate('qualified') == 'qualified' ? 'Qualified' : l10n.translate('qualified'),
              style: const TextStyle(
                  color: AppColors.pitchGreenLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }
    if (fate.waiting) {
      return Row(
        children: [
          const Icon(Icons.hourglass_bottom, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Text(l10n.translate('waiting_for_opponent'),
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      );
    }
    if (fate.action == StageProgressionAction.lowerBracket || fate.nextStage?.name.toLowerCase().contains('lower') == true) {
      final label = fate.nextFixture != null
          ? '${l10n.translate('goes_to') == 'goes_to' ? 'Goes to' : l10n.translate('goes_to')} Lower Bracket (${fate.nextStage?.name ?? 'Lower Match'})'
          : fate.nextStage != null
              ? '${l10n.translate('goes_to') == 'goes_to' ? 'Goes to' : l10n.translate('goes_to')} ${fate.nextStage!.name}'
              : 'Lower Bracket';
      return Row(
        children: [
          const Icon(Icons.alt_route, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          if (fate.nextFixtureWaiting) ...[
            const SizedBox(width: 8),
            const Icon(Icons.hourglass_bottom,
                color: Colors.amber, size: 14),
            Text(l10n.translate('waiting_for_opponent'),
                style: const TextStyle(color: Colors.amber, fontSize: 11)),
          ],
        ],
      );
    }
    if (fate.nextFixture != null) {
      final label =
          '${l10n.translate('advances_to')} ${fate.nextStage?.name ?? l10n.translate('next_match')}';
      return Row(
        children: [
          const Icon(Icons.arrow_forward_rounded,
              color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          if (fate.nextFixtureWaiting) ...[
            const SizedBox(width: 8),
            const Icon(Icons.hourglass_bottom,
                color: Colors.amber, size: 14),
            Text(l10n.translate('waiting_for_opponent'),
                style: const TextStyle(color: Colors.amber, fontSize: 11)),
          ],
        ],
      );
    }
    if (fate.nextStage != null) {
      return Row(
        children: [
          const Icon(Icons.arrow_forward_rounded,
              color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
                '${l10n.translate('advances_to')} ${fate.nextStage!.name}',
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }
    if (fate.isEliminated) {
      return Row(
        children: [
          const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Text(l10n.translate('eliminated'),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }
    return Text(_actionLabel(fate.action, l10n),
        style: const TextStyle(color: Colors.white70, fontSize: 13));
  }
}

String _actionLabel(StageProgressionAction a, AppLocalizations l10n) =>
    switch (a) {
      StageProgressionAction.advance => l10n.translate('advances_to'),
      StageProgressionAction.eliminate => l10n.translate('eliminated'),
      _ => l10n.translate('next_stage'),
    };
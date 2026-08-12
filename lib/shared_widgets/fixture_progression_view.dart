// lib/shared_widgets/fixture_progression_view.dart
// Shared read-only rendering of a fixture's bracket progression: winner
// advancing to the next match/stage, loser eliminated or dropping to a lower
// match, champion of the final, and waiting-for-opponent for unresolved
// fixtures. Progression data comes from TournamentProgressionResolver; this
// widget only renders it.

import 'package:flutter/material.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/engines/tournament_progression_engine.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/theme/app_colors.dart';

class FixtureProgressionView extends StatelessWidget {
  final FixtureProgression progression;
  final String Function(String?) teamName;

  const FixtureProgressionView({
    super.key,
    required this.progression,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    if (progression.fixture.isCompleted) {
      final winner = progression.winnerTeamId;
      final loser = progression.loserTeamId;
      if (winner == null) {
        // A tie (or no-result): neither side advanced. Surface an explicit
        // decision for both teams instead of leaving the fixture blank.
        final teams = [
          progression.fixture.resolvedTeamAId,
          progression.fixture.resolvedTeamBId,
        ].whereType<String>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in teams)
              _FateLine(
                teamName: teamName(t),
                fate: const TeamFate(),
                isWinner: false,
                champion: false,
                tied: true,
              ),
          ],
        );
      }
      final wFate = progression.winnerFate;
      final champion = wFate.champion ||
          (wFate.nextFixture == null &&
              !wFate.isEliminated &&
              wFate.action == StageProgressionAction.advance &&
              progression.stage.config.nextStageId == null);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FateLine(
              teamName: teamName(winner),
              fate: wFate,
              isWinner: true,
              champion: champion,
            ),
          if (loser != null && loser != winner)
            _FateLine(
              teamName: teamName(loser),
              fate: progression.loserFate,
              isWinner: false,
              champion: false,
            ),
        ],
      );
    }
    if (progression.waitingForOpponent) {
      return const _WaitingForOpponentChip();
    }
    return const SizedBox.shrink();
  }
}

class _FateLine extends StatelessWidget {
  final String teamName;
  final TeamFate fate;
  final bool isWinner;
  final bool champion;

  /// A completed fixture whose teams finished level — no winner/loser.
  final bool tied;

  const _FateLine({
    required this.teamName,
    required this.fate,
    required this.isWinner,
    required this.champion,
    this.tied = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = tied
        ? AppColors.floodlightGold
        : isWinner
            ? AppColors.pitchGreenLight
            : Colors.redAccent;
    final String label;
    final Widget? badge;
    if (champion) {
      label = '$teamName · ${l10n.translate('champion')}';
      badge = null;
    } else if (tied) {
      label = '$teamName · ${l10n.translate('match_tied')}';
      badge = null;
    } else if (fate.waiting) {
      label = '$teamName · ${l10n.translate('waiting_for_opponent')}';
      badge = null;
    } else if (fate.nextFixture != null) {
      label = '$teamName → ${fate.nextStage?.name ?? l10n.translate('next_match')}';
      badge = _FateBadge(fate);
    } else if (fate.isEliminated) {
      label = '$teamName · ${l10n.translate('eliminated')}';
      badge = null;
    } else {
      label = '$teamName · ${_actionLabel(fate.action, l10n)}';
      badge = null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            champion
                ? Icons.emoji_events
                : tied
                    ? Icons.handshake
                    : isWinner
                        ? Icons.arrow_forward_rounded
                        : Icons.remove_circle_outline,
            color: color.withValues(alpha: 0.7),
            size: 12,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 4), badge],
        ],
      ),
    );
  }
}

class _FateBadge extends StatelessWidget {
  final TeamFate fate;
  const _FateBadge(this.fate);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (text, color) = fate.nextFixtureReady
        ? (l10n.translate('next_match_ready'), AppColors.pitchGreenLight)
        : (l10n.translate('waiting_for_opponent'), Colors.amber);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _WaitingForOpponentChip extends StatelessWidget {
  const _WaitingForOpponentChip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(l10n.translate('waiting_for_opponent'),
            style: const TextStyle(
                color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

String _actionLabel(StageProgressionAction a, AppLocalizations l10n) =>
    switch (a) {
      StageProgressionAction.advance => l10n.translate('advances_to'),
      StageProgressionAction.eliminate => l10n.translate('eliminated'),
      _ => l10n.translate('next_stage'),
    };

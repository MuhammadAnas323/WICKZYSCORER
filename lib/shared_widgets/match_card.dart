import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/shared_widgets/alert_options_sheet.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/ball_strip.dart';
import 'package:sportyapp/shared_widgets/corner_accent.dart';
import 'package:sportyapp/core/extensions/datetime_extensions.dart';

class MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  final bool compact;

  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final inn = match.currentInnings;
    final cs = Theme.of(context).colorScheme;
    final gradient = AppColors.cardGradientFor(match.id);
    final completed = match.status == MatchStatus.completed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            CornerAccent(gradient: gradient),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(match.seriesName,
                          style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                      ),
                      if (match.isLive) const LiveBadge() else
                      Text(completed ? 'Result' :
                        match.scheduledAt.formattedDatetime,
                        style: AppTextStyles.labelSmall(
                          completed ? AppColors.floodlightGold : cs.onSurfaceVariant)),
                      if (match.status != MatchStatus.completed) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.notifications_none_rounded,
                              size: 18, color: cs.onSurfaceVariant),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => MatchAlertsSheet(matchId: match.id),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TeamScoreColumn(
                          teamName: match.teamA.shortName,
                          teamFlag: match.teamA.flagEmoji,
                          score: match.teamAScore,
                          isBatting: inn?.battingTeam.id == match.teamA.id,
                          onSurface: cs.onSurface,
                          onSurfaceVariant: cs.onSurfaceVariant,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('vs',
                          style: AppTextStyles.labelMedium(cs.onSurfaceVariant)),
                      ),
                      Expanded(
                        child: _TeamScoreColumn(
                          teamName: match.teamB.shortName,
                          teamFlag: match.teamB.flagEmoji,
                          score: match.teamBScore,
                          isBatting: inn?.battingTeam.id == match.teamB.id,
                          isRight: true,
                          onSurface: cs.onSurface,
                          onSurfaceVariant: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppConstants.radiusLG),
                      bottomRight: Radius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _footerLine(context)),
                      if (match.isLive && inn != null && inn.lastSixBalls.isNotEmpty)
                        BallStrip(balls: inn.lastSixBalls),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerLine(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = match.status == MatchStatus.completed;

    if (completed && match.resultSummary != null) {
      return Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 16, color: AppColors.floodlightGold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              match.resultSummary!,
              style: AppTextStyles.bodySmall(AppColors.success)
                  .copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final text = match.isLive && match.requiredRuns != null
        ? '${match.teamB.shortName} need ${match.requiredRuns} off ${match.remainingBalls} balls'
        : match.venue;

    return Text(
      text,
      style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TeamScoreColumn extends StatelessWidget {
  final String teamName;
  final String teamFlag;
  final String score;
  final bool isBatting;
  final bool isRight;
  final Color onSurface;
  final Color onSurfaceVariant;

  const _TeamScoreColumn({
    required this.teamName,
    required this.teamFlag,
    required this.score,
    required this.isBatting,
    required this.onSurface,
    required this.onSurfaceVariant,
    this.isRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isRight) ...[
                Text(teamFlag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  teamName,
                  style: AppTextStyles.titleSmall(onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBatting)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.sports_cricket, size: 12, color: AppColors.floodlightGold),
                ),
              if (isRight) ...[
                const SizedBox(width: 4),
                Flexible(child: Text(teamFlag, style: const TextStyle(fontSize: 20))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (score != '\u2014')
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(score, style: AppTextStyles.scoreMedium(onSurface)),
          ),
      ],
    );
  }
}

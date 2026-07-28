import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/ball_strip.dart';
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

  String _formatLabel(MatchFormat f) {
    switch (f) {
      case MatchFormat.test: return 'TEST';
      case MatchFormat.odi: return 'ODI';
      case MatchFormat.t20: return 'T20';
      case MatchFormat.t10: return 'T10';
      default: return 'CRICKET';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inn = match.currentInnings;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(_formatLabel(match.format),
                      style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(match.seriesName,
                      style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                  ),
                  if (match.isLive) const LiveBadge() else
                  Text(match.status == MatchStatus.completed ? 'Result' :
                    match.scheduledAt.formattedDatetime,
                    style: AppTextStyles.labelSmall(
                      match.status == MatchStatus.completed ?
                        AppColors.success : cs.onSurfaceVariant)),
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
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('vs', style: AppTextStyles.labelMedium(cs.onSurfaceVariant)),
                  ),
                  Expanded(
                    child: _TeamScoreColumn(
                      teamName: match.teamB.shortName,
                      teamFlag: match.teamB.flagEmoji,
                      score: match.teamBScore,
                      isBatting: inn?.battingTeam.id == match.teamB.id,
                      isRight: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppConstants.radiusLG),
                  bottomRight: Radius.circular(AppConstants.radiusLG),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      match.isLive && match.requiredRuns != null
                        ? '${match.teamB.shortName} need ${match.requiredRuns} off ${match.remainingBalls} balls'
                        : match.resultSummary ?? match.venue,
                      style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (match.isLive && inn != null && inn.lastSixBalls.isNotEmpty)
                    BallStrip(balls: inn.lastSixBalls),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamScoreColumn extends StatelessWidget {
  final String teamName;
  final String teamFlag;
  final String score;
  final bool isBatting;
  final bool isRight;

  const _TeamScoreColumn({
    required this.teamName,
    required this.teamFlag,
    required this.score,
    required this.isBatting,
    this.isRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                  style: AppTextStyles.titleSmall(cs.onBackground),
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
            child: Text(score, style: AppTextStyles.scoreMedium(cs.onBackground)),
          ),
      ],
    );
  }
}

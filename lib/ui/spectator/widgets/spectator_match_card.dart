import 'package:flutter/material.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/shared_widgets/alert_options_sheet.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/corner_accent.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

/// International-broadcast style match card for scorer-created matches.
/// Shows team short codes, innings scores, format, venue and live/result status.
///
/// While a match is live, an optional [live] payload (streamed from the
/// Realtime Database) overrides the innings scores so the card always shows the
/// latest ball, never a stale Firestore snapshot.
class SpectatorMatchCard extends StatelessWidget {
  final ScorerMatch match;
  final String Function(String teamId) teamName;
  final String Function(String teamId) teamShort;
  final String Function(String tournamentId) tournamentName;
  final VoidCallback onTap;
  final bool compact;
  final LiveMatchData? live;

  const SpectatorMatchCard({
    super.key,
    required this.match,
    required this.teamName,
    required this.teamShort,
    required this.tournamentName,
    required this.onTap,
    this.compact = false,
    this.live,
  });

  bool get isLive =>
      match.status == MatchStatus.inProgress || match.status == MatchStatus.live;

  String _scoreLine(Innings? inn) {
    if (inn == null) return '—';
    return '${inn.totalRuns}/${inn.wickets} (${inn.overs.toStringAsFixed(1)})';
  }

  /// The innings batted by [teamId]. Innings are stored in batting order, not
  /// team order, so a card must map them by batting team id — mapping innings1
  /// to team1 by position would swap the scores whenever the toss winner chose
  /// to bowl first.
  Innings? _inningsFor(String teamId) {
    for (final inn in [match.innings1, match.innings2]) {
      if (inn != null && inn.battingTeamId == teamId) return inn;
    }
    return null;
  }

  /// The RTDB score line for [teamId] while that team is batting live.
  String? _liveScoreLine(String teamId) {
    final l = live;
    if (l == null || l.battingTeamId != teamId) return null;
    return '${l.score.runs}/${l.score.wickets} (${l.score.overs}.${l.score.balls})';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradient = AppColors.cardGradientFor(match.id);
    final hero1 = isLive && match.battingTeamId == match.team1Id;
    final hero2 = isLive && match.battingTeamId == match.team2Id;
    final liveScore1 = _liveScoreLine(match.team1Id);
    final liveScore2 = _liveScoreLine(match.team2Id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isLive
                ? AppColors.liveRed.withValues(alpha: 0.6)
                : cs.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            CornerAccent(gradient: gradient),
            Column(
              children: [
                // Top bar: format · series · status
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.liveRed.withValues(alpha: 0.10)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tournamentName(match.tournamentId),
                          style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLive)
                        const LiveBadge()
                      else
                        Text(
                          match.status == MatchStatus.completed
                              ? 'RESULT'
                              : '${match.dateTime.month.toString().padLeft(2, '0')}/${match.dateTime.day.toString().padLeft(2, '0')}',
                          style: AppTextStyles.labelSmall(
                            match.status == MatchStatus.completed
                                ? AppColors.floodlightGold
                                : cs.onSurfaceVariant,
                          ),
                        ),
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
                          builder: (_) =>
                              MatchAlertsSheet(matchId: match.id),
                        ),
                      ),
                    ],
                  ),
                ),

                // Teams + scores
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TeamColumn(
                          name: teamName(match.team1Id),
                          short: teamShort(match.team1Id),
                          score: liveScore1 ??
                              _scoreLine(_inningsFor(match.team1Id)),
                          isBatting: hero1,
                          isRight: false,
                          onSurface: cs.onSurface,
                          onSurfaceVariant: cs.onSurfaceVariant,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'vs',
                          style:
                              AppTextStyles.labelMedium(cs.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: _TeamColumn(
                          name: teamName(match.team2Id),
                          short: teamShort(match.team2Id),
                          score: liveScore2 ??
                              _scoreLine(_inningsFor(match.team2Id)),
                          isBatting: hero2,
                          isRight: true,
                          onSurface: cs.onSurface,
                          onSurfaceVariant: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer: venue / result / toss
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                  ),
                  child: _footerLine(context),
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

    if (match.status == MatchStatus.completed) {
      return Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 16, color: AppColors.floodlightGold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              match.resultSummary ?? 'Match completed • ${match.venue}',
              style: AppTextStyles.bodySmall(AppColors.success)
                  .copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final String text;
    if (isLive) {
      final l = live;
      if (l != null && l.battingTeamId.isNotEmpty) {
        text = '${teamShort(l.battingTeamId)} batting • ${match.venue}';
      } else {
        final inn = match.currentInningsData;
        text = inn != null
            ? '${teamShort(inn.battingTeamId)} batting • ${match.venue}'
            : match.venue;
      }
    } else if (match.tossWinnerId != null) {
      text = '${teamShort(match.tossWinnerId!)} won the toss • ${match.venue}';
    } else {
      text = match.venue;
    }

    return Text(
      text,
      style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final String short;
  final String score;
  final bool isBatting;
  final bool isRight;
  final Color onSurface;
  final Color onSurfaceVariant;

  const _TeamColumn({
    required this.name,
    required this.short,
    required this.score,
    required this.isBatting,
    required this.isRight,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isRight
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onSurfaceVariant.withValues(alpha: 0.18),
              ),
              alignment: Alignment.center,
              child: Text(
                short.length > 3
                    ? short.substring(0, 3).toUpperCase()
                    : short.toUpperCase(),
                style: AppTextStyles.labelSmall(onSurface)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isBatting ? '$name ▸' : name,
                style: AppTextStyles.titleSmall(onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          score,
          style: AppTextStyles.scoreSmall(
            isBatting ? AppColors.floodlightGold : onSurface,
          ),
        ),
      ],
    );
  }
}

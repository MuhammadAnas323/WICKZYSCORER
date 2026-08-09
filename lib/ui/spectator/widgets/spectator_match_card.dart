import 'package:flutter/material.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/shared_widgets/alert_options_sheet.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
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

  String get _formatLabel {
    switch (match.format) {
      case MatchFormat.t20:
        return 'T20';
      case MatchFormat.odi:
        return 'ODI';
      case MatchFormat.test:
        return 'TEST';
      case MatchFormat.custom:
        return '${match.overs}-OVER';
    }
  }

  String _scoreLine(Innings? inn) {
    if (inn == null) return '—';
    return '${inn.totalRuns}/${inn.wickets} (${inn.overs.toStringAsFixed(1)})';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: isLive ? AppColors.liveRed.withOpacity(0.4) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top bar: format · series · status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.liveRed.withOpacity(0.12)
                    : cs.surfaceVariant.withOpacity(0.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _formatLabel,
                      style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                            ? AppColors.success
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
                      builder: (_) => MatchAlertsSheet(matchId: match.id),
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
                      score: liveScore1 ?? _scoreLine(match.innings1),
                      isBatting: hero1,
                      isRight: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'vs',
                      style: AppTextStyles.labelMedium(cs.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: _TeamColumn(
                      name: teamName(match.team2Id),
                      short: teamShort(match.team2Id),
                      score: liveScore2 ?? _scoreLine(match.innings2),
                      isBatting: hero2,
                      isRight: true,
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
                color: cs.surfaceVariant.withOpacity(0.5),
              ),
              child: Text(
                _footerText(),
                style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _footerText() {
    if (isLive) {
      final l = live;
      if (l != null && l.battingTeamId.isNotEmpty) {
        return '${teamShort(l.battingTeamId)} batting • ${match.venue}';
      }
      final inn = match.currentInningsData;
      if (inn != null) {
        return '${teamShort(inn.battingTeamId)} batting • ${match.venue}';
      }
      return match.venue;
    }
    if (match.status == MatchStatus.completed) {
      return match.resultSummary ?? 'Match completed • ${match.venue}';
    }
    if (match.tossWinnerId != null) {
      return '${teamShort(match.tossWinnerId!)} won the toss • ${match.venue}';
    }
    return match.venue;
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final String short;
  final String score;
  final bool isBatting;
  final bool isRight;

  const _TeamColumn({
    required this.name,
    required this.short,
    required this.score,
    required this.isBatting,
    required this.isRight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.pitchGreen, AppColors.pitchGreenDark],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                short.length > 3 ? short.substring(0, 3).toUpperCase() : short.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isBatting ? '$name ▸' : name,
                style: AppTextStyles.titleSmall(cs.onBackground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          score,
          style: AppTextStyles.scoreSmall(
            isBatting ? AppColors.pitchGreenLight : cs.onSurface,
          ),
        ),
      ],
    );
  }
}

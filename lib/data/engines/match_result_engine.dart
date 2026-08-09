// lib/data/engines/match_result_engine.dart
// Single source of truth for computing the result of a scored match from the
// final innings data. Every screen (scorer summary, spectator detail, cards,
// history, notifications) must derive results through this engine so winner,
// loser, margin and text are always consistent and never guessed from a UI
// selection or a hardcoded summary string.

import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/models/scorer/match_result.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';

class MatchResultEngine {
  const MatchResultEngine._();

  /// Total wickets available to a batting side for the given match.
  /// Standard formats carry 10 wickets; the playing XI (when known) is the
  /// authoritative count (players - 1); a super over carries 2.
  static int totalWicketsFor(ScorerMatch match, String battingTeamId) {
    if (match.isSuperOverInnings) return 2;
    final xi = battingTeamId == match.team1Id ? match.playingXI1 : match.playingXI2;
    if (xi.isNotEmpty) return xi.length - 1;
    return 10;
  }

  /// Computes the authoritative result from the finished match state.
  ///
  /// Order of precedence:
  ///  1. Abandoned / no-result states (no winner).
  ///  2. A played super over decides the match independently.
  ///  3. Tied main innings (no winner unless a super over was played).
  ///  4. Chasing team reaches the target  -> win by wickets.
  ///  5. Otherwise                        -> win by runs.
  static MatchResult compute({
    required ScorerMatch match,
    required String team1Name,
    required String team2Name,
    required AppLocalizations l10n,
  }) {
    final t1Name = team1Name;
    final t2Name = team2Name;
    String? teamNameOf(String? teamId) {
      if (teamId == null) return null;
      return teamId == match.team1Id ? t1Name : t2Name;
    }

    String? loserIdOf(String? winnerId) {
      if (winnerId == null) return null;
      return winnerId == match.team1Id ? match.team2Id : match.team1Id;
    }

    // 1. Abandoned / no-result. The match carries no winner and no margin.
    if (match.status == MatchStatus.abandoned) {
      final text = '$t1Name vs $t2Name — ${l10n.translate('match_no_result')}';
      return MatchResult(
        winnerTeamId: null,
        loserTeamId: null,
        type: MatchResultType.abandoned,
        resultText: text,
        losingText: text,
        isNoResult: true,
      );
    }

    final so1 = match.superOverInnings1;
    final so2 = match.superOverInnings2;

    // 2. Super over decides the match on its own innings.
    if (match.superOverPlayed && so1 != null && so2 != null) {
      final soTarget = so1.totalRuns + 1;
      final soChased = so2.totalRuns >= soTarget;
      if (so2.totalRuns == so1.totalRuns) {
        final text = '$t1Name vs $t2Name — ${l10n.translate('match_tied')}';
        return MatchResult(
          winnerTeamId: null,
          loserTeamId: null,
          type: MatchResultType.tie,
          resultText: text,
          losingText: text,
          isTie: true,
          isSuperOver: true,
        );
      }
      final winnerId = soChased ? so2.battingTeamId : so1.battingTeamId;
      final loserId = loserIdOf(winnerId);
      final winnerName = teamNameOf(winnerId) ?? '';
      final loserName = teamNameOf(loserId) ?? '';
      final margin = soChased
          ? 2 - so2.wickets
          : (soTarget - 1) - so2.totalRuns;
      final unit = soChased ? l10n.translate('wickets') : l10n.translate('runs');
      final suffix = ' (${l10n.translate('super_over_banner')})';
      return MatchResult(
        winnerTeamId: winnerId,
        loserTeamId: loserId,
        type: MatchResultType.superOver,
        margin: margin,
        resultText:
            '$winnerName ${l10n.translate('won_by')} $margin $unit$suffix',
        losingText:
            '$loserName ${l10n.translate('lost_by')} $margin $unit$suffix',
        isSuperOver: true,
      );
    }

    // 3. Tie on the main innings.
    if (match.isTie) {
      final text = '$t1Name vs $t2Name — ${l10n.translate('match_tied')}';
      return MatchResult(
        winnerTeamId: null,
        loserTeamId: null,
        type: MatchResultType.tie,
        resultText: text,
        losingText: text,
        isTie: true,
      );
    }

    final inn1 = match.innings1;
    final inn2 = match.innings2;

    // Incomplete / not scored enough to decide.
    if (inn1 == null || inn2 == null || !inn1.isComplete || !inn2.isComplete) {
      final text = '$t1Name vs $t2Name — ${l10n.translate('match_no_result')}';
      return MatchResult(
        winnerTeamId: null,
        loserTeamId: null,
        type: MatchResultType.noResult,
        resultText: text,
        losingText: text,
        isNoResult: true,
      );
    }

    final target = inn1.totalRuns + 1;
    final chasingWon = inn2.totalRuns >= target;

    // 4. Chasing team reached the target -> win by wickets.
    if (chasingWon) {
      final winnerId = inn2.battingTeamId;
      final loserId = loserIdOf(winnerId);
      final winnerName = teamNameOf(winnerId) ?? '';
      final loserName = teamNameOf(loserId) ?? '';
      final totalWickets = totalWicketsFor(match, winnerId);
      final margin = totalWickets - inn2.wickets;
      final unit = l10n.translate('wickets');
      return MatchResult(
        winnerTeamId: winnerId,
        loserTeamId: loserId,
        type: MatchResultType.byWickets,
        margin: margin,
        resultText:
            '$winnerName ${l10n.translate('won_by')} $margin $unit',
        losingText: '$loserName ${l10n.translate('lost_by')} $margin $unit',
      );
    }

    // 5. Chasing team fell short -> win by runs.
    final winnerId = inn1.battingTeamId;
    final loserId = loserIdOf(winnerId);
    final winnerName = teamNameOf(winnerId) ?? '';
    final loserName = teamNameOf(loserId) ?? '';
    final margin = inn1.totalRuns - inn2.totalRuns;
    final unit = l10n.translate('runs');
    return MatchResult(
      winnerTeamId: winnerId,
      loserTeamId: loserId,
      type: MatchResultType.byRuns,
      margin: margin,
      resultText: '$winnerName ${l10n.translate('won_by')} $margin $unit',
      losingText: '$loserName ${l10n.translate('lost_by')} $margin $unit',
    );
  }

  /// Single string summary for legacy display sites that only render one line.
  static String summaryOf(MatchResult result) => result.resultText;
}

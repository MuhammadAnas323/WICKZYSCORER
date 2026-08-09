// lib/data/models/scorer/match_result.dart
// Structured match result produced by MatchResultEngine and persisted on
// ScorerMatch so every consumer (scorer summary, spectator screens, cards,
// history, notifications) reads the same winner/loser/margin data.

enum MatchResultType {
  byRuns,
  byWickets,
  byInnings,
  tie,
  superOver,
  noResult,
  abandoned,
}

class MatchResult {
  final String? winnerTeamId;
  final String? loserTeamId;
  final MatchResultType type;

  /// Runs margin (win by runs) or wickets margin (win by wickets).
  /// Null for ties / no-results.
  final int? margin;

  /// Winner-oriented text, e.g. "Team A won by 18 runs".
  final String resultText;

  /// Loser-oriented text, e.g. "Team B lost by 18 runs".
  final String? losingText;

  final bool isTie;
  final bool isNoResult;
  final bool isSuperOver;
  final bool isDls;

  const MatchResult({
    this.winnerTeamId,
    this.loserTeamId,
    required this.type,
    this.margin,
    required this.resultText,
    this.losingText,
    this.isTie = false,
    this.isNoResult = false,
    this.isSuperOver = false,
    this.isDls = false,
  });

  MatchResult copyWith({
    String? winnerTeamId,
    String? loserTeamId,
    MatchResultType? type,
    int? margin,
    String? resultText,
    String? losingText,
    bool? isTie,
    bool? isNoResult,
    bool? isSuperOver,
    bool? isDls,
  }) {
    return MatchResult(
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
      loserTeamId: loserTeamId ?? this.loserTeamId,
      type: type ?? this.type,
      margin: margin ?? this.margin,
      resultText: resultText ?? this.resultText,
      losingText: losingText ?? this.losingText,
      isTie: isTie ?? this.isTie,
      isNoResult: isNoResult ?? this.isNoResult,
      isSuperOver: isSuperOver ?? this.isSuperOver,
      isDls: isDls ?? this.isDls,
    );
  }
}

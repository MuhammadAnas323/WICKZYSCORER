// lib/data/models/match_model.dart
// Match, innings, ball event, and partnership models.

import 'team_model.dart';

/// Match format.
enum MatchFormat { test, odi, t20, t10, hundredBall, other }

/// Match status.
enum MatchStatus { live, upcoming, completed, abandoned }

/// Result type.
enum ResultType { teamWon, draw, tie, noResult }

/// Represents a single ball event in the innings.
class BallEvent {
  final int over;
  final int ball;
  final String event; // '0','1','2','3','4','6','W','WD','NB'
  final String commentary;
  final String batsmanId;
  final String bowlerId;
  final bool isBoundary;
  final bool isSix;
  final bool isWicket;

  const BallEvent({
    required this.over,
    required this.ball,
    required this.event,
    required this.commentary,
    required this.batsmanId,
    required this.bowlerId,
    this.isBoundary = false,
    this.isSix = false,
    this.isWicket = false,
  });
}

/// Batting scorecard entry per batsman.
class BatterScore {
  final PlayerModel batsman;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;
  final String dismissal; // "c Rizwan b Shaheen" or "not out" or "dnb"
  final bool isOnCrease;

  const BatterScore({
    required this.batsman,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    required this.dismissal,
    this.isOnCrease = false,
  });
}

/// Bowling scorecard entry per bowler.
class BowlerScore {
  final PlayerModel bowler;
  final double overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economy;
  final int wides;
  final int noBalls;

  const BowlerScore({
    required this.bowler,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.economy,
    this.wides = 0,
    this.noBalls = 0,
  });
}

/// A batting partnership between two batsmen.
class Partnership {
  final PlayerModel batsman1;
  final PlayerModel batsman2;
  final int runs;
  final int balls;

  const Partnership({
    required this.batsman1,
    required this.batsman2,
    required this.runs,
    required this.balls,
  });
}

/// Fall of wicket entry.
class FallOfWicket {
  final int wicketNumber;
  final String batsmanName;
  final int runs;
  final String over; // e.g. "12.3"

  const FallOfWicket({
    required this.wicketNumber,
    required this.batsmanName,
    required this.runs,
    required this.over,
  });
}

/// Full innings data.
class InningsModel {
  final int inningsNumber; // 1 or 2
  final TeamModel battingTeam;
  final TeamModel bowlingTeam;
  final int runs;
  final int wickets;
  final double overs;
  final double runRate;
  final List<BatterScore> batters;
  final List<BowlerScore> bowlers;
  final List<BallEvent> ballEvents;
  final List<FallOfWicket> fallOfWickets;
  final List<Partnership> partnerships;
  final List<String> lastSixBalls; // Last 6 deliveries e.g. ['4','1','W','0','6','1']
  final bool isCompleted;

  const InningsModel({
    required this.inningsNumber,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.runRate,
    required this.batters,
    required this.bowlers,
    required this.ballEvents,
    required this.fallOfWickets,
    required this.partnerships,
    required this.lastSixBalls,
    this.isCompleted = false,
  });
}

/// The main match model.
class MatchModel {
  final String id;
  final String title; // e.g. "Pakistan vs India, 3rd T20I"
  final String seriesName;
  final String seriesId;
  final MatchFormat format;
  final MatchStatus status;
  final TeamModel teamA;
  final TeamModel teamB;
  final DateTime scheduledAt;
  final String venue;
  final String city;
  final String umpires;
  final int? totalOvers; // null for Test
  final List<InningsModel> innings;
  final ResultType? result;
  final String? resultSummary; // "Pakistan won by 34 runs"
  final String? tossWinner;
  final String? tossDecision; // "bat" | "bowl"
  final String? manOfMatch;
  final bool isLive;
  final String thumbnailUrl;
  final double? requiredRunRate; // if 2nd innings chasing
  final int? requiredRuns; // runs needed to win
  final int? remainingBalls;

  const MatchModel({
    required this.id,
    required this.title,
    required this.seriesName,
    required this.seriesId,
    required this.format,
    required this.status,
    required this.teamA,
    required this.teamB,
    required this.scheduledAt,
    required this.venue,
    required this.city,
    required this.umpires,
    this.totalOvers,
    required this.innings,
    this.result,
    this.resultSummary,
    this.tossWinner,
    this.tossDecision,
    this.manOfMatch,
    this.isLive = false,
    required this.thumbnailUrl,
    this.requiredRunRate,
    this.requiredRuns,
    this.remainingBalls,
  });

  /// Shorthand for current batting innings (last in list when live).
  InningsModel? get currentInnings =>
      innings.isNotEmpty ? innings.last : null;

  /// Team A score string e.g. "245/8 (48.2)"
  String get teamAScore {
    final i = innings.where((e) => e.battingTeam.id == teamA.id).toList();
    if (i.isEmpty) return '—';
    return '${i.last.runs}/${i.last.wickets} (${i.last.overs.toStringAsFixed(1)})';
  }

  /// Team B score string.
  String get teamBScore {
    final i = innings.where((e) => e.battingTeam.id == teamB.id).toList();
    if (i.isEmpty) return '—';
    return '${i.last.runs}/${i.last.wickets} (${i.last.overs.toStringAsFixed(1)})';
  }
}

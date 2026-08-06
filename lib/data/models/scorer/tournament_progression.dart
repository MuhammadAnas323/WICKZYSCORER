// lib/data/models/scorer/tournament_progression.dart
// Tournament Progression Engine data models

import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';

/// Indicates the current progression status of a team in the tournament
enum TeamProgressionStatus {
  active,       // Still playing
  eliminated,   // Knocked out
  champion,     // Won the tournament
  runnerUp,     // Lost in the finals
  thirdPlace,   // Won third place match
  withdrawn,    // Team pulled out
  disqualified  // Team was removed
}

/// A standard result outcome for match dependency engine
class MatchResultOutcome {
  final String matchId;
  final String winnerTeamId;
  final String loserTeamId;
  final bool wasTie;
  final bool wasAbandoned;
  final bool wasWalkover;

  const MatchResultOutcome({
    required this.matchId,
    required this.winnerTeamId,
    required this.loserTeamId,
    this.wasTie = false,
    this.wasAbandoned = false,
    this.wasWalkover = false,
  });
}

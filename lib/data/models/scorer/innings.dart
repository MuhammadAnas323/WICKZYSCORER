import 'package:sportyapp/data/models/scorer/ball_event.dart';

class Innings {
  final String id;
  final String battingTeamId;
  final String bowlingTeamId;
  final int inningsNumber;
  final List<BallEvent> balls;
  final List<String> battingOrder;
  final List<String> bowlingOrder;
  final bool isComplete;
  final String? strikerId;
  final String? nonStrikerId;
  final String? currentBowlerId;

  const Innings({
    required this.id,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.inningsNumber,
    required this.balls,
    required this.battingOrder,
    required this.bowlingOrder,
    required this.isComplete,
    this.strikerId,
    this.nonStrikerId,
    this.currentBowlerId,
  });

  int get totalRuns => balls.fold(0, (sum, ball) => sum + ball.totalRuns);
  
  int get wickets => balls.where((ball) => ball.isWicket).length;
  
  int get legalBallsDelivered => balls.where((ball) => ball.isLegalBall).length;

  double get overs {
    int legalBalls = legalBallsDelivered;
    int completedOvers = legalBalls ~/ 6;
    int remainingBalls = legalBalls % 6;
    return completedOvers + (remainingBalls / 10);
  }

  int get currentOverLegalBalls => legalBallsDelivered % 6;

  List<BallEvent> get currentOverBalls {
    if (balls.isEmpty) return [];
    int currentOver = balls.last.overNumber;
    return balls.where((ball) => ball.overNumber == currentOver).toList();
  }

  Innings copyWith({
    String? id,
    String? battingTeamId,
    String? bowlingTeamId,
    int? inningsNumber,
    List<BallEvent>? balls,
    List<String>? battingOrder,
    List<String>? bowlingOrder,
    bool? isComplete,
    String? strikerId,
    String? nonStrikerId,
    String? currentBowlerId,
  }) {
    return Innings(
      id: id ?? this.id,
      battingTeamId: battingTeamId ?? this.battingTeamId,
      bowlingTeamId: bowlingTeamId ?? this.bowlingTeamId,
      inningsNumber: inningsNumber ?? this.inningsNumber,
      balls: balls ?? this.balls,
      battingOrder: battingOrder ?? this.battingOrder,
      bowlingOrder: bowlingOrder ?? this.bowlingOrder,
      isComplete: isComplete ?? this.isComplete,
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      currentBowlerId: currentBowlerId ?? this.currentBowlerId,
    );
  }
}

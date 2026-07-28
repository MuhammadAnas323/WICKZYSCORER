// lib/core/utils/cricket_utils.dart
// Cricket-specific helper functions.

/// Returns run rate formatted to 2 decimal places, e.g. "6.34"
String formatRunRate(double rr) => rr.toStringAsFixed(2);

/// Formats overs like "12.4" (12 complete overs + 4 balls)
String formatOvers(int balls) {
  final overs = balls ~/ 6;
  final rem = balls % 6;
  return '$overs.$rem';
}

/// Returns over label e.g. "Ov 12.1"
String overLabel(int balls) => 'Ov ${formatOvers(balls)}';

/// Returns strike rate from runs and balls
double strikeRate(int runs, int balls) {
  if (balls == 0) return 0;
  return (runs / balls) * 100;
}

/// Returns economy from runs and balls bowled
double economy(int runs, int balls) {
  if (balls == 0) return 0;
  return (runs / balls) * 6;
}

/// Abbreviates over count. 20.0 → "20"
String shortOvers(double overs) {
  if (overs == overs.truncateToDouble()) return overs.toInt().toString();
  return overs.toStringAsFixed(1);
}

/// Ball type label for commentary styling
enum BallType { dot, single, two, three, four, six, wicket, wide, noBall }

BallType classifyBall(String event) {
  switch (event.toUpperCase()) {
    case 'W':
      return BallType.wicket;
    case '4':
      return BallType.four;
    case '6':
      return BallType.six;
    case 'WD':
      return BallType.wide;
    case 'NB':
      return BallType.noBall;
    case '0':
      return BallType.dot;
    case '1':
      return BallType.single;
    case '2':
      return BallType.two;
    case '3':
      return BallType.three;
    default:
      return BallType.dot;
  }
}

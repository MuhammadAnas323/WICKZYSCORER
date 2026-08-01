import 'package:sportyapp/data/models/scorer/dismissal.dart';

enum ExtrasType { none, wide, noBall, bye, legBye }

class BallEvent {
  final int overNumber;
  final int ballInOver;
  final String batsmanId;
  final String bowlerId;
  final int runs;
  final ExtrasType extrasType;
  final int extrasRuns;
  final bool isWicket;
  final Dismissal? dismissal;
  final bool isBoundary;
  final bool isSix;
  final DateTime timestamp;

  const BallEvent({
    required this.overNumber,
    required this.ballInOver,
    required this.batsmanId,
    required this.bowlerId,
    required this.runs,
    this.extrasType = ExtrasType.none,
    this.extrasRuns = 0,
    required this.isWicket,
    this.dismissal,
    required this.isBoundary,
    required this.isSix,
    required this.timestamp,
  });

  int get totalRuns => runs + extrasRuns;
  bool get isLegalBall => extrasType == ExtrasType.none || extrasType == ExtrasType.bye || extrasType == ExtrasType.legBye;
  
  String get displayLabel {
    if (isWicket) {
      return 'W';
    }
    switch (extrasType) {
      case ExtrasType.wide:
        return '${extrasRuns}Wd';
      case ExtrasType.noBall:
        return '${extrasRuns}Nb';
      case ExtrasType.bye:
        return '${extrasRuns}b';
      case ExtrasType.legBye:
        return '${extrasRuns}lb';
      case ExtrasType.none:
      default:
        return runs.toString();
    }
  }
}

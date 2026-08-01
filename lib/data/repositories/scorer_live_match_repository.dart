import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class ScorerLiveMatchRepository {
  final Ref _ref;
  ScorerMatch? _activeMatch;
  final _controller = StreamController<ScorerMatch?>.broadcast();

  ScorerLiveMatchRepository(this._ref);

  Stream<ScorerMatch?> get stream => _controller.stream;
  ScorerMatch? get activeMatch => _activeMatch;

  void setActiveMatch(ScorerMatch? match) {
    _activeMatch = match;
    _controller.add(match);
    if (match != null) {
      _ref.read(scorerRepositoryProvider).saveMatch(match);
    }
  }

  void recordBall(BallEvent event) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final updatedBalls = List<BallEvent>.from(inn.balls)..add(event);
    
    // Auto-swap strike if odd runs (1, 3, 5) were scored off the bat
    String? newStriker = inn.strikerId;
    String? newNonStriker = inn.nonStrikerId;

    if (event.runs % 2 != 0) {
      final temp = newStriker;
      newStriker = newNonStriker;
      newNonStriker = temp;
    }

    // Check if striker was dismissed (and not run out non-striker)
    if (event.isWicket && event.dismissal != null) {
      if (event.dismissal!.batsmanId == newStriker) {
        newStriker = null;
      } else if (event.dismissal!.batsmanId == newNonStriker) {
        newNonStriker = null;
      }
    }

    // Check if over completed (6 legal balls in over)
    final newLegalCount = updatedBalls.where((b) => b.isLegalBall).length;
    final isOverComplete = newLegalCount > 0 && newLegalCount % 6 == 0 && event.isLegalBall;

    if (isOverComplete) {
      // Over finished -> swap strike automatically
      final temp = newStriker;
      newStriker = newNonStriker;
      newNonStriker = temp;
    }

    final updatedInnings = inn.copyWith(
      balls: updatedBalls,
      strikerId: newStriker,
      nonStrikerId: newNonStriker,
    );

    final updatedMatch = match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
    );

    setActiveMatch(updatedMatch);
  }

  void undoLastBall() {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null || inn.balls.isEmpty) return;

    final updatedBalls = List<BallEvent>.from(inn.balls)..removeLast();

    final updatedInnings = inn.copyWith(balls: updatedBalls);
    final updatedMatch = match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
    );

    setActiveMatch(updatedMatch);
  }

  void swapStrike() {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final updatedInnings = inn.copyWith(
      strikerId: inn.nonStrikerId,
      nonStrikerId: inn.strikerId,
    );

    final updatedMatch = match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
    );

    setActiveMatch(updatedMatch);
  }

  void setBowler(String bowlerId) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final updatedBowlingOrder = List<String>.from(inn.bowlingOrder);
    if (!updatedBowlingOrder.contains(bowlerId)) {
      updatedBowlingOrder.add(bowlerId);
    }

    final updatedInnings = inn.copyWith(
      currentBowlerId: bowlerId,
      bowlingOrder: updatedBowlingOrder,
    );

    final updatedMatch = match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
    );

    setActiveMatch(updatedMatch);
  }

  void setNextBatsman(String batsmanId) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final updatedBattingOrder = List<String>.from(inn.battingOrder);
    if (!updatedBattingOrder.contains(batsmanId)) {
      updatedBattingOrder.add(batsmanId);
    }

    final updatedInnings = inn.copyWith(
      strikerId: inn.strikerId ?? batsmanId,
      nonStrikerId: inn.strikerId == null ? inn.nonStrikerId : (inn.nonStrikerId ?? batsmanId),
      battingOrder: updatedBattingOrder,
    );

    final updatedMatch = match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
    );

    setActiveMatch(updatedMatch);
  }

  void switchInnings({
    required String newBattingTeamId,
    required String newBowlingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  }) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;

    final secondInnings = Innings(
      id: 'inn_2',
      battingTeamId: newBattingTeamId,
      bowlingTeamId: newBowlingTeamId,
      inningsNumber: 2,
      balls: const [],
      battingOrder: [strikerId, nonStrikerId],
      bowlingOrder: [bowlerId],
      isComplete: false,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
    );

    final updatedMatch = match.copyWith(
      currentInnings: 2,
      innings2: secondInnings,
      status: MatchStatus.inProgress,
    );

    setActiveMatch(updatedMatch);
  }

  /// Marks the current innings as complete and saves it as a draft.
  /// Does NOT auto-advance to the next innings — the scorer taps a
  /// "Start 2nd Innings" button when ready.
  void completeCurrentInnings() {
    if (_activeMatch == null) return;
    final match = _activeMatch!;
    final inn = match.currentInningsData;
    if (inn == null || inn.isComplete) return;

    final updatedInnings = inn.copyWith(isComplete: true);
    final updatedMatch = match.copyWith(
      innings1: match.currentInnings == 1 ? updatedInnings : match.innings1,
      innings2: match.currentInnings == 2 ? updatedInnings : match.innings2,
    );

    setActiveMatch(updatedMatch);
  }

  /// Restores an in-progress draft match (e.g. after the app was closed
  /// mid-scoring) as the active live match, if none is active.
  Future<void> restoreActiveDraft() async {
    if (_activeMatch != null) return;
    final match = await _ref
        .read(scorerRepositoryProvider)
        .firstInProgressMatch();
    if (match != null) {
      setActiveMatch(match);
    }
  }

  void endMatch({required String winnerTeamId, required String summary}) {
    if (_activeMatch == null) return;
    final match = _activeMatch!;

    final updatedMatch = match.copyWith(
      status: MatchStatus.completed,
      winnerTeamId: winnerTeamId,
      resultSummary: summary,
    );

    setActiveMatch(updatedMatch);
  }

  void dispose() => _controller.close();
}

final scorerLiveMatchRepositoryProvider = Provider<ScorerLiveMatchRepository>((ref) {
  final repo = ScorerLiveMatchRepository(ref);
  ref.onDispose(repo.dispose);
  return repo;
});

/// StreamProvider so widgets can reactively read the live match scored by Scorer
final scorerLiveMatchStreamProvider = StreamProvider<ScorerMatch?>((ref) {
  return ref.watch(scorerLiveMatchRepositoryProvider).stream;
});

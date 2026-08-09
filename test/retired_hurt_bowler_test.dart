// test/retired_hurt_bowler_test.dart
// Guards the retired-hurt bowler flow: marking a bowler retired hurt must
// remove them from the current slot, persist across serialization, and be
// fully restored by Undo.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_serializers.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

ScorerMatch _baseMatch({Innings? inn1, int currentInnings = 1}) {
  return ScorerMatch(
    id: 'm1',
    tournamentId: 't1',
    team1Id: 'team1',
    team2Id: 'team2',
    venue: 'Ground',
    dateTime: DateTime(2026, 1, 1),
    format: MatchFormat.t20,
    overs: 20,
    status: MatchStatus.inProgress,
    playingXI1: const ['p1', 'p2', 'p3'],
    playingXI2: const ['p4', 'p5', 'p6'],
    innings1: inn1,
    currentInnings: currentInnings,
  );
}

Innings _innings() {
  return const Innings(
    id: 'inn_1',
    battingTeamId: 'team1',
    bowlingTeamId: 'team2',
    inningsNumber: 1,
    balls: [],
    battingOrder: ['p1', 'p2'],
    bowlingOrder: ['p4'],
    isComplete: false,
    strikerId: 'p1',
    nonStrikerId: 'p2',
    currentBowlerId: 'p4',
  );
}

BallEvent _ball({int runs = 0}) {
  return BallEvent(
    overNumber: 1,
    ballInOver: 1,
    batsmanId: 'p1',
    bowlerId: 'p4',
    runs: runs,
    extrasType: ExtrasType.none,
    extrasRuns: 0,
    isWicket: false,
    dismissal: null,
    isBoundary: false,
    isSix: false,
    timestamp: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late ScorerLiveMatchRepository liveRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        scorerRepositoryProvider.overrideWithValue(ScorerRepository(null)),
      ],
    );
    liveRepo = container.read(scorerLiveMatchRepositoryProvider);
  });

  tearDown(() {
    container.dispose();
  });

  test('retireBowlerHurt marks the bowler and clears the current slot', () {
    liveRepo.setActiveMatch(_baseMatch(inn1: _innings()));

    liveRepo.retireBowlerHurt('p4');

    final inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.retiredHurtBowlerIds, ['p4']);
    expect(inn.currentBowlerId, isNull);
  });

  test('retireBowlerHurt is idempotent for the same bowler', () {
    liveRepo.setActiveMatch(_baseMatch(inn1: _innings()));

    liveRepo.retireBowlerHurt('p4');
    liveRepo.retireBowlerHurt('p4');

    final inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.retiredHurtBowlerIds, ['p4']);
  });

  test('retired-hurt list round-trips through serialization', () {
    final inn = _innings().copyWith(
      retiredHurtBowlerIds: const ['p4'],
      currentBowlerId: null,
    );

    final restored = inningsFromJson(inningsToJson(inn));

    expect(restored.retiredHurtBowlerIds, ['p4']);
    expect(restored.currentBowlerId, isNull);
    expect(restored.bowlingOrder, ['p4']);
  });

  test('undo restores the retired-hurt list captured before the ball', () {
    liveRepo.setActiveMatch(_baseMatch(inn1: _innings()));

    // Current bowler retires hurt, then a replacement is selected and bowls.
    liveRepo.retireBowlerHurt('p4');
    liveRepo.setBowler('p5');
    liveRepo.recordBall(_ball(runs: 1));

    var inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.currentBowlerId, 'p5');
    expect(inn.retiredHurtBowlerIds, ['p4']);
    expect(inn.balls, hasLength(1));

    liveRepo.undoLastBall();
    inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.balls, isEmpty);
    expect(inn.retiredHurtBowlerIds, ['p4']);
    expect(inn.currentBowlerId, 'p5');
  });
}

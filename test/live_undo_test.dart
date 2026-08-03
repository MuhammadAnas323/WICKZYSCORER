// test/live_undo_test.dart
// Guards the live scoring undo fix: undoLastBall must fully restore the
// pre-ball state (striker/non-striker/bowler and batting order), not just
// drop the last ball event.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/dismissal.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
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

BallEvent _ball({
  required int runs,
  bool isWicket = false,
  Dismissal? dismissal,
  ExtrasType extras = ExtrasType.none,
  int extrasRuns = 0,
}) {
  return BallEvent(
    overNumber: 1,
    ballInOver: 1,
    batsmanId: 'p1',
    bowlerId: 'p4',
    runs: runs,
    extrasType: extras,
    extrasRuns: extrasRuns,
    isWicket: isWicket,
    dismissal: dismissal,
    isBoundary: runs == 4,
    isSix: runs == 6,
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
      overrides: [scorerRepositoryProvider.overrideWithValue(ScorerRepository(null))],
    );
    liveRepo = container.read(scorerLiveMatchRepositoryProvider);
  });

  tearDown(() {
    container.dispose();
  });

  test('undo restores strike after an odd run (strike swap)', () {
    liveRepo.setActiveMatch(_baseMatch(inn1: _innings()));

    // 1 run -> odd -> auto strike swap p1<->p2.
    liveRepo.recordBall(_ball(runs: 1));
    var inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.strikerId, 'p2');
    expect(inn.nonStrikerId, 'p1');

    liveRepo.undoLastBall();
    inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.balls, isEmpty);
    expect(inn.strikerId, 'p1');
    expect(inn.nonStrikerId, 'p2');
    expect(inn.totalRuns, 0);
  });

  test('undo restores the dismissed batsman and pops the batting order', () {
    final inn = _innings();
    liveRepo.setActiveMatch(_baseMatch(inn1: inn));

    // Wicket on p1, then a new batsman p3 joins.
    liveRepo.recordBall(_ball(
      runs: 0,
      isWicket: true,
      dismissal: Dismissal(
        type: DismissalType.caught,
        batsmanId: 'p1',
        bowlerId: 'p4',
        fielderId: 'p5',
      ),
    ));
    liveRepo.setNextBatsman('p3');

    var match = liveRepo.activeMatch!;
    expect(match.currentInningsData!.strikerId, 'p3');
    expect(match.currentInningsData!.battingOrder, ['p1', 'p2', 'p3']);
    expect(match.currentInningsData!.wickets, 1);

    liveRepo.undoLastBall();
    match = liveRepo.activeMatch!;
    expect(match.currentInningsData!.balls, isEmpty);
    expect(match.currentInningsData!.strikerId, 'p1');
    expect(match.currentInningsData!.battingOrder, ['p1', 'p2']);
    expect(match.currentInningsData!.wickets, 0);
  });

  test('undo removes a wide and keeps the over from counting it as legal', () {
    liveRepo.setActiveMatch(_baseMatch(inn1: _innings()));

    liveRepo.recordBall(_ball(runs: 0, extras: ExtrasType.wide, extrasRuns: 1));
    var inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.totalRuns, 1);
    expect(inn.legalBallsDelivered, 0);

    liveRepo.undoLastBall();
    inn = liveRepo.activeMatch!.currentInningsData!;
    expect(inn.balls, isEmpty);
    expect(inn.totalRuns, 0);
    expect(inn.legalBallsDelivered, 0);
  });

  test('setOvers increases and never drops below overs already bowled', () {
    liveRepo.setActiveMatch(_baseMatch(inn1: _innings()));

    liveRepo.setOvers(25);
    expect(liveRepo.activeMatch!.overs, 25);

    // Bowl 5 legal balls in over 1 -> min overs becomes 1.
    for (var i = 0; i < 5; i++) {
      liveRepo.recordBall(_ball(runs: 0));
    }
    liveRepo.setOvers(0);
    expect(liveRepo.activeMatch!.overs, 1);

    liveRepo.setOvers(10);
    expect(liveRepo.activeMatch!.overs, 10);
  });

  test('replacePlayer swaps the XI and in-innings references', () {
    liveRepo.setActiveMatch(_baseMatch(inn1: _innings()));

    liveRepo.replacePlayer(teamId: 'team1', playerOutId: 'p1', playerInId: 'p7');

    final match = liveRepo.activeMatch!;
    expect(match.playingXI1, ['p7', 'p2', 'p3']);
    final inn = match.currentInningsData!;
    expect(inn.strikerId, 'p7');
    expect(inn.battingOrder, ['p7', 'p2']);
    expect(inn.currentBowlerId, 'p4');
  });
}

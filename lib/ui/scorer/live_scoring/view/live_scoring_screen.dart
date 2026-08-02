import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/dismissal.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';

class LiveScoringScreen extends ConsumerStatefulWidget {
  const LiveScoringScreen({super.key});

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _ballAnimCtrl;
  late Animation<double> _ballAnim;

  bool _showExtras = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _ballAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _ballAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ballAnimCtrl, curve: Curves.elasticOut),
    );
    // Restore an in-progress draft match (e.g. after app was closed mid-scoring).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scorerLiveMatchRepositoryProvider).restoreActiveDraft();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ballAnimCtrl.dispose();
    super.dispose();
  }

  Future<List<ScorerPlayer>> _getPlayers(ScorerMatch match) async {
    final repo = ref.read(scorerRepositoryProvider);
    final [p1, p2] = await Future.wait([
      repo.getPlayersByTeam(match.team1Id),
      repo.getPlayersByTeam(match.team2Id),
    ]);
    return [...p1, ...p2];
  }

  void _recordBall({
    int runs = 0,
    bool isWicket = false,
    bool isBoundary = false,
    bool isSix = false,
    ExtrasType extras = ExtrasType.none,
    int extrasRuns = 0,
    Dismissal? dismissal,
  }) {
    final liveRepo = ref.read(scorerLiveMatchRepositoryProvider);
    final match = liveRepo.activeMatch;
    if (match == null) return;
    final inn = match.currentInningsData;
    if (inn == null) return;

    final legalCount = inn.legalBallsDelivered;
    final overNum = (legalCount ~/ 6) + 1;
    final ballInOver = (legalCount % 6) + 1;

    final event = BallEvent(
      overNumber: overNum,
      ballInOver: ballInOver,
      batsmanId: inn.strikerId ?? '',
      bowlerId: inn.currentBowlerId ?? '',
      runs: runs,
      extrasType: extras,
      extrasRuns: extrasRuns,
      isWicket: isWicket,
      dismissal: dismissal,
      isBoundary: isBoundary,
      isSix: isSix,
      timestamp: DateTime.now(),
    );

    liveRepo.recordBall(event);
    _ballAnimCtrl.forward(from: 0.0);

    // Check innings completion
    final updatedMatch = liveRepo.activeMatch;
    if (updatedMatch != null) {
      final updatedInn = updatedMatch.currentInningsData;
      if (updatedInn != null) {
        final isAllOut = updatedInn.wickets >= 10;
        final isOversComplete = updatedInn.legalBallsDelivered >= (updatedMatch.overs * 6);

        if ((isAllOut || isOversComplete) && updatedMatch.currentInnings == 1) {
          // Save the completed innings as a draft and let the scorer start
          // the 2nd innings manually.
          liveRepo.completeCurrentInnings();
        } else if ((isAllOut || isOversComplete) && updatedMatch.currentInnings == 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showMatchSummaryDialog(updatedMatch));
        }
      }
    }

    setState(() {
      _showExtras = false;
    });
  }

  void _showInningsBreakDialog(ScorerMatch match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InningsBreakDialog(
        match: match,
        onContinue: (strikerId, nonStrikerId, bowlerId) {
          Navigator.pop(ctx);
          ref.read(scorerLiveMatchRepositoryProvider).switchInnings(
            newBattingTeamId: match.team2Id == match.innings1?.battingTeamId ? match.team1Id : match.team2Id,
            newBowlingTeamId: match.innings1?.battingTeamId ?? match.team1Id,
            strikerId: strikerId,
            nonStrikerId: nonStrikerId,
            bowlerId: bowlerId,
          );
        },
      ),
    );
  }

  void _showMatchSummaryDialog(ScorerMatch match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MatchSummaryDialog(
        match: match,
        onClose: () {
          Navigator.pop(ctx);
          // Persist as completed and clear the active draft.
          final liveRepo = ref.read(scorerLiveMatchRepositoryProvider);
          final inn1 = match.innings1;
          final inn2 = match.innings2;
          final target = (inn1?.totalRuns ?? 0) + 1;
          final inn2Runs = inn2?.totalRuns ?? 0;
          final inn2Wickets = inn2?.wickets ?? 0;
          final winnerId = inn2Runs >= target ? match.team2Id : match.team1Id;
          final margin = inn2Runs >= target
              ? '${10 - inn2Wickets} wickets'
              : '${(target - 1) - inn2Runs} runs';
          liveRepo.endMatch(winnerTeamId: winnerId, summary: '$winnerId won by $margin');
          liveRepo.setActiveMatch(null);
          // Auto-advance the tournament schedule (if one exists for this match).
          final loserId = winnerId == match.team2Id ? match.team1Id : match.team2Id;
          ref.read(scorerRepositoryProvider).applyScheduleResult(
            tournamentId: match.tournamentId,
            winnerTeamId: winnerId,
            loserTeamId: loserId,
            matchTeam1Id: match.team1Id,
            matchTeam2Id: match.team2Id,
          );
          context.go('/scorer/dashboard');
        },
      ),
    );
  }

  void _showWicketModal(BuildContext context, ScorerMatch match, List<ScorerPlayer> allPlayers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WicketModal(
        match: match,
        allPlayers: allPlayers,
        onWicket: (dismissal) {
          Navigator.pop(ctx);
          _recordBall(isWicket: true, dismissal: dismissal);
          // Show new batsman picker
          _showNewBatsmanPicker(match, allPlayers);
        },
      ),
    );
  }

  void _showNewBatsmanPicker(ScorerMatch match, List<ScorerPlayer> allPlayers) {
    final inn = match.currentInningsData;
    if (inn == null) return;
    final battingTeamPlayers = allPlayers.where((p) => p.teamId == inn.battingTeamId).toList();
    final alreadyIn = inn.battingOrder.toSet();
    final available = battingTeamPlayers.where((p) => !alreadyIn.contains(p.id)).toList();

    if (available.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏏 New Batsman', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(12),
            ...available.map((p) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                child: Text('${p.jerseyNumber ?? '?'}', style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold)),
              ),
              title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(p.battingStyle.name, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              onTap: () {
                ref.read(scorerLiveMatchRepositoryProvider).setNextBatsman(p.id);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showBowlerPicker(ScorerMatch match, List<ScorerPlayer> allPlayers) {
    final inn = match.currentInningsData;
    if (inn == null) return;
    final bowlingTeamPlayers = allPlayers.where((p) => p.teamId == inn.bowlingTeamId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎳 Select Bowler', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(12),
            ...bowlingTeamPlayers.map((p) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                child: Text('${p.jerseyNumber ?? '?'}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(p.bowlingStyle.name, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              trailing: inn.currentBowlerId == p.id
                  ? const Icon(Icons.check_circle, color: AppColors.pitchGreenLight)
                  : null,
              onTap: () {
                ref.read(scorerLiveMatchRepositoryProvider).setBowler(p.id);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveRepo = ref.watch(scorerLiveMatchRepositoryProvider);
    final match = liveRepo.activeMatch;

    if (match == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_score_outlined, color: Colors.grey, size: 72),
              const Gap(16),
              const Text('No active match', style: TextStyle(color: Colors.grey, fontSize: 18)),
              const Gap(16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.pitchGreen, foregroundColor: Colors.white),
                onPressed: () => context.go('/scorer/dashboard'),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<ScorerPlayer>>(
      future: _getPlayers(match),
      builder: (context, snapshot) {
        final allPlayers = snapshot.data ?? [];
        return _buildScoringUI(match, allPlayers);
      },
    );
  }

  Widget _buildScoringUI(ScorerMatch match, List<ScorerPlayer> allPlayers) {
    final inn = match.currentInningsData;
    final totalRuns = inn?.totalRuns ?? 0;
    final wickets = inn?.wickets ?? 0;
    final overs = inn?.overs ?? 0.0;
    final currentOverBalls = inn?.currentOverBalls ?? [];
    final strikerId = inn?.strikerId;
    final nonStrikerId = inn?.nonStrikerId;
    final bowlerId = inn?.currentBowlerId;

    ScorerPlayer? findPlayer(String? id) => id == null ? null : allPlayers.where((p) => p.id == id).firstOrNull;
    final striker = findPlayer(strikerId);
    final nonStriker = findPlayer(nonStrikerId);
    final bowler = findPlayer(bowlerId);

    // Target for 2nd innings
    final target = match.currentInnings == 2 ? (match.innings1?.totalRuns ?? 0) + 1 : null;
    final runsNeeded = target != null ? target - totalRuns : null;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/scorer/dashboard'),
        ),
        title: Row(
          children: [
            FadeTransition(
              opacity: _pulseCtrl,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.liveRed,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    Gap(4),
                    Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const Gap(8),
            Text('${match.team1Id} vs ${match.team2Id}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _showMatchSummaryDialog(match),
            child: const Text('End Match', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Scoreboard ───────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.pitchGreen.withOpacity(0.3), AppColors.darkSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                // Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalRuns/$wickets',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 48, letterSpacing: -1),
                    ),
                    const Gap(12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '(${overs.toStringAsFixed(1)})',
                        style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (target != null)
                  Text(
                    'Target: $target | Need $runsNeeded runs',
                    style: const TextStyle(color: AppColors.floodlightGold, fontWeight: FontWeight.bold),
                  ),
                const Gap(8),
                // Current over balls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...currentOverBalls.map((b) => _ballDot(b)),
                    ...List.generate(
                      (6 - currentOverBalls.where((b) => b.isLegalBall).length).clamp(0, 6),
                      (i) => _emptyDot(),
                    ),
                  ],
                ),
                const Gap(12),
                // Batsmen & Bowler info
                Row(
                  children: [
                    _batInfoChip(striker, true),
                    const Gap(8),
                    _batInfoChip(nonStriker, false),
                    const Spacer(),
                    _bowlerInfoChip(bowler, inn),
                  ],
                ),
              ],
            ),
          ),

          // ── Run Pad ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  // ── 2nd Innings ready banner ─────────────────────────────
                  if (match.currentInnings == 1 && match.innings1?.isComplete == true) ...[
                    _secondInningsBanner(match),
                    const Gap(12),
                  ],
                  // Main run pad
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.4,
                    children: [
                      _runButton(0, AppColors.darkSurface, Colors.white70),
                      _runButton(1, AppColors.darkSurface, Colors.white),
                      _runButton(2, AppColors.darkSurface, Colors.white),
                      _runButton(3, AppColors.darkSurface, Colors.white),
                      _runButton(4, const Color(0xFF1A3A1A), AppColors.pitchGreenLight,
                          label: '4 ◈', isBoundary: true),
                      _runButton(5, AppColors.darkSurface, Colors.white),
                      _runButton(6, const Color(0xFF3A1A1A), Colors.redAccent,
                          label: '6 ★', isSix: true, isBoundary: true),
                      _runButton(7, AppColors.darkSurface, Colors.white),
                    ],
                  ),
                  const Gap(12),

                  // Extras & Wicket row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showExtras = !_showExtras),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _showExtras ? Colors.orange.withOpacity(0.2) : AppColors.darkSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _showExtras ? Colors.orange : Colors.white24),
                            ),
                            child: const Column(
                              children: [
                                Text('Extras', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Wd/Nb/B/Lb', style: TextStyle(color: Colors.orange, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final liveRepo = ref.read(scorerLiveMatchRepositoryProvider);
                            final m = liveRepo.activeMatch;
                            if (m != null) _showWicketModal(context, m, allPlayers);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.liveRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.liveRed.withOpacity(0.6)),
                            ),
                            child: const Column(
                              children: [
                                Text('WICKET', style: TextStyle(color: AppColors.liveRed, fontWeight: FontWeight.w900, fontSize: 14)),
                                Text('W', style: TextStyle(color: AppColors.liveRed, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Extras sub-picker
                  if (_showExtras) ...[
                    const Gap(10),
                    _extrasPicker(),
                  ],

                  const Gap(12),
                  // Controls row
                  Row(
                    children: [
                      Expanded(
                        child: _controlButton(
                          label: '↩ Undo',
                          icon: Icons.undo_rounded,
                          color: Colors.orange,
                          onTap: () {
                            ref.read(scorerLiveMatchRepositoryProvider).undoLastBall();
                          },
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: _controlButton(
                          label: '⇄ Swap Strike',
                          icon: Icons.swap_horiz_rounded,
                          color: Colors.blueAccent,
                          onTap: () {
                            ref.read(scorerLiveMatchRepositoryProvider).swapStrike();
                          },
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: _controlButton(
                          label: '🎳 Bowler',
                          icon: Icons.sports_cricket_outlined,
                          color: Colors.purpleAccent,
                          onTap: () {
                            final m = ref.read(scorerLiveMatchRepositoryProvider).activeMatch;
                            if (m != null) _showBowlerPicker(m, allPlayers);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ballDot(BallEvent ball) {
    Color bg;
    Color text;
    if (ball.isWicket) {
      bg = AppColors.liveRed;
      text = Colors.white;
    } else if (ball.isSix) {
      bg = Colors.redAccent;
      text = Colors.white;
    } else if (ball.isBoundary) {
      bg = AppColors.pitchGreen;
      text = Colors.white;
    } else {
      bg = Colors.white24;
      text = Colors.white;
    }

    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      alignment: Alignment.center,
      child: Text(ball.displayLabel, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyDot() {
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
    );
  }

  Widget _batInfoChip(ScorerPlayer? player, bool isStriker) {
    if (player == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isStriker)
              const Text('* ', style: TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold)),
            Text(
              player.name.split(' ').first,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        Text(isStriker ? 'Striker' : 'Non-Striker', style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _bowlerInfoChip(ScorerPlayer? player, Innings? inn) {
    if (player == null) return const SizedBox();
    final playerBalls = inn?.balls.where((b) => b.bowlerId == player.id).length ?? 0;
    final playerWickets = inn?.balls.where((b) => b.bowlerId == player.id && b.isWicket).length ?? 0;
    final playerRuns = inn?.balls.where((b) => b.bowlerId == player.id).fold(0, (s, b) => s + b.totalRuns) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(player.name.split(' ').first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text('$playerRuns runs • $playerWickets-W • ${(playerBalls ~/ 6)}.${playerBalls % 6} ov',
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _secondInningsBanner(ScorerMatch match) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.floodlightGold.withOpacity(0.2), AppColors.darkSurface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.floodlightGold.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.floodlightGold, size: 28),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1st Innings complete',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Innings saved. Start the 2nd innings when ready.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
              ],
            ),
          ),
          const Gap(8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.floodlightGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showInningsBreakDialog(match),
            child: const Text('Start 2nd Innings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _runButton(int runs, Color bg, Color textColor, {String? label, bool isBoundary = false, bool isSix = false}) {
    return ScaleTransition(
      scale: _ballAnim,
      child: GestureDetector(
        onTap: () => _recordBall(runs: runs, isBoundary: isBoundary, isSix: isSix),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isBoundary ? Colors.greenAccent.withOpacity(0.5) : Colors.white12),
            boxShadow: isSix
                ? [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 12)]
                : isBoundary
                    ? [BoxShadow(color: AppColors.pitchGreen.withOpacity(0.3), blurRadius: 12)]
                    : null,
          ),
          child: Center(
            child: Text(
              label ?? '$runs',
              style: TextStyle(
                color: textColor,
                fontSize: isBoundary ? 18 : 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _extrasPicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Extra Type', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          const Gap(8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ExtrasType.values.where((e) => e != ExtrasType.none).map((extType) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Text(extType.name.toUpperCase(), style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                      const Gap(4),
                      Row(
                        children: [1, 2, 4].map((r) => GestureDetector(
                          onTap: () => _recordBall(extras: extType, extrasRuns: r, runs: r),
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            alignment: Alignment.center,
                            child: Text('$r+', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const Gap(3),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Wicket Modal ──────────────────────────────────────────────────────────────

class _WicketModal extends ConsumerStatefulWidget {
  final ScorerMatch match;
  final List<ScorerPlayer> allPlayers;
  final ValueChanged<Dismissal> onWicket;

  const _WicketModal({required this.match, required this.allPlayers, required this.onWicket});

  @override
  ConsumerState<_WicketModal> createState() => _WicketModalState();
}

class _WicketModalState extends ConsumerState<_WicketModal> {
  DismissalType _type = DismissalType.caught;
  String? _fielderId;

  @override
  Widget build(BuildContext context) {
    final inn = widget.match.currentInningsData;
    if (inn == null) return const SizedBox();

    final fieldingTeam = widget.allPlayers.where((p) => p.teamId == inn.bowlingTeamId).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🚨 Wicket!', style: TextStyle(color: AppColors.liveRed, fontSize: 22, fontWeight: FontWeight.w900)),
          const Gap(16),
          const Text('Dismissal Type', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DismissalType.values.map((t) {
              final isSelected = _type == t;
              return ChoiceChip(
                label: Text(t.name),
                selected: isSelected,
                selectedColor: AppColors.liveRed,
                backgroundColor: Colors.white10,
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          if (_type == DismissalType.caught || _type == DismissalType.runOut || _type == DismissalType.stumped) ...[
            const Gap(16),
            const Text('Fielder (optional)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const Gap(8),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: fieldingTeam.map((p) {
                  final isSelected = _fielderId == p.id;
                  return GestureDetector(
                    onTap: () => setState(() => _fielderId = isSelected ? null : p.id),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            radius: 22,
                            child: Text('${p.jerseyNumber ?? '?'}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          ),
                          const Gap(4),
                          Text(p.name.split(' ').first, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const Gap(20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.liveRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final dismissal = Dismissal(
                  type: _type,
                  batsmanId: inn?.strikerId ?? '',
                  bowlerId: inn?.currentBowlerId ?? '',
                  fielderId: _fielderId,
                );
                widget.onWicket(dismissal);
              },
              child: const Text('Confirm Wicket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Innings Break Dialog ───────────────────────────────────────────────────────

class _InningsBreakDialog extends ConsumerStatefulWidget {
  final ScorerMatch match;
  final void Function(String strikerId, String nonStrikerId, String bowlerId) onContinue;

  const _InningsBreakDialog({required this.match, required this.onContinue});

  @override
  ConsumerState<_InningsBreakDialog> createState() => _InningsBreakDialogState();
}

class _InningsBreakDialogState extends ConsumerState<_InningsBreakDialog> {
  List<ScorerPlayer> _battingPlayers = [];
  List<ScorerPlayer> _bowlingPlayers = [];
  String? _strikerId;
  String? _nonStrikerId;
  String? _bowlerId;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final repo = ref.read(scorerRepositoryProvider);
    // Second innings batting team = first innings bowling team
    final inn1 = widget.match.innings1;
    if (inn1 == null) return;
    final batting = await repo.getPlayersByTeam(inn1.bowlingTeamId);
    final bowling = await repo.getPlayersByTeam(inn1.battingTeamId);
    setState(() {
      _battingPlayers = batting;
      _bowlingPlayers = bowling;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inn1 = widget.match.innings1;
    final score = inn1 != null ? '${inn1.totalRuns}/${inn1.wickets}' : '';
    final target = (inn1?.totalRuns ?? 0) + 1;

    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('⏸️ Innings Break', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1st Innings: $score', style: const TextStyle(color: Colors.white70)),
            Text('Target: $target runs', style: const TextStyle(color: AppColors.floodlightGold, fontWeight: FontWeight.bold, fontSize: 18)),
            const Gap(20),
            const Text('Select Opening Batsmen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Gap(8),
            ..._battingPlayers.take(6).map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                child: Text('${p.jerseyNumber ?? '?'}', style: const TextStyle(color: AppColors.pitchGreenLight, fontSize: 12)),
              ),
              title: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniPill('Strike', _strikerId == p.id, Colors.blueAccent, () => setState(() => _strikerId = p.id)),
                  const Gap(6),
                  _miniPill('Non-S', _nonStrikerId == p.id, AppColors.pitchGreenLight, () => setState(() => _nonStrikerId = p.id)),
                ],
              ),
            )),
            const Gap(16),
            const Text('Opening Bowler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Gap(8),
            ..._bowlingPlayers.where((p) => p.bowlingStyle != BowlingStyle.none).take(5).map((p) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: p.id,
              groupValue: _bowlerId,
              title: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
              activeColor: Colors.redAccent,
              onChanged: (val) => setState(() => _bowlerId = val),
            )),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pitchGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (_strikerId == null || _nonStrikerId == null || _bowlerId == null) return;
            widget.onContinue(_strikerId!, _nonStrikerId!, _bowlerId!);
          },
          child: const Text('Start 2nd Innings', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _miniPill(String label, bool isActive, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isActive ? color : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── Match Summary Dialog ───────────────────────────────────────────────────────

class _MatchSummaryDialog extends StatelessWidget {
  final ScorerMatch match;
  final VoidCallback onClose;

  const _MatchSummaryDialog({required this.match, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final inn1 = match.innings1;
    final inn2 = match.innings2;
    final target = (inn1?.totalRuns ?? 0) + 1;
    final inn2Runs = inn2?.totalRuns ?? 0;
    final inn2Wickets = inn2?.wickets ?? 0;

    String result;
    if (inn2Runs >= target) {
      final wicketsLeft = 10 - inn2Wickets;
      result = '${match.team2Id} won by $wicketsLeft wickets!';
    } else {
      final margin = target - 1 - inn2Runs;
      result = '${match.team1Id} won by $margin runs!';
    }

    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Center(child: Text('🏆 Match Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pitchGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.pitchGreenLight.withOpacity(0.5)),
            ),
            child: Text(result, style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          ),
          const Gap(20),
          if (inn1 != null) _scoreRow('1st Innings', inn1.battingTeamId, '${inn1.totalRuns}/${inn1.wickets}', '(${inn1.overs.toStringAsFixed(1)} ov)'),
          const Gap(8),
          if (inn2 != null) _scoreRow('2nd Innings', inn2.battingTeamId, '${inn2.totalRuns}/${inn2.wickets}', '(${inn2.overs.toStringAsFixed(1)} ov)'),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.floodlightGold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onClose,
          child: const Text('Finish Match', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _scoreRow(String label, String teamId, String score, String overs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(teamId.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(score, style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.w900, fontSize: 20)),
          Text(overs, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ],
    );
  }
}

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
import 'package:sportyapp/core/localization/app_localizations.dart';

class LiveScoringScreen extends ConsumerStatefulWidget {
  const LiveScoringScreen({super.key});

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  bool _showExtras = false;
  ExtrasType? _selectedExtrasType;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    // Restore an in-progress draft match (e.g. after app was closed mid-scoring).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scorerLiveMatchRepositoryProvider).restoreActiveDraft();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<_MatchData> _loadMatchData(ScorerMatch match) async {
    final repo = ref.read(scorerRepositoryProvider);
    final [p1, p2] = await Future.wait([
      repo.getPlayersByTeam(match.team1Id),
      repo.getPlayersByTeam(match.team2Id),
    ]);
    final [t1, t2] = await Future.wait([
      repo.getTeam(match.team1Id),
      repo.getTeam(match.team2Id),
    ]);
    return _MatchData(
      players: [...p1, ...p2],
      team1Name: t1?.name ?? match.team1Id,
      team2Name: t2?.name ?? match.team2Id,
    );
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

    // Check innings completion
    final updatedMatch = liveRepo.activeMatch;
    if (updatedMatch != null) {
      final updatedInn = updatedMatch.currentInningsData;
      if (updatedInn != null) {
        final isAllOut = updatedInn.wickets >= 10;
        final isOversComplete =
            updatedInn.legalBallsDelivered >= (updatedMatch.overs * 6);

        if ((isAllOut || isOversComplete) && updatedMatch.currentInnings == 1) {
          // Save the completed innings as a draft and let the scorer start
          // the 2nd innings manually.
          liveRepo.completeCurrentInnings();
        } else if ((isAllOut || isOversComplete) &&
            updatedMatch.currentInnings == 2) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _showMatchSummaryDialog(updatedMatch));
        }
      }
    }

    setState(() {
      _showExtras = false;
      _selectedExtrasType = null;
    });
  }

  void _recordExtras(ExtrasType type, int total) {
    _recordBall(
      runs: 0,
      extras: type,
      extrasRuns: total,
      isBoundary:
          (type == ExtrasType.bye || type == ExtrasType.legBye) && total == 4,
    );
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
                newBattingTeamId: match.team2Id == match.innings1?.battingTeamId
                    ? match.team1Id
                    : match.team2Id,
                newBowlingTeamId:
                    match.innings1?.battingTeamId ?? match.team1Id,
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
          liveRepo.endMatch(
              winnerTeamId: winnerId, summary: '$winnerId won by $margin');
          liveRepo.setActiveMatch(null);
          // Auto-advance the tournament schedule (if one exists for this match).
          final loserId =
              winnerId == match.team2Id ? match.team1Id : match.team2Id;
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

  void _showWicketModal(
      BuildContext context, ScorerMatch match, List<ScorerPlayer> allPlayers) {
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final inn = match.currentInningsData;
    if (inn == null) return;
    final battingTeamPlayers =
        allPlayers.where((p) => p.teamId == inn.battingTeamId).toList();
    final alreadyIn = inn.battingOrder.toSet();
    final available =
        battingTeamPlayers.where((p) => !alreadyIn.contains(p.id)).toList();

    if (available.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏏 ${l10n.translate('batsman')}',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const Gap(12),
            ...available.map((p) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                    child: Text('${p.jerseyNumber ?? '?'}',
                        style: const TextStyle(
                            color: AppColors.pitchGreenLight,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p.name,
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(p.battingStyle.name,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  onTap: () {
                    ref
                        .read(scorerLiveMatchRepositoryProvider)
                        .setNextBatsman(p.id);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showBowlerPicker(ScorerMatch match, List<ScorerPlayer> allPlayers) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final inn = match.currentInningsData;
    if (inn == null) return;
    final bowlingTeamPlayers =
        allPlayers.where((p) => p.teamId == inn.bowlingTeamId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎳 ${l10n.translate('bowler')}',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const Gap(12),
            ...bowlingTeamPlayers.map((p) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent.withOpacity(0.15),
                    child: Text('${p.jerseyNumber ?? '?'}',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p.name,
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(p.bowlingStyle.name,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  trailing: inn.currentBowlerId == p.id
                      ? const Icon(Icons.check_circle,
                          color: AppColors.pitchGreenLight)
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final liveRepo = ref.watch(scorerLiveMatchRepositoryProvider);
    // Watch the stream so any repo mutation (record ball, undo, swap strike,
    // bowler change) rebuilds this screen instead of only incidental setState.
    final match =
        ref.watch(scorerLiveMatchStreamProvider).value ?? liveRepo.activeMatch;

    if (match == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_score_outlined,
                  color: Colors.grey, size: 72),
              const Gap(16),
              Text(l10n.translate('match_not_found'),
                  style: const TextStyle(color: Colors.grey, fontSize: 18)),
              const Gap(16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pitchGreen,
                    foregroundColor: Colors.white),
                onPressed: () => context.go('/scorer/dashboard'),
                child: Text(l10n.translate('back')),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<_MatchData>(
      future: _loadMatchData(match),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return _buildScoringUI(
          match,
          data?.players ?? [],
          team1Name: data?.team1Name ?? match.team1Id,
          team2Name: data?.team2Name ?? match.team2Id,
        );
      },
    );
  }

  Widget _buildScoringUI(
    ScorerMatch match,
    List<ScorerPlayer> allPlayers, {
    required String team1Name,
    required String team2Name,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final inn = match.currentInningsData;
    final totalRuns = inn?.totalRuns ?? 0;
    final wickets = inn?.wickets ?? 0;
    final overs = inn?.overs ?? 0.0;
    final currentOverBalls = inn?.currentOverBalls ?? [];
    final strikerId = inn?.strikerId;
    final nonStrikerId = inn?.nonStrikerId;
    final bowlerId = inn?.currentBowlerId;

    ScorerPlayer? findPlayer(String? id) =>
        id == null ? null : allPlayers.where((p) => p.id == id).firstOrNull;
    final striker = findPlayer(strikerId);
    final nonStriker = findPlayer(nonStrikerId);
    final bowler = findPlayer(bowlerId);

    // Target for 2nd innings
    final target =
        match.currentInnings == 2 ? (match.innings1?.totalRuns ?? 0) + 1 : null;
    final runsNeeded = target != null ? target - totalRuns : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Colors.white, size: 8),
                    const Gap(4),
                    Text(l10n.translate('live'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const Gap(8),
            Flexible(
              child: Text(
                '$team1Name vs $team2Name',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    color: colorScheme.onBackground.withOpacity(0.7),
                    fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _showMatchSummaryDialog(match),
            child: Text(l10n.translate('end_match'),
                style: const TextStyle(color: Colors.redAccent)),
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
                colors: [
                  AppColors.pitchGreen.withOpacity(0.3),
                  colorScheme.surface
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                // Score
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$totalRuns/$wickets',
                        style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 48,
                            letterSpacing: -1),
                      ),
                      const Gap(12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '(${overs.toStringAsFixed(1)})',
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                if (target != null)
                  Text(
                    '${l10n.translate('target')}: $target | ${l10n.translate('runs_needed')} $runsNeeded',
                    style: const TextStyle(
                        color: AppColors.floodlightGold,
                        fontWeight: FontWeight.bold),
                  ),
                const Gap(8),
                // Current over balls — flex-wrap layout so an over with any
                // number of wides/no-balls (extra deliveries) plus the 6 legal
                // balls flows onto extra rows instead of overflowing the
                // scoreboard on narrow (320–375px) screens.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...currentOverBalls.map((b) => _ballDot(b)),
                    ...List.generate(
                      (6 - currentOverBalls.where((b) => b.isLegalBall).length)
                          .clamp(0, 6),
                      (_) => _emptyDot(),
                    ),
                  ],
                ),
                const Gap(6),
                // Ball counts are always visible: legal deliveries vs extras.
                Text(
                  '${l10n.translate('legal_balls')} ${currentOverBalls.where((b) => b.isLegalBall).length}/6 · '
                  '${l10n.translate('extras')} ${currentOverBalls.where((b) => !b.isLegalBall).length}',
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.38),
                      fontSize: 10),
                ),
                const Gap(12),
                // Batsmen & Bowler info
                Row(
                  children: [
                    Flexible(child: _batInfoChip(striker, true)),
                    const Gap(8),
                    Flexible(child: _batInfoChip(nonStriker, false)),
                    const Spacer(),
                    Flexible(child: _bowlerInfoChip(bowler, inn)),
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
                  if (match.currentInnings == 1 &&
                      match.innings1?.isComplete == true) ...[
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
                      _runButton(0, colorScheme.surface,
                          colorScheme.onSurface.withOpacity(0.7)),
                      _runButton(1, colorScheme.surface, colorScheme.onSurface),
                      _runButton(2, colorScheme.surface, colorScheme.onSurface),
                      _runButton(3, colorScheme.surface, colorScheme.onSurface),
                      _runButton(4, AppColors.pitchGreen.withOpacity(0.1),
                          AppColors.pitchGreenLight,
                          label: '4 ◈', isBoundary: true),
                      _runButton(5, colorScheme.surface, colorScheme.onSurface),
                      _runButton(6, Colors.redAccent.withOpacity(0.1),
                          Colors.redAccent,
                          label: '6 ★', isSix: true, isBoundary: true),
                      _runButton(7, colorScheme.surface, colorScheme.onSurface),
                    ],
                  ),
                  const Gap(12),

                  // Extras & Wicket row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _showExtras = !_showExtras),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _showExtras
                                  ? Colors.orange.withOpacity(0.2)
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _showExtras
                                      ? Colors.orange
                                      : theme.dividerColor),
                            ),
                            child: Column(
                              children: [
                                Text(l10n.translate('extras'),
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const Text('Wd/Nb/B/Lb',
                                    style: TextStyle(
                                        color: Colors.orange, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final liveRepo =
                                ref.read(scorerLiveMatchRepositoryProvider);
                            final m = liveRepo.activeMatch;
                            if (m != null)
                              _showWicketModal(context, m, allPlayers);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.liveRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.liveRed.withOpacity(0.6)),
                            ),
                            child: Column(
                              children: [
                                Text(l10n.translate('wicket').toUpperCase(),
                                    style: const TextStyle(
                                        color: AppColors.liveRed,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14)),
                                const Text('W',
                                    style: TextStyle(
                                        color: AppColors.liveRed,
                                        fontSize: 10)),
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
                          label: '↩ ${l10n.translate('undo')}',
                          icon: Icons.undo_rounded,
                          color: Colors.orange,
                          onTap: () {
                            ref
                                .read(scorerLiveMatchRepositoryProvider)
                                .undoLastBall();
                          },
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: _controlButton(
                          label: '⇄ ${l10n.translate('swap_strike')}',
                          icon: Icons.swap_horiz_rounded,
                          color: Colors.blueAccent,
                          onTap: () {
                            ref
                                .read(scorerLiveMatchRepositoryProvider)
                                .swapStrike();
                          },
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: _controlButton(
                          label: '🎳 ${l10n.translate('bowler')}',
                          icon: Icons.sports_cricket_outlined,
                          color: Colors.purpleAccent,
                          onTap: () {
                            final m = ref
                                .read(scorerLiveMatchRepositoryProvider)
                                .activeMatch;
                            if (m != null) _showBowlerPicker(m, allPlayers);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  // Overs & substitution row
                  Row(
                    children: [
                      Expanded(
                        child: _miniControl(
                          label: '- ${l10n.translate('overs')}',
                          icon: Icons.remove_rounded,
                          color: colorScheme.onBackground.withOpacity(0.7),
                          onTap: () => _changeOvers(-1),
                        ),
                      ),
                      const Gap(6),
                      _oversBadge(match.overs),
                      const Gap(6),
                      Expanded(
                        child: _miniControl(
                          label: '+ ${l10n.translate('overs')}',
                          icon: Icons.add_rounded,
                          color: colorScheme.onBackground.withOpacity(0.7),
                          onTap: () => _changeOvers(1),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        flex: 2,
                        child: _miniControl(
                          label: l10n.translate('replace_player'),
                          icon: Icons.swap_vert_rounded,
                          color: Colors.blueAccent,
                          onTap: () => _showReplacePlayerSheet(
                              match, allPlayers, team1Name, team2Name),
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
    } else if (!ball.isLegalBall) {
      // Wide / no-ball (extra delivery) — visually distinct, orange ring.
      bg = Colors.orange.withOpacity(0.18);
      text = Colors.orangeAccent;
    } else {
      bg = Colors.white24;
      text = Colors.white;
    }

    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: ball.isLegalBall ? null : Border.all(color: Colors.orange),
      ),
      alignment: Alignment.center,
      child: Text(ball.displayLabel,
          style: TextStyle(
              color: text, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _emptyDot() {
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }

  Widget _batInfoChip(ScorerPlayer? player, bool isStriker) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    if (player == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isStriker)
              const Text('* ',
                  style: TextStyle(
                      color: AppColors.pitchGreenLight,
                      fontWeight: FontWeight.bold)),
            Flexible(
              child: Text(
                player.name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ],
        ),
        Text(
            isStriker
                ? l10n.translate('striker')
                : l10n.translate('non_striker'),
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _bowlerInfoChip(ScorerPlayer? player, Innings? inn) {
    final colorScheme = Theme.of(context).colorScheme;
    if (player == null) return const SizedBox();
    final playerBalls =
        inn?.balls.where((b) => b.bowlerId == player.id).length ?? 0;
    final playerWickets =
        inn?.balls.where((b) => b.bowlerId == player.id && b.isWicket).length ??
            0;
    final playerRuns = inn?.balls
            .where((b) => b.bowlerId == player.id)
            .fold(0, (s, b) => s + b.totalRuns) ??
        0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(player.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        Text(
            '$playerRuns runs • $playerWickets-W • ${(playerBalls ~/ 6)}.${playerBalls % 6} ov',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _secondInningsBanner(ScorerMatch match) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.floodlightGold.withOpacity(0.2),
            colorScheme.surface
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.floodlightGold.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded,
              color: AppColors.floodlightGold, size: 28),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('innings_break'),
                  style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                Text(
                  'Innings saved. Start the 2nd innings when ready.',
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showInningsBreakDialog(match),
            child: Text(l10n.translate('start_second_innings'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _runButton(int runs, Color bg, Color textColor,
      {String? label, bool isBoundary = false, bool isSix = false}) {
    return GestureDetector(
      onTap: () =>
          _recordBall(runs: runs, isBoundary: isBoundary, isSix: isSix),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isBoundary
                  ? Colors.greenAccent.withOpacity(0.5)
                  : Colors.white12),
          boxShadow: isSix
              ? [
                  BoxShadow(
                      color: Colors.redAccent.withOpacity(0.3), blurRadius: 12)
                ]
              : isBoundary
                  ? [
                      BoxShadow(
                          color: AppColors.pitchGreen.withOpacity(0.3),
                          blurRadius: 12)
                    ]
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
    );
  }

  Widget _extrasPicker() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedExtrasType;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.translate('select_extra_type'),
              style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const Gap(8),
          // Type row — always visible.
          Row(
            children: [
              Expanded(child: _extrasTypeButton(ExtrasType.wide, 'Wide')),
              const Gap(6),
              Expanded(child: _extrasTypeButton(ExtrasType.noBall, 'No Ball')),
            ],
          ),
          const Gap(6),
          Row(
            children: [
              Expanded(child: _extrasTypeButton(ExtrasType.bye, 'Bye')),
              const Gap(6),
              Expanded(child: _extrasTypeButton(ExtrasType.legBye, 'Leg Bye')),
            ],
          ),
          const Gap(10),
          // Run count row — shown ALWAYS (not only after a type is tapped).
          Row(
            children: [
              Expanded(
                child: Text(
                  selected == null
                      ? l10n.translate('extra_type_hint')
                      : '${_extrasTitle(selected)} runs',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
              if (selected != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => setState(() => _selectedExtrasType = null),
                  child: Text(l10n.translate('update'),
                      style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.54),
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
            ],
          ),
          const Gap(4),
          Row(
            children: [1, 2, 3, 4].map((r) {
              return Expanded(child: _extrasRunButton(selected, r));
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _extrasTitle(ExtrasType type) {
    switch (type) {
      case ExtrasType.wide:
        return 'Wide';
      case ExtrasType.noBall:
        return 'No Ball';
      case ExtrasType.bye:
        return 'Bye';
      case ExtrasType.legBye:
        return 'Leg Bye';
      case ExtrasType.none:
        return 'Extra';
    }
  }

  Widget _extrasTypeButton(ExtrasType type, String label) {
    return GestureDetector(
      onTap: () => setState(() => _selectedExtrasType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12),
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _extrasRunButton(ExtrasType? type, int runs) {
    final isByes = type == ExtrasType.bye || type == ExtrasType.legBye;
    return GestureDetector(
      onTap: () {
        if (type == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text(
                  'Select an extra type (Wide / No Ball / Bye / Leg Bye) first'),
              backgroundColor: Colors.orange,
            ));
          return;
        }
        _recordExtras(type, runs);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text('$runs',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const Gap(2),
            Text(
              isByes
                  ? (runs == 1 ? 'bye' : 'byes')
                  : (runs == 1 ? 'run' : 'runs'),
              style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _changeOvers(int delta) {
    final liveRepo = ref.read(scorerLiveMatchRepositoryProvider);
    final m = liveRepo.activeMatch;
    if (m == null) return;
    liveRepo.setOvers(m.overs + delta);
  }

  Widget _oversBadge(int overs) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$overs',
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(l10n.translate('overs'),
              style: const TextStyle(color: Colors.grey, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _miniControl({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap == null ? Colors.white24 : color, size: 18),
            const Gap(2),
            Text(label,
                style: TextStyle(
                    color: onTap == null ? Colors.white24 : color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showReplacePlayerSheet(ScorerMatch match, List<ScorerPlayer> allPlayers,
      String team1Name, String team2Name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReplacePlayerSheet(
        match: match,
        allPlayers: allPlayers,
        team1Name: team1Name,
        team2Name: team2Name,
        onReplace: (teamId, playerOutId, playerInId) {
          Navigator.pop(ctx);
          ref.read(scorerLiveMatchRepositoryProvider).replacePlayer(
                teamId: teamId,
                playerOutId: playerOutId,
                playerInId: playerInId,
              );
        },
      ),
    );
  }

  Widget _controlButton(
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
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
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Match Data ─────────────────────────────────────────────────────────────────

class _MatchData {
  final List<ScorerPlayer> players;
  final String team1Name;
  final String team2Name;

  const _MatchData({
    required this.players,
    required this.team1Name,
    required this.team2Name,
  });
}

// ── Replace Player Sheet ──────────────────────────────────────────────────────

class _ReplacePlayerSheet extends ConsumerStatefulWidget {
  final ScorerMatch match;
  final List<ScorerPlayer> allPlayers;
  final String team1Name;
  final String team2Name;
  final void Function(String teamId, String playerOutId, String playerInId)
      onReplace;

  const _ReplacePlayerSheet({
    required this.match,
    required this.allPlayers,
    required this.team1Name,
    required this.team2Name,
    required this.onReplace,
  });

  @override
  ConsumerState<_ReplacePlayerSheet> createState() =>
      _ReplacePlayerSheetState();
}

class _ReplacePlayerSheetState extends ConsumerState<_ReplacePlayerSheet> {
  int _teamIndex = 0;
  String? _outId;
  String? _inId;

  String get _teamId =>
      _teamIndex == 0 ? widget.match.team1Id : widget.match.team2Id;

  List<ScorerPlayer> get _xiPlayers {
    final ids =
        _teamIndex == 0 ? widget.match.playingXI1 : widget.match.playingXI2;
    return widget.allPlayers.where((p) => ids.contains(p.id)).toList();
  }

  List<ScorerPlayer> get _benchPlayers {
    final ids =
        _teamIndex == 0 ? widget.match.playingXI1 : widget.match.playingXI2;
    return widget.allPlayers
        .where((p) => p.teamId == _teamId && !ids.contains(p.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canConfirm = _outId != null && _inId != null;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.translate('replace_player'),
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: _teamTab(0, widget.team1Name),
                ),
                const Gap(8),
                Expanded(
                  child: _teamTab(1, widget.team2Name),
                ),
              ],
            ),
            const Gap(16),
            const Text('Player to replace',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _xiPlayers
                  .map((p) =>
                      _playerChip(p, selected: _outId == p.id, onTap: () {
                        setState(() {
                          _outId = p.id;
                          if (_inId == p.id) _inId = null;
                        });
                      }))
                  .toList(),
            ),
            const Gap(16),
            const Text('Replacement from bench',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const Gap(8),
            if (_benchPlayers.isEmpty)
              Text(l10n.translate('no_bench_players'),
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.38),
                      fontSize: 12))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _benchPlayers
                    .map((p) =>
                        _playerChip(p, selected: _inId == p.id, onTap: () {
                          setState(() => _inId = p.id);
                        }))
                    .toList(),
              ),
            const Gap(20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: canConfirm
                    ? () => widget.onReplace(_teamId, _outId!, _inId!)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  disabledBackgroundColor:
                      colorScheme.onSurface.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.translate('confirm_substitution'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamTab(int index, String name) {
    final active = _teamIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() {
        _teamIndex = index;
        _outId = null;
        _inId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.blueAccent.withOpacity(0.25)
              : colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? Colors.blueAccent : theme.dividerColor),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: active
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _playerChip(ScorerPlayer p,
      {required bool selected, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green.withOpacity(0.25)
              : colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? Colors.green : theme.dividerColor),
        ),
        child: Text(
          p.name,
          style: TextStyle(
            color: selected
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.7),
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w400,
          ),
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

  const _WicketModal(
      {required this.match, required this.allPlayers, required this.onWicket});

  @override
  ConsumerState<_WicketModal> createState() => _WicketModalState();
}

class _WicketModalState extends ConsumerState<_WicketModal> {
  DismissalType _type = DismissalType.caught;
  String? _fielderId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final inn = widget.match.currentInningsData;
    if (inn == null) return const SizedBox();

    final fieldingTeam =
        widget.allPlayers.where((p) => p.teamId == inn.bowlingTeamId).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🚨 ${l10n.translate('wicket_alert')}',
              style: const TextStyle(
                  color: AppColors.liveRed,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const Gap(16),
          Text(l10n.translate('dismissal_type'),
              style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
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
                backgroundColor: colorScheme.onSurface.withOpacity(0.1),
                labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : colorScheme.onSurface.withOpacity(0.7),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal),
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          if (_type == DismissalType.caught ||
              _type == DismissalType.runOut ||
              _type == DismissalType.stumped) ...[
            const Gap(16),
            Text(l10n.translate('fielder_optional'),
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const Gap(8),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: fieldingTeam.map((p) {
                  final isSelected = _fielderId == p.id;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _fielderId = isSelected ? null : p.id),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blueAccent.withOpacity(0.2)
                            : colorScheme.onSurface.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.transparent),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            radius: 22,
                            child: Text('${p.jerseyNumber ?? '?'}',
                                style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Gap(4),
                          Text(p.name.split(' ').first,
                              style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final dismissal = Dismissal(
                  type: _type,
                  batsmanId: inn.strikerId ?? '',
                  bowlerId: inn.currentBowlerId ?? '',
                  fielderId: _fielderId,
                );
                widget.onWicket(dismissal);
              },
              child: Text(l10n.translate('confirm_wicket'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
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
  final void Function(String strikerId, String nonStrikerId, String bowlerId)
      onContinue;

  const _InningsBreakDialog({required this.match, required this.onContinue});

  @override
  ConsumerState<_InningsBreakDialog> createState() =>
      _InningsBreakDialogState();
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
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final inn1 = widget.match.innings1;
    final score = inn1 != null ? '${inn1.totalRuns}/${inn1.wickets}' : '';
    final target = (inn1?.totalRuns ?? 0) + 1;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('⏸️ ${l10n.translate('innings_break')}',
          style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1st Innings: $score',
                style:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
            Text('${l10n.translate('target')}: $target runs',
                style: const TextStyle(
                    color: AppColors.floodlightGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const Gap(20),
            Text(l10n.translate('opening_players'),
                style: TextStyle(
                    color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
            const Gap(8),
            ..._battingPlayers.take(6).map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                    child: Text('${p.jerseyNumber ?? '?'}',
                        style: const TextStyle(
                            color: AppColors.pitchGreenLight, fontSize: 12)),
                  ),
                  title: Text(p.name,
                      style: TextStyle(
                          color: colorScheme.onSurface, fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniPill('Strike', _strikerId == p.id, Colors.blueAccent,
                          () => setState(() => _strikerId = p.id)),
                      const Gap(6),
                      _miniPill(
                          'Non-S',
                          _nonStrikerId == p.id,
                          AppColors.pitchGreenLight,
                          () => setState(() => _nonStrikerId = p.id)),
                    ],
                  ),
                )),
            const Gap(16),
            Text(l10n.translate('opening_bowler'),
                style: TextStyle(
                    color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
            const Gap(8),
            ..._bowlerCandidates().map((p) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: p.id,
                  groupValue: _bowlerId,
                  title: Text(p.name,
                      style: TextStyle(
                          color: colorScheme.onSurface, fontSize: 13)),
                  activeColor: Colors.redAccent,
                  onChanged: (val) => setState(() => _bowlerId = val),
                )),
            if (_bowlerCandidates().isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                    'No players available to bowl. Add players to the bowling team first.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              ),
            if (_strikerId == null ||
                _nonStrikerId == null ||
                _bowlerId == null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(l10n.translate('select_openers'),
                    style: const TextStyle(
                        color: Colors.orangeAccent, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pitchGreen,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: (_strikerId == null ||
                  _nonStrikerId == null ||
                  _bowlerId == null)
              ? null
              : () =>
                  widget.onContinue(_strikerId!, _nonStrikerId!, _bowlerId!),
          child: Text(l10n.translate('start_second_innings'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  /// Players who can bowl, falling back to the full bowling squad when nobody
  /// has a declared bowling style so the innings can always start.
  List<ScorerPlayer> _bowlerCandidates() {
    final styled = _bowlingPlayers
        .where((p) => p.bowlingStyle != BowlingStyle.none)
        .toList();
    if (styled.isNotEmpty) return styled;
    return _bowlingPlayers;
  }

  Widget _miniPill(
      String label, bool isActive, Color color, VoidCallback onTap) {
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
        child: Text(label,
            style: TextStyle(
                color: isActive ? color : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
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
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

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
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Center(
          child: Text('🏆 ${l10n.translate('match_summary')}',
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 22))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pitchGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.pitchGreenLight.withOpacity(0.5)),
            ),
            child: Text(result,
                style: const TextStyle(
                    color: AppColors.pitchGreenLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                textAlign: TextAlign.center),
          ),
          const Gap(20),
          if (inn1 != null)
            _scoreRow(
                '1st Innings',
                inn1.battingTeamId,
                '${inn1.totalRuns}/${inn1.wickets}',
                '(${inn1.overs.toStringAsFixed(1)} ov)',
                colorScheme),
          const Gap(8),
          if (inn2 != null)
            _scoreRow(
                '2nd Innings',
                inn2.battingTeamId,
                '${inn2.totalRuns}/${inn2.wickets}',
                '(${inn2.overs.toStringAsFixed(1)} ov)',
                colorScheme),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.floodlightGold,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onClose,
          child: Text(l10n.translate('confirm'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _scoreRow(String label, String teamId, String score, String overs,
      ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(teamId.toUpperCase(),
              style: TextStyle(
                  color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(score,
              style: const TextStyle(
                  color: AppColors.pitchGreenLight,
                  fontWeight: FontWeight.w900,
                  fontSize: 20)),
          Text(overs, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ],
    );
  }
}

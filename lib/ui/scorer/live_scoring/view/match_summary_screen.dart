import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/match_result.dart';
import 'package:sportyapp/data/engines/match_result_engine.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class MatchSummaryScreen extends ConsumerStatefulWidget {
  const MatchSummaryScreen({super.key});

  @override
  ConsumerState<MatchSummaryScreen> createState() =>
      _MatchSummaryScreenState();
}

class _SummaryData {
  final ScorerMatch? match;
  final List<ScorerPlayer> players;
  final String team1Name;
  final String team2Name;

  const _SummaryData({
    required this.match,
    required this.players,
    required this.team1Name,
    required this.team2Name,
  });
}

class _MatchSummaryScreenState extends ConsumerState<MatchSummaryScreen> {
  String? _pomId;
  String? _bestBatsmanId;
  String? _bestBowlerId;
  final TextEditingController _pomPrizeCtrl = TextEditingController();
  final TextEditingController _bestBatsmanPrizeCtrl = TextEditingController();
  final TextEditingController _bestBowlerPrizeCtrl = TextEditingController();
  final Map<String, String> _customAwards = {};
  final Map<String, String> _customAwardsPrizes = {};
  bool _finishing = false;

  late Future<_SummaryData> _dataFuture;
  String? _matchId;
  bool _dataFutureInitialized = false;

  @override
  void dispose() {
    _pomPrizeCtrl.dispose();
    _bestBatsmanPrizeCtrl.dispose();
    _bestBowlerPrizeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dataFutureInitialized) return;
    _matchId = GoRouterState.of(context).uri.queryParameters['matchId'];
    _dataFuture = _loadData();
    _dataFutureInitialized = true;
  }

  /// Resolves the match to summarise. An explicit `matchId` on the route wins:
  /// it is used both when re-opening a completed match from the Matches tab and
  /// after live scoring ends. This matters because the live repo's active match
  /// may hold an UNRELATED draft — showing that instead of the requested match
  /// would render an empty summary. Without a matchId we fall back to the live
  /// session, then the most recent in-progress draft.
  Future<ScorerMatch?> _resolveMatch() async {
    final liveRepo = ref.read(scorerLiveMatchRepositoryProvider);
    final repo = ref.read(scorerRepositoryProvider);
    if (_matchId != null && _matchId!.isNotEmpty) {
      final byId = await repo.getMatch(_matchId!);
      if (byId != null) return byId;
      final active = liveRepo.activeMatch;
      if (active != null && active.id == _matchId) return active;
    }
    return liveRepo.activeMatch ?? await repo.firstInProgressMatch();
  }

  Future<_SummaryData> _loadData() async {
    final match = await _resolveMatch();
    final repo = ref.read(scorerRepositoryProvider);
    final team1Id = match?.team1Id ?? '';
    final team2Id = match?.team2Id ?? '';
    final [p1, p2] = await Future.wait([
      repo.getPlayersByTeam(team1Id),
      repo.getPlayersByTeam(team2Id),
    ]);
    final [t1, t2] = await Future.wait([
      repo.getTeam(team1Id),
      repo.getTeam(team2Id),
    ]);

    // Always include the players actually named in the match (both playing XIs
    // plus every innings' batting/bowling orders and ball references), so the
    // Award & Prizes sheet never ends up empty even when the team->player
    // association is missing from the local repo view (e.g. cloud data that has
    // players but no matching teamId, or a stale cache).
    final players = await _resolveMatchPlayers(match, repo, [...p1, ...p2]);

    // Re-opening the summary for an already-completed match must show the
    // awards that were saved at completion time (winner, best batsman/bowler,
    // prizes and custom awards). Pre-fill the state from the loaded match so
    // the Award & Prizes sheet displays the real winners instead of starting
    // blank.
    if (match != null) {
      _pomId = match.playerOfTheMatchId;
      _bestBatsmanId = match.bestBatsmanId;
      _bestBowlerId = match.bestBowlerId;
      _pomPrizeCtrl.text = match.playerOfTheMatchPrize ?? '';
      _bestBatsmanPrizeCtrl.text = match.bestBatsmanPrize ?? '';
      _bestBowlerPrizeCtrl.text = match.bestBowlerPrize ?? '';
      _customAwards
        ..clear()
        ..addAll(match.customAwards);
      _customAwardsPrizes
        ..clear()
        ..addAll(match.customAwardsPrizes);
    }

    return _SummaryData(
      match: match,
      players: players,
      team1Name: t1?.name ?? team1Id,
      team2Name: t2?.name ?? team2Id,
    );
  }

  /// Resolves the list of players shown in the Award & Prizes sheet.
  ///
  /// Starts from the players already found via [ScorerRepository.getPlayersByTeam]
  /// and adds every player referenced by the match itself — `playingXI1`/
  /// `playingXI2`, plus striker/non-striker/bowler and ball events across all
  /// innings — so the sheet always lists the actual participants even when the
  /// team→player mapping is missing.
  Future<List<ScorerPlayer>> _resolveMatchPlayers(
    ScorerMatch? match,
    ScorerRepository repo,
    List<ScorerPlayer> initial,
  ) async {
    if (match == null) return initial;
    final byId = <String, ScorerPlayer>{
      for (final p in initial) p.id: p,
    };

    final referenced = <String>{
      ...match.playingXI1,
      ...match.playingXI2,
    };
    for (final inn in [
      match.innings1,
      match.innings2,
      match.superOverInnings1,
      match.superOverInnings2,
    ]) {
      if (inn == null) continue;
      if (inn.strikerId != null) referenced.add(inn.strikerId!);
      if (inn.nonStrikerId != null) referenced.add(inn.nonStrikerId!);
      if (inn.currentBowlerId != null) referenced.add(inn.currentBowlerId!);
      referenced.addAll(inn.battingOrder);
      referenced.addAll(inn.bowlingOrder);
      for (final ball in inn.balls) {
        if (ball.batsmanId.isNotEmpty) referenced.add(ball.batsmanId);
        if (ball.bowlerId.isNotEmpty) referenced.add(ball.bowlerId);
      }
    }

    final missing = referenced
        .where((id) => !byId.containsKey(id))
        .toList();
    for (final id in missing) {
      final p = await repo.getPlayer(id);
      if (p != null) byId[id] = p;
    }

    return byId.values.toList();
  }

  Future<void> _finish(ScorerMatch match, _SummaryData data) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final l10n = AppLocalizations.of(context);

    // The match is already completed (summary re-opened from the Matches tab):
    // there is no active live session to end, so persist the award/prize edits
    // directly and leave the result/status untouched.
    if (match.status == MatchStatus.completed) {
      try {
        await ref.read(scorerRepositoryProvider).saveMatch(match.copyWith(
          playerOfTheMatchId: _pomId,
          bestBatsmanId: _bestBatsmanId,
          bestBowlerId: _bestBowlerId,
          playerOfTheMatchPrize: _pomPrizeCtrl.text.trim().isEmpty
              ? null
              : _pomPrizeCtrl.text.trim(),
          bestBatsmanPrize: _bestBatsmanPrizeCtrl.text.trim().isEmpty
              ? null
              : _bestBatsmanPrizeCtrl.text.trim(),
          bestBowlerPrize: _bestBowlerPrizeCtrl.text.trim().isEmpty
              ? null
              : _bestBowlerPrizeCtrl.text.trim(),
          customAwards: _customAwards,
          customAwardsPrizes: _customAwardsPrizes,
        ));
      } catch (e) {
        debugPrint('[MatchSummary] save awards failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l10n.translate('complete_match')} failed: $e'),
        ));
        setState(() => _finishing = false);
        return;
      }
      if (!mounted) return;
      context.go('/scorer/dashboard');
      return;
    }

    final result = _result(match, data, l10n);
    final liveRepo = ref.read(scorerLiveMatchRepositoryProvider);

    // 1. Persist the completed match. This is the critical step — if it fails,
    // stay on this screen and let the scorer retry.
    try {
      final completed = liveRepo.endMatch(
        winnerTeamId: result.winnerTeamId,
        loserTeamId: result.loserTeamId,
        summary: result.resultText,
        resultType: result.type,
        resultMargin: result.margin,
        isNoResult: result.isNoResult,
        isDls: result.isDls,
        playerOfTheMatchId: _pomId,
        bestBatsmanId: _bestBatsmanId,
        bestBowlerId: _bestBowlerId,
        playerOfTheMatchPrize: _pomPrizeCtrl.text.trim().isEmpty
            ? null
            : _pomPrizeCtrl.text.trim(),
        bestBatsmanPrize: _bestBatsmanPrizeCtrl.text.trim().isEmpty
            ? null
            : _bestBatsmanPrizeCtrl.text.trim(),
        bestBowlerPrize: _bestBowlerPrizeCtrl.text.trim().isEmpty
            ? null
            : _bestBowlerPrizeCtrl.text.trim(),
        customAwards: _customAwards,
        customAwardsPrizes: _customAwardsPrizes,
      );
      liveRepo.setActiveMatch(null);
      // Explicitly await the persistence (cache + Firestore) so the completed
      // match with its full innings/ball data is saved before leaving the
      // screen — otherwise spectators could read a stale draft with no balls.
      if (completed != null) {
        await ref.read(scorerRepositoryProvider).saveMatch(completed);
      }
    } catch (e) {
      debugPrint('[MatchSummary] endMatch failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.translate('complete_match')} failed: $e'),
      ));
      setState(() => _finishing = false);
      return;
    }

    // 2. Advance tournament schedule/tables. Best-effort — the match itself is
    // already completed and persisted, so a schedule sync failure must never
    // strand the scorer on this screen. A tie/no-result has no winner/loser to
    // advance.
    if (result.winnerTeamId != null && result.loserTeamId != null) {
      try {
        await ref.read(scorerRepositoryProvider).applyScheduleResult(
              tournamentId: match.tournamentId,
              winnerTeamId: result.winnerTeamId!,
              loserTeamId: result.loserTeamId!,
              matchTeam1Id: match.team1Id,
              matchTeam2Id: match.team2Id,
            );
      } catch (e) {
        debugPrint('[MatchSummary] schedule sync failed: $e');
      }
    }

    if (!mounted) return;
    context.go('/scorer/dashboard');
  }

  /// Computes the match result through the centralized [MatchResultEngine],
  /// honouring super overs, ties and no-result states.
  MatchResult _result(
      ScorerMatch match, _SummaryData data, AppLocalizations l10n) {
    return MatchResultEngine.compute(
      match: match,
      team1Name: data.team1Name,
      team2Name: data.team2Name,
      l10n: l10n,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
          onPressed: () => context.go('/scorer/dashboard'),
        ),
        title: Text('🏆 ${l10n.translate('match_summary')}',
            style: TextStyle(
                color: colorScheme.onBackground,
                fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<_SummaryData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final match = data?.match;
          if (data == null || match == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_score_outlined,
                      color: Colors.grey, size: 56),
                  const Gap(12),
                  Text(l10n.translate('match_not_found'),
                      style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const Gap(12),
                  ElevatedButton(
                    onPressed: () => context.go('/scorer/dashboard'),
                    child: Text(l10n.translate('back')),
                  ),
                ],
              ),
            );
          }
          return _buildBody(match, data, colorScheme, l10n);
        },
      ),
    );
  }

  Widget _buildBody(ScorerMatch match, _SummaryData data, ColorScheme colorScheme,
      AppLocalizations l10n) {
    final inn1 = match.innings1;
    final inn2 = match.innings2;
    final so1 = match.superOverInnings1;
    final so2 = match.superOverInnings2;
    final result = _result(match, data, l10n);

    String? teamNameFor(String? teamId) {
      if (teamId == null) return null;
      return teamId == match.team1Id ? data.team1Name : data.team2Name;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: result.isTie
                ? AppColors.floodlightGold.withOpacity(0.12)
                : AppColors.pitchGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: result.isTie
                    ? AppColors.floodlightGold.withOpacity(0.5)
                    : AppColors.pitchGreenLight.withOpacity(0.5)),
          ),
          child: Text(
            result.isTie
                ? '🤝 ${result.resultText}'
                : '🏆 ${result.resultText}',
            style: TextStyle(
                color: result.isTie
                    ? AppColors.floodlightGold
                    : AppColors.pitchGreenLight,
                fontWeight: FontWeight.bold,
                fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(16),
        if (inn1 != null)
          _scoreRow(
              l10n.translate('innings1'), teamNameFor(inn1.battingTeamId),
              '${inn1.totalRuns}/${inn1.wickets}',
              '(${inn1.overs.toStringAsFixed(1)} ${l10n.translate('overs')})',
              colorScheme),
        if (inn2 != null) ...[
          const Gap(8),
          _scoreRow(
              l10n.translate('innings2'), teamNameFor(inn2.battingTeamId),
              '${inn2.totalRuns}/${inn2.wickets}',
              '(${inn2.overs.toStringAsFixed(1)} ${l10n.translate('overs')})',
              colorScheme),
        ],
        if (so1 != null) ...[
          const Gap(8),
          _scoreRow(
              '⚡ ${l10n.translate('super_over_banner')}',
              teamNameFor(so1.battingTeamId),
              '${so1.totalRuns}/${so1.wickets}',
              '(1.0 ${l10n.translate('overs')})',
              colorScheme),
        ],
        if (so2 != null) ...[
          const Gap(8),
          _scoreRow(
              '⚡ ${l10n.translate('super_over_banner')}',
              teamNameFor(so2.battingTeamId),
              '${so2.totalRuns}/${so2.wickets}',
              '(1.0 ${l10n.translate('overs')})',
              colorScheme),
        ],
        const Gap(24),
        ..._scorecards(match, data, teamNameFor, l10n, colorScheme),
        const Gap(24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
            ),
            onPressed: () => _showAwardsSheet(match, data),
            icon: const Icon(Icons.emoji_events_outlined),
            label: Text(
              l10n.translate('award_prizes'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const Gap(12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.floodlightGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
            ),
            onPressed: _finishing ? null : () => _finish(match, data),
            child: Text(
                _finishing
                    ? '...'
                    : match.status == MatchStatus.completed
                        ? l10n.translate('save_awards')
                        : l10n.translate('complete_match'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  void _showAwardsSheet(ScorerMatch match, _SummaryData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AwardsSheet(
        match: match,
        players: data.players,
        team1Name: data.team1Name,
        team2Name: data.team2Name,
        initialPomId: _pomId,
        initialBatsmanId: _bestBatsmanId,
        initialBowlerId: _bestBowlerId,
        initialPomPrize: _pomPrizeCtrl.text,
        initialBatsmanPrize: _bestBatsmanPrizeCtrl.text,
        initialBowlerPrize: _bestBowlerPrizeCtrl.text,
        initialCustomAwards: _customAwards,
        initialCustomPrizes: _customAwardsPrizes,
        onSave: (pomId, batsmanId, bowlerId, pomPrize, batsmanPrize,
            bowlerPrize, customAwards, customPrizes) {
          setState(() {
            _pomId = pomId;
            _bestBatsmanId = batsmanId;
            _bestBowlerId = bowlerId;
            _pomPrizeCtrl.text = pomPrize;
            _bestBatsmanPrizeCtrl.text = batsmanPrize;
            _bestBowlerPrizeCtrl.text = bowlerPrize;
            _customAwards
              ..clear()
              ..addAll(customAwards);
            _customAwardsPrizes
              ..clear()
              ..addAll(customPrizes);
          });
        },
      ),
    );
  }

  Widget _scoreRow(String label, String? teamName, String score, String overs,
      ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Text(teamName ?? '',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  // ─── Full scorecards (batting + bowling figures for every innings) ────────

  List<Widget> _scorecards(
    ScorerMatch match,
    _SummaryData data,
    String? Function(String?) teamNameFor,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final names = <String, String>{
      for (final p in data.players) p.id: p.name,
    };
    String playerName(String? id) =>
        id == null || id.isEmpty ? '' : (names[id] ?? id);

    final innings = <(Innings?, String)>[
      (match.innings1, l10n.translate('innings1')),
      (match.innings2, l10n.translate('innings2')),
      if (match.superOverInnings1 != null)
        (match.superOverInnings1, '⚡ ${l10n.translate('super_over_banner')}'),
      if (match.superOverInnings2 != null)
        (match.superOverInnings2, '⚡ ${l10n.translate('super_over_banner')}'),
    ];

    return [
      for (final entry in innings)
        if (entry.$1 != null)
          _scorecardCard(
            title:
                '${entry.$2} — ${teamNameFor(entry.$1!.battingTeamId) ?? ''}',
            score: '${entry.$1!.totalRuns}/${entry.$1!.wickets} '
                '(${entry.$1!.overs.toStringAsFixed(1)} ${l10n.translate('overs')})',
            batters: _battersFor(entry.$1!, playerName),
            bowlers:
                buildBowlingScorecard(entry.$1!, playerName: playerName),
            cs: cs,
          ),
    ];
  }

  List<LiveBatter> _battersFor(Innings inn, String Function(String?) name) {
    // In a finished innings nobody is genuinely "batting" — the last pair is
    // simply not out.
    return buildBattingScorecard(inn, playerName: name)
        .map((b) => inn.isComplete && b.status == 'batting'
            ? LiveBatter(
                playerId: b.playerId,
                name: b.name,
                runs: b.runs,
                balls: b.balls,
                fours: b.fours,
                sixes: b.sixes,
                status: 'not out',
                onStrike: false,
              )
            : b)
        .toList();
  }

  Widget _scorecardCard({
    required String title,
    required String score,
    required List<LiveBatter> batters,
    required List<LiveBowler> bowlers,
    required ColorScheme cs,
  }) {
    final batted = batters.where((b) => b.status != 'yet to bat').toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.pitchGreen.withOpacity(0.15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                Text(score,
                    style: const TextStyle(
                        color: AppColors.pitchGreenLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ],
            ),
          ),
          if (batted.isNotEmpty) ...[
            const Gap(6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  _tableHeader(
                      cs, const ['Batter', 'R', 'B', '4s', '6s', 'SR']),
                  ...batted.map((b) => _batterRow(cs, b)),
                ],
              ),
            ),
          ],
          if (bowlers.isNotEmpty) ...[
            const Gap(8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  _tableHeader(
                      cs, const ['Bowler', 'O', 'M', 'R', 'W', 'Econ']),
                  ...bowlers.map((b) => _bowlerRow(cs, b)),
                ],
              ),
            ),
          ],
          const Gap(10),
        ],
      ),
    );
  }

  Widget _tableHeader(ColorScheme cs, List<String> cols) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: cols.asMap().entries.map((e) {
          return Expanded(
            flex: e.key == 0 ? 4 : 1,
            child: Text(e.value,
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                textAlign: e.key == 0 ? TextAlign.left : TextAlign.center),
          );
        }).toList(),
      ),
    );
  }

  Widget _batterRow(ColorScheme cs, LiveBatter b) {
    final cols = [
      b.runs.toString(),
      b.balls.toString(),
      b.fours.toString(),
      b.sixes.toString(),
      b.strikeRate.toStringAsFixed(1),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: cs.onSurface.withOpacity(0.08), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                Text(b.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.5), fontSize: 10)),
              ],
            ),
          ),
          ...cols.map((v) => Expanded(
                child: Text(v,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                    textAlign: TextAlign.center),
              )),
        ],
      ),
    );
  }

  Widget _bowlerRow(ColorScheme cs, LiveBowler b) {
    final cols = [
      b.oversLabel,
      b.maidens.toString(),
      b.runs.toString(),
      b.wickets.toString(),
      b.economy.toStringAsFixed(2),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: cs.onSurface.withOpacity(0.08), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
          ...cols.map((v) => Expanded(
                child: Text(v,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                    textAlign: TextAlign.center),
              )),
        ],
      ),
    );
  }
}

// ─── Award selection sheet ────────────────────────────────────────────────

class _AwardsSheet extends StatefulWidget {
  final ScorerMatch match;
  final List<ScorerPlayer> players;
  final String team1Name;
  final String team2Name;
  final String? initialPomId;
  final String? initialBatsmanId;
  final String? initialBowlerId;
  final String initialPomPrize;
  final String initialBatsmanPrize;
  final String initialBowlerPrize;
  final Map<String, String> initialCustomAwards;
  final Map<String, String> initialCustomPrizes;
  final void Function(
    String? pomId,
    String? batsmanId,
    String? bowlerId,
    String pomPrize,
    String batsmanPrize,
    String bowlerPrize,
    Map<String, String> customAwards,
    Map<String, String> customPrizes,
  ) onSave;

  const _AwardsSheet({
    required this.match,
    required this.players,
    required this.team1Name,
    required this.team2Name,
    required this.initialPomId,
    required this.initialBatsmanId,
    required this.initialBowlerId,
    required this.initialPomPrize,
    required this.initialBatsmanPrize,
    required this.initialBowlerPrize,
    required this.initialCustomAwards,
    required this.initialCustomPrizes,
    required this.onSave,
  });

  @override
  State<_AwardsSheet> createState() => _AwardsSheetState();
}

class _AwardsSheetState extends State<_AwardsSheet> {
  late String? _pomId;
  late String? _batsmanId;
  late String? _bowlerId;
  late final TextEditingController _pomPrizeCtrl;
  late final TextEditingController _batsmanPrizeCtrl;
  late final TextEditingController _bowlerPrizeCtrl;
  late final Map<String, String> _customAwards;
  late final Map<String, String> _customPrizes;
  final Set<String> _expanded = {};
  late final Map<String, _BatStat> _batStats;
  late final Map<String, _BowlStat> _bowlStats;

  @override
  void initState() {
    super.initState();
    _pomId = widget.initialPomId;
    _batsmanId = widget.initialBatsmanId;
    _bowlerId = widget.initialBowlerId;
    _pomPrizeCtrl = TextEditingController(text: widget.initialPomPrize);
    _batsmanPrizeCtrl = TextEditingController(text: widget.initialBatsmanPrize);
    _bowlerPrizeCtrl = TextEditingController(text: widget.initialBowlerPrize);
    _customAwards = Map.of(widget.initialCustomAwards);
    _customPrizes = Map.of(widget.initialCustomPrizes);
    _batStats = _computeBatStats(widget.match);
    _bowlStats = _computeBowlStats(widget.match);
  }

  @override
  void dispose() {
    _pomPrizeCtrl.dispose();
    _batsmanPrizeCtrl.dispose();
    _bowlerPrizeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.floodlightGold),
                const Gap(8),
                Expanded(
                  child: Text(
                    l10n.translate('award_prizes'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _awardSection(
                    context: context,
                    icon: '🏏',
                    title: l10n.translate('player_of_match'),
                    selectedId: _pomId,
                    onSelect: (id) => setState(() => _pomId = id),
                    sectionKey: 'pom',
                    candidates: _rankedBy(
                        (p) =>
                            (_batStats[p.id]?.runs ?? 0) +
                            ((_bowlStats[p.id]?.wickets ?? 0) * 20)),
                    detailOf: _pomDetail,
                    prizeCtrl: _pomPrizeCtrl,
                  ),
                  _awardSection(
                    context: context,
                    icon: '🎯',
                    title: l10n.translate('best_batsman'),
                    selectedId: _batsmanId,
                    onSelect: (id) => setState(() => _batsmanId = id),
                    sectionKey: 'bat',
                    candidates: _rankedBy(
                        (p) => _batStats[p.id]?.runs ?? 0),
                    detailOf: (p) => _batDetail(p.id),
                    prizeCtrl: _batsmanPrizeCtrl,
                  ),
                  _awardSection(
                    context: context,
                    icon: '🎳',
                    title: l10n.translate('best_bowler'),
                    selectedId: _bowlerId,
                    onSelect: (id) => setState(() => _bowlerId = id),
                    sectionKey: 'bowl',
                    candidates: _rankedBy(
                        (p) => _bowlStats[p.id]?.wickets ?? 0),
                    detailOf: (p) => _bowlDetail(p.id),
                    prizeCtrl: _bowlerPrizeCtrl,
                  ),
                  const Gap(8),
                  _customAwardsSection(context, l10n),
                  const Gap(24),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pitchGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: () {
                    widget.onSave(
                      _pomId,
                      _batsmanId,
                      _bowlerId,
                      _pomPrizeCtrl.text.trim(),
                      _batsmanPrizeCtrl.text.trim(),
                      _bowlerPrizeCtrl.text.trim(),
                      _customAwards,
                      _customPrizes,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    l10n.translate('save_awards'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _awardSection({
    required BuildContext context,
    required String icon,
    required String title,
    required String? selectedId,
    required ValueChanged<String?> onSelect,
    required String sectionKey,
    required List<ScorerPlayer> candidates,
    required String Function(ScorerPlayer) detailOf,
    required TextEditingController prizeCtrl,
  }) {
    final l10n = AppLocalizations.of(context);
    final showAll = _expanded.contains(sectionKey);
    final visible = showAll ? candidates : candidates.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$icon $title',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const Gap(6),
        if (widget.players.isEmpty)
          Text(
            l10n.translate('no_players'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          )
        else ...[
          ...visible.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _PlayerPickCard(
                  player: p,
                  teamName: _teamName(p),
                  detail: detailOf(p),
                  selected: selectedId == p.id,
                  onTap: () => onSelect(selectedId == p.id ? null : p.id),
                ),
              )),
          if (candidates.length > 5)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() {
                showAll
                    ? _expanded.remove(sectionKey)
                    : _expanded.add(sectionKey);
              }),
              child: Text(
                showAll
                    ? l10n.translate('show_less')
                    : l10n.translate('show_all_players'),
                style: const TextStyle(
                    color: AppColors.pitchGreenLight, fontSize: 12),
              ),
            ),
        ],
        const Gap(2),
        _prizeFieldLocal(context, l10n.translate('prize_optional'), prizeCtrl),
        const Gap(18),
      ],
    );
  }

  Widget _customAwardsSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12, height: 12),
        Text('🏅 ${l10n.translate('custom_awards')}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const Gap(8),
        if (_customAwards.isNotEmpty)
          ..._customAwards.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _customAwardCard(context, l10n, e.key),
              )),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.pitchGreenLight,
            side: const BorderSide(color: AppColors.pitchGreen),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
          ),
          onPressed: () => _addCustomCategory(l10n),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.translate('add_custom_award')),
        ),
      ],
    );
  }

  Widget _customAwardCard(
      BuildContext context, AppLocalizations l10n, String category) {
    final playerId = _customAwards[category] ?? '';
    final prizeCtrl = TextEditingController(text: _customPrizes[category]);
    final player =
        widget.players.where((p) => p.id == playerId).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('🏅 $category',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 18),
                onPressed: () => setState(() {
                  _customAwards.remove(category);
                  _customPrizes.remove(category);
                }),
              ),
            ],
          ),
          InkWell(
            onTap: () => _pickCustomWinner(category),
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: player != null
                        ? AppColors.pitchGreen
                        : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(Icons.person,
                      color: player != null
                          ? AppColors.pitchGreenLight
                          : Colors.grey,
                      size: 18),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      player?.name ?? l10n.translate('tap_to_choose_winner'),
                      style: TextStyle(
                          color: player != null
                              ? Colors.white
                              : Colors.grey,
                          fontSize: 13,
                          fontWeight: player != null
                              ? FontWeight.w600
                              : FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (player != null)
                    Text(
                      player.teamId == widget.match.team1Id
                          ? widget.team1Name
                          : widget.team2Name,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
          const Gap(6),
          TextField(
            controller: prizeCtrl,
            onChanged: (v) => _customPrizes[category] = v,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: l10n.translate('prize_optional'),
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              isDense: true,
              filled: true,
              fillColor: Colors.white10,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: AppColors.pitchGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomCategory(AppLocalizations l10n) async {
    final category = await showDialog<String>(
      context: context,
      builder: (ctx) => _CustomCategoryDialog(
        suggested: [
          l10n.translate('best_fielder'),
          l10n.translate('best_wicket_keeper'),
          l10n.translate('most_sixes'),
          l10n.translate('most_fours'),
          l10n.translate('best_strike_rate'),
          l10n.translate('best_economy'),
        ],
      ),
    );
    if (category == null || category.trim().isEmpty) return;
    final key = category.trim();
    if (_customAwards.containsKey(key)) return;
    setState(() {
      _customAwards[key] = '';
      _customPrizes[key] = '';
    });
    await _pickCustomWinner(key);
  }

  Future<void> _pickCustomWinner(String category) async {
    final picked = await showModalBottomSheet<ScorerPlayer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomWinnerPicker(
        players: widget.players,
        team1Id: widget.match.team1Id,
        team2Id: widget.match.team2Id,
        team1Name: widget.team1Name,
        team2Name: widget.team2Name,
        currentWinnerId: _customAwards[category],
        batting: _batStats,
        bowling: _bowlStats,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _customAwards[category] = picked.id);
    }
  }

  List<ScorerPlayer> _rankedBy(int Function(ScorerPlayer) metric) {
    final list = List<ScorerPlayer>.from(widget.players)
      ..sort((a, b) => metric(b).compareTo(metric(a)));
    return list;
  }

  String _teamName(ScorerPlayer p) => p.teamId == widget.match.team1Id
      ? widget.team1Name
      : widget.team2Name;

  String _pomDetail(ScorerPlayer p) {
    final bat = _batDetail(p.id);
    final bowl = _bowlDetail(p.id);
    if (bat.isEmpty) return bowl;
    if (bowl.isEmpty) return bat;
    return '$bat  •  $bowl';
  }

  String _batDetail(String playerId) {
    final b = _batStats[playerId];
    if (b == null || b.balls == 0) return '—';
    final sr = b.balls > 0
        ? (b.runs * 100 / b.balls).toStringAsFixed(1)
        : '0.0';
    return 'R ${b.runs} · ${b.balls}B · ${b.fours}×4 · ${b.sixes}×6 · SR $sr';
  }

  String _bowlDetail(String playerId) {
    final b = _bowlStats[playerId];
    if (b == null || b.legalBalls == 0) return '—';
    final overs = '${b.legalBalls ~/ 6}.${b.legalBalls % 6}';
    final econ = b.legalBalls > 0
        ? (b.runsConceded * 6 / b.legalBalls).toStringAsFixed(1)
        : '0.0';
    return 'W ${b.wickets} · O $overs · R ${b.runsConceded} · Econ $econ';
  }

  Map<String, _BatStat> _computeBatStats(ScorerMatch match) {
    final acc = <String, _BatStat>{};
    for (final inn in [
      match.innings1,
      match.innings2,
      match.superOverInnings1,
      match.superOverInnings2,
    ]) {
      if (inn == null) continue;
      for (final ball in inn.balls) {
        if (ball.batsmanId.isEmpty || !ball.isLegalBall) continue;
        final a = acc.putIfAbsent(ball.batsmanId, () => _BatStat());
        a.balls++;
        a.runs += ball.runs;
        if (ball.isBoundary && ball.runs == 4) a.fours++;
        if (ball.isSix) a.sixes++;
      }
    }
    return acc;
  }

  Map<String, _BowlStat> _computeBowlStats(ScorerMatch match) {
    final acc = <String, _BowlStat>{};
    for (final inn in [
      match.innings1,
      match.innings2,
      match.superOverInnings1,
      match.superOverInnings2,
    ]) {
      if (inn == null) continue;
      for (final ball in inn.balls) {
        if (ball.bowlerId.isEmpty) continue;
        final a = acc.putIfAbsent(ball.bowlerId, () => _BowlStat());
        a.runsConceded += ball.totalRuns;
        if (ball.isWicket) a.wickets++;
        if (ball.isLegalBall) a.legalBalls++;
      }
    }
    return acc;
  }

  Widget _prizeFieldLocal(BuildContext context, String label,
      TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: Colors.white10,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.pitchGreen),
        ),
      ),
    );
  }
}

/// A tappable player card with 5px radius showing name, team and a stat line.
class _PlayerPickCard extends StatelessWidget {
  final ScorerPlayer player;
  final String teamName;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerPickCard({
    required this.player,
    required this.teamName,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.pitchGreen.withOpacity(0.18)
              : Colors.white10,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: selected ? AppColors.pitchGreen : Colors.white12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: selected
                  ? AppColors.pitchGreen.withOpacity(0.3)
                  : Colors.white12,
              child: Text('${player.jerseyNumber ?? '?'}',
                  style: TextStyle(
                      color: selected
                          ? AppColors.pitchGreenLight
                          : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$teamName · ${detail.isEmpty ? '—' : detail}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Gap(8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.pitchGreenLight : Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-height picker listing every player with their stats so the scorer can
/// pick any winner for a custom award category.
class _CustomWinnerPicker extends StatelessWidget {
  final List<ScorerPlayer> players;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final String? currentWinnerId;
  final Map<String, _BatStat> batting;
  final Map<String, _BowlStat> bowling;

  const _CustomWinnerPicker({
    required this.players,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    required this.currentWinnerId,
    required this.batting,
    required this.bowling,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    String teamNameOf(ScorerPlayer p) =>
        p.teamId == team1Id ? team1Name : team2Name;

    String detail(ScorerPlayer p) {
      final b = batting[p.id];
      final w = bowling[p.id];
      final parts = <String>[];
      if (b != null && b.balls > 0) {
        parts.add(
            'R ${b.runs} (${b.balls}B, ${b.fours}×4, ${b.sixes}×6, SR ${(b.runs * 100 / b.balls).toStringAsFixed(1)})');
      }
      if (w != null && w.legalBalls > 0) {
        parts.add(
            'W ${w.wickets} (${w.legalBalls ~/ 6}.${w.legalBalls % 6} ov, R ${w.runsConceded}, Econ ${(w.runsConceded * 6 / w.legalBalls).toStringAsFixed(1)})');
      }
      return parts.join('  ·  ');
    }

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.person_search, color: AppColors.pitchGreenLight),
                const Gap(8),
                Expanded(
                  child: Text(
                    l10n.translate('choose_winner'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: players.isEmpty
                  ? [
                      Text(
                        l10n.translate('no_players'),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      )
                    ]
                  : players
                      .map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: _PlayerPickCard(
                              player: p,
                              teamName: teamNameOf(p),
                              detail: detail(p),
                              selected: currentWinnerId == p.id,
                              onTap: () => Navigator.pop(context, p),
                            ),
                          ))
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dialog to name a custom award category (with common suggestions).
class _CustomCategoryDialog extends StatefulWidget {
  final List<String> suggested;
  const _CustomCategoryDialog({required this.suggested});

  @override
  State<_CustomCategoryDialog> createState() => _CustomCategoryDialogState();
}

class _CustomCategoryDialogState extends State<_CustomCategoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      title: Text(l10n.translate('add_custom_award'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.translate('category_name'),
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                isDense: true,
                filled: true,
                fillColor: Colors.white10,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.pitchGreen),
                ),
              ),
            ),
            if (widget.suggested.isNotEmpty) ...[
              const Gap(12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.suggested
                    .map((s) => InkWell(
                          onTap: () =>
                              setState(() => _controller.text = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(5),
                              border:
                                  Border.all(color: Colors.white12),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.translate('close'),
              style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pitchGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
          ),
          onPressed: () => Navigator.pop(
              context, _controller.text.trim().isEmpty ? null : _controller.text.trim()),
          child: Text(l10n.translate('add'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// Small performance accumulators.
class _BatStat {
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
}

class _BowlStat {
  int legalBalls = 0;
  int runsConceded = 0;
  int wickets = 0;
}

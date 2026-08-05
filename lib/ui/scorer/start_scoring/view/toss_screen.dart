// lib/ui/scorer/start_scoring/view/toss_screen.dart
// Toss + opening batsmen/bowler, then start the live scoring draft.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';

class TossScreen extends ConsumerStatefulWidget {
  final String matchId;

  const TossScreen({super.key, required this.matchId});

  @override
  ConsumerState<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends ConsumerState<TossScreen> {
  ScorerMatch? _match;
  String? _team1Name;
  String? _team2Name;
  List<ScorerPlayer> _team1Players = [];
  List<ScorerPlayer> _team2Players = [];
  final Set<String> _squad1 = {};
  final Set<String> _squad2 = {};
  bool _loading = true;
  bool _starting = false;

  String? _tossWinnerId;
  TossDecision _tossDecision = TossDecision.bat;
  String? _openingStrikerId;
  String? _openingNonStrikerId;
  String? _openingBowlerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final match = await repo.findMatchById(widget.matchId);
    if (match == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final t1 = await repo.getTeam(match.team1Id);
    final t2 = await repo.getTeam(match.team2Id);
    final p1 = await repo.getPlayersByTeam(match.team1Id);
    final p2 = await repo.getPlayersByTeam(match.team2Id);
    if (!mounted) return;
    setState(() {
      _match = match;
      _team1Name = t1?.name ?? match.team1Id;
      _team2Name = t2?.name ?? match.team2Id;
      _team1Players = p1;
      _team2Players = p2;
      // Honour the squad set on the squad setup screen; fall back to every
      // player on the team when no squad has been chosen yet.
      _squad1
        ..clear()
        ..addAll(match.playingXI1.isNotEmpty ? match.playingXI1 : p1.map((p) => p.id));
      _squad2
        ..clear()
        ..addAll(match.playingXI2.isNotEmpty ? match.playingXI2 : p2.map((p) => p.id));
      _loading = false;
    });
  }

  Future<void> _manageSquads() async {
    await context.push('/scorer/matches/${widget.matchId}/squad');
    if (mounted) _load();
  }

  String? get _battingTeamId {
    if (_tossWinnerId == null) return null;
    if (_tossDecision == TossDecision.bat) return _tossWinnerId;
    return _tossWinnerId == _match?.team1Id ? _match?.team2Id : _match?.team1Id;
  }

  String? get _bowlingTeamId {
    final bat = _battingTeamId;
    if (bat == null) return null;
    return bat == _match?.team1Id ? _match?.team2Id : _match?.team1Id;
  }

  List<ScorerPlayer> _battingPlayers() =>
      _battingTeamId == _match?.team1Id ? _team1Players : _team2Players;

  List<ScorerPlayer> _bowlingPlayers() =>
      _bowlingTeamId == _match?.team1Id ? _team1Players : _team2Players;

  List<ScorerPlayer> _squadPlayers(List<ScorerPlayer> players, Set<String> squad) {
    if (squad.isEmpty) return players;
    return players.where((p) => squad.contains(p.id)).toList();
  }

  Future<void> _startScoring() async {
    final l10n = AppLocalizations.of(context);
    final match = _match;
    if (match == null) return;
    final battingTeamId = _battingTeamId;
    final bowlingTeamId = _bowlingTeamId;
    if (battingTeamId == null || bowlingTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('select_toss_winner')), backgroundColor: Colors.red),
      );
      return;
    }
    final battingPlayers = _squadPlayers(_battingPlayers(), _battingTeamId == match.team1Id ? _squad1 : _squad2);
    final bowlingPlayers = _squadPlayers(_bowlingPlayers(), _battingTeamId == match.team1Id ? _squad1 : _squad2);
    if (battingPlayers.isEmpty || bowlingPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('select_min_player')), backgroundColor: Colors.red),
      );
      return;
    }
    if (_openingStrikerId == null || _openingNonStrikerId == null || _openingBowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('select_openers')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _starting = true);
    final repo = ref.read(scorerRepositoryProvider);

    final inn1 = Innings(
      id: 'inn_1_${match.id}',
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      inningsNumber: 1,
      balls: const [],
      battingOrder: [_openingStrikerId!, _openingNonStrikerId!],
      bowlingOrder: [_openingBowlerId!],
      isComplete: false,
      strikerId: _openingStrikerId,
      nonStrikerId: _openingNonStrikerId,
      currentBowlerId: _openingBowlerId,
    );

    final started = match.copyWith(
      tossWinnerId: _tossWinnerId,
      tossDecision: _tossDecision,
      openingStrikerId: _openingStrikerId,
      openingNonStrikerId: _openingNonStrikerId,
      openingBowlerId: _openingBowlerId,
      playingXI1: _squad1.isEmpty ? _team1Players.map((p) => p.id).toList() : _squad1.toList(),
      playingXI2: _squad2.isEmpty ? _team2Players.map((p) => p.id).toList() : _squad2.toList(),
      status: MatchStatus.inProgress,
      innings1: inn1,
      currentInnings: 1,
    );

    await repo.saveMatch(started);
    ref.read(scorerLiveMatchRepositoryProvider).setActiveMatch(started);
    if (!mounted) return;
    context.pushReplacement('/scorer/live-scoring');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.translate('toss_and_openers'),
            style: AppTextStyles.titleMedium(colorScheme.onBackground)
                .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : _match == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.translate('match_not_found'), style: TextStyle(color: colorScheme.onBackground, fontSize: 18)),
                      const Gap(16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.pitchGreen),
                        onPressed: () => context.pop(),
                        child: Text(l10n.translate('back')),
                      ),
                    ],
                  ),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final match = _match!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pitchGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded, color: AppColors.pitchGreenLight, size: 22),
                const Gap(10),
                Expanded(
                  child: Text(
                    '${_teamName(match.team1Id)} • ${_squad1.length} ${l10n.translate('in_squad')}  vs  ${_teamName(match.team2Id)} • ${_squad2.length} ${l10n.translate('in_squad')}',
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          TextButton.icon(
            onPressed: _manageSquads,
            icon: const Icon(Icons.settings_suggest_rounded, color: AppColors.pitchGreenLight, size: 18),
            label: Text(l10n.translate('manage_squads'), style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold)),
          ),
          const Gap(12),
          _tossPicker(),
          const Gap(28),
          _openingPlayersPicker(),
          const Gap(32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liveRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _starting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sports_score_rounded, size: 24),
            label: Text(_starting ? l10n.translate('starting') : l10n.translate('start_scoring'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _starting ? null : _startScoring,
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _tossPicker() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final match = _match!;
    final t1 = _teamName(match.team1Id);
    final t2 = _teamName(match.team2Id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.translate('toss_winner_query'), style: TextStyle(color: colorScheme.onBackground.withOpacity(0.7), fontSize: 16)),
        const Gap(12),
        Row(
          children: [
            Expanded(child: _selectCard(t1, _tossWinnerId == match.team1Id, () => setState(() => _tossWinnerId = match.team1Id))),
            const Gap(12),
            Expanded(child: _selectCard(t2, _tossWinnerId == match.team2Id, () => setState(() => _tossWinnerId = match.team2Id))),
          ],
        ),
        if (_tossWinnerId != null) ...[
          const Gap(20),
          Text(l10n.translate('toss_decision_query'), style: TextStyle(color: colorScheme.onBackground.withOpacity(0.7), fontSize: 16)),
          const Gap(12),
          Row(
            children: [
              Expanded(child: _decisionCard(l10n.translate('bat'), TossDecision.bat, Icons.sports_cricket)),
              const Gap(12),
              Expanded(child: _decisionCard(l10n.translate('bowl'), TossDecision.bowl, Icons.catching_pokemon)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _selectCard(String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pitchGreen.withOpacity(0.2) : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.pitchGreenLight : theme.dividerColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected ? AppColors.pitchGreenLight : colorScheme.onSurface.withOpacity(0.54), size: 24),
            const Gap(8),
            Text(label, style: TextStyle(color: isSelected ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _decisionCard(String label, TossDecision decision, IconData icon) {
    final isSelected = _tossDecision == decision;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _tossDecision = decision),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.floodlightGold.withOpacity(0.15) : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.floodlightGold : theme.dividerColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.floodlightGold : colorScheme.onSurface.withOpacity(0.54), size: 26),
            const Gap(6),
            Text(label, style: TextStyle(color: isSelected ? AppColors.floodlightGold : colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _openingPlayersPicker() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final match = _match!;
    final battingTeamId = _battingTeamId;
    if (battingTeamId == null) {
      return Text(
        l10n.translate('toss_picker_hint'),
        style: TextStyle(color: colorScheme.onBackground.withOpacity(0.54)),
      );
    }
    final battingSquad = _squadPlayers(_battingPlayers(), battingTeamId == match.team1Id ? _squad1 : _squad2);
    final bowlingSquad = _squadPlayers(_bowlingPlayers(), battingTeamId == match.team1Id ? _squad2 : _squad1);
    final battingName = _teamName(battingTeamId);
    final bowlingName = _teamName(battingTeamId == match.team1Id ? match.team2Id : match.team1Id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$battingName — ${l10n.translate('opening_players')}', style: TextStyle(color: colorScheme.onBackground, fontWeight: FontWeight.bold, fontSize: 15)),
        const Gap(8),
        if (battingSquad.isEmpty)
          _emptySquadHint('$battingName has no players in the squad.')
        else
          ...battingSquad.take(11).map((p) => _playerSelectorTile(
            player: p,
            isStriker: _openingStrikerId == p.id,
            isNonStriker: _openingNonStrikerId == p.id,
            onTapStriker: () => setState(() => _openingStrikerId = p.id),
            onTapNonStriker: () => setState(() => _openingNonStrikerId = p.id),
          )),
        const Gap(20),
        Text('$bowlingName — ${l10n.translate('opening_bowler')}', style: TextStyle(color: colorScheme.onBackground, fontWeight: FontWeight.bold, fontSize: 15)),
        const Gap(8),
        if (bowlingSquad.isEmpty)
          _emptySquadHint('$bowlingName has no players in the squad.')
        else
          ..._bowlerCandidates(bowlingSquad).map((p) => _bowlerSelectorTile(
            player: p,
            isSelected: _openingBowlerId == p.id,
            onTap: () => setState(() => _openingBowlerId = p.id),
          )),
      ],
    );
  }

  List<ScorerPlayer> _bowlerCandidates(List<ScorerPlayer> players) {
    final bowlers = players.where((p) => p.bowlingStyle != BowlingStyle.none).toList();
    return bowlers.isEmpty ? players : bowlers;
  }

  Widget _emptySquadHint(String message) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_alt_1, color: colorScheme.onSurface.withOpacity(0.38), size: 20),
          const Gap(10),
          Expanded(
            child: Text(message, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.54), fontSize: 13)),
          ),
          TextButton(
            onPressed: _manageSquads,
            child: Text(l10n.translate('manage_squad'), style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _teamName(String? id) {
    if (id == null) return 'Team';
    if (id == _match?.team1Id) return _team1Name ?? id;
    if (id == _match?.team2Id) return _team2Name ?? id;
    return id;
  }

  Widget _playerSelectorTile({
    required ScorerPlayer player,
    required bool isStriker,
    required bool isNonStriker,
    required VoidCallback onTapStriker,
    required VoidCallback onTapNonStriker,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isStriker || isNonStriker) ? AppColors.pitchGreen.withOpacity(0.1) : colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (isStriker || isNonStriker) ? AppColors.pitchGreenLight.withOpacity(0.5) : colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(player.name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600))),
          _pillButton('Striker', isStriker, onTapStriker, Colors.blueAccent),
          const Gap(8),
          _pillButton('Non-Striker', isNonStriker, onTapNonStriker, AppColors.pitchGreenLight),
        ],
      ),
    );
  }

  Widget _bowlerSelectorTile({required ScorerPlayer player, required bool isSelected, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withOpacity(0.1) : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.redAccent.withOpacity(0.5) : colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Colors.redAccent : colorScheme.onSurface.withOpacity(0.54)),
            const Gap(12),
            Expanded(child: Text(player.name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600))),
            Text(player.bowlingStyle.name, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, bool isActive, VoidCallback onTap, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : colorScheme.onSurface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isActive ? color : colorScheme.onSurface.withOpacity(0.54), fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

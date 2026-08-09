import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/ui/scorer/shared/player_form_dialog.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';


/// Full match-setup wizard — pick teams, playing XI, toss, opening batsmen, opening bowler
class MatchSetupScreen extends ConsumerStatefulWidget {
  final String? matchId; // if editing existing match

  const MatchSetupScreen({super.key, this.matchId});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  int _step = 0; // 0=match info, 1=toss, 2=opening players

  // Step 0 – Match info
  final _team1Controller = TextEditingController();
  final _team2Controller = TextEditingController();
  final _oversController = TextEditingController(text: '20');
  String? _team1Id;
  String? _team2Id;
  String _venue = '';
  DateTime? _dateTime; // optional
  int _overs = 20;
  MatchFormat _format = MatchFormat.t20;
  List<ScorerTeam> _allTeams = [];

  // Step 1 – Toss
  String? _tossWinnerId;
  TossDecision _tossDecision = TossDecision.bat;

  // Step 2 – Playing XI & Openers
  List<ScorerPlayer> _team1Players = [];
  List<ScorerPlayer> _team2Players = [];
  final Set<String> _playingXI1 = {};
  final Set<String> _playingXI2 = {};
  String? _openingStrikerId;
  String? _openingNonStrikerId;
  String? _openingBowlerId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    _oversController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    final repo = ref.read(scorerRepositoryProvider);
    final teams = await repo.getAllTeams();
    if (!mounted) return;
    setState(() {
      _allTeams = teams;
      _isLoading = false;
    });
  }

  Future<void> _loadPlayers() async {
    if (_team1Id == null || _team2Id == null) return;
    final repo = ref.read(scorerRepositoryProvider);
    final [p1, p2] = await Future.wait([
      repo.getPlayersByTeam(_team1Id!),
      repo.getPlayersByTeam(_team2Id!),
    ]);
    setState(() {
      _team1Players = p1;
      _team2Players = p2;
      _playingXI1.addAll(p1.map((p) => p.id));
      _playingXI2.addAll(p2.map((p) => p.id));
    });
  }

  Future<String> _resolveTeam(String name, int serial) async {
    final repo = ref.read(scorerRepositoryProvider);
    final match = _allTeams.where((t) =>
        t.name.trim().toLowerCase() == name.trim().toLowerCase()).firstOrNull;
    if (match != null) return match.id;

    final trimmed = name.trim();
    final id = 'team_local_${DateTime.now().millisecondsSinceEpoch}_$serial';
    final team = ScorerTeam(
      id: id,
      name: trimmed,
      shortCode: trimmed.length >= 3 ? trimmed.substring(0, 3).toUpperCase() : trimmed.toUpperCase(),
      tournamentId: 't_custom',
      playerIds: const [],
    );
    await repo.saveTeam(team);
    if (mounted) setState(() => _allTeams = List.of(_allTeams)..add(team));
    return id;
  }

  Future<void> _addPlayerToTeam(String teamId) async {
    final repo = ref.read(scorerRepositoryProvider);
    final team = await repo.getTeam(teamId);
    await showDialog(
      context: context,
      builder: (ctx) => PlayerFormDialog(
        teamId: teamId,
        tournamentId: team?.tournamentId ?? '',
        onSave: (player) async {
          await repo.savePlayer(player);
          if (!mounted) return;
          if (teamId == _team1Id) {
            setState(() {
              _team1Players.add(player);
              _playingXI1.add(player.id);
            });
          } else if (teamId == _team2Id) {
            setState(() {
              _team2Players.add(player);
              _playingXI2.add(player.id);
            });
          }
        },
      ),
    );
  }

  Future<void> _exchangePlayers() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(scorerRepositoryProvider);
    final player1 = await showDialog<ScorerPlayer>(
      context: context,
      builder: (ctx) => _PlayerPickDialog(
        title: '${l10n.translate('select_player_from')} ${_teamName(_team1Id, l10n)}',
        players: _team1Players,
      ),
    );
    if (player1 == null || !mounted) return;
    final player2 = await showDialog<ScorerPlayer>(
      context: context,
      builder: (ctx) => _PlayerPickDialog(
        title: '${l10n.translate('select_player_from')} ${_teamName(_team2Id, l10n)}',
        players: _team2Players,
      ),
    );
    if (player2 == null || !mounted) return;

    // Swap team membership + playing XI membership
    final t1 = await repo.getTeam(_team1Id!);
    final t2 = await repo.getTeam(_team2Id!);
    await repo.savePlayer(player1.copyWith(
      teamId: _team2Id!,
      tournamentId: t2?.tournamentId ?? '',
    ));
    await repo.savePlayer(player2.copyWith(
      teamId: _team1Id!,
      tournamentId: t1?.tournamentId ?? '',
    ));

    // Swap team playerIds
    if (t1 != null) {
      await repo.saveTeam(t1.copyWith(playerIds: t1.playerIds.map((id) => id == player1.id ? player2.id : id).toList()));
    }
    if (t2 != null) {
      await repo.saveTeam(t2.copyWith(playerIds: t2.playerIds.map((id) => id == player2.id ? player1.id : id).toList()));
    }

    // Swap XI lists
    setState(() {
      if (_playingXI1.contains(player1.id)) {
        _playingXI1.remove(player1.id);
        _playingXI1.add(player2.id);
      }
      if (_playingXI2.contains(player2.id)) {
        _playingXI2.remove(player2.id);
        _playingXI2.add(player1.id);
      }
    });
    await _loadPlayers();
  }

  Future<void> _pickMatchDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? now),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _nextStep() async {
    final l10n = AppLocalizations.of(context);
    if (_step == 0) {
      final name1 = _team1Controller.text.trim();
      final name2 = _team2Controller.text.trim();
      if (name1.isEmpty || name2.isEmpty || name1.toLowerCase() == name2.toLowerCase() || _venue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('please_fill_info')), backgroundColor: Colors.red),
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        _team1Id = await _resolveTeam(name1, 1);
        _team2Id = await _resolveTeam(name2, 2);
        await _loadPlayers();
        setState(() => _step++);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }
    if (_step == 1 && _tossWinnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('select_toss_winner')), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _step++);
  }

  void _prevStep() {
    setState(() => _step--);
  }

  String _teamName(String? id, AppLocalizations l10n) {
    if (id == null) return l10n.translate('team');
    return _allTeams.firstWhere((t) => t.id == id, orElse: () => ScorerTeam(id: id, name: id, shortCode: id, tournamentId: '', playerIds: [])).name;
  }

  List<ScorerPlayer> _battingPlayers() {
    // The batting team is determined by the toss
    final battingTeamId = (_tossDecision == TossDecision.bat) ? _tossWinnerId : (_tossWinnerId == _team1Id ? _team2Id : _team1Id);
    return battingTeamId == _team1Id ? _team1Players : _team2Players;
  }

  List<ScorerPlayer> _bowlingPlayers() {
    final battingTeamId = (_tossDecision == TossDecision.bat) ? _tossWinnerId : (_tossWinnerId == _team1Id ? _team2Id : _team1Id);
    return battingTeamId == _team1Id ? _team2Players : _team1Players;
  }

  String _battingTeamId() {
    final battingTeamId = (_tossDecision == TossDecision.bat) ? _tossWinnerId : (_tossWinnerId == _team1Id ? _team2Id : _team1Id);
    return battingTeamId ?? _team1Id!;
  }

  String _bowlingTeamId() {
    final bat = _battingTeamId();
    return bat == _team1Id ? _team2Id! : _team1Id!;
  }

  Future<void> _startMatch() async {
    final l10n = AppLocalizations.of(context);
    if (_openingStrikerId == null || _openingNonStrikerId == null || _openingBowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('select_openers')), backgroundColor: Colors.red),
      );
      return;
    }

    final repo = ref.read(scorerRepositoryProvider);
    final matchId = 'm_${DateTime.now().millisecondsSinceEpoch}';
    final battingTeamId = _battingTeamId();
    final bowlingTeamId = _bowlingTeamId();

    final inn1 = Innings(
      id: 'inn_1_$matchId',
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

    final match = ScorerMatch(
      id: matchId,
      tournamentId: 't_custom',
      team1Id: _team1Id!,
      team2Id: _team2Id!,
      venue: _venue,
      dateTime: _dateTime ?? DateTime.now(),
      format: _format,
      overs: _overs,
      status: MatchStatus.inProgress,
      tossWinnerId: _tossWinnerId,
      tossDecision: _tossDecision,
      playingXI1: _playingXI1.toList(),
      playingXI2: _playingXI2.toList(),
      openingStrikerId: _openingStrikerId,
      openingNonStrikerId: _openingNonStrikerId,
      openingBowlerId: _openingBowlerId,
      innings1: inn1,
      currentInnings: 1,
    );

    await repo.saveMatch(match);
    ref.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    if (mounted) context.pushReplacement('/scorer/live-scoring');
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
        leading: _step > 0
            ? IconButton(icon: Icon(Icons.arrow_back, color: colorScheme.onBackground), onPressed: _prevStep)
            : BackButton(color: colorScheme.onBackground),
        title: Text(
          [l10n.translate('match_info'), l10n.translate('toss'), l10n.translate('opening_players')][_step],
          style: AppTextStyles.headlineSmall(colorScheme.onBackground),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: colorScheme.surfaceVariant,
            color: AppColors.pitchGreen,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : switch (_step) {
              0 => _buildStep0(),
              1 => _buildStep1(),
              _ => _buildStep2(),
            },
    );
  }

  Widget _buildStep0() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(l10n.translate('select_teams')),
          const Gap(12),
          Row(
            children: [
              Expanded(child: _teamManualField(l10n.translate('team_1'), _team1Controller)),
              const Gap(12),
              Text(l10n.translate('vs'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
              const Gap(12),
              Expanded(child: _teamManualField(l10n.translate('team_2'), _team2Controller)),
            ],
          ),
          const Gap(8),
          Text(l10n.translate('create_match_hint'),
              style: TextStyle(color: colorScheme.onBackground.withOpacity(0.54), fontSize: 12)),
          const Gap(20),
          _sectionLabel(l10n.translate('venue')),
          const Gap(8),
          TextField(
            style: TextStyle(color: colorScheme.onBackground),
            onChanged: (val) => setState(() => _venue = val),
            decoration: InputDecoration(
              hintText: l10n.translate('enter_venue'),
              hintStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.38)),
              filled: true,
              fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on, color: AppColors.pitchGreenLight),
            ),
          ),
          const Gap(20),
          _sectionLabel(l10n.translate('match_time')),
          const Gap(8),
          InkWell(
            onTap: _pickMatchDateTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.pitchGreenLight),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      _dateTime == null
                          ? l10n.translate('set_match_time')
                          : _dateTime!.toLocal().toString().replaceRange(16, 19, ''),
                      style: TextStyle(
                        color: _dateTime == null ? colorScheme.onBackground.withOpacity(0.38) : colorScheme.onBackground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_dateTime != null)
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onBackground.withOpacity(0.38), size: 18),
                      onPressed: () => setState(() => _dateTime = null),
                    ),
                ],
              ),
            ),
          ),
          const Gap(20),
          _sectionLabel(l10n.translate('format_and_overs')),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MatchFormat>(
                  value: _format,
                  dropdownColor: colorScheme.surface,
                  style: TextStyle(color: colorScheme.onBackground),
                  decoration: InputDecoration(
                    labelText: l10n.translate('match_format'),
                    labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.7)),
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
                    border: const OutlineInputBorder(),
                  ),
                  items: MatchFormat.values.map((f) => DropdownMenuItem(value: f, child: Text(f.name.toUpperCase()))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() {
                      _format = val;
                      _overs = val == MatchFormat.t20 ? 20 : val == MatchFormat.odi ? 50 : 5;
                      _oversController.text = '$_overs';
                    });
                  },
                ),
              ),
              const Gap(12),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colorScheme.onBackground),
                  controller: _oversController,
                  onChanged: (val) => setState(() => _overs = int.tryParse(val) ?? _overs),
                  decoration: InputDecoration(
                    labelText: l10n.translate('overs'),
                    labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.7)),
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const Gap(32),
          _nextButton('${l10n.translate('continue_to_toss')} →'),
        ],
      ),
    );
  }

  Widget _teamManualField(String label, TextEditingController controller) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return TextFormField(
      controller: controller,
      style: TextStyle(color: colorScheme.onBackground),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.7)),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
        border: const OutlineInputBorder(),
        suffixIcon: _allTeams.isEmpty
            ? null
            : PopupMenuButton<String>(
                icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface.withOpacity(0.7)),
                tooltip: 'Select from existing teams',
                color: colorScheme.surface,
                onSelected: (name) => setState(() => controller.text = name),
                itemBuilder: (_) => _allTeams.map((t) => PopupMenuItem(
                  value: t.name,
                  child: Text(t.name, style: TextStyle(color: colorScheme.onSurface)),
                )).toList(),
              ),
      ),
    );
  }

  Widget _buildStep1() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final t1Name = _teamName(_team1Id, l10n);
    final t2Name = _teamName(_team2Id, l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.translate('toss_winner'), style: TextStyle(color: colorScheme.onBackground.withOpacity(0.7), fontSize: 16)),
          const Gap(16),
          _tossTeamButton(t1Name, _team1Id!),
          const Gap(12),
          _tossTeamButton(t2Name, _team2Id!),
          const Gap(32),
          if (_tossWinnerId != null) ...[
            Text(l10n.translate('toss_decision'), style: TextStyle(color: colorScheme.onBackground.withOpacity(0.7), fontSize: 16)),
            const Gap(12),
            Row(
              children: [
                Expanded(child: _tossDecisionButton(l10n.translate('bat'), TossDecision.bat, Icons.sports_cricket)),
                const Gap(12),
                Expanded(child: _tossDecisionButton(l10n.translate('bowl'), TossDecision.bowl, Icons.catching_pokemon)),
              ],
            ),
            const Gap(32),
            _nextButton('${l10n.translate('set_opening_players')} →'),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final l10n = AppLocalizations.of(context);
    
    final battingPlayers = _battingPlayers();
    final bowlingPlayers = _bowlingPlayers();
    final battingTeamName = _teamName(_battingTeamId(), l10n);
    final bowlingTeamName = _teamName(_bowlingTeamId(), l10n);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionLabel('$battingTeamName — ${l10n.translate('opening_players')}'),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: AppColors.pitchGreenLight, size: 20),
                tooltip: '${l10n.translate('add_player')} to ${_teamName(_battingTeamId(), l10n)}',
                onPressed: () => _addPlayerToTeam(_battingTeamId()),
              ),
            ],
          ),
          const Gap(8),
          ...battingPlayers.take(11).map((p) => _playerSelectorTile(
            player: p,
            isStriker: _openingStrikerId == p.id,
            isNonStriker: _openingNonStrikerId == p.id,
            onTapStriker: () => setState(() => _openingStrikerId = p.id),
            onTapNonStriker: () => setState(() => _openingNonStrikerId = p.id),
          )),
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: _sectionLabel('$bowlingTeamName — ${l10n.translate('opening_bowler')}'),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: Colors.redAccent, size: 20),
                tooltip: '${l10n.translate('add_player')} to ${_teamName(_bowlingTeamId(), l10n)}',
                onPressed: () => _addPlayerToTeam(_bowlingTeamId()),
              ),
            ],
          ),
          const Gap(8),
          ...bowlingPlayers.where((p) => p.bowlingStyle != BowlingStyle.none).take(6).map((p) => _bowlerSelectorTile(
            player: p,
            isSelected: _openingBowlerId == p.id,
            onTap: () => setState(() => _openingBowlerId = p.id),
          )),
          if (bowlingPlayers.where((p) => p.bowlingStyle != BowlingStyle.none).isEmpty)
            ...bowlingPlayers.take(6).map((p) => _bowlerSelectorTile(
              player: p,
              isSelected: _openingBowlerId == p.id,
              onTap: () => setState(() => _openingBowlerId = p.id),
            )),
          const Gap(16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: Text(l10n.translate('exchange_between_teams'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _exchangePlayers,
          ),
          const Gap(32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liveRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.sports_score_rounded, size: 24),
            label: Text('🔴  ${l10n.translate('start_scoring')}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            onPressed: _startMatch,
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5));

  Widget _tossTeamButton(String name, String teamId) {
    final isSelected = _tossWinnerId == teamId;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _tossWinnerId = teamId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pitchGreen.withOpacity(0.2) : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.pitchGreenLight : theme.dividerColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.check_circle_rounded : Icons.circle_outlined, color: isSelected ? AppColors.pitchGreenLight : colorScheme.onSurface.withOpacity(0.54)),
            const Gap(12),
            Text(name, style: TextStyle(color: isSelected ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _tossDecisionButton(String label, TossDecision decision, IconData icon) {
    final isSelected = _tossDecision == decision;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _tossDecision = decision),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.floodlightGold.withOpacity(0.15) : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.floodlightGold : theme.dividerColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.floodlightGold : colorScheme.onSurface.withOpacity(0.54), size: 28),
            const Gap(6),
            Text(label, style: TextStyle(color: isSelected ? AppColors.floodlightGold : colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _playerSelectorTile({
    required ScorerPlayer player,
    required bool isStriker,
    required bool isNonStriker,
    required VoidCallback onTapStriker,
    required VoidCallback onTapNonStriker,
  }) {
    final l10n = AppLocalizations.of(context);
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
          _pillButton(l10n.translate('striker'), isStriker, onTapStriker, Colors.blueAccent),
          const Gap(8),
          _pillButton(l10n.translate('non_striker'), isNonStriker, onTapNonStriker, AppColors.pitchGreenLight),
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

  Widget _nextButton(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.pitchGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: _nextStep,
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

class _PlayerPickDialog extends StatelessWidget {
  final String title;
  final List<ScorerPlayer> players;

  const _PlayerPickDialog({required this.title, required this.players});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: players.isEmpty
            ? Center(child: Text(l10n.translate('no_data'), style: TextStyle(color: colorScheme.onSurface.withOpacity(0.54))))
            : ListView.separated(
                itemCount: players.length,
                separatorBuilder: (_, __) => Divider(color: theme.dividerColor, height: 1),
                itemBuilder: (ctx, i) {
                  final p = players[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                      child: Text('${p.jerseyNumber ?? '?'}', style: const TextStyle(color: AppColors.pitchGreenLight, fontSize: 12)),
                    ),
                    title: Text(p.name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text(p.role.name, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.translate('cancel'), style: TextStyle(color: colorScheme.onSurface.withOpacity(0.54))),
        ),
      ],
    );
  }
}

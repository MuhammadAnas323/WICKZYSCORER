// lib/ui/scorer/squad_setup/view/squad_setup_screen.dart
// Squad setup for a match — both teams choose their playing XI and can add or
// edit players before moving on to the toss.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/shared/player_form_dialog.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class SquadSetupScreen extends ConsumerStatefulWidget {
  final String matchId;

  const SquadSetupScreen({super.key, required this.matchId});

  @override
  ConsumerState<SquadSetupScreen> createState() => _SquadSetupScreenState();
}

class _SquadSetupScreenState extends ConsumerState<SquadSetupScreen> {
  ScorerMatch? _match;
  ScorerTeam? _team1;
  ScorerTeam? _team2;
  List<ScorerPlayer> _team1Players = [];
  List<ScorerPlayer> _team2Players = [];
  final Set<String> _xi1 = {};
  final Set<String> _xi2 = {};
  bool _loading = true;
  bool _saving = false;

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
      _team1 = t1;
      _team2 = t2;
      _team1Players = p1;
      _team2Players = p2;
      _xi1
        ..clear()
        ..addAll(match.playingXI1.isNotEmpty
            ? match.playingXI1
            : p1.map((p) => p.id));
      _xi2
        ..clear()
        ..addAll(match.playingXI2.isNotEmpty
            ? match.playingXI2
            : p2.map((p) => p.id));
      _loading = false;
    });
  }

  Future<void> _deleteMatch(AppLocalizations l10n) async {
    final match = _match;
    if (match == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(l10n.translate('delete_match'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          '${l10n.translate('delete_match_permanently')} (${_teamName(_team1)} vs ${_teamName(_team2)})',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.translate('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.liveRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.translate('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(scorerRepositoryProvider);
    await repo.deleteMatch(match.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Match deleted'), backgroundColor: AppColors.liveRed),
    );
    context.go('/scorer/matches');
  }

  Future<void> _addPlayer(String teamId, ScorerTeam? team) async {
    final repo = ref.read(scorerRepositoryProvider);
    final created = await showDialog<ScorerPlayer>(
      context: context,
      builder: (ctx) => PlayerFormDialog(
        teamId: teamId,
        tournamentId: team?.tournamentId ?? 't_custom',
        onSave: (player) async {
          await repo.savePlayer(player);
        },
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      if (teamId == _match?.team1Id) {
        _team1Players.add(created);
        _xi1.add(created.id);
      } else {
        _team2Players.add(created);
        _xi2.add(created.id);
      }
    });
  }

  Future<void> _editPlayer(ScorerPlayer player) async {
    final repo = ref.read(scorerRepositoryProvider);
    final updated = await showDialog<ScorerPlayer>(
      context: context,
      builder: (ctx) => PlayerFormDialog(
        teamId: player.teamId,
        tournamentId: player.tournamentId,
        existingPlayer: player,
        onSave: (saved) async {
          await repo.savePlayer(saved);
        },
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final isTeam1 = updated.teamId == _match?.team1Id;
      final list = isTeam1 ? _team1Players : _team2Players;
      final index = list.indexWhere((p) => p.id == updated.id);
      if (index >= 0) list[index] = updated;
    });
  }

  Future<void> _removePlayer(ScorerPlayer player) async {
    final repo = ref.read(scorerRepositoryProvider);
    await repo.deletePlayer(player.id);
    if (!mounted) return;
    setState(() {
      if (player.teamId == _match?.team1Id) {
        _team1Players.removeWhere((p) => p.id == player.id);
        _xi1.remove(player.id);
      } else {
        _team2Players.removeWhere((p) => p.id == player.id);
        _xi2.remove(player.id);
      }
    });
  }

  bool get _canStart => _xi1.isNotEmpty && _xi2.isNotEmpty;

  Future<void> _continueToToss(AppLocalizations l10n) async {
    final match = _match;
    if (match == null) return;
    if (!_canStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('select_min_player')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(scorerRepositoryProvider);
    final updated = match.copyWith(
      playingXI1: _xi1.toList(),
      playingXI2: _xi2.toList(),
    );
    await repo.saveMatch(updated);
    if (!mounted) return;
    context.pushReplacement('/scorer/toss?matchId=${match.id}');
  }

  String _teamName(ScorerTeam? team) => team?.name ?? 'Team';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.translate('set_squads'),
            style: AppTextStyles.titleMedium(cs.onBackground)
                .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
        actions: [
          if (_match != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.liveRed),
              tooltip: l10n.translate('delete_match'),
              onPressed: () => _deleteMatch(l10n),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : _match == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.translate('match_not_found'),
                          style:
                              TextStyle(color: cs.onBackground, fontSize: 18)),
                      const Gap(16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pitchGreen),
                        onPressed: () => context.pop(),
                        child: Text(l10n.translate('back')),
                      ),
                    ],
                  ),
                )
              : _buildForm(l10n),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    final match = _match!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.pitchGreen,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                _teamSection(
                  title: _teamName(_team1),
                  players: _team1Players,
                  xi: _xi1,
                  teamId: match.team1Id,
                  accent:
                      isDark ? AppColors.pitchGreenLight : AppColors.pitchGreen,
                  l10n: l10n,
                ),
                const Gap(24),
                _teamSection(
                  title: _teamName(_team2),
                  players: _team2Players,
                  xi: _xi2,
                  teamId: match.team2Id,
                  accent: Colors.blueAccent,
                  l10n: l10n,
                ),
                const Gap(32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.liveRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sports_score_rounded, size: 24),
                  label: Text(
                      _saving
                          ? l10n.translate('saving')
                          : l10n.translate('start_scoring_title'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: (_saving || !_canStart)
                      ? null
                      : () => _continueToToss(l10n),
                ),
                if (!_canStart) ...[
                  const Gap(8),
                  Text(
                    l10n.translate('select_min_player'),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Gap(40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _teamSection({
    required String title,
    required List<ScorerPlayer> players,
    required Set<String> xi,
    required String teamId,
    required Color accent,
    required AppLocalizations l10n,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: cs.onBackground,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
            ),
            Text('${xi.length} ${l10n.translate('in_squad')}',
                style: TextStyle(
                    color: accent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const Gap(4),
        Text(
          l10n.translate('tap_checkbox'),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const Gap(12),
        if (players.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Text(l10n.translate('no_players_yet'),
                    style: const TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center),
                const Gap(10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withOpacity(0.5)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(l10n.translate('add_player'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _addPlayer(
                      teamId, teamId == _match?.team1Id ? _team1 : _team2),
                ),
              ],
            ),
          )
        else
          ...players.map((p) => _playerTile(
                player: p,
                inXi: xi.contains(p.id),
                accent: accent,
                onToggle: () => setState(() {
                  if (xi.contains(p.id)) {
                    xi.remove(p.id);
                  } else {
                    xi.add(p.id);
                  }
                }),
                onEdit: () => _editPlayer(p),
                onRemove: () => _removePlayer(p),
                l10n: l10n,
              )),
        const Gap(10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withOpacity(0.5)),
            ),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(l10n.translate('add_player'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () =>
                _addPlayer(teamId, teamId == _match?.team1Id ? _team1 : _team2),
          ),
        ),
      ],
    );
  }

  Widget _playerTile({
    required ScorerPlayer player,
    required bool inXi,
    required Color accent,
    required VoidCallback onToggle,
    required VoidCallback onEdit,
    required VoidCallback onRemove,
    required AppLocalizations l10n,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            inXi ? accent.withOpacity(0.08) : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: inXi
                ? accent.withOpacity(0.4)
                : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(
                    inXi
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: inXi ? accent : Colors.white38,
                    size: 26,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.name,
                            style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(
                          '${player.jerseyNumber != null ? '#${player.jerseyNumber} • ' : ''}${player.role.name.toUpperCase()}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white54, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

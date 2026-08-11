// lib/ui/scorer/schedule/view/schedule_builder_screen.dart
// Manual Schedule Builder — user picks the teams (from current tournament),
// date/time and venue for every match, and organises them into stages
// (e.g. Group, Quarter Final, Semi Final, Final).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

enum _LoserFate { nextStage, nextMatch, eliminate }

class MatchDraft {
  final String teamAId;
  final String teamBId;
  final DateTime? scheduled;
  final String? venue;
  const MatchDraft({
    required this.teamAId,
    required this.teamBId,
    this.scheduled,
    this.venue,
  });
}

class ScheduleBuilderScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const ScheduleBuilderScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<ScheduleBuilderScreen> createState() =>
      _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState extends ConsumerState<ScheduleBuilderScreen> {
  List<ScheduleStage> _stages = [];
  List<ScorerTeam> _teams = [];
  bool _isLoading = true;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _id(String prefix) =>
      '${prefix}_${widget.tournamentId}_${_serial++}_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final teams = await repo.getTeamsByTournament(widget.tournamentId);
    final stages = await repo.getSchedule(widget.tournamentId);
    if (!mounted) return;
    setState(() {
      _teams = teams;
      _stages = stages;
      _isLoading = false;
    });
  }

  Future<void> _persist() async {
    var stageOrder = 0;
    final normalized = _stages.map((s) {
      var fxOrder = 0;
      return s.copyWith(
        order: stageOrder++,
        fixtures: s.fixtures.map((f) => f.copyWith(order: fxOrder++)).toList(),
      );
    }).toList();
    await ref
        .read(scorerRepositoryProvider)
        .saveSchedule(widget.tournamentId, normalized);
  }

  Future<void> _save() async {
    await _persist();
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.translate('save')),
        backgroundColor: AppColors.pitchGreen,
      ));
      Navigator.of(context).pop(true);
    }
  }

  // ── Row management ──────────────────────────────────────────────────────

  void _addStage() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(l10n.translate('add_stage'),
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'e.g. Group A, Quarter Final, Semi Final, Final',
              hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38)),
              labelText: l10n.translate('tournament_name'),
              labelStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.translate('cancel'),
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.54)))),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _stages.add(ScheduleStage(
                      id: _id('stage'),
                      name: name,
                      order: _stages.length,
                      type: ScheduleStageType.custom,
                      fixtures: const [],
                    ));
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text(l10n.translate('save'),
                  style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
    _persist();
  }

  void _renameStage(int index) {
    final stage = _stages[index];
    final controller = TextEditingController(text: stage.name);
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(l10n.translate('rename_stage'),
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
                labelText: l10n.translate('tournament_name'),
                labelStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.translate('cancel'),
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.54)))),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                setState(() {
                  _stages[index] = _stages[index]
                      .copyWith(name: name.isEmpty ? stage.name : name);
                });
                Navigator.pop(ctx);
              },
              child: Text(l10n.translate('save'),
                  style: TextStyle(color: theme.colorScheme.onPrimary)),
            ),
          ],
        );
      },
    );
    _persist();
  }

  void _removeStage(int index) {
    setState(() => _stages = List.from(_stages)..removeAt(index));
    _persist();
  }

  void _moveStage(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _stages.length) return;
    setState(() {
      final lst = List<ScheduleStage>.from(_stages);
      final item = lst.removeAt(index);
      lst.insert(target, item);
      _stages = lst;
    });
    _persist();
  }

  Future<void> _addFixture(int stageIndex) async {
    final l10n = AppLocalizations.of(context);
    if (_teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.translate('create_tournament_hint')),
      ));
      return;
    }
    final draft = await showModalBottomSheet<MatchDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MatchEditSheet(
        teams: _activeTeams,
        existingFixtures: _stages[stageIndex].fixtures,
        title: l10n.translate('add_match'),
      ),
    );
    if (draft == null) return;
    setState(() {
      final stage = _stages[stageIndex];
      final fixtures = List<ScheduleFixture>.from(stage.fixtures);
      fixtures.add(ScheduleFixture(
        id: _id('fx'),
        order: fixtures.length,
        teamASource: Source.team(draft.teamAId),
        teamBSource: Source.team(draft.teamBId),
        resolvedTeamAId: draft.teamAId,
        resolvedTeamBId: draft.teamBId,
        scheduledDateTime: draft.scheduled,
        venue: draft.venue,
        status: FixtureStatus.ready,
      ));
      _stages[stageIndex] = stage.copyWith(fixtures: fixtures);
    });
    _persist();
  }

  Future<void> _editFixture(int stageIdx, int fxIdx) async {
    final l10n = AppLocalizations.of(context);
    final stage = _stages[stageIdx];
    final fx = stage.fixtures[fxIdx];
    final draft = await showModalBottomSheet<MatchDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MatchEditSheet(
        teams: _editTeamsFor(fx),
        existingFixtures: stage.fixtures,
        title: l10n.translate('edit_fixture'),
        initialTeamAId: fx.resolvedTeamAId ?? fx.teamASource.teamId,
        initialTeamBId: fx.resolvedTeamBId ?? fx.teamBSource.teamId,
        initialScheduled: fx.scheduledDateTime,
        initialVenue: fx.venue,
      ),
    );
    if (draft == null) return;
    setState(() {
      final fixtures = List<ScheduleFixture>.from(stage.fixtures);
      fixtures[fxIdx] = fx.copyWith(
        teamASource: Source.team(draft.teamAId),
        teamBSource: Source.team(draft.teamBId),
        resolvedTeamAId: draft.teamAId,
        resolvedTeamBId: draft.teamBId,
        scheduledDateTime: draft.scheduled,
        venue: draft.venue,
      );
      _stages[stageIdx] = _stages[stageIdx].copyWith(fixtures: fixtures);
    });
    _persist();
  }

  void _removeFixture(int stageIdx, int fxIdx) {
    setState(() {
      final stage = _stages[stageIdx];
      _stages[stageIdx] =
          stage.copyWith(fixtures: List.from(stage.fixtures)..removeAt(fxIdx));
    });
    _persist();
  }

  /// Declares the winner of a fixture: the winner stays in the tournament and is
  /// available in the next level, while the loser is marked eliminated (kept in the
  /// list but no longer shown in new-match team pickers of later stages).
  Future<void> _declareResult(int stageIdx, int fxIdx) async {
    final stage = _stages[stageIdx];
    final fx = stage.fixtures[fxIdx];

    if (fx.status == FixtureStatus.completed) {
      setState(() {
        final fixtures = List<ScheduleFixture>.from(stage.fixtures);
        fixtures[fxIdx] = fx.copyWith(status: FixtureStatus.ready);
        _stages[stageIdx] = _stages[stageIdx].copyWith(fixtures: fixtures);
      });
      _persist();
      return;
    }

    final aName = _teamName(fx.resolvedTeamAId);
    final bName = _teamName(fx.resolvedTeamBId);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.translate('toss_winner_query'),
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events,
                  color: AppColors.pitchGreenLight),
              title: Text('$aName ${l10n.translate('winner')}',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              subtitle: Text(l10n.translate('next_stage'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events,
                  color: AppColors.pitchGreenLight),
              title: Text('$bName ${l10n.translate('winner')}',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              subtitle: Text(l10n.translate('next_stage'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 1),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (!mounted) return;

    final winnerId = choice == 0 ? fx.resolvedTeamAId : fx.resolvedTeamBId;
    final loserId = choice == 0 ? fx.resolvedTeamBId : fx.resolvedTeamAId;
    final winnerName = _teamName(winnerId);
    final loserName = _teamName(loserId);

    // Step 2 — where should the loser go? (winner auto-advances to the next level)
    final fate = await showModalBottomSheet<_LoserFate>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                children: [
                  Text(l10n.translate('match_summary'),
                      style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('$winnerName ${l10n.translate('winner')}',
                      style: const TextStyle(
                          color: AppColors.pitchGreenLight,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  Text('${l10n.translate('loser_fate')} $loserName?',
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 12)),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            ListTile(
              leading: const Icon(Icons.trending_up,
                  color: AppColors.pitchGreenLight),
              title: Text(l10n.translate('next_stage'),
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              subtitle: Text(l10n.translate('next_stage'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, _LoserFate.nextStage),
            ),
            ListTile(
              leading:
                  const Icon(Icons.replay, color: AppColors.pitchGreenLight),
              title: Text(l10n.translate('next_match'),
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              subtitle: Text(l10n.translate('next_match'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, _LoserFate.nextMatch),
            ),
            ListTile(
              leading: const Icon(Icons.highlight_off_outlined,
                  color: Colors.redAccent),
              title: Text(l10n.translate('eliminate'),
                  style: const TextStyle(color: Colors.redAccent)),
              subtitle: Text(l10n.translate('eliminate'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 11)),
              onTap: () => Navigator.pop(ctx, _LoserFate.eliminate),
            ),
          ],
        ),
      ),
    );
    if (fate == null) return;

    setState(() {
      final fixtures = List<ScheduleFixture>.from(stage.fixtures);
      fixtures[fxIdx] = fx.copyWith(status: FixtureStatus.completed);
      _stages[stageIdx] = _stages[stageIdx].copyWith(fixtures: fixtures);
    });

    if (fate == _LoserFate.eliminate) {
      final loserTeam = _teams.where((t) => t.id == loserId).firstOrNull;
      if (loserTeam != null && !loserTeam.isEliminated) {
        await ref
            .read(scorerRepositoryProvider)
            .saveTeam(loserTeam.copyWith(isEliminated: true));
        if (mounted) {
          setState(() {
            _teams = _teams
                .map(
                    (t) => t.id == loserId ? t.copyWith(isEliminated: true) : t)
                .toList();
          });
        }
      }
    }
    await _persist();
  }

  String _teamName(String? id) => id == null
      ? ''
      : (_teams.where((t) => t.id == id).firstOrNull?.name ?? id);

  List<ScorerTeam> get _activeTeams =>
      _teams.where((t) => !t.isEliminated).toList();

  /// For editing an existing fixture: active teams, plus the currently selected
  /// teams of the fixture (even if eliminated) so the dropdown value is valid.
  List<ScorerTeam> _editTeamsFor(ScheduleFixture fx) {
    final selected = <String>{
      if (fx.resolvedTeamAId != null) fx.resolvedTeamAId!,
      if (fx.resolvedTeamBId != null) fx.resolvedTeamBId!,
    };
    final result = List<ScorerTeam>.from(_activeTeams);
    for (final t in _teams) {
      if (selected.contains(t.id) && !result.any((r) => r.id == t.id)) {
        result.add(t);
      }
    }
    return result;
  }

  bool _isEliminated(String? id) =>
      id != null &&
      (_teams.where((t) => t.id == id).firstOrNull?.isEliminated ?? false);

  /// Winner of a completed fixture is the participating team that is still active.
  String? _winnerOf(ScheduleFixture fx) {
    if (fx.status != FixtureStatus.completed) return null;
    if (fx.resolvedTeamAId != null && !_isEliminated(fx.resolvedTeamAId)) {
      return fx.resolvedTeamAId;
    }
    if (fx.resolvedTeamBId != null && !_isEliminated(fx.resolvedTeamBId)) {
      return fx.resolvedTeamBId;
    }
    return null;
  }

  String _fmtTime(DateTime? d) {
    if (d == null) return 'Not set';
    final local = d.toLocal();
    final date = '${local.day}/${local.month}/${local.year}';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: Text(l10n.translate('manual_schedule'),
            style: TextStyle(
                color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded,
                color: AppColors.pitchGreenLight, size: 26),
            tooltip: l10n.translate('save'),
            onPressed: _save,
          ),
          const Gap(8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : RefreshIndicator(
              color: AppColors.pitchGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headerCard(),
                  const Gap(16),
                  if (_stages.isEmpty && _teams.isEmpty)
                    _noTeamsCard()
                  else
                    ...List.generate(_stages.length, (i) => _stageCard(i)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.pitchGreenLight,
                      side: BorderSide(
                          color: AppColors.pitchGreen.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.translate('add_stage'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _addStage,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _headerCard() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('manual_schedule'),
              style:
                  TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
          const Gap(4),
          Text(
              l10n.translate('create_match_hint'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 12)),
          const Gap(8),
          Row(children: [
            const Icon(Icons.group_outlined,
                color: AppColors.pitchGreenLight, size: 16),
            const Gap(4),
            Flexible(
              child: Text('${_teams.length} ${l10n.translate('teams')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _noTeamsCard() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: Text(
        l10n.translate('create_tournament_hint'),
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54)),
      ),
    );
  }

  Widget _stageCard(int index) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stage = _stages[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(_stageIcon(stage),
                      color: AppColors.pitchGreenLight, size: 22),
                ),
                const Gap(10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.name,
                          style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                          softWrap: true,
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                        ),
                        const Gap(2),
                        Text('${stage.fixtures.length} ${l10n.translate('matches')}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                _stageActionIcon(
                    Icons.keyboard_arrow_up, () => _moveStage(index, -1), color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54)),
                _stageActionIcon(
                    Icons.keyboard_arrow_down, () => _moveStage(index, 1), color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54)),
                _stageActionIcon(
                    Icons.edit_outlined, () => _renameStage(index), color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54)),
                _stageActionIcon(
                    Icons.delete_outline, () => _removeStage(index),
                    color: Colors.redAccent),
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),
          ...stage.fixtures.asMap().entries.map((entry) {
              final f = entry.key;
              final fx = entry.value;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fx.status == FixtureStatus.completed
                                  ? '${l10n.translate('winner')}: ${_teamName(_winnerOf(fx))}'
                                  : '${_teamName(fx.resolvedTeamAId)} vs ${_teamName(fx.resolvedTeamBId)}',
                              style: TextStyle(
                                color: fx.status == FixtureStatus.completed
                                    ? AppColors.pitchGreenLight
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const Gap(4),
                            Row(children: [
                              Icon(Icons.schedule,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38), size: 12),
                              const Gap(4),
                              Text(_fmtTime(fx.scheduledDateTime),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                              if ((fx.venue ?? '').isNotEmpty) ...[
                                const Gap(10),
                                Icon(Icons.location_on,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38), size: 12),
                                const Gap(4),
                                Flexible(
                                    child: Text(fx.venue!,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 11))),
                              ],
                            ]),
                            if (_isEliminated(fx.resolvedTeamAId))
                              _eliminatedTag(_teamName(fx.resolvedTeamAId))
                            else if (_isEliminated(fx.resolvedTeamBId))
                              _eliminatedTag(_teamName(fx.resolvedTeamBId)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          fx.status == FixtureStatus.completed
                              ? Icons.replay
                              : Icons.emoji_events_outlined,
                          color: fx.status == FixtureStatus.completed
                              ? AppColors.charcoal200
                              : AppColors.floodlightGold,
                          size: 20,
                        ),
                        tooltip: fx.status == FixtureStatus.completed
                            ? 'Reset result'
                            : l10n.translate('declare_result'),
                        onPressed: () => _declareResult(index, f),
                      ),
                      IconButton(
                          icon: Icon(Icons.edit_outlined,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38), size: 16),
                          onPressed: () => _editFixture(index, f)),
                      IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 16),
                          onPressed: () => _removeFixture(index, f)),
                    ],
                  ),
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextButton.icon(
              onPressed: () => _addFixture(index),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.translate('add_match')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eliminatedTag(String name) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$name — Eliminated',
            style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  IconData _stageIcon(ScheduleStage stage) {
    final lower = stage.name.toLowerCase();
    if (lower.contains('final')) return Icons.emoji_events_outlined;
    if (lower.contains('semi')) return Icons.looks_two;
    if (lower.contains('quarter')) return Icons.looks_4;
    if (lower.contains('group')) return Icons.groups_outlined;
    return Icons.more_horiz;
  }

  Widget _stageActionIcon(IconData icon, VoidCallback onPressed,
      {Color color = Colors.white54}) {
    return IconButton(
      icon: Icon(icon, color: color, size: 18),
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
    );
  }
}

class _MatchEditSheet extends StatefulWidget {
  final List<ScorerTeam> teams;
  final List<ScheduleFixture> existingFixtures;
  final String title;
  final String? initialTeamAId;
  final String? initialTeamBId;
  final DateTime? initialScheduled;
  final String? initialVenue;

  const _MatchEditSheet({
    required this.teams,
    required this.existingFixtures,
    required this.title,
    this.initialTeamAId,
    this.initialTeamBId,
    this.initialScheduled,
    this.initialVenue,
  });

  @override
  State<_MatchEditSheet> createState() => _MatchEditSheetState();
}

class _MatchEditSheetState extends State<_MatchEditSheet> {
  late String? _teamA;
  late String? _teamB;
  late DateTime? _scheduled;
  late TextEditingController _venueCtrl;

  @override
  void initState() {
    super.initState();
    _teamA = widget.initialTeamAId;
    _teamB = widget.initialTeamBId;
    _scheduled = widget.initialScheduled;
    _venueCtrl = TextEditingController(text: widget.initialVenue ?? '');
  }

  @override
  void dispose() {
    _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = _scheduled ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Match date',
    );
    if (pickedDate == null) return;
    final currentTime = TimeOfDay.fromDateTime(now);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: 'Match time',
    );
    if (pickedTime == null) return;
    setState(() {
      _scheduled = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _fmtTime(DateTime? d) {
    if (d == null) return 'Set date & time';
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year}  $hh:$mm';
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final a = _teamA;
    final b = _teamB;
    if (a == null || b == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.translate('select_teams'))));
      return;
    }
    if (a == b) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('select_different_teams'))));
      return;
    }
    Navigator.of(context).pop(MatchDraft(
      teamAId: a,
      teamBId: b,
      scheduled: _scheduled,
      venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Gap(4),
              Text(l10n.translate('create_match_hint'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.54), fontSize: 12)),
              const Gap(16),
              _teamDropdown(
                  l10n.translate('team_a'), _teamA, (id) => setState(() => _teamA = id)),
              const Gap(12),
              _teamDropdown(
                  l10n.translate('team_b'), _teamB, (id) => setState(() => _teamB = id)),
              const Gap(12),
              InkWell(
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.translate('match_time'),
                    prefixIcon: const Icon(Icons.schedule,
                        color: AppColors.pitchGreenLight, size: 20),
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant,
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(_fmtTime(_scheduled),
                      style:
                          TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
                ),
              ),
              const Gap(12),
              TextField(
                controller: _venueCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: l10n.translate('venue'),
                  labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant,
                  border: const OutlineInputBorder(),
                ),
              ),
              const Gap(20),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pitchGreen,
                    foregroundColor: Colors.white),
                child: Text(l10n.translate('save'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamDropdown(
      String label, String? value, ValueChanged<String?> onChanged) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: theme.colorScheme.surface,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant,
        border: const OutlineInputBorder(),
      ),
      items: widget.teams
          .map((t) => DropdownMenuItem(
              value: t.id,
              child: Text(t.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      hint: Text(l10n.translate('select_teams'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38))),
    );
  }
}

// lib/ui/scorer/start_scoring/view/schedule_match_screen.dart
// Schedule an upcoming match for a tournament (teams, venue, date/time).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class ScheduleMatchScreen extends ConsumerStatefulWidget {
  final String? tournamentId;

  const ScheduleMatchScreen({super.key, this.tournamentId});

  @override
  ConsumerState<ScheduleMatchScreen> createState() =>
      _ScheduleMatchScreenState();
}

class _ScheduleMatchScreenState extends ConsumerState<ScheduleMatchScreen> {
  ScorerTournament? _tournament;
  List<ScorerTeam> _teams = [];
  bool _loading = true;
  bool _saving = false;

  String? _team1Id;
  String? _team2Id;
  String _venue = '';
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    if (widget.tournamentId != null) {
      final t = await repo.getTournament(widget.tournamentId!);
      final teams = await repo.getTeamsByTournament(widget.tournamentId!);
      if (!mounted) return;
      setState(() {
        _tournament = t;
        _teams = teams;
        _loading = false;
      });
    } else {
      final tournaments = await repo.getTournaments();
      if (!mounted) return;
      if (tournaments.isNotEmpty) {
        final t = tournaments.first;
        final teams = await repo.getTeamsByTournament(t.id);
        if (!mounted) return;
        setState(() {
          _tournament = t;
          _teams = teams;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _schedule() async {
    final l10l = AppLocalizations.of(context);
    if (_team1Id == null || _team2Id == null || _team1Id == _team2Id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10l.translate('select_different_teams')), backgroundColor: Colors.red),
      );
      return;
    }
    if (_venue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10l.translate('enter_venue_error')), backgroundColor: Colors.red),
      );
      return;
    }
    if (_tournament == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10l.translate('no_tournament_selected')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(scorerRepositoryProvider);
    final t = _tournament!;
    final match = ScorerMatch(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      tournamentId: t.id,
      team1Id: _team1Id!,
      team2Id: _team2Id!,
      venue: _venue,
      dateTime: _dateTime,
      format: t.format,
      overs: t.format == MatchFormat.t20 ? 20 : t.format == MatchFormat.odi ? 50 : t.customOvers,
      status: MatchStatus.upcoming,
      playingXI1: const [],
      playingXI2: const [],
      currentInnings: 1,
    );

    await repo.saveMatch(match);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10l.translate('match_scheduled')), backgroundColor: AppColors.pitchGreen),
    );
    context.pop(true);
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
        title: Text(l10n.translate('schedule_match'),
            style: AppTextStyles.titleMedium(colorScheme.onBackground)
                .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : _tournament == null
              ? _noTournament()
              : _buildForm(),
    );
  }

  Widget _noTournament() {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 72, color: AppColors.charcoal400),
          const Gap(16),
          Text(
            l10n.translate('no_tournaments_available'),
            style: TextStyle(color: colorScheme.onBackground, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          Text(
            l10n.translate('create_tournament_hint'),
            style: TextStyle(color: colorScheme.onBackground.withOpacity(0.54), fontSize: 13),
          ),
          const Gap(24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: Text(l10n.translate('create_tournament'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => context.push('/scorer/tournaments/create'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final teams = _teams;

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
                const Icon(Icons.emoji_events_rounded, color: AppColors.pitchGreenLight, size: 22),
                const Gap(10),
                Expanded(
                  child: Text(
                    _tournament!.name,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _tournament!.format.name.toUpperCase(),
                  style: const TextStyle(color: AppColors.pitchGreenLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Gap(24),
          _label(l10n.translate('teams')),
          const Gap(8),
          _teamDropdown(l10n.translate('select_teams'), _team1Id, (val) => setState(() => _team1Id = val), teams),
          const Gap(16),
          _teamDropdown(l10n.translate('select_teams'), _team2Id, (val) => setState(() => _team2Id = val), teams),
          const Gap(24),
          _label(l10n.translate('venue')),
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
          const Gap(24),
          _label(l10n.translate('match_time')),
          const Gap(8),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.pitchGreenLight),
                  const Gap(12),
                  Text(
                    _dateTime.toLocal().toString().replaceRange(16, 19, ''),
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const Gap(32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded, size: 24),
            label: Text(_saving ? l10n.translate('scheduling') : l10n.translate('schedule_match'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _saving ? null : _schedule,
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
      );

  Widget _teamDropdown(
    String hint,
    String? selected,
    ValueChanged<String?> onChanged,
    List<ScorerTeam> teams,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: selected,
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
        border: const OutlineInputBorder(),
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.38)),
      ),
      items: teams
          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

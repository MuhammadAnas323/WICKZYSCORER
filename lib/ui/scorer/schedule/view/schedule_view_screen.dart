// lib/ui/scorer/schedule/view/schedule_view_screen.dart
// Schedule View — read-only overview of a tournament's stages & fixtures.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class ScheduleViewScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const ScheduleViewScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<ScheduleViewScreen> createState() => _ScheduleViewScreenState();
}

class _ScheduleViewScreenState extends ConsumerState<ScheduleViewScreen> {
  List<ScheduleStage> _stages = [];
  List<ScorerTeam> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final stages = await repo.getSchedule(widget.tournamentId);
    final teams = await repo.getTeamsByTournament(widget.tournamentId);
    if (!mounted) return;
    setState(() {
      _stages = stages;
      _teams = teams;
      _isLoading = false;
    });
  }

  String _teamName(String? id) =>
      id == null ? 'TBD' : (_teams.where((t) => t.id == id).firstOrNull?.name ?? id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text('Schedule', style: AppTextStyles.headlineSmall(Colors.white)),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await context.push('/scorer/tournaments/${widget.tournamentId}/schedule-builder');
              _load();
            },
            icon: Icon(Icons.edit_outlined, color: AppColors.pitchGreenLight, size: 18),
            label: const Text('Edit', style: TextStyle(color: AppColors.pitchGreenLight)),
          ),
          const Gap(8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : RefreshIndicator(
              color: AppColors.pitchGreen,
              onRefresh: _load,
              child: _stages.isEmpty ? _empty() : _list(),
            ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.calendar_month_outlined, color: Colors.grey, size: 56),
        const Gap(12),
        const Text(
          'No schedule yet',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Gap(4),
        const Text(
          'Build a schedule from templates to organise stages & fixtures.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const Gap(20),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.pitchGreen, foregroundColor: Colors.white),
            onPressed: () async {
              await context.push('/scorer/tournaments/${widget.tournamentId}/schedule-builder');
              _load();
            },
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Build Schedule'),
          ),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var s = 0; s < _stages.length; s++) _stageCard(_stages[s]),
      ],
    );
  }

  Widget _stageCard(ScheduleStage stage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(
                  stage.type == ScheduleStageType.knockout
                      ? Icons.emoji_events_outlined
                      : stage.type == ScheduleStageType.roundRobin
                          ? Icons.repeat_rounded
                          : Icons.more_horiz,
                  color: AppColors.pitchGreenLight,
                  size: 18,
                ),
                const Gap(8),
                Expanded(
                  child: Text(stage.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text('${stage.fixtures.length} fixtures',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          if (stage.fixtures.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No fixtures', style: TextStyle(color: Colors.white38, fontSize: 12)))
          else
            ...stage.fixtures.map((f) => _fixtureRow(f)),
        ],
      ),
    );
  }

  Widget _fixtureRow(ScheduleFixture fx) {
    final ready = fx.isReady && fx.resolvedTeamAId != null && fx.resolvedTeamBId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF181818), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _teamDot(fx.resolvedTeamAId != null),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _teamName(fx.resolvedTeamAId),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 7),
                    child: Text('vs', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                  Row(
                    children: [
                      _teamDot(fx.resolvedTeamBId != null),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _teamName(fx.resolvedTeamBId),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (fx.venue != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 7, top: 4),
                      child: Row(children: [
                        const Icon(Icons.location_on, color: Colors.white38, size: 12),
                        const SizedBox(width: 4),
                        Text(fx.venue!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ]),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusChip(fx.status),
                if (ready)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 28,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.pitchGreenLight,
                          backgroundColor: AppColors.pitchGreen.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {},
                        child: const Text('Start', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamDot(bool resolved) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: resolved ? AppColors.pitchGreenLight : Colors.white24,
      ),
    );
  }

  Widget _statusChip(FixtureStatus status) {
    final (label, color) = switch (status) {
      FixtureStatus.pending => ('Pending', AppColors.charcoal200),
      FixtureStatus.ready => ('Ready', AppColors.pitchGreenLight),
      FixtureStatus.live => ('Live', AppColors.liveRed),
      FixtureStatus.completed => ('Done', Colors.white54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
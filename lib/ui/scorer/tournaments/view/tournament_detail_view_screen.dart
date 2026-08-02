import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';

class TournamentDetailViewScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const TournamentDetailViewScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentDetailViewScreen> createState() => _TournamentDetailViewScreenState();
}

class _TournamentDetailViewScreenState extends ConsumerState<TournamentDetailViewScreen> {
  ScorerTournament? _tournament;
  List<ScorerTeam> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(scorerRepositoryProvider);
    final tournament = await repo.getTournament(widget.tournamentId);
    final teams = await repo.getTeamsByTournament(widget.tournamentId);
    setState(() {
      _tournament = tournament;
      _teams = teams;
      _isLoading = false;
    });
  }

  Future<void> _togglePayment(ScorerTeam team) async {
    final repo = ref.read(scorerRepositoryProvider);
    await repo.toggleTeamPaymentStatus(team.id);
    await _loadData();
  }

  Future<void> _deleteTeam(ScorerTeam team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Remove Team?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Remove "${team.name}" from this tournament?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(scorerRepositoryProvider);
      await repo.deleteTeam(team.id);
      await _loadData();
      ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
    }
  }

  Future<void> _deleteTournament() async {
    final codeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Delete Tournament', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeController,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Enter security code to delete',
            labelStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Color(0xFF2A2A2A),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final entered = codeController.text.trim();
    final t = _tournament;
    if (entered.isEmpty || t?.securityCode == null || entered != t!.securityCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect security code. Tournament not deleted.')),
      );
      return;
    }

    await ref.read(scorerRepositoryProvider).deleteTournament(widget.tournamentId);
    ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
    if (mounted) context.go('/scorer/tournaments');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
        body: const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen)),
      );
    }

    final t = _tournament;
    if (t == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
        body: const Center(child: Text('Tournament not found', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(t.name, style: AppTextStyles.headlineSmall(Colors.white), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.pitchGreenLight),
            tooltip: 'Edit Tournament',
            onPressed: () async {
              await context.push('/scorer/tournaments/${t.id}/edit');
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Tournament',
            onPressed: _deleteTournament,
          ),
          const Gap(4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.pitchGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, fontWeight: FontWeight.bold),
        label: const Text('Add Team', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await context.push('/scorer/teams?tournamentId=${t.id}');
          _loadData();
        },
      ),
      body: RefreshIndicator(
        color: AppColors.pitchGreen,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament Overview Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.pitchGreen.withOpacity(0.25), AppColors.darkSurface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: AppColors.floodlightGold, size: 28),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pitchGreen.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t.format.name.toUpperCase(),
                            style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 16),
                        const Gap(4),
                        Text(t.venue, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const Gap(16),
                        const Icon(Icons.sports_cricket, color: Colors.white54, size: 16),
                        const Gap(4),
                        Text('${t.customOvers} Overs', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Financial & Cash Prizes Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.floodlightGold.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.monetization_on_outlined, color: AppColors.floodlightGold, size: 20),
                        Gap(8),
                        Text('Financials & Cash Prizes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        _prizeTile('Entry Fee', t.entryFee != null ? '\$${t.entryFee!.toStringAsFixed(0)}' : 'Free', Colors.blueAccent),
                        const Gap(8),
                        _prizeTile('Winner Prize 🏆', t.winnerPrize != null ? '\$${t.winnerPrize!.toStringAsFixed(0)}' : 'TBD', AppColors.floodlightGold),
                        const Gap(8),
                        _prizeTile('Runner-Up 🥈', t.runnerUpPrize != null ? '\$${t.runnerUpPrize!.toStringAsFixed(0)}' : 'TBD', Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Match Schedule Card
              GestureDetector(
                onTap: () async {
                  await context.push('/scorer/tournaments/${t.id}/schedule');
                  _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.pitchGreen.withOpacity(0.18), AppColors.darkSurface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: AppColors.pitchGreenLight, size: 26),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Match Schedule',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Gap(2),
                            Text('Stages, fixtures & auto-advancement',
                                style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white38),
                    ],
                  ),
                ),
              ),
              const Gap(24),

              // Teams Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Participating Teams (${_teams.length})', style: AppTextStyles.titleLarge(Colors.white)),
                ],
              ),
              const Gap(12),

              if (_teams.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.groups_outlined, size: 48, color: Colors.grey),
                      const Gap(12),
                      const Text(
                        'No teams added yet',
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      const Text(
                        'Add participating teams to get started.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const Gap(16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pitchGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await context.push('/scorer/teams?tournamentId=${t.id}');
                          _loadData();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add First Team'),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _teams.length,
                  separatorBuilder: (_, __) => const Gap(10),
                  itemBuilder: (ctx, i) {
                    final team = _teams[i];
                    return GestureDetector(
                      onTap: () async {
                        await context.push('/scorer/teams/${team.id}/players');
                        _loadData();
                      },
                      child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                            child: Text(
                              team.shortCode.isNotEmpty ? team.shortCode : 'T',
                              style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('${team.playerIds.length} Squad Players', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          // Payment Toggle Chip
                          GestureDetector(
                            onTap: () => _togglePayment(team),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: team.isEntryFeePaid ? AppColors.pitchGreen.withOpacity(0.2) : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: team.isEntryFeePaid ? AppColors.pitchGreenLight : Colors.redAccent,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    team.isEntryFeePaid ? Icons.check_circle : Icons.pending,
                                    color: team.isEntryFeePaid ? AppColors.pitchGreenLight : Colors.redAccent,
                                    size: 14,
                                  ),
                                  const Gap(4),
                                  Text(
                                    team.isEntryFeePaid ? 'Paid' : 'Unpaid',
                                    style: TextStyle(
                                      color: team.isEntryFeePaid ? AppColors.pitchGreenLight : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                            tooltip: 'Team Details',
                            onPressed: () async {
                              await context.push('/scorer/teams/${team.id}/edit');
                              _loadData();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            tooltip: 'Remove Team',
                            onPressed: () => _deleteTeam(team),
                          ),
                        ],
                      ),
                    ),
                    );
                  },
                ),

              const Gap(80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prizeTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const Gap(2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

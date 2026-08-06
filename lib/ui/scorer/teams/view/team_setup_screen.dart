import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/ui/scorer/shared/player_form_dialog.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';

class TeamSetupScreen extends ConsumerStatefulWidget {
  final String? tournamentId;
  final String? teamId;

  const TeamSetupScreen({super.key, this.tournamentId, this.teamId});

  @override
  ConsumerState<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends ConsumerState<TeamSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _whatsappController = TextEditingController();
  List<ScorerPlayer> _players = [];
  bool _isLoading = false;
  String? _resolvedTournamentId;

  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _resolvedTournamentId = widget.tournamentId;
    if (widget.teamId != null) _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _isLoading = true);
    final repo = ref.read(scorerRepositoryProvider);
    final team = await repo.getTeam(widget.teamId!);
    if (team != null) {
      _nameController.text = team.name;
      _ownerNameController.text = team.ownerName ?? '';
      _whatsappController.text = team.whatsappNumber ?? '';
      _resolvedTournamentId = team.tournamentId;
      _isPaid = team.isEntryFeePaid;
      final players = await repo.getPlayersByTeam(team.id);
      setState(() => _players = players);
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(scorerRepositoryProvider);
    final id = widget.teamId ?? 'team_${DateTime.now().millisecondsSinceEpoch}';

    final trimmed = _nameController.text.trim();

    final team = ScorerTeam(
      id: id,
      name: trimmed,
      shortCode: trimmed.length >= 3
          ? trimmed.substring(0, 3).toUpperCase()
          : trimmed.toUpperCase(),
      tournamentId: _resolvedTournamentId ?? '',
      playerIds: _players.map((p) => p.id).toList(),
      isEntryFeePaid: _isPaid,
      ownerName: _ownerNameController.text.trim().isEmpty
          ? null
          : _ownerNameController.text.trim(),
      whatsappNumber: _whatsappController.text.trim().isEmpty
          ? null
          : _whatsappController.text.trim(),
    );

    await repo.saveTeam(team);
    for (final player in _players) {
      await repo.savePlayer(player.copyWith(
          teamId: id, tournamentId: _resolvedTournamentId ?? ''));
    }

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(l10n.translate('save')), backgroundColor: AppColors.pitchGreen),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if ((_resolvedTournamentId ?? '').isNotEmpty) {
      context.go('/scorer/tournaments/$_resolvedTournamentId');
    } else {
      context.pop();
    }

    // Refresh dashboards after leaving this screen; never blocks navigation.
    try {
      ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
    } catch (_) {}
  }

  void _addPlayer() {
    showDialog(
      context: context,
      builder: (ctx) => PlayerFormDialog(
        teamId: widget.teamId ?? 'temp',
        tournamentId: _resolvedTournamentId ?? '',
        onSave: (player) {
          setState(() => _players.add(player));
        },
      ),
    );
  }

  void _removePlayer(ScorerPlayer player) {
    setState(() => _players.remove(player));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textColor = theme.colorScheme.onBackground;
    final subTextColor = theme.colorScheme.onSurfaceVariant;
    final surfaceColor = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text(
          widget.teamId == null ? l10n.translate('create_tournament').replaceAll('Tournament', 'Team') : l10n.translate('edit_tournament').replaceAll('Tournament', 'Team'),
          style: AppTextStyles.headlineSmall(textColor),
        ),
        actions: [
          TextButton(
            onPressed: _saveTeam,
            child: Text(l10n.translate('save'),
                style: const TextStyle(
                    color: AppColors.pitchGreenLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlayer,
        backgroundColor: AppColors.pitchGreen,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(l10n.translate('add_player'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Team basic info
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: l10n.translate('team_name'),
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: const Icon(Icons.groups_rounded,
                            color: AppColors.pitchGreenLight),
                        filled: true,
                        fillColor: surfaceColor,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? l10n.translate('required') : null,
                    ),
                    const Gap(12),
                    TextFormField(
                      controller: _ownerNameController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: l10n.translate('owner_name'),
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: AppColors.pitchGreenLight),
                        filled: true,
                        fillColor: surfaceColor,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const Gap(12),
                    TextFormField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText:
                            l10n.translate('whatsapp'),
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: const Icon(Icons.phone_android,
                            color: AppColors.pitchGreenLight),
                        filled: true,
                        fillColor: surfaceColor,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const Gap(14),
                    // Entry Fee Payment Status Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _isPaid
                                ? AppColors.pitchGreenLight.withOpacity(0.4)
                                : Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(_isPaid ? Icons.check_circle : Icons.pending,
                                  color: _isPaid
                                      ? AppColors.pitchGreenLight
                                      : Colors.redAccent,
                                  size: 20),
                              const Gap(8),
                              Text(
                                '${l10n.translate('entry_fees')}: ${_isPaid ? l10n.translate('paid').toUpperCase() : l10n.translate('unpaid').toUpperCase()}',
                                style: TextStyle(
                                    color: _isPaid
                                        ? AppColors.pitchGreenLight
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isPaid,
                            activeThumbColor: AppColors.pitchGreenLight,
                            onChanged: (val) => setState(() => _isPaid = val),
                          ),
                        ],
                      ),
                    ),
                    const Gap(20),

                    // Squad header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${l10n.translate('squad')} (${_players.length} ${l10n.translate('teams')})',
                            style: AppTextStyles.titleLarge(textColor)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pitchGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color:
                                    AppColors.pitchGreenLight.withOpacity(0.5)),
                          ),
                          child: const Text(
                            'Optional Squad Size',
                            style: TextStyle(
                                color: AppColors.pitchGreenLight,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),

                    if (_players.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person_add_outlined,
                                size: 48, color: subTextColor),
                            const Gap(12),
                            Text(
                              l10n.translate('no_players_yet'),
                              style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(4),
                            Text(
                              l10n.translate('tap_checkbox'),
                              style:
                                  TextStyle(color: subTextColor, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...(_players.asMap().entries.map((entry) {
                        final i = entry.key;
                        final player = entry.value;
                        return _PlayerTile(
                          player: player,
                          index: i + 1,
                          onRemove: () => _removePlayer(player),
                          onEdit: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => PlayerFormDialog(
                                teamId: widget.teamId ?? 'temp',
                                tournamentId: _resolvedTournamentId ?? '',
                                existingPlayer: player,
                                onSave: (updated) {
                                  setState(() {
                                    _players[i] = updated;
                                  });
                                },
                              ),
                            );
                          },
                        );
                      })),

                    const Gap(100),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final ScorerPlayer player;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const _PlayerTile(
      {required this.player,
      required this.index,
      required this.onRemove,
      required this.onEdit});

  Color _roleColor(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:
        return Colors.blueAccent;
      case PlayerRole.bowler:
        return Colors.redAccent;
      case PlayerRole.allRounder:
        return AppColors.pitchGreenLight;
      case PlayerRole.wicketKeeper:
        return Colors.orangeAccent;
    }
  }

  String _roleLabel(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:
        return 'BAT';
      case PlayerRole.bowler:
        return 'BOWL';
      case PlayerRole.allRounder:
        return 'AR';
      case PlayerRole.wicketKeeper:
        return 'WK';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onBackground;
    final subTextColor = theme.colorScheme.onSurfaceVariant;
    final surfaceColor = theme.colorScheme.surface;
    final roleColor = _roleColor(player.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Jersey number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: roleColor.withOpacity(0.15),
              border: Border.all(color: roleColor.withOpacity(0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${player.jerseyNumber ?? index}',
              style: TextStyle(
                  color: roleColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(
                  '${player.battingStyle.name.toUpperCase()} • ${player.bowlingStyle.name.toUpperCase()}',
                  style: TextStyle(color: subTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_roleLabel(player.role),
                style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
          IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: subTextColor.withOpacity(0.7), size: 18),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 18),
              onPressed: onRemove),
        ],
      ),
    );
  }
}

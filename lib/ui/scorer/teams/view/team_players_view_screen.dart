import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class TeamPlayersViewScreen extends ConsumerStatefulWidget {
  final String teamId;

  const TeamPlayersViewScreen({super.key, required this.teamId});

  @override
  ConsumerState<TeamPlayersViewScreen> createState() => _TeamPlayersViewScreenState();
}

class _TeamPlayersViewScreenState extends ConsumerState<TeamPlayersViewScreen> {
  ScorerTeam? _team;
  List<ScorerPlayer> _players = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(scorerRepositoryProvider);
    final team = await repo.getTeam(widget.teamId);
    if (team != null) {
      final players = await repo.getPlayersByTeam(team.id);
      setState(() {
        _team = team;
        _players = players;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _openWhatsApp(String number) async {
    final cleanNum = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanNum');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch WhatsApp for $number'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePlayer(ScorerPlayer player) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(l10n.translate('remove_player'), style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('Remove ${player.name} from ${_team?.name}?', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('delete'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(scorerRepositoryProvider).deletePlayer(player.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textColor = theme.colorScheme.onBackground;
    final subTextColor = theme.colorScheme.onSurfaceVariant;
    final surfaceColor = theme.colorScheme.surface;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen)),
      );
    }

    if (_team == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, leading: BackButton(color: textColor)),
        body: Center(child: Text(l10n.translate('match_not_found'), style: TextStyle(color: textColor))),
      );
    }

    final team = _team!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text(team.name, style: AppTextStyles.headlineSmall(textColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.pitchGreenLight),
            tooltip: l10n.translate('edit_tournament').replaceAll('Tournament', 'Team'),
            onPressed: () async {
              await context.push('/scorer/teams/${team.id}/edit');
              _loadData();
            },
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/scorer/teams/${team.id}/edit');
          _loadData();
        },
        backgroundColor: AppColors.pitchGreen,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(l10n.translate('squad'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                        child: Text(
                          team.shortCode.isNotEmpty ? team.shortCode : 'T',
                          style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const Gap(14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team.name, style: AppTextStyles.titleMedium(textColor)),
                            const Gap(2),
                            Text('${l10n.translate('short_code')}: ${team.shortCode} • ${_players.length} ${l10n.translate('teams')}', style: TextStyle(color: subTextColor, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Payment Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: team.isEntryFeePaid ? AppColors.pitchGreen.withOpacity(0.2) : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: team.isEntryFeePaid ? AppColors.pitchGreenLight : Colors.redAccent),
                        ),
                        child: Text(
                          team.isEntryFeePaid ? l10n.translate('paid') : l10n.translate('unpaid'),
                          style: TextStyle(color: team.isEntryFeePaid ? AppColors.pitchGreenLight : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),

                  if (team.ownerName != null || team.whatsappNumber != null) ...[
                    Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (team.ownerName != null)
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 14, color: subTextColor),
                                  const Gap(6),
                                  Text('${l10n.translate('owner_name')}: ${team.ownerName}', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            if (team.whatsappNumber != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone_android, size: 14, color: subTextColor),
                                    const Gap(6),
                                    Text(team.whatsappNumber!, style: TextStyle(color: subTextColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (team.whatsappNumber != null && team.whatsappNumber!.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () => _openWhatsApp(team.whatsappNumber!),
                            icon: const Icon(Icons.chat_bubble_outline, size: 14),
                            label: Text(l10n.translate('whatsapp'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Gap(20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${l10n.translate('squad')} (${_players.length})', style: AppTextStyles.titleMedium(textColor)),
              ],
            ),
            const Gap(10),

            if (_players.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(l10n.translate('no_players_yet'), style: TextStyle(color: subTextColor)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _players.length,
                separatorBuilder: (_, __) => const Gap(8),
                itemBuilder: (ctx, i) {
                  final player = _players[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.dividerColor.withOpacity(0.1),
                          child: Text(
                            player.jerseyNumber != null ? '#${player.jerseyNumber}' : '${i + 1}',
                            style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(player.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                              const Gap(2),
                              Text(
                                '${player.role.name.toUpperCase()} • ${player.battingStyle.name} • ${player.bowlingStyle.name}',
                                style: TextStyle(color: subTextColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          onPressed: () => _deletePlayer(player),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const Gap(80),
          ],
        ),
      ),
    );
  }
}

// lib/shared_widgets/alert_options_sheet.dart
// Bottom sheet shown when the user taps the bell on a match or tournament
// card. Offers the master alerts switch plus per-event toggles (match start,
// 1st innings start, 2nd innings start, wickets, match end). Requires a
// signed-in spectator; otherwise it offers a sign-in shortcut.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/spectator/match_detail/viewmodel/match_notification_prefs_provider.dart';

/// Per-match alert options for [matchId].
class MatchAlertsSheet extends ConsumerWidget {
  final String matchId;
  const MatchAlertsSheet({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(matchNotificationPrefsProvider(matchId));
    final notifier =
        ref.read(matchNotificationPrefsProvider(matchId).notifier);
    return _AlertsSheet(
      title: 'Match Alerts',
      enabled: prefs.enabled,
      onMasterChanged: (_) => notifier.toggleAlerts(),
      toggles: [
        _AlertOption(
          label: 'Match start',
          value: prefs.matchStart,
          onChanged: (_) => notifier.toggleMatchStart(),
        ),
        _AlertOption(
          label: '1st Innings start',
          value: prefs.firstInningsStart,
          onChanged: (_) => notifier.toggleFirstInningsStart(),
        ),
        _AlertOption(
          label: '2nd Innings start',
          value: prefs.secondInningsStart,
          onChanged: (_) => notifier.toggleSecondInningsStart(),
        ),
        _AlertOption(
          label: 'Wickets',
          value: prefs.wicket,
          onChanged: (_) => notifier.toggleWicket(),
        ),
        _AlertOption(
          label: 'Match end',
          value: prefs.matchComplete,
          onChanged: (_) => notifier.toggleMatchComplete(),
        ),
      ],
    );
  }
}

/// Tournament-wide alert options for [tournamentId].
class TournamentAlertsSheet extends ConsumerWidget {
  final String tournamentId;
  const TournamentAlertsSheet({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(tournamentNotificationPrefsProvider(tournamentId));
    final notifier = ref
        .read(tournamentNotificationPrefsProvider(tournamentId).notifier);
    return _AlertsSheet(
      title: 'Tournament Alerts',
      enabled: prefs.enabled,
      onMasterChanged: (_) => notifier.toggleAlerts(),
      toggles: [
        _AlertOption(
          label: 'Match start',
          value: prefs.matchStart,
          onChanged: (_) => notifier.toggleMatchStart(),
        ),
        _AlertOption(
          label: '1st Innings start',
          value: prefs.firstInningsStart,
          onChanged: (_) => notifier.toggleFirstInningsStart(),
        ),
        _AlertOption(
          label: '2nd Innings start',
          value: prefs.secondInningsStart,
          onChanged: (_) => notifier.toggleSecondInningsStart(),
        ),
        _AlertOption(
          label: 'Wickets',
          value: prefs.wicket,
          onChanged: (_) => notifier.toggleWicket(),
        ),
        _AlertOption(
          label: 'Match end',
          value: prefs.matchComplete,
          onChanged: (_) => notifier.toggleMatchComplete(),
        ),
      ],
    );
  }
}

class _AlertOption {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AlertOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });
}

class _AlertsSheet extends ConsumerWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool> onMasterChanged;
  final List<_AlertOption> toggles;

  const _AlertsSheet({
    required this.title,
    required this.enabled,
    required this.onMasterChanged,
    required this.toggles,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.pitchGreenLight, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: AppTextStyles.titleMedium(cs.onSurface)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: cs.onSurface.withOpacity(0.7)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (user == null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sign in to get match alerts.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/signin');
                        },
                        child: const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(title,
                    style: AppTextStyles.titleSmall(cs.onSurface)
                        .copyWith(fontWeight: FontWeight.bold)),
                value: enabled,
                activeTrackColor: AppColors.pitchGreen,
                onChanged: onMasterChanged,
              ),
              if (enabled) ...[
                const Divider(color: Colors.white12, height: 1),
                ...toggles.map((t) => SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.label,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      value: t.value,
                      activeTrackColor: AppColors.pitchGreen,
                      onChanged: t.onChanged,
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

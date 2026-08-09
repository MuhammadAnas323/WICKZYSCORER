import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/settings/viewmodel/settings_viewmodel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('settings'), style: AppTextStyles.headlineSmall(cs.onBackground)),
      ),
      body: ListView(
        children: [
          _SectionHeader(l10n.translate('appearance')),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: Text(l10n.translate('theme')),
            trailing: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode, size: 16), label: Text(l10n.translate('light'))),
                ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode, size: 16), label: Text(l10n.translate('dark'))),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) {
                ref.read(settingsViewModelProvider.notifier).setThemeMode(s.first);
              },
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.translate('language')),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ur', label: Text('اردو')),
              ],
              selected: {ref.watch(localeProvider).languageCode},
              onSelectionChanged: (s) {
                ref.read(settingsViewModelProvider.notifier).setLocale(Locale(s.first));
              },
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.translate('notifications')),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_rounded),
            title: Text(l10n.translate('enable_notifications')),
            value: state.notificationsEnabled,
            onChanged: (_) => ref.read(settingsViewModelProvider.notifier).toggleNotifications(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sports_cricket_rounded),
            title: Text(l10n.translate('live_score_alerts')),
            value: state.liveScoreAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleLiveScore()
              : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.gps_fixed_rounded),
            title: Text(l10n.translate('wicket_alerts')),
            value: state.wicketAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleWicket()
              : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded),
            title: Text(l10n.translate('match_start_reminders')),
            value: state.matchStartAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleMatchStart()
              : null,
          ),
          const Divider(),
          _SectionHeader(l10n.translate('about')),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.translate('version')),
            trailing: Text('1.0.0', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ListTile(
            leading: const Icon(Icons.description_rounded),
            title: Text(l10n.translate('privacy_policy')),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: Text(l10n.translate('terms_of_service')),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {},
          ),
          const Divider(),
          _SectionHeader(l10n.translate('account')),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: Text(l10n.translate('sign_out'), style: const TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.translate('sign_out')),
                  content: Text(l10n.translate('sign_out_confirm')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.translate('cancel')),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.translate('sign_out')),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                debugPrint('[DEBUG] Settings screen direct FirebaseAuth.signOut() CALLED. Stack: ${StackTrace.current}');
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/role-selection');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(title.toUpperCase(),
        style: AppTextStyles.labelSmall(cs.primary)
          .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700)),
    );
  }
}
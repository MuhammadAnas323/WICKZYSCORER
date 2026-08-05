import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/settings/viewmodel/settings_viewmodel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.headlineSmall(cs.onBackground)),
      ),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 16), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16), label: Text('Dark')),
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
            title: const Text('Language'),
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
          const _SectionHeader('API & Feeds'),
          ListTile(
            leading: const Icon(Icons.api_rounded, color: Colors.green),
            title: const Text('Cricket API Settings'),
            subtitle: const Text('Admin Settings • Manage connected channel APIs'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/cricket-api-settings'),
          ),
          const Divider(),
          const _SectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_rounded),
            title: const Text('Enable Notifications'),
            value: state.notificationsEnabled,
            onChanged: (_) => ref.read(settingsViewModelProvider.notifier).toggleNotifications(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sports_cricket_rounded),
            title: const Text('Live Score Alerts'),
            value: state.liveScoreAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleLiveScore()
              : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.gps_fixed_rounded),
            title: const Text('Wicket Alerts'),
            value: state.wicketAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleWicket()
              : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded),
            title: const Text('Match Start Reminders'),
            value: state.matchStartAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleMatchStart()
              : null,
          ),
          const Divider(),
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Version'),
            trailing: Text('1.0.0', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ListTile(
            leading: const Icon(Icons.description_rounded),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {},
          ),
          const Divider(),
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                debugPrint('[DEBUG] Settings screen direct FirebaseAuth.signOut() CALLED. Stack: ${StackTrace.current}');
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/signin');
              }
            },
          ),
          const Divider(),
          const _SectionHeader('Developer'),
          ListTile(
            leading: const Icon(Icons.delete_sweep_rounded, color: Colors.deepOrange),
            title: const Text('Clear All Scorer Data', style: TextStyle(color: Colors.deepOrange)),
            subtitle: const Text('Deletes every tournament, team, player, match and schedule from this device and Firestore.'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text(
                    'This permanently removes ALL tournaments, teams, players, '
                    'matches and schedules from Firestore and this device. '
                    'This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                final repo = ref.read(scorerRepositoryProvider);
                await repo.clearAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All scorer data cleared.')),
                  );
                }
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
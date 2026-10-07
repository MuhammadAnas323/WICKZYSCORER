import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/extensions/string_extensions.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/settings/viewmodel/settings_viewmodel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.translate('delete_account').toTitleCase),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.translate('reenter_credentials')),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: l10n.translate('email').toTitleCase),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l10n.translate('required');
                      if (val.trim() != currentUserEmail) return l10n.translate('email_match_error');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.translate('password').toTitleCase,
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? l10n.translate('required') : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(l10n.translate('enter_email_first'))),
                          );
                          return;
                        }
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(l10n.translate('password_reset_sent'))),
                            );
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e)), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: Text(l10n.translate('forgot_password').toTitleCase, style: const TextStyle(color: AppColors.pitchGreen)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: Text(l10n.translate('cancel').toTitleCase),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: isLoading ? null : () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setState(() => isLoading = true);
                try {
                  await ref.read(currentUserProvider.notifier).softDeleteAccount(
                        emailController.text.trim(),
                        passwordController.text.trim(),
                      );
                  if (!context.mounted) return;
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (infoCtx) => AlertDialog(
                      title: Text(l10n.translate('account_deactivated').toTitleCase),
                      content: Text(
                        l10n.translate('account_deactivated_msg'),
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.pitchGreen, foregroundColor: Colors.white),
                          onPressed: () async {
                            Navigator.pop(infoCtx);
                            await ref.read(currentUserProvider.notifier).signOut();
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              context.go('/');
                            }
                          },
                          child: Text(l10n.translate('ok').toTitleCase),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (dialogContext.mounted) {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e)), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.translate('confirm_delete')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsViewModelProvider);
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('settings').toTitleCase, style: AppTextStyles.headlineSmall(cs.onBackground)),
      ),
      body: ListView(
        children: [
          _SectionHeader(l10n.translate('appearance').toTitleCase),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: Text(l10n.translate('theme').toTitleCase),
            trailing: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode, size: 16), label: Text(l10n.translate('light').toTitleCase)),
                ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode, size: 16), label: Text(l10n.translate('dark').toTitleCase)),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) {
                ref.read(settingsViewModelProvider.notifier).setThemeMode(s.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                side: WidgetStateProperty.all(BorderSide(color: AppColors.pitchGreen.withValues(alpha: 0.6), width: 1.2)),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.translate('language').toTitleCase),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ur', label: Text('اردو')),
              ],
              selected: {ref.watch(localeProvider).languageCode},
              onSelectionChanged: (s) {
                ref.read(settingsViewModelProvider.notifier).setLocale(Locale(s.first));
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                side: WidgetStateProperty.all(BorderSide(color: AppColors.pitchGreen.withValues(alpha: 0.6), width: 1.2)),
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.translate('notifications').toTitleCase),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_rounded),
            title: Text(l10n.translate('enable_notifications').toTitleCase),
            value: state.notificationsEnabled,
            onChanged: (_) => ref.read(settingsViewModelProvider.notifier).toggleNotifications(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sports_cricket_rounded),
            title: Text(l10n.translate('live_score_alerts').toTitleCase),
            value: state.liveScoreAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleLiveScore()
              : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.gps_fixed_rounded),
            title: Text(l10n.translate('wicket_alerts').toTitleCase),
            value: state.wicketAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleWicket()
              : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded),
            title: Text(l10n.translate('match_start_reminders').toTitleCase),
            value: state.matchStartAlerts,
            onChanged: state.notificationsEnabled
              ? (_) => ref.read(settingsViewModelProvider.notifier).toggleMatchStart()
              : null,
          ),
          const Divider(),
          _SectionHeader(l10n.translate('about').toTitleCase),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.translate('version').toTitleCase),
            trailing: Text('1.0.0', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          ListTile(
            leading: const Icon(Icons.description_rounded),
            title: Text(l10n.translate('privacy_policy').toTitleCase),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: Text(l10n.translate('terms_of_service').toTitleCase),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {},
          ),
          const Divider(),
          _SectionHeader(l10n.translate('account').toTitleCase),
          Builder(
            builder: (context) {
              final appUser = ref.watch(currentUserProvider);
              final isScorer = appUser?.role == AppUserRole.scorer;
              final switchTitle = isScorer
                  ? l10n.translate('switch_to_spectator')
                  : l10n.translate('switch_to_scorer');
              final switchSubtitle = isScorer
                  ? l10n.translate('switch_to_spectator_subtitle')
                  : l10n.translate('switch_to_scorer_subtitle');

              return ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.pitchGreen),
                title: Text(switchTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(switchSubtitle),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () async {
                  final notifier = ref.read(currentUserProvider.notifier);
                  final targetRole =
                      isScorer ? AppUserRole.spectator : AppUserRole.scorer;
                  final success = await notifier.switchToRole(targetRole);

                  if (success) {
                    if (context.mounted) {
                      context.go(targetRole == AppUserRole.scorer
                          ? '/scorer/dashboard'
                          : '/home');
                    }
                  } else {
                    await notifier.signOut();
                    if (context.mounted) {
                      context.go(targetRole == AppUserRole.scorer
                          ? '/scorer-signup'
                          : '/spectator-signup');
                    }
                  }
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: Text(l10n.translate('delete_account').toTitleCase, style: const TextStyle(color: Colors.red)),
            onTap: () => _showDeleteAccountDialog(context, ref, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: Text(l10n.translate('sign_out').toTitleCase, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.translate('sign_out').toTitleCase),
                  content: Text(l10n.translate('sign_out_confirm')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.translate('cancel').toTitleCase),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.translate('sign_out').toTitleCase),
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
  Widget andBuild(BuildContext context) => throw UnimplementedError();
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

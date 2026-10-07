import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/ui/settings/viewmodel/settings_viewmodel.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _checkVerification() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isChecking = true);
    try {
      final user = fa.FirebaseAuth.instance.currentUser;
      await user?.reload();
      final refreshedUser = fa.FirebaseAuth.instance.currentUser;
      if (refreshedUser?.emailVerified == true) {
        if (!mounted) return;
        final hasSelected = ref.read(settingsViewModelProvider).hasSelectedLanguage;
        if (!hasSelected) {
          context.go('/language-selection');
        } else {
          final appUser = ref.read(currentUserProvider);
          if (appUser?.role == AppUserRole.scorer) {
            context.go('/scorer/dashboard');
          } else {
            context.go('/home');
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('email_not_verified_yet')),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.translate('error_checking_verification')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isResending = true);
    try {
      final user = fa.FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('verification_email_sent')),
            backgroundColor: AppColors.pitchGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.translate('failed_resend_verification')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = fa.FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'your email';
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final instructions = l10n.translate('verify_email_instructions').replaceAll('{email}', email);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.pitchGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined, size: 36, color: AppColors.pitchGreen),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.translate('verify_email'),
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineMedium(cs.onBackground),
              ),
              const SizedBox(height: 12),
              Text(
                instructions,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              AppPrimaryButton(
                label: l10n.translate('check_verification_status'),
                isLoading: _isChecking,
                onPressed: _checkVerification,
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isResending ? null : _resendEmail,
                child: Text(
                  _isResending
                      ? l10n.translate('resending')
                      : l10n.translate('resend_verification_email'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await ref.read(currentUserProvider.notifier).signOut();
                  if (context.mounted) context.go('/role-selection');
                },
                child: Text(
                  l10n.translate('sign_out_other_account'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

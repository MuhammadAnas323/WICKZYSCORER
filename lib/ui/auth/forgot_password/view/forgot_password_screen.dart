import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/ui/auth/shared/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      // 1. Check if email exists in Firestore users collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('no_account_found_email')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // 2. Email exists -> Send password reset link
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = AppErrorHandler.getUserFriendlyMessage(e);
        if (e.code == 'user-not-found') {
          message = l10n.translate('no_account_found_email');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      title: _isSuccess ? l10n.translate('check_your_email') : l10n.translate('reset_password'),
      subtitle: _isSuccess 
          ? l10n.translate('reset_instructions_sent').replaceAll('{email}', _emailController.text) 
          : l10n.translate('reset_password_sub'),
      showBackButton: true,
      onBack: () => context.go('/signin'),
      footer: TextButton(
        onPressed: () => context.go('/signin'),
        child: Text(l10n.translate('back_to_sign_in'), style: AppTextStyles.labelLarge(AppColors.pitchGreen)),
      ),
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _isSuccess ? _buildSuccessView(cs, l10n) : _buildFormView(cs, l10n),
        ),
      ],
    );
  }

  Widget _buildFormView(ColorScheme cs, AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppTextStyles.bodyMedium(cs.onSurface),
            decoration: InputDecoration(
              labelText: l10n.translate('email'),
              labelStyle: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.pitchGreen),
              filled: true,
              fillColor: cs.surfaceVariant.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            validator: (val) {
              final email = val?.trim() ?? '';
              final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$', caseSensitive: false);
              if (!regex.hasMatch(email)) {
                return l10n.translate('invalid_email');
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            label: l10n.translate('send_reset_link'),
            isLoading: _isLoading,
            onPressed: _sendResetLink,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ColorScheme cs, AppLocalizations l10n) {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.pitchGreen, size: 80),
        const SizedBox(height: 24),
        Text(
          l10n.translate('reset_instructions_sent').replaceAll('{email}', _emailController.text),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

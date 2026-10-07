import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/utils/auth_dialog_utils.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/ui/auth/shared/auth_scaffold.dart';

class ScorerSignInScreen extends ConsumerStatefulWidget {
  const ScorerSignInScreen({super.key});

  @override
  ConsumerState<ScorerSignInScreen> createState() => _ScorerSignInScreenState();
}

class _ScorerSignInScreenState extends ConsumerState<ScorerSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(currentUserProvider.notifier).signInAsScorer(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      if (mounted) {
        context.go('/scorer/dashboard');
      }
    } catch (e) {
      if (mounted) {
        await handleSignInException(context, ref, e, onSuccess: () {
          context.go('/scorer/dashboard');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      title: l10n.translate('scorer_sign_in'),
      subtitle: l10n.translate('scorer_sign_in_sub'),
      showBackButton: true,
      onBack: () => context.go('/role-selection'),
      footer: Center(
        child: GestureDetector(
          onTap: () => context.push('/scorer-signup'),
          child: RichText(
            text: TextSpan(
              text: l10n.translate('dont_have_account'),
              style: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
              children: [
                TextSpan(
                  text: l10n.translate('sign_up'),
                  style: const TextStyle(
                    color: AppColors.pitchGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                style: AppTextStyles.bodyMedium(cs.onSurface),
                decoration: InputDecoration(
                  labelText: l10n.translate('password'),
                  labelStyle: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.pitchGreen),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                  filled: true,
                  fillColor: cs.surfaceVariant.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return l10n.translate('required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text(l10n.translate('forgot_password'), style: AppTextStyles.labelMedium(AppColors.pitchGreen)),
                ),
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: l10n.translate('scorer_sign_in'),
                isLoading: _isLoading,
                onPressed: _submitSignIn,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

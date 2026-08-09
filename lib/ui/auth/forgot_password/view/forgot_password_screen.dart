import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';

import 'package:sportyapp/ui/auth/shared/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isLoading = false;
      _isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AuthScaffold(
      title: _isSuccess ? 'Check your email' : 'Reset Password',
      subtitle: _isSuccess 
          ? 'We have sent reset instructions' 
          : 'Enter your email and we will send you a reset link.',
      footer: TextButton(
        onPressed: () => context.go('/signin'),
        child: Text('Back to Sign In', style: AppTextStyles.labelLarge(AppColors.pitchGreen)),
      ),
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _isSuccess ? _buildSuccessView(cs) : _buildFormView(cs),
        ),
      ],
    );
  }

  Widget _buildFormView(ColorScheme cs) {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailController,
          style: AppTextStyles.bodyMedium(cs.onSurface),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.pitchGreen),
            filled: true,
            fillColor: cs.surfaceVariant.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 32),
        AppPrimaryButton(
          label: 'Send Reset Link',
          isLoading: _isLoading,
          onPressed: _sendResetLink,
        ),
      ],
    );
  }

  Widget _buildSuccessView(ColorScheme cs) {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.pitchGreen, size: 80),
        const SizedBox(height: 24),
        Text(
          'We have sent password reset instructions to ${_emailController.text}',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
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
            const SnackBar(
              content: Text('No account found with this email address.'),
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
          message = 'No account found with this email address.';
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
    return AuthScaffold(
      title: _isSuccess ? 'Check your email' : 'Reset Password',
      subtitle: _isSuccess 
          ? 'We have sent reset instructions' 
          : 'Enter your email and we will send you a reset link.',
      showBackButton: true,
      onBack: () => context.go('/signin'),
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
              labelText: 'Email',
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
                return 'Please, email address is not correct';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            label: 'Send Reset Link',
            isLoading: _isLoading,
            onPressed: _sendResetLink,
          ),
        ],
      ),
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

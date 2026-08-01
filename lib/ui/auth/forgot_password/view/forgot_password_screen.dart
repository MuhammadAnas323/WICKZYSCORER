import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';

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
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _isSuccess ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text('Reset Password', style: AppTextStyles.headlineLarge(Colors.white)),
        const SizedBox(height: 8),
        Text('Enter your email and we will send you a reset link.', style: AppTextStyles.bodyMedium(AppColors.charcoal200)),
        const SizedBox(height: 48),
        TextFormField(
          controller: _emailController,
          style: AppTextStyles.bodyMedium(Colors.white),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: AppTextStyles.bodyMedium(AppColors.charcoal200),
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.charcoal200),
            filled: true,
            fillColor: AppColors.darkSurfaceVariant,
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.charcoal600)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.pitchGreen)),
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

  Widget _buildSuccessView() {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.check_circle_outline, color: AppColors.pitchGreen, size: 80),
        const SizedBox(height: 24),
        Center(child: Text('Check your email', style: AppTextStyles.headlineMedium(Colors.white))),
        const SizedBox(height: 16),
        Text(
          'We have sent password reset instructions to ${_emailController.text}',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium(AppColors.charcoal200),
        ),
        const SizedBox(height: 48),
        TextButton(
          onPressed: () => context.go('/signin'),
          child: Text('Back to Sign In', style: AppTextStyles.labelLarge(AppColors.pitchGreen)),
        ),
      ],
    );
  }
}

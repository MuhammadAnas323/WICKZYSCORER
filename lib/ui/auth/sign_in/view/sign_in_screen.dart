import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/ui/auth/sign_in/viewmodel/sign_in_viewmodel.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SignInState>(signInViewModelProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
      if (next.success) {
        final currentUser = ref.read(currentUserProvider);
        if (currentUser?.role == AppUserRole.scorer) {
          context.go('/scorer/dashboard');
        } else if (currentUser?.role == AppUserRole.spectator) {
          context.go('/home');
        }
      }
    });

    final state = ref.watch(signInViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Center(child: Text('Welcome Back', style: AppTextStyles.displayMedium(Colors.white))),
              const SizedBox(height: 8),
              Center(child: Text('Sign in to continue', style: AppTextStyles.bodyMedium(AppColors.charcoal200))),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                style: AppTextStyles.bodyMedium(Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: AppTextStyles.bodyMedium(AppColors.charcoal200),
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.charcoal200),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: AppColors.charcoal200),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                  filled: true,
                  fillColor: AppColors.darkSurfaceVariant,
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.charcoal600)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.pitchGreen)),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text('Forgot Password?', style: AppTextStyles.labelMedium(AppColors.pitchGreen)),
                ),
              ),
              const SizedBox(height: 32),
              AppPrimaryButton(
                label: 'Sign In',
                isLoading: state.isLoading,
                onPressed: () {
                  ref.read(signInViewModelProvider.notifier).signIn(
                    _emailController.text,
                    _passwordController.text,
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => context.push('/role-selection'),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: AppTextStyles.bodyMedium(AppColors.charcoal200),
                      children: [
                        TextSpan(
                          text: 'Sign Up',
                          style: AppTextStyles.titleMedium(AppColors.pitchGreen),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

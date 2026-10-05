import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/ui/auth/sign_in/viewmodel/sign_in_viewmodel.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/ui/auth/shared/auth_scaffold.dart';
import 'package:sportyapp/ui/auth/widgets/google_sign_in_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitSignIn() {
    try {
      if (_formKey.currentState?.validate() ?? false) {
        ref.read(signInViewModelProvider.notifier).signIn(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.getUserFriendlyMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Sign in to continue',
      showBackButton: true,
      onBack: () => context.go('/role-selection'),
      footer: Center(
        child: GestureDetector(
          onTap: () => context.push('/role-selection'),
          child: RichText(
            text: TextSpan(
              text: "Don't have an account? ",
              style: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
              children: [
                const TextSpan(
                  text: 'Sign Up',
                  style: TextStyle(
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                style: AppTextStyles.bodyMedium(cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Password',
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
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text('Forgot Password?', style: AppTextStyles.labelMedium(AppColors.pitchGreen)),
                ),
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Sign In',
                isLoading: state.isEmailLoading,
                onPressed: _submitSignIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        GoogleSignInButton(
          isLoading: state.isGoogleLoading,
          onPressed: () {
            try {
              ref.read(signInViewModelProvider.notifier).signInWithGoogle();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppErrorHandler.getUserFriendlyMessage(e)),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

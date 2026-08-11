import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/ui/auth/widgets/common_signup_form.dart';
import 'package:sportyapp/ui/auth/widgets/google_sign_in_button.dart';
import 'package:sportyapp/ui/auth/scorer_signup/viewmodel/scorer_signup_viewmodel.dart';

import 'package:sportyapp/ui/auth/shared/auth_scaffold.dart';

class ScorerSignupScreen extends ConsumerStatefulWidget {
  const ScorerSignupScreen({super.key});

  @override
  ConsumerState<ScorerSignupScreen> createState() => _ScorerSignupScreenState();
}

class _ScorerSignupScreenState extends ConsumerState<ScorerSignupScreen> {
  final _formKey = GlobalKey<CommonSignupFormState>();

  @override
  Widget build(BuildContext context) {
    ref.listen<ScorerSignupState>(scorerSignupViewModelProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
      if (next.success) {
        context.go('/scorer/dashboard');
      }
    });

    final state = ref.watch(scorerSignupViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Scorer Sign Up',
      subtitle: 'Sign up for professional matches',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Already have an account? ',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          GestureDetector(
            onTap: () => context.go('/signin'),
            child: Text('Sign In',
                style: TextStyle(
                  color: AppColors.pitchGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                )),
          ),
        ],
      ),
      children: [
        CommonSignupForm(key: _formKey, isScorer: true),
        const SizedBox(height: 32),
        AppPrimaryButton(
          label: 'Sign Up',
          isLoading: state.isEmailLoading,
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              ref.read(scorerSignupViewModelProvider.notifier).signUp(
                    name: _formKey.currentState!.nameController.text,
                    email: _formKey.currentState!.emailController.text,
                    password: _formKey.currentState!.passwordController.text,
                    organization: _formKey.currentState!.orgController.text,
                  );
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        GoogleSignInButton(
          isLoading: state.isGoogleLoading,
          onPressed: () {
            ref.read(scorerSignupViewModelProvider.notifier).signUpWithGoogle();
          },
        ),
      ],
    );
  }
}

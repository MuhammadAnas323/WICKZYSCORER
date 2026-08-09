import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/ui/auth/widgets/common_signup_form.dart';
import 'package:sportyapp/ui/auth/widgets/google_sign_in_button.dart';
import 'package:sportyapp/ui/auth/spectator_signup/viewmodel/spectator_signup_viewmodel.dart';

import 'package:sportyapp/ui/auth/shared/auth_scaffold.dart';

class SpectatorSignupScreen extends ConsumerStatefulWidget {
  const SpectatorSignupScreen({super.key});

  @override
  ConsumerState<SpectatorSignupScreen> createState() => _SpectatorSignupScreenState();
}

class _SpectatorSignupScreenState extends ConsumerState<SpectatorSignupScreen> {
  final _formKey = GlobalKey<CommonSignupFormState>();

  @override
  Widget build(BuildContext context) {
    ref.listen<SpectatorSignupState>(spectatorSignupViewModelProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
      if (next.success) {
        context.go('/home');
      }
    });

    final state = ref.watch(spectatorSignupViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Spectator Sign Up',
      subtitle: 'Follow your favorite tournaments',
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
        CommonSignupForm(key: _formKey, isScorer: false),
        const SizedBox(height: 32),
        AppPrimaryButton(
          label: 'Create Account',
          isLoading: state.isLoading,
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              ref.read(spectatorSignupViewModelProvider.notifier).signUp(
                    name: _formKey.currentState!.nameController.text,
                    email: _formKey.currentState!.emailController.text,
                    password: _formKey.currentState!.passwordController.text,
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
          isLoading: state.isLoading,
          onPressed: () {
            ref
                .read(spectatorSignupViewModelProvider.notifier)
                .signUpWithGoogle();
          },
        ),
      ],
    );
  }
}

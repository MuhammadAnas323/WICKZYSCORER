import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/ui/auth/widgets/common_signup_form.dart';
import 'package:sportyapp/ui/auth/scorer_signup/viewmodel/scorer_signup_viewmodel.dart';

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Scorer Sign Up', style: AppTextStyles.headlineLarge(AppColors.floodlightGold)),
              const SizedBox(height: 8),
              Text('Start scoring professional matches', style: AppTextStyles.bodyMedium(AppColors.charcoal200)),
              const SizedBox(height: 32),
              CommonSignupForm(key: _formKey, isScorer: true),
              const SizedBox(height: 40),
              AppPrimaryButton(
                label: 'Start Scoring',
                isLoading: state.isLoading,
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    ref.read(scorerSignupViewModelProvider.notifier).signUp(
                          name: _formKey.currentState!.nameController.text,
                          email: _formKey.currentState!.emailController.text,
                          password: _formKey.currentState!.passwordController.text,
                          phone: _formKey.currentState!.phoneController.text,
                          address: _formKey.currentState!.addressController.text,
                          organization: _formKey.currentState!.orgController.text,
                        );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/ui/auth/widgets/common_signup_form.dart';
import 'package:sportyapp/ui/auth/spectator_signup/viewmodel/spectator_signup_viewmodel.dart';

class SpectatorSignupScreen extends ConsumerStatefulWidget {
  const SpectatorSignupScreen({super.key});

  @override
  ConsumerState<SpectatorSignupScreen> createState() => _SpectatorSignupScreenState();
}

class _SpectatorSignupScreenState extends ConsumerState<SpectatorSignupScreen> {
  final _formKey = GlobalKey<CommonSignupFormState>();
  String? _selectedTournament;
  final _tournaments = ['KPL 2024', 'National T20', 'PSL 2024'];

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
              Text('Spectator Sign Up', style: AppTextStyles.headlineLarge(Colors.white)),
              const SizedBox(height: 8),
              Text('Follow your favorite tournaments', style: AppTextStyles.bodyMedium(AppColors.charcoal200)),
              const SizedBox(height: 32),
              CommonSignupForm(key: _formKey, isScorer: false),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTournament,
                dropdownColor: AppColors.darkSurface,
                style: AppTextStyles.bodyMedium(Colors.white),
                decoration: InputDecoration(
                  labelText: 'Favorite Tournament (Optional)',
                  labelStyle: AppTextStyles.bodyMedium(AppColors.charcoal200),
                  filled: true,
                  fillColor: AppColors.darkSurfaceVariant,
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.charcoal600)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.pitchGreen)),
                ),
                items: _tournaments.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedTournament = val),
              ),
              const SizedBox(height: 40),
              AppPrimaryButton(
                label: 'Create Account',
                isLoading: state.isLoading,
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    ref.read(spectatorSignupViewModelProvider.notifier).signUp(
                          name: _formKey.currentState!.nameController.text,
                          email: _formKey.currentState!.emailController.text,
                          password: _formKey.currentState!.passwordController.text,
                          phone: _formKey.currentState!.phoneController.text,
                          address: _formKey.currentState!.addressController.text,
                          favoriteTournamentId: _selectedTournament,
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

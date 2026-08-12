import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';
import 'package:sportyapp/ui/auth/shared/auth_scaffold.dart';
import 'package:sportyapp/ui/auth/viewmodel/auth_viewmodel.dart';
import 'package:sportyapp/ui/auth/widgets/google_sign_in_button.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = false;

  void _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    if (!_isLogin && name.isEmpty) return;

    final vm = ref.read(authViewModelProvider.notifier);
    try {
      if (_isLogin) {
        await vm.signInWithEmail(email, password);
      } else {
        await vm.signUpWithEmail(email, password, name);
      }
    } catch (e) {
      debugPrint('Auth submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: _isLogin ? 'Welcome Back!' : 'Create Account',
      subtitle: _isLogin
          ? 'Sign in as a spectator or a scorer'
          : 'Join as a spectator or a scorer',
      footer: TextButton(
        onPressed: () {
          setState(() {
            _isLogin = !_isLogin;
          });
        },
        child: Text(
          _isLogin
              ? "Don't have an account? Sign Up"
              : "Already have an account? Login",
          style: AppTextStyles.titleMedium(AppColors.pitchGreen),
        ),
      ),
      children: [
        if (!_isLogin) ...[
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: AppTextStyles.bodyMedium(cs.onSurface),
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline, color: AppColors.pitchGreen),
              filled: true,
              fillColor: cs.surfaceVariant.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: AppTextStyles.bodyMedium(cs.onSurface),
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.pitchGreen),
            filled: true,
            fillColor: cs.surfaceVariant.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          style: AppTextStyles.bodyMedium(cs.onSurface),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.pitchGreen),
            filled: true,
            fillColor: cs.surfaceVariant.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 32),
        AppPrimaryButton(
          label: _isLogin ? 'Login' : 'Sign Up',
          isLoading: isLoading,
          onPressed: _submit,
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
          isLoading: isLoading,
          onPressed: () async {
            try {
              await ref.read(authViewModelProvider.notifier).signInWithGoogle();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))),
                );
              }
            }
          },
        ),
      ],
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (e) {
    return const Stream.empty();
  }
});

final firebaseAvailableProvider = Provider<bool>((ref) {
  try {
    FirebaseAuth.instance;
    return true;
  } catch (_) {
    return false;
  }
});

final userDetailProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull;
});

class AuthViewModel extends StateNotifier<bool> {
  final Ref ref;
  AuthViewModel(this.ref) : super(false);

  Future<void> signUpWithEmail(String email, String password, String name) async {
    state = true;
    try {
      await ref.read(currentUserProvider.notifier).signUpSpectator(
        name: name,
        email: email,
        password: password,
      );
    } catch (e, stack) {
      debugPrint('SignUp error: $e\n$stack');
      rethrow;
    } finally {
      if (mounted) state = false;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = true;
    try {
      await ref.read(currentUserProvider.notifier).signIn(email, password);
    } catch (e, stack) {
      debugPrint('SignIn error: $e\n$stack');
      rethrow;
    } finally {
      if (mounted) state = false;
    }
  }

  Future<void> signInWithGoogle() async {
    state = true;
    try {
      await ref.read(currentUserProvider.notifier).signInWithGoogle();
    } catch (e, stack) {
      debugPrint('Google Sign-In error: $e\n$stack');
      rethrow;
    } finally {
      if (mounted) state = false;
    }
  }

  Future<void> signOut() async {
    debugPrint('[DEBUG] AuthViewModel.signOut() CALLED. Stack: ${StackTrace.current}');
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}

final authViewModelProvider = StateNotifierProvider<AuthViewModel, bool>((ref) {
  return AuthViewModel(ref);
});

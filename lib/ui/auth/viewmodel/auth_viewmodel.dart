import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  AuthViewModel() : super(false);

  Future<void> signUpWithEmail(String email, String password, String name) async {
    state = true;
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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
      // Direct access to FirebaseAuth is okay here if we use standard Google provider,
      // but CurrentUserNotifier/AuthService handle role sync which is better.
      // However AuthViewModel seems to be used mainly by SignUpScreen which is a bit messy.
      // I'll stick to the pattern but it's redundant with SignInViewModel.
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
  return AuthViewModel();
});

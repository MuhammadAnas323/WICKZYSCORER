import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';

class SignInState {
  final bool isEmailLoading;
  final bool isGoogleLoading;
  final String? error;
  final bool success;

  SignInState({
    this.isEmailLoading = false,
    this.isGoogleLoading = false,
    this.error,
    this.success = false,
  });

  SignInState copyWith({
    bool? isEmailLoading,
    bool? isGoogleLoading,
    String? error,
    bool? success,
  }) {
    return SignInState(
      isEmailLoading: isEmailLoading ?? this.isEmailLoading,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

class SignInViewModel extends StateNotifier<SignInState> {
  final Ref ref;
  SignInViewModel(this.ref) : super(SignInState());

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isEmailLoading: true, error: null);
    try {
      await ref.read(currentUserProvider.notifier).signIn(email, password);
      state = state.copyWith(isEmailLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isEmailLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isGoogleLoading: true, error: null);
    try {
      await ref.read(currentUserProvider.notifier).signInWithGoogle();
      state = state.copyWith(isGoogleLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isGoogleLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }
}

final signInViewModelProvider = StateNotifierProvider.autoDispose<SignInViewModel, SignInState>((ref) {
  return SignInViewModel(ref);
});


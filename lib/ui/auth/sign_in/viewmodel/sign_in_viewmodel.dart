import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';

class SignInState {
  final bool isLoading;
  final String? error;
  final bool success;

  SignInState({this.isLoading = false, this.error, this.success = false});

  SignInState copyWith({bool? isLoading, String? error, bool? success}) {
    return SignInState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

class SignInViewModel extends StateNotifier<SignInState> {
  final Ref ref;
  SignInViewModel(this.ref) : super(SignInState());

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(currentUserProvider.notifier).signIn(email, password);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final signInViewModelProvider = StateNotifierProvider.autoDispose<SignInViewModel, SignInState>((ref) {
  return SignInViewModel(ref);
});

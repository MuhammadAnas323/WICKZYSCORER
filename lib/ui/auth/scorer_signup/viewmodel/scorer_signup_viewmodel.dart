import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';

class ScorerSignupState {
  final bool isEmailLoading;
  final bool isGoogleLoading;
  final String? error;
  final bool success;

  ScorerSignupState({
    this.isEmailLoading = false,
    this.isGoogleLoading = false,
    this.error,
    this.success = false,
  });

  ScorerSignupState copyWith({
    bool? isEmailLoading,
    bool? isGoogleLoading,
    String? error,
    bool? success,
  }) {
    return ScorerSignupState(
      isEmailLoading: isEmailLoading ?? this.isEmailLoading,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

class ScorerSignupViewModel extends StateNotifier<ScorerSignupState> {
  final Ref ref;
  ScorerSignupViewModel(this.ref) : super(ScorerSignupState());

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? organization,
  }) async {
    state = state.copyWith(isEmailLoading: true, error: null);
    try {
      await ref.read(currentUserProvider.notifier).signUpScorer(
        name: name,
        email: email,
        password: password,
        organization: organization,
      );
      state = state.copyWith(isEmailLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isEmailLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> signUpWithGoogle({String? organization}) async {
    state = state.copyWith(isGoogleLoading: true, error: null);
    try {
      await ref
          .read(currentUserProvider.notifier)
          .signUpScorerWithGoogle(organization: organization);
      state = state.copyWith(isGoogleLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isGoogleLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }
}

final scorerSignupViewModelProvider = StateNotifierProvider.autoDispose<ScorerSignupViewModel, ScorerSignupState>((ref) {
  return ScorerSignupViewModel(ref);
});


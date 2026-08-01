import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';

class ScorerSignupState {
  final bool isLoading;
  final String? error;
  final bool success;

  ScorerSignupState({this.isLoading = false, this.error, this.success = false});

  ScorerSignupState copyWith({bool? isLoading, String? error, bool? success}) {
    return ScorerSignupState(
      isLoading: isLoading ?? this.isLoading,
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
    required String phone,
    required String address,
    String? organization,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(currentUserProvider.notifier).signUpScorer(
        name: name,
        email: email,
        password: password,
        phone: phone,
        address: address,
        organization: organization,
      );
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final scorerSignupViewModelProvider = StateNotifierProvider.autoDispose<ScorerSignupViewModel, ScorerSignupState>((ref) {
  return ScorerSignupViewModel(ref);
});

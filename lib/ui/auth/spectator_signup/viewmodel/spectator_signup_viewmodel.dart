import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';

class SpectatorSignupState {
  final bool isEmailLoading;
  final bool isGoogleLoading;
  final String? error;
  final bool success;

  SpectatorSignupState({
    this.isEmailLoading = false,
    this.isGoogleLoading = false,
    this.error,
    this.success = false,
  });

  SpectatorSignupState copyWith({
    bool? isEmailLoading,
    bool? isGoogleLoading,
    String? error,
    bool? success,
  }) {
    return SpectatorSignupState(
      isEmailLoading: isEmailLoading ?? this.isEmailLoading,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

class SpectatorSignupViewModel extends StateNotifier<SpectatorSignupState> {
  final Ref ref;
  SpectatorSignupViewModel(this.ref) : super(SpectatorSignupState());

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? favoriteTournamentId,
  }) async {
    state = state.copyWith(isEmailLoading: true, error: null);
    try {
      await ref.read(currentUserProvider.notifier).signUpSpectator(
        name: name,
        email: email,
        password: password,
        favoriteTournamentId: favoriteTournamentId,
      );
      state = state.copyWith(isEmailLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isEmailLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> signUpWithGoogle() async {
    state = state.copyWith(isGoogleLoading: true, error: null);
    try {
      await ref
          .read(currentUserProvider.notifier)
          .signUpSpectatorWithGoogle();
      state = state.copyWith(isGoogleLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isGoogleLoading: false, error: AppErrorHandler.getUserFriendlyMessage(e));
    }
  }
}

final spectatorSignupViewModelProvider = StateNotifierProvider.autoDispose<SpectatorSignupViewModel, SpectatorSignupState>((ref) {
  return SpectatorSignupViewModel(ref);
});


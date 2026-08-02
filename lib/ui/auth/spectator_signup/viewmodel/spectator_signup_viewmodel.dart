import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';

class SpectatorSignupState {
  final bool isLoading;
  final String? error;
  final bool success;

  SpectatorSignupState({this.isLoading = false, this.error, this.success = false});

  SpectatorSignupState copyWith({bool? isLoading, String? error, bool? success}) {
    return SpectatorSignupState(
      isLoading: isLoading ?? this.isLoading,
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(currentUserProvider.notifier).signUpSpectator(
        name: name,
        email: email,
        password: password,
        favoriteTournamentId: favoriteTournamentId,
      );
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final spectatorSignupViewModelProvider = StateNotifierProvider.autoDispose<SpectatorSignupViewModel, SpectatorSignupState>((ref) {
  return SpectatorSignupViewModel(ref);
});

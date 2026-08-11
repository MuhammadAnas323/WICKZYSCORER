import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SplashState {
  initializing,
  loading,
  complete,
}

class SplashViewModel extends StateNotifier<SplashState> {
  SplashViewModel() : super(SplashState.initializing) {
    _startLoadingProcess();
  }

  Future<void> _startLoadingProcess() async {
    // Simulate initialization
    await Future.delayed(const Duration(milliseconds: 400));
    state = SplashState.loading;

    // Simulate heavy match engine loading
    // In a real scenario, this would await actual initialization futures
    await Future.delayed(const Duration(milliseconds: 3600));

    // Master timeline (4s) + simulated loading (0.4s + 3.6s) = exactly 4000ms,
    // so navigation fires right as the master timeline completes — the total
    // Flutter splash is exactly 4s (native 1s + Flutter 4s = 5s launch).
    state = SplashState.complete;
  }
}

final splashViewModelProvider = StateNotifierProvider<SplashViewModel, SplashState>((ref) {
  return SplashViewModel();
});

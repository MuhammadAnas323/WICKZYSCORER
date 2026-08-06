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
    await Future.delayed(const Duration(milliseconds: 500));
    state = SplashState.loading;
    
    // Simulate heavy match engine loading
    // In a real scenario, this would await actual initialization futures
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // Timeline finishes loading at around 2.5s and navigates at 3.0s
    await Future.delayed(const Duration(milliseconds: 500));
    state = SplashState.complete;
  }
}

final splashViewModelProvider = StateNotifierProvider<SplashViewModel, SplashState>((ref) {
  return SplashViewModel();
});

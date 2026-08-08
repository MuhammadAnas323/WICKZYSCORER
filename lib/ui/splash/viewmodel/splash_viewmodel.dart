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
    await Future.delayed(const Duration(milliseconds: 4200));
    
    // Timeline finishes loading at around 4.6s and navigates at 5.0s, right
    // after the logo has finished spinning.
    await Future.delayed(const Duration(milliseconds: 400));
    state = SplashState.complete;
  }
}

final splashViewModelProvider = StateNotifierProvider<SplashViewModel, SplashState>((ref) {
  return SplashViewModel();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashState {
  final bool isLoading;
  const SplashState({this.isLoading = true});
  SplashState copyWith({bool? isLoading}) =>
    SplashState(isLoading: isLoading ?? this.isLoading);
}

class SplashViewModel extends StateNotifier<SplashState> {
  SplashViewModel() : super(const SplashState()) {
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds: 3));
    state = state.copyWith(isLoading: false);
  }
}

final splashViewModelProvider = StateNotifierProvider<SplashViewModel, SplashState>(
  (ref) => SplashViewModel());

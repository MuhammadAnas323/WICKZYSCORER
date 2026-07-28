import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  final int currentPage;
  const OnboardingState({this.currentPage = 0});
  OnboardingState copyWith({int? currentPage}) =>
    OnboardingState(currentPage: currentPage ?? this.currentPage);
}

class OnboardingViewModel extends StateNotifier<OnboardingState> {
  OnboardingViewModel() : super(const OnboardingState());

  void nextPage() {
    if (state.currentPage < 3) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }

  void setPage(int page) => state = state.copyWith(currentPage: page);
}

final onboardingViewModelProvider =
    StateNotifierProvider<OnboardingViewModel, OnboardingState>(
  (ref) => OnboardingViewModel());

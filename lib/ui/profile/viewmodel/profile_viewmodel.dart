import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileState {
  final String displayName;
  final String favoriteTeam;
  final int savedMatches;
  final bool notificationsEnabled;
  const ProfileState({
    this.displayName = 'Cricket Fan',
    this.favoriteTeam = '🏑 Pakistan',
    this.savedMatches = 5,
    this.notificationsEnabled = true,
  });
  ProfileState copyWith({String? displayName, String? favoriteTeam,
    int? savedMatches, bool? notificationsEnabled}) =>
    ProfileState(
      displayName: displayName ?? this.displayName,
      favoriteTeam: favoriteTeam ?? this.favoriteTeam,
      savedMatches: savedMatches ?? this.savedMatches,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
}

class ProfileViewModel extends StateNotifier<ProfileState> {
  ProfileViewModel() : super(const ProfileState());
  void updateName(String name) => state = state.copyWith(displayName: name);
  void toggleNotifications() => state = state.copyWith(
    notificationsEnabled: !state.notificationsEnabled);
}

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>(
  (ref) => ProfileViewModel());

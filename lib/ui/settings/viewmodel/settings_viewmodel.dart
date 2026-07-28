import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool liveScoreAlerts;
  final bool wicketAlerts;
  final bool matchStartAlerts;
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.liveScoreAlerts = true,
    this.wicketAlerts = true,
    this.matchStartAlerts = true,
  });
  SettingsState copyWith({ThemeMode? themeMode, bool? notificationsEnabled,
    bool? liveScoreAlerts, bool? wicketAlerts, bool? matchStartAlerts}) =>
    SettingsState(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      liveScoreAlerts: liveScoreAlerts ?? this.liveScoreAlerts,
      wicketAlerts: wicketAlerts ?? this.wicketAlerts,
      matchStartAlerts: matchStartAlerts ?? this.matchStartAlerts,
    );
}

class SettingsViewModel extends StateNotifier<SettingsState> {
  SettingsViewModel() : super(const SettingsState());

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
  void toggleNotifications() => state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
  void toggleLiveScore() => state = state.copyWith(liveScoreAlerts: !state.liveScoreAlerts);
  void toggleWicket() => state = state.copyWith(wicketAlerts: !state.wicketAlerts);
  void toggleMatchStart() => state = state.copyWith(matchStartAlerts: !state.matchStartAlerts);
}

final settingsViewModelProvider = StateNotifierProvider<SettingsViewModel, SettingsState>(
  (ref) => SettingsViewModel());

// Global theme mode provider watched by MaterialApp
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final bool notificationsEnabled;
  final bool liveScoreAlerts;
  final bool wicketAlerts;
  final bool matchStartAlerts;
  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.locale = const Locale('en'),
    this.notificationsEnabled = true,
    this.liveScoreAlerts = true,
    this.wicketAlerts = true,
    this.matchStartAlerts = true,
  });
  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? notificationsEnabled,
    bool? liveScoreAlerts,
    bool? wicketAlerts,
    bool? matchStartAlerts,
  }) =>
    SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      liveScoreAlerts: liveScoreAlerts ?? this.liveScoreAlerts,
      wicketAlerts: wicketAlerts ?? this.wicketAlerts,
      matchStartAlerts: matchStartAlerts ?? this.matchStartAlerts,
    );
}

class SettingsViewModel extends StateNotifier<SettingsState> {
  SettingsViewModel() : super(const SettingsState());

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setLocale(Locale locale) => state = state.copyWith(locale: locale);
  void toggleNotifications() => state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
  void toggleLiveScore() => state = state.copyWith(liveScoreAlerts: !state.liveScoreAlerts);
  void toggleWicket() => state = state.copyWith(wicketAlerts: !state.wicketAlerts);
  void toggleMatchStart() => state = state.copyWith(matchStartAlerts: !state.matchStartAlerts);
}

final settingsViewModelProvider = StateNotifierProvider<SettingsViewModel, SettingsState>(
  (ref) => SettingsViewModel());

// Global theme mode provider watched by MaterialApp
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final settings = ref.watch(settingsViewModelProvider);
  return settings.themeMode;
});

// Global locale provider watched by MaterialApp
final localeProvider = StateProvider<Locale>((ref) {
  final settings = ref.watch(settingsViewModelProvider);
  return settings.locale;
});

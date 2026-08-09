import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Preference keys ──────────────────────────────────────────────────────────
const _kTheme = 'pref_theme_mode';
const _kLocale = 'pref_locale';
const _kNotifEnabled = 'pref_notif_enabled';
const _kLiveScore = 'pref_live_score';
const _kWicket = 'pref_wicket';
const _kMatchStart = 'pref_match_start';

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
  SettingsViewModel() : super(const SettingsState()) { _load(); }

  // ── Load from SharedPreferences on startup ────────────────────────────────
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_kLocale) ?? 'en';
    state = SettingsState(
      // The app is light-mode only; ignore any previously saved dark theme.
      themeMode: ThemeMode.light,
      locale: Locale(langCode),
      notificationsEnabled: prefs.getBool(_kNotifEnabled) ?? true,
      liveScoreAlerts: prefs.getBool(_kLiveScore) ?? true,
      wicketAlerts: prefs.getBool(_kWicket) ?? true,
      matchStartAlerts: prefs.getBool(_kMatchStart) ?? true,
    );
  }

  // ── Persist helpers ───────────────────────────────────────────────────────
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTheme, state.themeMode.index);
    await prefs.setString(_kLocale, state.locale.languageCode);
    await prefs.setBool(_kNotifEnabled, state.notificationsEnabled);
    await prefs.setBool(_kLiveScore, state.liveScoreAlerts);
    await prefs.setBool(_kWicket, state.wicketAlerts);
    await prefs.setBool(_kMatchStart, state.matchStartAlerts);
  }

  // ── Public API ────────────────────────────────────────────────────────────
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _save();
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _save();
  }

  Future<void> toggleNotifications() async {
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
    await _save();
  }

  Future<void> toggleLiveScore() async {
    state = state.copyWith(liveScoreAlerts: !state.liveScoreAlerts);
    await _save();
  }

  Future<void> toggleWicket() async {
    state = state.copyWith(wicketAlerts: !state.wicketAlerts);
    await _save();
  }

  Future<void> toggleMatchStart() async {
    state = state.copyWith(matchStartAlerts: !state.matchStartAlerts);
    await _save();
  }
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

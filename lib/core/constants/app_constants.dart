// lib/core/constants/app_constants.dart
// Core application constants used throughout SPORTYAPP.

/// Application-wide constants for SPORTYAPP.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'SPORTYAPP';
  static const String appTagline = 'Live Cricket. Every Ball.';
  static const String appVersion = '1.0.0';

  // Animation durations
  static const Duration splashDuration = Duration(milliseconds: 2500);
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);
  static const Duration pulseInterval = Duration(milliseconds: 900);

  // Spacing scale (8pt grid)
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // Border radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusFull = 100.0;

  // Card elevation
  static const double elevationLow = 2.0;
  static const double elevationMid = 4.0;
  static const double elevationHigh = 8.0;

  // Bottom nav
  static const int bottomNavHome = 0;
  static const int bottomNavLive = 1;
  static const int bottomNavMatches = 2;
  static const int bottomNavTournaments = 3;
  static const int bottomNavProfile = 4;

  // SharedPreferences keys
  static const String prefIsFirstLaunch = 'is_first_launch';
  static const String prefThemeMode = 'theme_mode';
  static const String prefNotificationsEnabled = 'notifications_enabled';

  // Match status strings
  static const String statusLive = 'live';
  static const String statusUpcoming = 'upcoming';
  static const String statusCompleted = 'completed';

  // Agora
  static const String agoraAppId = '12982bdfadab4b378b96d4a6cb0bf604';
  static const String agoraAppCertificate = ''; // stored server-side only
  static const String agoraTempToken =
      '007eJxTYEg7vFvr6Tle63WiYv7V86v3T7/N+v+A5BUun1/zmHfJR5YrMBgaWVoYJaWkJaYkJpkkGZtbJFmapZgkmiUnGSSlmRmYXM/JyGoIZGTwMrJmZmSAQBCfkyE4wD8oJNIxIICBAQDg8CAe';
  static const String agoraTempChannelName = 'SPORTYAPP';
}

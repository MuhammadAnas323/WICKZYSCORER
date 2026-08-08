// lib/main.dart
// Entry point for CRIXORA.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/routes/app_router.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/theme/app_theme.dart';
import 'package:sportyapp/ui/scorer/shared/widgets/cloud_error_toast.dart';
import 'package:sportyapp/ui/settings/viewmodel/settings_viewmodel.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/services/match_alert_service.dart';
import 'package:sportyapp/core/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sportyapp/firebase_options.dart';

/// One-time cleanup key — set to true after the legacy data wipe has run once.
const _kCleanupV2Done = 'scorer_cleanup_v2_done';

/// One-time local cache clear key — set to true after stale SharedPreferences
/// scorer/spectator copies have been removed once.
const _kLocalClearDone = 'scorer_local_clear_done';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase — must be awaited before runApp().
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (_) {
    // Already initialized — safe to ignore.
  }

  // Set system UI style overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // Lock orientation to portrait (since build is for mobile phones only)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // One-time cleanup: remove ALL current tournaments and matches (Task 4).
  // This wipes the old demo/test data once so it can never reach the scorer or
  // spectator side again. It is intentionally a ONE-SHOT migration — after it
  // runs the ownership rules in `firestore.rules` take over. If the rules are
  // already deployed (ownership-enforcing), keep `allow write` temporary or run
  // this wipe from the Firebase console instead.
  final cleanupPrefs = await SharedPreferences.getInstance();
  if (!(cleanupPrefs.getBool(_kCleanupV2Done) ?? false)) {
    final cleanupContainer = ProviderContainer();
    try {
      await cleanupContainer
          .read(scorerRepositoryProvider)
          .purgeAllForCleanup();
      await cleanupPrefs.setBool(_kCleanupV2Done, true);
    } catch (_) {
      // Best-effort cleanup; never block startup on it.
    }
    cleanupContainer.dispose();
  }

  // One-time local cache clear: drop stale SharedPreferences copies of scorer
  // data so BOTH the scorer and spectator portions reload purely from Firestore
  // (which is now the single source of truth for completed/live results).
  if (!(cleanupPrefs.getBool(_kLocalClearDone) ?? false)) {
    final clearContainer = ProviderContainer();
    try {
      await clearContainer
          .read(scorerRepositoryProvider)
          .clearLocalCache();
      await cleanupPrefs.setBool(_kLocalClearDone, true);
    } catch (_) {
      // Best-effort; never block startup on it.
    }
    clearContainer.dispose();
  }

  // Schedule notification setup AFTER the first frame instead of awaiting it
  // before runApp(): creating the Android channels and requesting permission
  // are platform-channel round-trips that otherwise block the splash from
  // rendering. The service lazy-initializes on first use, and taps that arrive
  // before init finishes are buffered until `onMatchTap` is set.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.instance.init();
  });

  runApp(
    const ProviderScope(
      child: SportyApp(),
    ),
  );
}

class SportyApp extends ConsumerWidget {
  const SportyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // Keep the match-alert RTDB listener alive for the whole app lifetime.
    ref.watch(matchAlertListenerProvider);

    // Route notification taps to the tapped match. Buffered taps (e.g. when the
    // app was opened from a terminated state) are delivered here.
    NotificationService.instance.onMatchTap = (matchId) {
      router.push('/spectator/match/$matchId');
    };

    return MaterialApp.router(
      title: 'CRIXORA',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const CloudErrorToast(),
          ],
        );
      },

      // Theme Mode configurations
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      // Localization
      locale: locale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('ur', ''),
      ],
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Router configuration
      routerConfig: router,
    );
  }
}

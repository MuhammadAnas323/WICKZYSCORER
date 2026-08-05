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
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sportyapp/firebase_options.dart';

/// One-time cleanup key — set to true after the legacy data wipe has run once.
const _kCleanupV2Done = 'scorer_cleanup_v2_done';

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

    return MaterialApp.router(
      title: 'CRIXORA',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const CloudErrorToast(),
        ],
      ),

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

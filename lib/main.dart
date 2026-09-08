// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/routes/app_router.dart';
import 'package:sportyapp/theme/app_theme.dart';
import 'package:sportyapp/ui/scorer/shared/widgets/cloud_error_toast.dart';
import 'package:sportyapp/ui/settings/viewmodel/settings_viewmodel.dart';
import 'package:sportyapp/ui/splash/view/wickzy_splash_screen.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/core/services/match_alert_service.dart';
import 'package:sportyapp/core/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sportyapp/firebase_options.dart';

void main() {
  mainCommon(DefaultFirebaseOptions.currentPlatform);
}

/// Common app entry point called by main_dev.dart and main_prod.dart
void mainCommon(FirebaseOptions firebaseOptions) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase with environment-specific options
  try {
    await Firebase.initializeApp(
      options: firebaseOptions,
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

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

    // Route notification taps to the tapped match.
    NotificationService.instance.onMatchTap = (matchId) {
      router.push('/spectator/match/$matchId');
    };

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SplashGate(
        child: MaterialApp.router(
          title: 'Wickzy Scorer',
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
        ),
      ),
    );
  }
}
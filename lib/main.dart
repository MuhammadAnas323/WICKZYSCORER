// lib/main.dart
// Entry point for CRIXORA.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/routes/app_router.dart';
import 'package:sportyapp/theme/app_theme.dart';
import 'package:sportyapp/ui/settings/viewmodel/settings_viewmodel.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sportyapp/firebase_options.dart';

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

    return MaterialApp.router(
      title: 'CRIXORA',
      debugShowCheckedModeBanner: false,

      // Theme Mode configurations
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      // Router configuration
      routerConfig: router,
    );
  }
}

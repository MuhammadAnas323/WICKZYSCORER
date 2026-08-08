// test/splash_background_test.dart
// Guards the splash background fix: the animated background must render without
// attempting to load the (never-shipped) `assets/images/splash_bg.jpg`, which
// previously produced the "Unable to load asset" runtime error on startup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/ui/splash/widgets/animated_background.dart';

void main() {
  testWidgets('AnimatedBackground renders without an asset load error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0D2818),
          body: AnimatedBackground(child: SizedBox.expand()),
        ),
      ),
    );
    // Pump several frames so any image-stream error from the old
    // `DecorationImage(AssetImage(...))` would have surfaced by now.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(AnimatedBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

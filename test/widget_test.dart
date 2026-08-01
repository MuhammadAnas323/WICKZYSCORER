// test/widget_test.dart
// Basic smoke test for CRIXORA.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/main.dart';

void main() {
  testWidgets('SportyApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SportyApp(),
      ),
    );

    // Verify that the splash screen or initial layout builds.
    expect(find.byType(SportyApp), findsOneWidget);
  });
}

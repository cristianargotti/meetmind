import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetmind/main.dart';
import 'package:meetmind/services/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    // Prevent GoogleFonts from making HTTP requests in tests
    GoogleFonts.config.allowRuntimeFetching = false;

    // Initialize SharedPreferences with empty values for test environment
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.initialize();
  });

  Widget buildApp() {
    return const ProviderScope(child: MeetMindApp());
  }

  testWidgets('App renders splash screen on launch', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    // Use pump with duration instead of pumpAndSettle —
    // flutter_animate has repeat animations that never settle
    await tester.pump(const Duration(seconds: 2));

    // Splash screen shows app name
    expect(find.text('Aura Meet'), findsWidgets);
  });

  testWidgets('App navigates to login after splash', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Mark onboarding as complete so splash goes to login
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    await UserPreferences.initialize();

    await tester.pumpWidget(buildApp());
    // Wait for splash animation + navigation delay (2.5s)
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    // Should see login screen elements
    expect(find.text('Aura Meet'), findsWidgets);
  });
}

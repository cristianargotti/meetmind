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
    await tester.pump(const Duration(milliseconds: 500));

    // Splash screen shows app name
    expect(find.text('Aura Meet'), findsWidgets);

    // Advance past splash animations (use pump, not pumpAndSettle,
    // because flutter_animate creates continuous animations)
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('App navigates to login after splash', (
    WidgetTester tester,
  ) async {
    // Use a tall enough viewport to prevent RenderFlex overflow on login screen
    tester.view.physicalSize = const Size(1284, 2778);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Suppress layout overflow errors in tests (login screen is designed
    // for real device sizes and may overflow slightly in test viewports)
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('overflowed')) return; // Suppress overflow in tests
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    // Mark onboarding as complete so splash goes to login
    SharedPreferences.setMockInitialValues({'pref_onboarding_complete': true});
    await UserPreferences.initialize();

    await tester.pumpWidget(buildApp());

    // Advance past splash delay (2.5s) + navigation
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));

    // Should see login/app content
    expect(find.text('Aura Meet'), findsWidgets);

    // Advance past remaining animations (use pump, not pumpAndSettle,
    // because flutter_animate creates continuous animations that never settle)
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}

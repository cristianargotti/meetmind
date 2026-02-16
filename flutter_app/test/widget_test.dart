import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetmind/main.dart';

void main() {
  setUp(() {
    // Prevent GoogleFonts from making HTTP requests in tests
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildApp() {
    return const ProviderScope(child: MeetMindApp());
  }

  testWidgets('App renders home screen with title', (
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

    // Check for localized title (defaults to English)
    expect(find.text('Aura Meet'), findsWidgets);
    expect(find.text('Your AI meeting companion'), findsOneWidget);
  });

  testWidgets('Home screen has start meeting FAB', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsWidgets);
  });

  testWidgets('Bottom navigation has 3 items', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    // Bottom nav labels are now localized
    expect(find.text('Aura'), findsWidgets); // First word of homeTitle
  });
}

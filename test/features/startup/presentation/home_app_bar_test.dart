// Stage B3-R1 Slice D — focused tests for the Home top-bar cleanup.
//
// Slice D removed the Home top-bar calendar and shield actions so
// only the hamburger navigation and the Home title remain. The
// underlying domain/security logic is unchanged — Privacy remains
// reachable through the global navigation drawer — but the AppBar
// no longer renders the two removed controls.
//
// The Home screen reads the StartupController, so the harness
// uses the full TestPrivacyDependencies.buildApp with a real
// Drift-backed startup repository and completes onboarding to
// land naturally on the Home screen. The assertions then drill
// into the HomeScreen subtree by key.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  group('Stage B3-R1 Slice D: Home top-bar cleanup', () {
    testWidgets('TEST 1 — Home title and hamburger remain present', (
      tester,
    ) async {
      await _pumpHome(tester);
      expect(find.byKey(const Key('home-app-bar')), findsOneWidget);
      expect(find.byKey(const Key('home-title')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-app-bar')),
          matching: find.text('Home'),
        ),
        findsOneWidget,
        reason: 'AppBar title text must read "Home" exactly once',
      );
      expect(find.byKey(const Key('home-hamburger')), findsOneWidget);
    });

    testWidgets('TEST 2 — Home calendar top-bar action is absent', (
      tester,
    ) async {
      await _pumpHome(tester);
      // Slice C removed the calendar action. Slice D keeps it
      // removed — the AppBar must not contain a calendar IconButton.
      expect(find.byTooltip('Open today in Planner'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-app-bar')),
          matching: find.byIcon(Icons.calendar_month_outlined),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('home-app-bar')),
          matching: find.byIcon(Icons.today_outlined),
        ),
        findsNothing,
      );
    });

    testWidgets('TEST 3 — Home shield top-bar action is absent', (
      tester,
    ) async {
      await _pumpHome(tester);
      expect(find.byTooltip('Open privacy lock'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-app-bar')),
          matching: find.byIcon(Icons.shield_outlined),
        ),
        findsNothing,
        reason: 'no shield icon may live inside the Home AppBar',
      );
    });

    testWidgets('TEST 4 — AppBar has no top-bar actions', (tester) async {
      await _pumpHome(tester);
      final appBarFinder = find.byKey(const Key('home-app-bar'));
      final appBar = tester.widget<AppBar>(appBarFinder);
      expect(
        appBar.actions,
        isEmpty,
        reason: 'no top-bar actions remain on the Home AppBar',
      );
      // The hamburger remains the only IconButton inside the
      // AppBar; no other tap targets survive the cleanup.
      expect(
        find.descendant(of: appBarFinder, matching: find.byType(IconButton)),
        findsOneWidget,
        reason: 'only the hamburger IconButton remains',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('TEST 5 — hamburger resolves the global drawer scope', (
      tester,
    ) async {
      await _pumpHome(tester);
      // The hamburger must resolve GlobalDrawerScope.of(...) and
      // call its open() hook. With the app shell attached the
      // drawer open path runs; with no shell the controller
      // returns false and the tap must not throw. The test only
      // asserts that the tap completes without an exception.
      final hamburger = find.byKey(const Key('home-hamburger'));
      await tester.tap(hamburger);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TEST 6 — bottom navigation remains unchanged', (tester) async {
      await _pumpHome(tester);
      // The bottom navigation anchors the five primary tabs:
      // Home, Planner, Pathways, Contacts, More. Slice D does not
      // touch it. Assert the navigation anchor key exists and
      // that each tab label is present inside the navigation.
      expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);
      final bottomNav = find.byKey(const Key('main-bottom-navigation'));
      expect(
        find.descendant(of: bottomNav, matching: find.text('Home')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomNav, matching: find.text('Planner')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomNav, matching: find.text('Pathways')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomNav, matching: find.text('Contacts')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomNav, matching: find.text('More')),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(862, 1824);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final database = openMemoryDatabase();
  addTearDown(database.close);
  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();

  await tester.pumpWidget(
    privacy.buildApp(
      environment: const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
      diagnostics: SanitizedDiagnostics(),
      startupRepository: startup,
      plannerDateSource: const FixedPlannerDateSource(
        PlannerDate(year: 2026, month: 7, day: 31),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

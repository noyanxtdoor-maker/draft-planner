// Pack 3 — centralized Settings home.
//
// Only real sections/rows appear; every row reads real state and performs
// real behavior; unsupported settings (Appearance, Notifications section,
// Accessibility, Country and Language, Contacts, Account/Sync) are absent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/presentation/planner_settings_screen.dart';
import 'package:rmplanner/features/privacy/presentation/permissions_screen.dart';
import 'package:rmplanner/features/privacy/presentation/privacy_center_screen.dart';
import 'package:rmplanner/features/settings/presentation/colors_screen.dart';
import 'package:rmplanner/features/settings/presentation/settings_screen.dart';
import 'package:rmplanner/features/settings/presentation/start_of_week_screen.dart';

import '../../../support/test_dependencies.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
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
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home-hamburger')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('drawer-account-settings')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('global-app-drawer-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer-account-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('Settings shows only the real canonical sections and rows', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    expect(
      find.byKey(const Key('settings-section-privacy-and-device')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings-section-planner-and-calendar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings-section-planning')),
      findsOneWidget,
    );

    for (final key in <String>[
      'settings-privacy-data',
      'settings-permissions',
      'settings-planner-calendar',
      'settings-colors',
      'settings-start-of-week',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }

    // Unsupported settings must not appear (locked policy 8 / 10).
    for (final key in <String>[
      'settings-section-appearance',
      'settings-section-notifications',
      'settings-section-accessibility',
      'settings-section-country-and-language',
      'settings-section-contacts',
      'settings-section-account-and-sync',
    ]) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    for (final text in <String>[
      'Appearance',
      'Theme',
      'Accent Color',
      'Accessibility',
      'Country and Language',
      'Sync preferences',
    ]) {
      expect(find.text(text), findsNothing, reason: 'unsupported: $text');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every visible row reads real state and performs real '
      'behavior', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);

    // Permissions reads the real (denied) permission gateway state.
    await tester.tap(find.byKey(const Key('settings-permissions')));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionsScreen), findsOneWidget);
    expect(find.text('Not requested'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Privacy and Data opens the canonical Privacy Center.
    await tester.tap(find.byKey(const Key('settings-privacy-data')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyCenterScreen), findsOneWidget);
    expect(find.text('Privacy controls'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Planner and Calendar opens the real planner settings.
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-planner-calendar')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-planner-calendar')));
    await tester.pumpAndSettle();
    expect(find.byType(PlannerSettingsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Colors opens the real colors screen.
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-colors')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-colors')));
    await tester.pumpAndSettle();
    expect(find.byType(ColorsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Start of week opens the real selector.
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-start-of-week')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings-start-of-week')));
    await tester.pumpAndSettle();
    expect(find.byType(StartOfWeekScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

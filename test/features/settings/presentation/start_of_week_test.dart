import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/settings/data/drift_start_of_week_repository.dart';
import 'package:rmplanner/features/settings/presentation/settings_screen.dart';
import 'package:rmplanner/features/settings/presentation/start_of_week_screen.dart';

import '../../../support/test_dependencies.dart';

void main() {
  Future<AppDatabase> pumpToSettings(WidgetTester tester) async {
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
    return database;
  }

  testWidgets('Settings shows the PLANNING section with Start of week = Monday',
      (tester) async {
    await pumpToSettings(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      find.byKey(const Key('settings-section-planning')),
      findsOneWidget,
    );
    final row = find.byKey(const Key('settings-start-of-week'));
    expect(row, findsOneWidget);
    expect(find.text('Start of week'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
  });

  testWidgets(
      'selector defaults to the persisted day and offers all 7 choices',
      (tester) async {
    await pumpToSettings(tester);
    await tester.tap(find.byKey(const Key('settings-start-of-week')));
    await tester.pumpAndSettle();
    expect(find.byType(StartOfWeekScreen), findsOneWidget);
    for (final day in <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ]) {
      expect(find.text(day), findsOneWidget);
    }
    // Monday (day 1) is selected by default.
    final group = tester.widget<RadioGroup<int>>(
      find.byType(RadioGroup<int>),
    );
    expect(group.groupValue, DateTime.monday);
  });

  testWidgets('Cancel keeps the previous value and does not persist',
      (tester) async {
    final database = await pumpToSettings(tester);
    await tester.tap(find.byKey(const Key('settings-start-of-week')));
    await tester.pumpAndSettle();
    // Select Tuesday -> confirmation appears.
    await tester.tap(find.byKey(const Key('start-of-week-2')));
    await tester.pumpAndSettle();
    expect(find.text('Change start of week?'), findsOneWidget);
    expect(find.textContaining('will not be deleted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-of-week-cancel')));
    await tester.pumpAndSettle();
    // Selection reverted: Monday still chosen.
    final group = tester.widget<RadioGroup<int>>(
      find.byType(RadioGroup<int>),
    );
    expect(group.groupValue, DateTime.monday);
    final repository = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    final profile = await (database.select(database.localProfiles)
          ..where((table) => table.slot.equals('primary')))
        .getSingle();
    expect(
      await repository.readStartOfWeek(profileId: profile.id),
      DateTime.monday,
    );
  });

  testWidgets('Confirm persists the new day and the Settings subtitle updates',
      (tester) async {
    final database = await pumpToSettings(tester);
    await tester.tap(find.byKey(const Key('settings-start-of-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-of-week-7')));
    await tester.pumpAndSettle();
    expect(find.text('Change start of week?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-of-week-confirm')));
    await tester.pumpAndSettle();
    // Back on Settings with the new day shown.
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
    final repository = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    final profile = await (database.select(database.localProfiles)
          ..where((table) => table.slot.equals('primary')))
        .getSingle();
    expect(
      await repository.readStartOfWeek(profileId: profile.id),
      DateTime.sunday,
    );
  });
}

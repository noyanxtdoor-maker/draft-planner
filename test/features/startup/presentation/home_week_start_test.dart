import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/settings/data/drift_start_of_week_repository.dart';

import '../../../support/test_dependencies.dart';

void main() {
  // 2026-08-13 is a Thursday.  Monday week = Aug 10-16; Sunday week = Aug 9-15.
  const thursday = PlannerDate(year: 2026, month: 8, day: 13);

  Future<void> pumpHome(
    WidgetTester tester,
    AppDatabase database, {
    PlannerDate today = thursday,
  }) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        plannerDateSource: FixedPlannerDateSource(today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unestablished current period hides cards and shows Start Planning',
      (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    await pumpHome(tester, database);

    // Header + View All remain.
    expect(find.text('Life Goals'), findsOneWidget);
    expect(find.byKey(const Key('home-wli-view-all')), findsOneWidget);
    // Life Goal cards are hidden.
    final goalCards = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('home-indicator-goal-');
    });
    expect(goalCards, findsNothing);
    expect(find.byKey(const Key('home-daily-target-quick-control')), findsNothing);
    // Centered Start Planning is visible.
    expect(find.byKey(const Key('home-start-weekly-planning')), findsOneWidget);
    expect(find.text('Start Planning'), findsOneWidget);
    // The established pill is NOT shown.
    expect(find.text('Goal Planning'), findsNothing);
    // Active Pathways unchanged.
    expect(find.byKey(const Key('home-pathway-employment')), findsOneWidget);
  });

  testWidgets(
      'deliberate entry establishes the period; Home then shows cards and '
      'Goal Planning', (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    await pumpHome(tester, database);

    expect(find.byKey(const Key('home-start-weekly-planning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-start-weekly-planning')));
    await tester.pumpAndSettle();
    // The Goal Planning screen opens with the new title.
    expect(find.text('Goal Planning'), findsWidgets);

    // Return Home: now established.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Goal Planning'), findsOneWidget);
    expect(find.byKey(const Key('home-start-weekly-planning')), findsNothing);
    // Cards are visible again (the six canonical Goals were bootstrapped).
    final goalCards = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('home-indicator-goal-');
    });
    expect(goalCards, findsWidgets);
  });

  testWidgets('established Home shows the Goal Planning pill and 0/0 for unset',
      (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    await establishWeeklyPlan(
      database: database,
      profileId: profile.id,
      date: thursday,
    );
    await pumpHome(tester, database);

    expect(find.byKey(const Key('home-start-weekly-planning')), findsNothing);
    expect(find.text('Goal Planning'), findsOneWidget);
    // Home-only unset target renders 0/0 (never 0/Not set).
    expect(find.textContaining('Not set'), findsNothing);
    expect(find.text('0/0'), findsWidgets);
  });

  testWidgets('a non-Monday configured start is used for the current period',
      (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final startOfWeek = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 13, 12)),
    );
    await startOfWeek.saveStartOfWeek(
      profileId: profile.id,
      startDay: DateTime.sunday,
    );
    // Establish the SUNDAY week (Aug 9-15), not the Monday week (Aug 10-16).
    await establishWeeklyPlan(
      database: database,
      profileId: profile.id,
      date: thursday,
      startDay: DateTime.sunday,
    );
    await pumpHome(tester, database);

    expect(find.text('Goal Planning'), findsOneWidget);
    expect(find.byKey(const Key('home-start-weekly-planning')), findsNothing);
    // With only the Sunday week established, opening planning must land on
    // the Sunday-resolved period (Aug 9-15).
    await tester.tap(find.byKey(const Key('weekly-targets-button')));
    await tester.pumpAndSettle();
    expect(find.text('Goal Planning'), findsWidgets);
    expect(find.text('Aug 9 – Aug 15, 2026'), findsOneWidget);
  });
}

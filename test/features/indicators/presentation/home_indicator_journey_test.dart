import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets('AC-B-001..007,012..018,020: Home shows six factual cards and '
      'target prompt at the approved viewport', (tester) async {
    const monday = PlannerDate(year: 2026, month: 7, day: 27);
    tester.view.physicalSize = const Size(941, 1672);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final startup = buildTestRepository(database: database);
    await startup.completeOnboarding();
    final privacy = TestPrivacyDependencies(database: database);

    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        plannerDateSource: const FixedPlannerDateSource(monday),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly Life Indicators'), findsOneWidget);
    expect(find.byKey(const Key('home-active-period')), findsOneWidget);
    for (final key in <String>[
      'job_applications',
      'scripture_study',
      'exercise',
      'meaningful_connections',
      'budget_review',
      'temple_visit',
    ]) {
      expect(find.byKey(Key('home-indicator-$key')), findsOneWidget);
    }
    expect(find.text('Actual'), findsNWidgets(6));
    expect(find.text('Target'), findsNWidgets(6));
    expect(find.text('Scheduled'), findsNWidgets(6));
    expect(find.text('Not set'), findsNWidgets(6));
    expect(find.textContaining('worthiness'), findsNothing);

    await tester.tap(find.byKey(const Key('home-indicator-job_applications')));
    await tester.pumpAndSettle();
    expect(find.text('Indicator Detail'), findsOneWidget);
    expect(find.text('2026-07-27 — 2026-08-02'), findsOneWidget);
    expect(find.text('Contribution History'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-targets-button')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-indicator-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('weekly-targets-button')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Targets'), findsOneWidget);
    expect(find.textContaining('Actual is read-only'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Q4 / AC-B-002,003,016: Home remains usable at 200% text scale', (
    tester,
  ) async {
    const monday = PlannerDate(year: 2026, month: 7, day: 27);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 2.5;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final startup = buildTestRepository(database: database);
    await startup.completeOnboarding();
    final privacy = TestPrivacyDependencies(database: database);

    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        plannerDateSource: const FixedPlannerDateSource(monday),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly Life Indicators'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-indicator-meaningful_connections')),
      220,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-indicator-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.byKey(const Key('home-indicator-meaningful_connections')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

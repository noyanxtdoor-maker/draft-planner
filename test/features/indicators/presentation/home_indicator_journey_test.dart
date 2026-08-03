import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'VS-08 Home shows the unplanned current week and canonical planning entry',
    (tester) async {
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
      expect(find.text('Start Weekly Planning'), findsOneWidget);
      expect(
        find.byKey(const Key('home-start-weekly-planning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home-indicator-job_applications')),
        findsNothing,
      );
      expect(find.text('Scheduled'), findsNothing);
      expect(find.textContaining('worthiness'), findsNothing);
      expect(find.byKey(const Key('home-pathway-employment')), findsOneWidget);

      await tester.tap(find.text('Start Weekly Planning'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Planning'), findsOneWidget);
      expect(
        find.byKey(const Key('weekly-plan-indicator-job_applications')),
        findsOneWidget,
      );
      expect(find.text('Set Goal'), findsNWidgets(6));
      await tester.tap(
        find.byKey(const Key('weekly-plan-indicator-job_applications')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit Goal'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('Home remains usable at 200% text scale', (tester) async {
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
      find.byKey(const Key('home-pathway-documents')),
      220,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-indicator-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('home-pathway-documents')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

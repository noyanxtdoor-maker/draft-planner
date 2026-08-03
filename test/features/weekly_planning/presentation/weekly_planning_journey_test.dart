import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'VS08: Weekly Planning is WLI-only and has no global commitment creation',
    (tester) async {
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
      await tester.ensureVisible(
        find.byKey(const Key('weekly-targets-button')),
      );
      await tester.tap(find.byKey(const Key('weekly-targets-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Weekly Planning'), findsOneWidget);
      expect(find.textContaining('Jul 27'), findsOneWidget);
      expect(find.textContaining('Jul 27'), findsOneWidget);
      expect(find.textContaining('Asia/Manila'), findsNothing);
      expect(find.byKey(const Key('weekly-plan-identity')), findsNothing);
      expect(find.textContaining('Actual is factual'), findsNothing);
      expect(
        find.byKey(const Key('weekly-plan-indicator-job_applications')),
        findsOneWidget,
      );
      expect(find.text('Create Goal'), findsOneWidget);
      expect(find.text('Daily Progress Goal'), findsOneWidget);
      expect(find.text('Weekly Goals'), findsOneWidget);
      expect(find.text('Set Goal'), findsNWidgets(5));
      expect(find.byKey(const Key('weekly-plan-add-commitment')), findsNothing);
      expect(find.byKey(const Key('weekly-plan-create-task')), findsNothing);
      expect(find.byKey(const Key('weekly-plan-create-event')), findsNothing);
      expect(find.text('Commitments'), findsNothing);
      expect(find.text('New Task'), findsNothing);
      expect(find.text('New Event'), findsNothing);

      final historyButton = tester.widget<IconButton>(
        find.byKey(const Key('weekly-plan-history-button')),
      );
      expect(historyButton.onPressed, isNotNull);
      historyButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Prior Weeks'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'Q4 / AC-I-002,004,008,019: Weekly Planning remains usable at 200% text',
    (tester) async {
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
      await tester.tap(find.text('Start Weekly Planning'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Planning'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-plan-indicator-meaningful_connections')),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('weekly-plan-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.byKey(const Key('weekly-plan-indicator-meaningful_connections')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

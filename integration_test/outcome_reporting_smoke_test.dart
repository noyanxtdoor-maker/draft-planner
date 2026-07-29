import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'VS-06 Android smoke: required Task report and ledger-derived Actual',
    (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startupRepository = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      final profile = await startupRepository.completeOnboarding();
      final taskRepository = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      await taskRepository.saveTask(
        profileId: profile.id,
        draft: const PlannerTaskDraft(
          id: 'android-report-task',
          title: 'Android report fixture',
          dueDate: selected,
          requiresReport: true,
        ),
      );

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startupRepository,
          plannerDateSource: const FixedPlannerDateSource(selected),
          plannerIdentifierSource: SequenceIdentifierSource(<String>[
            '66000000-0000-4000-8000-000000000001',
            '66000000-0000-4000-8000-000000000002',
          ]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planner-overflow-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-tasks-view')), findsOneWidget);
      await tester.tap(find.text('Android report fixture'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complete-task-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('report-outcome-completedHappened')),
      );
      await tester.tap(
        find.byKey(const Key('report-indicator-job_applications')),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('submit-outcome-report')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('outcome-report-form')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('submit-outcome-report')));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(
        await database.select(database.outcomeReports).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.activityLedgerEntries).get(),
        hasLength(1),
      );
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      final actual = await reporting.readActual(
        profileId: profile.id,
        indicatorKey: 'job_applications',
        startDate: selected,
        endDate: selected,
      );
      expect(actual.value.scaledValue, 1);
    },
  );
}

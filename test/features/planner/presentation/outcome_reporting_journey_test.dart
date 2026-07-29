import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'AC-G-001..020 / AC-H-001..020: required Task report, contribution, '
    'correction, and immutable history remain coherent',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          id: 'required-report-task',
          title: 'Required reporting fixture',
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
            '60000000-0000-4000-8000-000000000001',
            '60000000-0000-4000-8000-000000000002',
            '60000000-0000-4000-8000-000000000003',
            '60000000-0000-4000-8000-000000000004',
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
      await tester.scrollUntilVisible(
        find.text('Required reporting fixture'),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('planner-tasks-view')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Required reporting fixture'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('complete-task-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('outcome-report-form')), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Required reporting fixture'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('report-outcome-completedHappened')),
      );
      await tester.tap(
        find.byKey(const Key('report-indicator-job_applications')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('report-indicator-value-job_applications')),
        '999999999999999999999999999999',
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
      expect(find.textContaining('supported range'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('report-indicator-value-job_applications')),
        -300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('outcome-report-form')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.byKey(const Key('report-indicator-value-job_applications')),
        '1',
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
      await tester.tap(find.byKey(const Key('task-activity-history-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-history-list')), findsOneWidget);
      expect(find.textContaining('Effective'), findsWidgets);

      await tester.tap(find.text('Required reporting fixture').first);
      await tester.pumpAndSettle();
      final firstReport = await database
          .select(database.outcomeReports)
          .getSingle();
      await tester.tap(find.byKey(Key('correct-report-${firstReport.id}')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('report-outcome-didNotHappen')));
      await tester.scrollUntilVisible(
        find.byKey(const Key('report-correction-reason')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('outcome-report-form')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.byKey(const Key('report-correction-reason')),
        'The first report selected the wrong factual outcome.',
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

      expect(find.textContaining('Effective'), findsWidgets);
      expect(find.textContaining('Superseded'), findsOneWidget);
      final reports = await database.select(database.outcomeReports).get();
      expect(reports, hasLength(2));
      final ledger = await database
          .select(database.activityLedgerEntries)
          .get();
      expect(ledger, hasLength(2));

      final outcomeRepository = DriftOutcomeReportingRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      final actual = await outcomeRepository.readActual(
        profileId: profile.id,
        indicatorKey: 'job_applications',
        startDate: selected,
        endDate: selected,
      );
      expect(actual.value.scaledValue, 0);
      final audit = await outcomeRepository.auditProjection(profile.id);
      expect(audit.isConsistent, isTrue);
      expect(audit.issueCount, 0);
    },
  );
}

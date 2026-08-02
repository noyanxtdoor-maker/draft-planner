import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'VS08 owner override: Task completion uses direct status and no Activity Report UI',
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
      await DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      ).saveTask(
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

      expect(find.byKey(const Key('open-task-report-button')), findsNothing);
      expect(find.textContaining('Activity Report'), findsNothing);
      await tester.tap(find.byKey(const Key('complete-task-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('outcome-report-form')), findsNothing);
      expect(find.text('Completed'), findsOneWidget);

      final task = await (database.select(
        database.plannerTasks,
      )..where((row) => row.id.equals('required-report-task'))).getSingle();
      expect(task.status, PlannerTaskStatus.completed.name);

      await tester.tap(find.byKey(const Key('task-activity-history-button')));
      await tester.pumpAndSettle();
      expect(find.text('No status activity recorded yet.'), findsOneWidget);
      expect(find.textContaining('Activity Report'), findsNothing);
    },
  );
}

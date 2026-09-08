import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test(
    'pending reminder source excludes date-only and out-of-range Tasks',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final repository = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 9, 6, 10)),
      );
      const start = PlannerDate(year: 2026, month: 9, day: 6);
      const end = PlannerDate(year: 2026, month: 10, day: 18);

      Future<void> save({
        required String id,
        required PlannerDate dueDate,
        int? dueMinute,
      }) async {
        await repository.saveTask(
          profileId: profile.id,
          draft: PlannerTaskDraft(
            id: id,
            title: id,
            dueDate: dueDate,
            dueMinute: dueMinute,
            requiresReport: true,
          ),
        );
      }

      await save(
        id: '30000000-0000-4000-8000-000000000001',
        dueDate: start,
        dueMinute: 14 * 60 + 15,
      );
      await save(
        id: '30000000-0000-4000-8000-000000000002',
        dueDate: start.addDays(1),
      );
      await save(
        id: '30000000-0000-4000-8000-000000000003',
        dueDate: end.addDays(1),
        dueMinute: 9 * 60,
      );
      for (final entry in <(String, PlannerTaskStatus)>[
        ('30000000-0000-4000-8000-000000000004', PlannerTaskStatus.completed),
        ('30000000-0000-4000-8000-000000000005', PlannerTaskStatus.skipped),
        ('30000000-0000-4000-8000-000000000006', PlannerTaskStatus.cancelled),
      ]) {
        await save(id: entry.$1, dueDate: start, dueMinute: 10 * 60);
        await repository.changeTaskStatus(
          profileId: profile.id,
          taskId: entry.$1,
          target: entry.$2,
          operationId: 'badge-${entry.$2.name}',
        );
      }

      final pending = await repository.readPendingReminderTasks(
        profileId: profile.id,
        startDate: start,
        endDate: end,
      );
      expect(pending.map((task) => task.id), <String>[
        '30000000-0000-4000-8000-000000000001',
      ]);
      expect(pending.single.dueMinute, 14 * 60 + 15);
      expect(
        await repository.readActionableBadgeTasks(
          profileId: profile.id,
          startDate: start,
          endDate: end,
        ),
        <String>[
          '30000000-0000-4000-8000-000000000001',
          '30000000-0000-4000-8000-000000000002',
        ],
      );
    },
  );
}

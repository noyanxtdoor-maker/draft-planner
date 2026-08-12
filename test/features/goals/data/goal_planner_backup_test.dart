import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;
  late DriftGoalRepository goals;
  late DriftPlannerRepository planner;
  late String profileId;

  final clock = FixedClock(DateTime.utc(2026, 8, 3, 12));

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    goals = DriftGoalRepository(
      database: database,
      clock: clock,
      identifiers: const UuidIdentifierSource(),
    );
    planner = DriftPlannerRepository(database: database, clock: clock);
    await DriftEventTypeRepository(
      database: database,
      clock: clock,
    ).readEventTypes(profileId: profileId);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'backup round trip preserves linked Tasks, status history, and contributions',
    () async {
      final jobType = (await database.select(database.activityTypes).get())
          .singleWhere(
            (row) => row.stableKey == SystemEventTypeKeys.jobApplication,
          );
      final task = await planner.saveTask(
        profileId: profileId,
        draft: PlannerTaskDraft(
          id: 'backup-task',
          title: 'Apply for a role',
          dueDate: const PlannerDate(year: 2026, month: 8, day: 3),
          dueMinute: 600,
          requiresReport: false,
          linkedActivityTypeId: jobType.id,
          linkedActivityTypeStableKey: jobType.stableKey,
          linkedActivityTypeLabelSnapshot: jobType.label,
        ),
      );
      expect(task.linkedActivityTypeStableKey, jobType.stableKey);

      final outcome = await planner.changeTaskStatus(
        profileId: profileId,
        taskId: task.id,
        target: PlannerTaskStatus.completed,
        operationId: 'backup-task-complete',
      );
      expect(outcome, TaskStatusChangeOutcome.changed);

      final backup = await goals.exportBackup(profileId);
      expect(backup['format'], 'rmplanner.backup.v2');
      expect(backup['schemaVersion'], 2);
      expect(backup['plannerTasks'], hasLength(1));
      expect(backup['taskStatusChanges'], hasLength(1));
      expect(backup['taskGoalContributions'], hasLength(1));

      await database.delete(database.taskGoalContributions).go();
      await database.delete(database.taskStatusChanges).go();
      await database.delete(database.plannerTasks).go();

      await goals.importBackup(profileId: profileId, backup: backup);

      final restored = await planner.readTask(
        profileId: profileId,
        taskId: task.id,
      );
      expect(restored, isNotNull);
      expect(restored!.title, 'Apply for a role');
      expect(restored.status, PlannerTaskStatus.completed);
      expect(restored.dueDate, const PlannerDate(year: 2026, month: 8, day: 3));
      expect(restored.dueMinute, 600);
      expect(restored.linkedActivityTypeId, jobType.id);
      expect(restored.linkedActivityTypeStableKey, jobType.stableKey);
      expect(restored.linkedActivityTypeLabelSnapshot, jobType.label);

      final statusChanges = await database
          .select(database.taskStatusChanges)
          .get();
      expect(statusChanges, hasLength(1));
      expect(statusChanges.single.operationId, 'backup-task-complete');
      expect(
        statusChanges.single.activityTypeStableKeySnapshot,
        jobType.stableKey,
      );
      expect(statusChanges.single.activityTypeLabelSnapshot, jobType.label);

      final contributions = await database
          .select(database.taskGoalContributions)
          .get();
      expect(contributions, hasLength(1));
      expect(contributions.single.taskId, task.id);
      expect(contributions.single.indicatorKey, 'job_applications');
      expect(contributions.single.state, 'active');
      expect(
        contributions.single.activityTypeStableKeySnapshot,
        jobType.stableKey,
      );
      expect(contributions.single.activityTypeLabelSnapshot, jobType.label);

      final jobGoal = (await goals.readActiveGoals(
        profileId,
      )).singleWhere((goal) => goal.indicatorKey == 'job_applications');
      final progress = await goals.readProgress(
        profileId: profileId,
        goalId: jobGoal.id,
        today: const PlannerDate(year: 2026, month: 8, day: 3),
      );
      expect(progress!.weeklyActual.scaledValue, 1);

      await goals.importBackup(profileId: profileId, backup: backup);
      expect(await database.select(database.plannerTasks).get(), hasLength(1));
      expect(
        await database.select(database.taskStatusChanges).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.taskGoalContributions).get(),
        hasLength(1),
      );
    },
  );

  test(
    'completing a linked Task while the Goal slot is empty creates no orphan '
    'contribution',
    () async {
      final jobType = (await database.select(database.activityTypes).get())
          .singleWhere(
            (row) => row.stableKey == SystemEventTypeKeys.jobApplication,
          );
      final jobGoal = (await goals.readActiveGoals(
        profileId,
      )).singleWhere((goal) => goal.indicatorKey == 'job_applications');

      // Permanently delete the active Goal so its slot has no compatible
      // active Goal, then complete a linked Task.
      await goals.deleteGoal(
        profileId: profileId,
        goalId: jobGoal.id,
        operationId: 'empty-slot-delete',
      );
      final task = await planner.saveTask(
        profileId: profileId,
        draft: PlannerTaskDraft(
          id: 'empty-slot-task',
          title: 'Apply while slot empty',
          dueDate: const PlannerDate(year: 2026, month: 8, day: 3),
          dueMinute: 600,
          requiresReport: false,
          linkedActivityTypeId: jobType.id,
          linkedActivityTypeStableKey: jobType.stableKey,
          linkedActivityTypeLabelSnapshot: jobType.label,
        ),
      );
      final outcome = await planner.changeTaskStatus(
        profileId: profileId,
        taskId: task.id,
        target: PlannerTaskStatus.completed,
        operationId: 'empty-slot-complete',
      );
      expect(outcome, TaskStatusChangeOutcome.changed);

      // No orphan contribution row is created while the slot is empty, and
      // no progress is attributed to the deleted Goal.
      final contributions = await database
          .select(database.taskGoalContributions)
          .get();
      expect(contributions, isEmpty);
      final deleted = await goals.readGoal(
        profileId: profileId,
        goalId: jobGoal.id,
      );
      expect(deleted?.status, GoalStatus.deleted);

      // A replacement Goal takes the freed slot; a newly completed linked
      // Task then contributes exactly once under the new identity.
      final replacement = await goals.createGoal(
        profileId: profileId,
        role: GoalRole.dailyWeekly,
        title: 'Job Applications Renewed',
        targets: const GoalTargets(
          daily: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
          weekly: IndicatorAmount(scaledValue: 3, scale: 0, unit: 'count'),
        ),
        operationId: 'empty-slot-replacement',
      );
      expect(replacement.activeSlotIndex, 1);
      expect(replacement.indicatorKey, 'job_applications');

      final second = await planner.saveTask(
        profileId: profileId,
        draft: PlannerTaskDraft(
          id: 'empty-slot-task-2',
          title: 'Apply after replacement',
          dueDate: const PlannerDate(year: 2026, month: 8, day: 3),
          dueMinute: 600,
          requiresReport: false,
          linkedActivityTypeId: jobType.id,
          linkedActivityTypeStableKey: jobType.stableKey,
          linkedActivityTypeLabelSnapshot: jobType.label,
        ),
      );
      final secondOutcome = await planner.changeTaskStatus(
        profileId: profileId,
        taskId: second.id,
        target: PlannerTaskStatus.completed,
        operationId: 'empty-slot-complete-2',
      );
      expect(secondOutcome, TaskStatusChangeOutcome.changed);

      final afterReplacement = await database
          .select(database.taskGoalContributions)
          .get();
      expect(afterReplacement, hasLength(1));
      expect(afterReplacement.single.taskId, second.id);
      expect(afterReplacement.single.indicatorKey, 'job_applications');
      final progress = await goals.readProgress(
        profileId: profileId,
        goalId: replacement.id,
        today: const PlannerDate(year: 2026, month: 8, day: 3),
      );
      expect(progress!.weeklyActual.scaledValue, 1);
    },
  );

  test(
    'invalid Planner backup does not partially apply Goal changes',
    () async {
      final backup = await goals.exportBackup(profileId);
      final goalRows = [
        for (final row in (backup['goals']! as List))
          Map<String, Object?>.from(row as Map),
      ];
      final originalTitle = goalRows.first['title'];
      goalRows.first['title'] = 'Should not be imported';

      final invalidBackup = <String, Object?>{
        ...backup,
        'goals': goalRows,
        'plannerTasks': <Object?>[
          <String, Object?>{
            'id': 'invalid-task',
            'title': 'Invalid task',
            'createdAtUtc': 'not-a-date',
            'updatedAtUtc': 'not-a-date',
          },
        ],
      };

      await expectLater(
        goals.importBackup(profileId: profileId, backup: invalidBackup),
        throwsA(isA<GoalValidationException>()),
      );

      final unchanged = (await goals.readActiveGoals(profileId)).first;
      expect(unchanged.title, originalTitle);
      expect(await database.select(database.plannerTasks).get(), isEmpty);
    },
  );
}

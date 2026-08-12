import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const periodStart = PlannerDate(year: 2026, month: 8, day: 3);
  final clock = FixedClock(DateTime.utc(2026, 8, 3, 12));

  DriftGoalRepository createRepository(AppDatabase database) {
    return DriftGoalRepository(
      database: database,
      clock: clock,
      identifiers: const UuidIdentifierSource(),
    );
  }

  Future<(AppDatabase, DriftGoalRepository, String)> arrange() async {
    final database = openMemoryDatabase();
    final startup = buildTestRepository(database: database);
    final profile = await startup.completeOnboarding();
    return (database, createRepository(database), profile.id);
  }

  test('migrates six canonical goals and reads are watcher-stable', () async {
    final (database, repository, profileId) = await arrange();
    addTearDown(database.close);

    final active = await repository.readActiveGoals(profileId);
    expect(active, hasLength(6));
    expect(
      active.where((goal) => goal.role == GoalRole.dailyWeekly),
      hasLength(1),
    );
    expect(active.where((goal) => goal.role == GoalRole.weekly), hasLength(4));
    expect(
      active.where((goal) => goal.role == GoalRole.weeklyMonthly),
      hasLength(1),
    );
    expect(active.map((goal) => goal.activeSlotIndex), <int?>[
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
    expect(active[3].title, 'Budget Review');
    expect(active.every((goal) => goal.iconId == null), isTrue);

    final activityRows = await (database.select(
      database.goalActivities,
    )..where((table) => table.profileId.equals(profileId))).get();
    expect(activityRows, hasLength(6));

    var eventCount = 0;
    final subscription = repository.watchChanges(profileId).listen((_) {
      eventCount += 1;
    });
    addTearDown(subscription.cancel);
    await repository.readPlanning(
      profileId: profileId,
      periodStart: periodStart,
    );
    await Future<void>.delayed(Duration.zero);
    expect(eventCount, 0);
  });

  test(
    'planning projects only canonical active slots and orders replacements by role',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);

      final active = await repository.readActiveGoals(profileId);
      for (var index = 0; index < active.length; index += 1) {
        await repository.archiveGoal(
          profileId: profileId,
          goalId: active[index].id,
          operationId: 'pack1-archive-default-$index',
        );
      }

      const target = IndicatorAmount(scaledValue: 2, scale: 0, unit: 'count');
      await repository.createGoal(
        profileId: profileId,
        role: GoalRole.weeklyMonthly,
        title: 'Replacement Monthly',
        iconId: 'temple',
        targets: const GoalTargets(weekly: target, monthly: target),
        operationId: 'pack1-create-monthly',
      );
      for (var index = 4; index >= 1; index -= 1) {
        await repository.createGoal(
          profileId: profileId,
          role: GoalRole.weekly,
          title: 'Replacement Weekly $index',
          iconId: 'open_book',
          targets: const GoalTargets(weekly: target),
          operationId: 'pack1-create-weekly-$index',
        );
      }
      await repository.createGoal(
        profileId: profileId,
        role: GoalRole.dailyWeekly,
        title: 'Replacement Daily',
        iconId: 'briefcase',
        targets: const GoalTargets(daily: target, weekly: target),
        operationId: 'pack1-create-daily',
      );

      final planning = await repository.readPlanning(
        profileId: profileId,
        periodStart: periodStart,
      );
      expect(planning.daily?.goal.title, 'Replacement Daily');
      expect(planning.weekly.map((progress) => progress.goal.title), <String>[
        'Replacement Weekly 4',
        'Replacement Weekly 3',
        'Replacement Weekly 2',
        'Replacement Weekly 1',
      ]);
      expect(
        planning.weekly.map((progress) => progress.goal.activeSlotIndex),
        <int?>[2, 3, 4, 5],
      );
      expect(planning.monthly?.goal.title, 'Replacement Monthly');
      expect(planning.daily?.goal.iconId, 'briefcase');
      expect(planning.monthly?.goal.iconId, 'temple');

      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'pack1-invalid-active-goal',
              profileId: profileId,
              role: GoalRole.weekly.storageName,
              title: 'Invalid Unslotted Goal',
              status: GoalStatus.active.name,
              activeSlotIndex: const Value<int?>(null),
              indicatorKey: const Value<String?>(null),
              iconId: const Value<String?>(null),
              createdAtUtc: clock.value,
              updatedAtUtc: clock.value,
              archivedAtUtc: const Value<DateTime?>(null),
            ),
          );
      final reloaded = await repository.readPlanning(
        profileId: profileId,
        periodStart: periodStart,
      );
      final projectedTitles = <String>[
        if (reloaded.daily != null) reloaded.daily!.goal.title,
        ...reloaded.weekly.map((progress) => progress.goal.title),
        if (reloaded.monthly != null) reloaded.monthly!.goal.title,
      ];
      expect(projectedTitles, isNot(contains('Invalid Unslotted Goal')));
      expect(
        (await repository.readActiveGoals(profileId)).map((goal) => goal.title),
        contains('Invalid Unslotted Goal'),
      );

      final occupiedWeekly = reloaded.weekly.first.goal;
      await repository.archiveGoal(
        profileId: profileId,
        goalId: occupiedWeekly.id,
        operationId: 'pack1-archive-for-invalid-slot-capacity',
      );
      expect((await repository.readCapacity(profileId)).availableWeekly, 1);
      final replacement = await repository.createGoal(
        profileId: profileId,
        role: GoalRole.weekly,
        title: 'Capacity ignores invalid active slot',
        targets: const GoalTargets(weekly: target),
        operationId: 'pack1-create-after-invalid-slot',
      );
      expect(replacement.activeSlotIndex, occupiedWeekly.activeSlotIndex);
    },
  );

  test(
    'daily target update changes only the target and one idempotent outbox row',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      final daily = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.role == GoalRole.dailyWeekly);
      final before = await repository.readProgress(
        profileId: profileId,
        goalId: daily.id,
        today: periodStart,
      );
      expect(before != null, isTrue);
      final baseline = before!;
      final activityCountBefore = await (database.select(
        database.goalActivities,
      )..where((table) => table.profileId.equals(profileId))).get();
      final outboxCountBefore = await (database.select(
        database.goalOutboxOperations,
      )..where((table) => table.profileId.equals(profileId))).get();
      final ledgerCountBefore = await (database.select(
        database.activityLedgerEntries,
      )..where((table) => table.profileId.equals(profileId))).get();
      final reportCountBefore = await (database.select(
        database.outcomeReports,
      )..where((table) => table.profileId.equals(profileId))).get();

      const nextDailyTarget = IndicatorAmount(
        scaledValue: 3,
        scale: 0,
        unit: 'count',
      );
      final targets = GoalTargets(
        daily: nextDailyTarget,
        weekly: baseline.weeklyTarget.value,
        monthly: baseline.monthlyTarget.value,
      );
      final updated = await repository.saveGoal(
        profileId: profileId,
        goalId: daily.id,
        title: daily.title,
        iconId: daily.iconId,
        targets: targets,
        operationId: 'pack1-daily-target-update',
      );
      final retried = await repository.saveGoal(
        profileId: profileId,
        goalId: daily.id,
        title: daily.title,
        iconId: daily.iconId,
        targets: targets,
        operationId: 'pack1-daily-target-update',
      );
      final after = await repository.readProgress(
        profileId: profileId,
        goalId: daily.id,
        today: periodStart,
      );

      expect(updated.id, daily.id);
      expect(retried.id, daily.id);
      expect(updated.title, daily.title);
      expect(updated.iconId, daily.iconId);
      expect(updated.role, daily.role);
      expect(updated.activeSlotIndex, daily.activeSlotIndex);
      expect(after?.dailyTarget.value?.scaledValue, 3);
      expect(after?.dailyActual.scaledValue, baseline.dailyActual.scaledValue);
      expect(after?.dailyActual.scale, baseline.dailyActual.scale);
      expect(after?.dailyActual.unit, baseline.dailyActual.unit);
      expect(
        after?.weeklyActual.scaledValue,
        baseline.weeklyActual.scaledValue,
      );
      expect(after?.weeklyActual.scale, baseline.weeklyActual.scale);
      expect(after?.weeklyActual.unit, baseline.weeklyActual.unit);
      expect(
        after?.monthlyActual.scaledValue,
        baseline.monthlyActual.scaledValue,
      );
      expect(after?.monthlyActual.scale, baseline.monthlyActual.scale);
      expect(after?.monthlyActual.unit, baseline.monthlyActual.unit);

      final activityCountAfter = await (database.select(
        database.goalActivities,
      )..where((table) => table.profileId.equals(profileId))).get();
      final outboxCountAfter = await (database.select(
        database.goalOutboxOperations,
      )..where((table) => table.profileId.equals(profileId))).get();
      final targetOperations = outboxCountAfter.where(
        (row) => row.operationId == 'pack1-daily-target-update',
      );
      final ledgerCountAfter = await (database.select(
        database.activityLedgerEntries,
      )..where((table) => table.profileId.equals(profileId))).get();
      final reportCountAfter = await (database.select(
        database.outcomeReports,
      )..where((table) => table.profileId.equals(profileId))).get();

      expect(activityCountAfter, hasLength(activityCountBefore.length));
      expect(outboxCountAfter.length, outboxCountBefore.length + 1);
      expect(targetOperations, hasLength(1));
      expect(ledgerCountAfter, hasLength(ledgerCountBefore.length));
      expect(reportCountAfter, hasLength(reportCountBefore.length));
    },
  );

  test(
    'rename, archive, restore, and target history keep the same identity',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      final original = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.title == 'Scripture Study');
      const weeklyTarget = IndicatorAmount(
        scaledValue: 7,
        scale: 0,
        unit: 'count',
      );

      final renamed = await repository.saveGoal(
        profileId: profileId,
        goalId: original.id,
        title: 'Scripture Study Updated',
        targets: const GoalTargets(weekly: weeklyTarget),
        operationId: 'rename-scripture-study',
      );
      final retriedRename = await repository.saveGoal(
        profileId: profileId,
        goalId: original.id,
        title: 'Scripture Study Updated',
        targets: const GoalTargets(weekly: weeklyTarget),
        operationId: 'rename-scripture-study',
      );
      expect(renamed.id, original.id);
      expect(retriedRename.id, original.id);
      expect(renamed.activeSlotIndex, original.activeSlotIndex);
      expect(renamed.title, 'Scripture Study Updated');

      await repository.archiveGoal(
        profileId: profileId,
        goalId: original.id,
        operationId: 'archive-scripture-study',
      );
      await repository.archiveGoal(
        profileId: profileId,
        goalId: original.id,
        operationId: 'archive-scripture-study',
      );
      final archived = await repository.readGoal(
        profileId: profileId,
        goalId: original.id,
      );
      expect(archived?.status, GoalStatus.archived);
      expect(archived?.activeSlotIndex, equals(null));

      final replacement = await repository.createGoal(
        profileId: profileId,
        role: GoalRole.weekly,
        title: 'Replacement Weekly Goal',
        targets: const GoalTargets(weekly: weeklyTarget),
        operationId: 'create-replacement-goal',
      );
      await expectLater(
        repository.restoreGoal(
          profileId: profileId,
          goalId: original.id,
          operationId: 'restore-while-full',
        ),
        throwsA(isA<GoalCapacityException>()),
      );

      await repository.archiveGoal(
        profileId: profileId,
        goalId: replacement.id,
        operationId: 'archive-replacement-goal',
      );
      final restored = await repository.restoreGoal(
        profileId: profileId,
        goalId: original.id,
        operationId: 'restore-scripture-study',
      );
      final retriedRestore = await repository.restoreGoal(
        profileId: profileId,
        goalId: original.id,
        operationId: 'restore-scripture-study',
      );
      expect(restored.id, original.id);
      expect(retriedRestore.id, original.id);
      expect(restored.title, 'Scripture Study Updated');
      expect(restored.activeSlotIndex, original.activeSlotIndex);
      expect(restored.role, GoalRole.weekly);

      final progress = await repository.readProgress(
        profileId: profileId,
        goalId: original.id,
        today: periodStart,
      );
      expect(progress?.weeklyTarget.value?.scaledValue, 7);
      final history = await repository.readActivityHistory(profileId);
      expect(
        history.where(
          (item) =>
              item.activity.goalId == original.id &&
              item.activity.action == GoalActivityAction.renamed,
        ),
        hasLength(1),
      );
      expect(
        history.where(
          (item) =>
              item.activity.goalId == original.id &&
              item.activity.action == GoalActivityAction.archived,
        ),
        hasLength(1),
      );
      expect(
        history.where(
          (item) =>
              item.activity.goalId == original.id &&
              item.activity.action == GoalActivityAction.restored,
        ),
        hasLength(1),
      );
      expect(
        history.where(
          (item) =>
              item.activity.goalId == original.id &&
              item.activity.operationId == 'rename-scripture-study',
        ),
        hasLength(1),
      );
      expect(
        history.where(
          (item) =>
              item.activity.goalId == original.id &&
              item.activity.operationId == 'archive-scripture-study',
        ),
        hasLength(1),
      );
      expect(
        history.where(
          (item) =>
              item.activity.goalId == original.id &&
              item.activity.operationId == 'restore-scripture-study',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'archive removes its WLI card and frees its compatible planner slot',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: clock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
        reportSource: reporting,
      );
      final indicators = DriftIndicatorRepository(
        database: database,
        clock: clock,
        calendarEvents: calendar,
      );
      final scripture = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.title == 'Scripture Study');

      await repository.archiveGoal(
        profileId: profileId,
        goalId: scripture.id,
        operationId: 'archive-scripture-for-visibility',
      );
      final home = await indicators.readHome(
        profileId: profileId,
        period: IndicatorPeriod.currentWeek(periodStart),
        today: periodStart,
      );
      expect(
        home.indicators.map((indicator) => indicator.label),
        isNot(contains('Scripture Study')),
      );
      final planning = await repository.readPlanning(
        profileId: profileId,
        periodStart: periodStart,
      );
      expect(
        planning.weekly.map((goal) => goal.goal.title),
        isNot(contains('Scripture Study')),
      );
      expect((await repository.readCapacity(profileId)).availableWeekly, 1);
    },
  );

  test(
    'create retries return one goal, activity, and outbox operation',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      final exercise = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.title == 'Exercise');
      await repository.archiveGoal(
        profileId: profileId,
        goalId: exercise.id,
        operationId: 'archive-exercise-for-create-retry',
      );
      const target = IndicatorAmount(scaledValue: 3, scale: 0, unit: 'count');
      final created = await repository.createGoal(
        profileId: profileId,
        role: GoalRole.weekly,
        title: 'Retry-safe Goal',
        targets: const GoalTargets(weekly: target),
        operationId: 'create-retry-safe-goal',
      );
      final retried = await repository.createGoal(
        profileId: profileId,
        role: GoalRole.weekly,
        title: 'Retry-safe Goal',
        targets: const GoalTargets(weekly: target),
        operationId: 'create-retry-safe-goal',
      );
      expect(retried.id, created.id);
      expect(
        (await repository.readActiveGoals(
          profileId,
        )).where((goal) => goal.title == 'Retry-safe Goal'),
        hasLength(1),
      );
      expect(
        (await repository.readActivityHistory(profileId)).where(
          (item) => item.activity.operationId == 'create-retry-safe-goal',
        ),
        hasLength(1),
      );
      expect(
        await (database.select(database.goalOutboxOperations)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.operationId.equals('create-retry-safe-goal'),
            ))
            .get(),
        hasLength(1),
      );
    },
  );

  test(
    'backup preserves nullable icon readiness and rejects slot conflicts',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      final backup = await repository.exportGoalBackup(profileId);
      final rawGoals = (backup['goals']! as List<Object?>)
          .map((value) => Map<String, Object?>.from(value! as Map))
          .toList(growable: true);
      final scripture = rawGoals.firstWhere(
        (goal) => goal['title'] == 'Scripture Study',
      );
      expect(scripture['iconId'], equals(null));
      scripture['iconId'] = 'future-icon-id';
      await repository.importGoalBackup(
        profileId: profileId,
        backup: <String, Object?>{'goals': rawGoals},
      );
      expect(
        (await repository.readGoal(
          profileId: profileId,
          goalId: scripture['id']! as String,
        ))?.iconId,
        'future-icon-id',
      );

      final conflicting = rawGoals
          .map((goal) => Map<String, Object?>.from(goal))
          .toList(growable: true);
      final weekly = conflicting.firstWhere(
        (goal) => goal['role'] == GoalRole.weekly.storageName,
      );
      weekly['activeSlotIndex'] = 1;
      await expectLater(
        repository.importGoalBackup(
          profileId: profileId,
          backup: <String, Object?>{'goals': conflicting},
        ),
        throwsA(isA<GoalValidationException>()),
      );
      expect(
        (await repository.readGoal(
          profileId: profileId,
          goalId: weekly['id']! as String,
        ))?.activeSlotIndex,
        isNot(1),
      );
    },
  );

  test(
    'nextAvailableSlot resolves the exact first free slot per role',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);

      // With all six canonical slots active there is nothing free.
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.dailyWeekly,
        ),
        equals(null),
      );
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.weekly,
        ),
        equals(null),
      );
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.weeklyMonthly,
        ),
        equals(null),
      );

      final weekly = (await repository.readActiveGoals(
        profileId,
      )).where((goal) => goal.role == GoalRole.weekly).toList();
      expect(weekly, hasLength(4));

      // Archive slot 2 (Scripture Study) -> next free weekly slot is 2.
      await repository.archiveGoal(
        profileId: profileId,
        goalId: weekly.firstWhere((goal) => goal.activeSlotIndex == 2).id,
        operationId: 'slot-free-2',
      );
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.weekly,
        ),
        2,
      );

      // Deleting it keeps slot 2 free for a replacement.
      final slot2 = (await repository.readArchivedGoals(
        profileId: profileId,
      )).singleWhere((goal) => goal.activeSlotIndex == null);
      await repository.deleteGoal(
        profileId: profileId,
        goalId: slot2.id,
        operationId: 'slot-free-2-delete',
      );
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.weekly,
        ),
        2,
      );

      // Archive slot 6 (Temple Visit) -> next free monthly slot is 6.
      final temple = (await repository.readActiveGoals(
        profileId,
      )).singleWhere((goal) => goal.role == GoalRole.weeklyMonthly);
      await repository.archiveGoal(
        profileId: profileId,
        goalId: temple.id,
        operationId: 'slot-free-6',
      );
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.weeklyMonthly,
        ),
        6,
      );

      // Archive slot 1 -> next free daily slot is 1.
      final daily = (await repository.readActiveGoals(
        profileId,
      )).singleWhere((goal) => goal.role == GoalRole.dailyWeekly);
      await repository.archiveGoal(
        profileId: profileId,
        goalId: daily.id,
        operationId: 'slot-free-1',
      );
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.dailyWeekly,
        ),
        1,
      );
    },
  );

  test(
    'createGoal validates the previewed slot and rejects a stale expectation',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      const target = IndicatorAmount(scaledValue: 2, scale: 0, unit: 'count');

      final freeSlot = await repository.nextAvailableSlot(
        profileId: profileId,
        role: GoalRole.weekly,
      );
      expect(freeSlot, equals(null)); // full before any archive

      final exercise = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.title == 'Exercise');
      await repository.archiveGoal(
        profileId: profileId,
        goalId: exercise.id,
        operationId: 'stale-preview-archive',
      );
      final previewed = await repository.nextAvailableSlot(
        profileId: profileId,
        role: GoalRole.weekly,
      );
      expect(previewed, 3);

      final created = await repository.createGoal(
        profileId: profileId,
        role: GoalRole.weekly,
        title: 'Previewed Replacement',
        targets: const GoalTargets(weekly: target),
        expectedSlotIndex: previewed,
        operationId: 'stale-preview-create',
      );
      expect(created.activeSlotIndex, previewed);

      // A stale expectation from an older preview must be rejected instead
      // of silently creating the Goal in a different slot.  After archiving
      // the previewed Goal, slot 3 is again the next free weekly slot; an old
      // preview pointing at slot 4 is stale and must throw.
      await repository.archiveGoal(
        profileId: profileId,
        goalId: created.id,
        operationId: 'stale-preview-archive-2',
      );
      await expectLater(
        repository.createGoal(
          profileId: profileId,
          role: GoalRole.weekly,
          title: 'Stale Expectation',
          targets: const GoalTargets(weekly: target),
          expectedSlotIndex: 4,
          operationId: 'stale-preview-create-2',
        ),
        throwsA(isA<GoalValidationException>()),
      );
      // The Goal itself is not created when the slot expectation is stale.
      expect(
        (await repository.readActiveGoals(profileId)).map((goal) => goal.title),
        isNot(contains('Stale Expectation')),
      );
    },
  );

  test(
    'delete permanently hides an active Goal, frees its slot, and preserves history',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      final exercise = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.title == 'Exercise');

      // Give the Goal some history to protect before deletion.
      await repository.saveGoal(
        profileId: profileId,
        goalId: exercise.id,
        title: 'Exercise Daily',
        targets: const GoalTargets(
          weekly: IndicatorAmount(scaledValue: 5, scale: 0, unit: 'count'),
        ),
        operationId: 'delete-history-rename',
      );
      await repository.archiveGoal(
        profileId: profileId,
        goalId: exercise.id,
        operationId: 'delete-history-archive',
      );
      await repository.restoreGoal(
        profileId: profileId,
        goalId: exercise.id,
        operationId: 'delete-history-restore',
      );

      await repository.deleteGoal(
        profileId: profileId,
        goalId: exercise.id,
        operationId: 'delete-exercise',
      );

      // Hidden from every user-facing surface.
      expect(
        (await repository.readActiveGoals(profileId)).map((goal) => goal.id),
        isNot(contains(exercise.id)),
      );
      expect(
        (await repository.readArchivedGoals(
          profileId: profileId,
        )).map((goal) => goal.id),
        isNot(contains(exercise.id)),
      );
      final deleted = await repository.readGoal(
        profileId: profileId,
        goalId: exercise.id,
      );
      expect(deleted?.status, GoalStatus.deleted);
      expect(deleted?.activeSlotIndex, equals(null));
      expect(deleted?.deletedAtUtc, isNot(equals(null)));

      // The freed slot can host a replacement with the same Event Type.
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.weekly,
        ),
        3,
      );
      const target = IndicatorAmount(scaledValue: 2, scale: 0, unit: 'count');
      final replacement = await repository.createGoal(
        profileId: profileId,
        role: GoalRole.weekly,
        title: 'Replacement Exercise',
        targets: const GoalTargets(weekly: target),
        operationId: 'delete-replacement',
      );
      expect(replacement.activeSlotIndex, 3);
      expect(
        replacement.assignedEventTypeStableKey,
        exercise.assignedEventTypeStableKey,
      );
      expect(replacement.indicatorKey, exercise.indicatorKey);
      expect(replacement.title, 'Replacement Exercise');
      expect(replacement.iconId, equals(null));

      // Deleted Goals cannot be restored.
      await expectLater(
        repository.restoreGoal(
          profileId: profileId,
          goalId: exercise.id,
          operationId: 'delete-restore-attempt',
        ),
        throwsA(isA<GoalValidationException>()),
      );

      // Historical records keep the original identity.
      final history = await repository.readActivityHistory(profileId);
      final exerciseHistory = history
          .where((item) => item.activity.goalId == exercise.id)
          .toList();
      expect(exerciseHistory, isNotEmpty);
      expect(
        exerciseHistory.map((item) => item.activity.action),
        containsAll(<GoalActivityAction>[
          GoalActivityAction.created,
          GoalActivityAction.renamed,
          GoalActivityAction.archived,
          GoalActivityAction.restored,
          GoalActivityAction.deleted,
        ]),
      );
      expect(
        exerciseHistory.where(
          (item) => item.activity.operationId == 'delete-exercise',
        ),
        hasLength(1),
      );

      // The replacement's history is isolated from the deleted Goal's.
      final replacementHistory = history
          .where((item) => item.activity.goalId == replacement.id)
          .toList();
      expect(replacementHistory, isNotEmpty);
      expect(
        replacementHistory
            .map((item) => item.activity.operationId)
            .where((operation) => operation.startsWith('delete-history')),
        isEmpty,
      );

      // Re-running bootstrap must not resurrect the deleted Goal.
      final active = await repository.readActiveGoals(profileId);
      expect(active.map((goal) => goal.id), isNot(contains(exercise.id)));
    },
  );

  test(
    'delete permanently removes an archived Goal and frees its slot',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);
      final scripture = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.title == 'Scripture Study');
      await repository.archiveGoal(
        profileId: profileId,
        goalId: scripture.id,
        operationId: 'delete-archived-archive',
      );

      await repository.deleteGoal(
        profileId: profileId,
        goalId: scripture.id,
        operationId: 'delete-archived',
      );

      expect(
        (await repository.readArchivedGoals(
          profileId: profileId,
        )).map((goal) => goal.id),
        isNot(contains(scripture.id)),
      );
      expect(
        await repository.nextAvailableSlot(
          profileId: profileId,
          role: GoalRole.weekly,
        ),
        2,
      );
      await expectLater(
        repository.restoreGoal(
          profileId: profileId,
          goalId: scripture.id,
          operationId: 'delete-archived-restore',
        ),
        throwsA(isA<GoalValidationException>()),
      );
    },
  );

  test(
    'a backup taken before deletion cannot resurrect the deleted Goal',
    () async {
      final (database, repository, profileId) = await arrange();
      addTearDown(database.close);

      final before = await repository.exportGoalBackup(profileId);
      final exercise = (await repository.readActiveGoals(
        profileId,
      )).firstWhere((goal) => goal.title == 'Exercise');
      await repository.deleteGoal(
        profileId: profileId,
        goalId: exercise.id,
        operationId: 'backup-delete',
      );

      // Importing the older snapshot must not resurrect the deleted Goal.
      await repository.importGoalBackup(profileId: profileId, backup: before);
      final deleted = await repository.readGoal(
        profileId: profileId,
        goalId: exercise.id,
      );
      expect(deleted?.status, GoalStatus.deleted);
      expect(
        (await repository.readActiveGoals(profileId)).map((goal) => goal.id),
        isNot(contains(exercise.id)),
      );
    },
  );

  test('home indicator reads do not emit a write notification loop', () async {
    final (database, repository, profileId) = await arrange();
    addTearDown(database.close);
    final reporting = DriftOutcomeReportingRepository(
      database: database,
      clock: clock,
    );
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      reportSource: reporting,
    );
    final indicators = DriftIndicatorRepository(
      database: database,
      clock: clock,
      calendarEvents: calendar,
    );
    var eventCount = 0;
    final subscription = indicators.watchChanges(profileId).listen((_) {
      eventCount += 1;
    });
    addTearDown(subscription.cancel);
    await indicators.readHome(
      profileId: profileId,
      period: IndicatorPeriod.currentWeek(periodStart),
      today: periodStart,
    );
    await Future<void>.delayed(Duration.zero);
    expect(eventCount, 0);
  });

  test('Delta 4 A1: cancelling a contributing Event immediately removes only '
      'that Event from Home Actual while preserving report history, manual '
      'contributions, and retry idempotency', () async {
    final (database, repository, profileId) = await arrange();
    addTearDown(database.close);
    final goal = (await repository.readActiveGoals(
      profileId,
    )).singleWhere((candidate) => candidate.role == GoalRole.dailyWeekly);
    final indicatorKey = goal.indicatorKey!;
    final reporting = DriftOutcomeReportingRepository(
      database: database,
      clock: clock,
    );
    final events = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      reportSource: reporting,
    );
    final changeGenerations = <int>[];
    final changeSubscription = repository
        .watchChanges(profileId)
        .listen(changeGenerations.add);
    addTearDown(changeSubscription.cancel);
    const eventId = '10101010-1010-4010-8010-101010101010';
    const eventReportId = '20202020-2020-4020-8020-202020202020';
    const eventReportOperation = '30303030-3030-4030-8030-303030303030';
    const manualReportId = '40404040-4040-4040-8040-404040404040';
    const manualSourceId = '50505050-5050-4050-8050-505050505050';
    const manualOperation = '60606060-6060-4060-8060-606060606060';
    const cancelOperation = '70707070-7070-4070-8070-707070707070';
    const contribution = IndicatorValue(
      scaledValue: 1,
      scale: 0,
      unit: 'count',
    );

    await events.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: eventId,
        title: 'Delta 4 contributing Event',
        timing: CalendarEventTiming.timed,
        startDate: periodStart,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        timeZoneId: 'Asia/Manila',
        requiresReport: true,
        goalId: goal.id,
        contributionRuleKey: 'life-indicator:$indicatorKey:1:0:count',
      ),
    );
    final eventSource = await reporting.readEventSource(
      profileId: profileId,
      eventId: eventId,
      originalDate: periodStart,
    );
    await reporting.submit(
      profileId: profileId,
      draft: OutcomeReportDraft(
        id: eventReportId,
        source: eventSource!,
        activityDate: periodStart,
        outcome: OutcomeKind.completedHappened,
        contributions: <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'event:$indicatorKey',
            indicatorKey: indicatorKey,
            value: contribution,
          ),
        ],
      ),
      operationId: eventReportOperation,
    );
    await reporting.submit(
      profileId: profileId,
      draft: OutcomeReportDraft(
        id: manualReportId,
        source: const OutcomeReportSource(
          type: OutcomeSourceType.manual,
          sourceId: manualSourceId,
          label: 'Manual Job Application',
          activityDate: periodStart,
        ),
        activityDate: periodStart,
        outcome: OutcomeKind.completedHappened,
        contributions: <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'manual:$indicatorKey',
            indicatorKey: indicatorKey,
            value: contribution,
          ),
        ],
      ),
      operationId: manualOperation,
    );

    expect(
      (await repository.readProgress(
        profileId: profileId,
        goalId: goal.id,
        today: periodStart,
      ))!.dailyActual.scaledValue,
      2,
    );

    final lifecycleRefresh = repository.watchChanges(profileId).first;
    final changed = await events.cancelEvent(
      profileId: profileId,
      eventId: eventId,
      originalDate: periodStart,
      scope: CalendarEventEditScope.occurrence,
      operationId: cancelOperation,
    );
    await lifecycleRefresh;
    final retry = await events.cancelEvent(
      profileId: profileId,
      eventId: eventId,
      originalDate: periodStart,
      scope: CalendarEventEditScope.occurrence,
      operationId: cancelOperation,
    );

    expect(changed, CalendarEventMutationOutcome.changed);
    expect(retry, CalendarEventMutationOutcome.unchanged);
    expect(
      (await repository.readProgress(
        profileId: profileId,
        goalId: goal.id,
        today: periodStart,
      ))!.dailyActual.scaledValue,
      1,
      reason:
          'the manual contribution remains while the deleted Event '
          'no longer qualifies for current Actual',
    );
    expect(await database.select(database.outcomeReports).get(), hasLength(2));
    expect(
      await database.select(database.activityLedgerEntries).get(),
      hasLength(2),
      reason:
          'immutable factual history is retained; projection decides '
          'whether the Event still counts',
    );
    await Future<void>.delayed(Duration.zero);
    expect(changeGenerations.length, greaterThan(1));
    expect(
      changeGenerations.toSet(),
      hasLength(changeGenerations.length),
      reason:
          'every committed lifecycle change needs a distinct Riverpod value; '
          'a void or constant stream leaves Home stuck on stale Actuals',
    );
  });
}

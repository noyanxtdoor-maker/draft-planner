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
    expect(active[3].title, 'Ministering Visit');
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
}

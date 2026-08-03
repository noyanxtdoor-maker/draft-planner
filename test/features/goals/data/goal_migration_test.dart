import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test('v16 to v17 migrates goals and re-keys legacy targets safely', () async {
    final sqliteDatabase = sqlite3.openInMemory();

    try {
      final version16 = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 16,
      );
      final profile = await buildTestRepository(
        database: version16,
      ).completeOnboarding();
      final now = DateTime.utc(2026, 8, 2, 12);

      await (version16.update(version16.lifeIndicatorDefinitions)..where(
            (table) =>
                table.profileId.equals(profile.id) &
                table.indicatorKey.equals('meaningful_connections'),
          ))
          .write(
            const LifeIndicatorDefinitionsCompanion(
              label: Value<String>('Ministering Visits Custom'),
            ),
          );
      await version16
          .into(version16.indicatorGoalRevisions)
          .insert(
            IndicatorGoalRevisionsCompanion.insert(
              id: 'legacy-indicator-target',
              profileId: profile.id,
              goalId: const Value<String?>(null),
              indicatorKey: 'meaningful_connections',
              periodType: 'weekly',
              periodStartDate: '2026-07-27',
              periodEndDate: '2026-08-02',
              state: 'explicit',
              valueScaled: const Value<int?>(4),
              valueScale: 0,
              unit: 'count',
              supersedesRevisionId: const Value<String?>(null),
              operationId: 'legacy-indicator-target-operation',
              createdAtUtc: now,
            ),
          );
      await version16
          .into(version16.weeklyIndicatorTargetRevisions)
          .insert(
            WeeklyIndicatorTargetRevisionsCompanion.insert(
              id: 'legacy-weekly-target',
              profileId: profile.id,
              indicatorKey: 'meaningful_connections',
              goalId: const Value<String?>(null),
              periodStartDate: '2026-07-27',
              state: 'explicit',
              valueScaled: const Value<int?>(4),
              valueScale: 0,
              unit: 'count',
              supersedesRevisionId: const Value<String?>(null),
              operationId: 'legacy-weekly-target-operation',
              createdAtUtc: now,
            ),
          );
      await version16.close();

      final version17 = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 17,
      );
      final goals = await (version17.select(
        version17.goals,
      )..where((table) => table.profileId.equals(profile.id))).get();
      expect(goals, hasLength(6));
      expect(
        goals.where((goal) => goal.role == GoalRole.dailyWeekly.storageName),
        hasLength(1),
      );
      expect(
        goals.where((goal) => goal.role == GoalRole.weekly.storageName),
        hasLength(4),
      );
      expect(
        goals.where((goal) => goal.role == GoalRole.weeklyMonthly.storageName),
        hasLength(1),
      );
      final slot4 = goals.singleWhere((goal) => goal.activeSlotIndex == 4);
      expect(slot4.id, '${profile.id}:goal:4');
      expect(slot4.title, 'Ministering Visits Custom');
      expect(slot4.iconId, equals(null));

      final indicatorTarget =
          await (version17.select(version17.indicatorGoalRevisions)
                ..where((table) => table.id.equals('legacy-indicator-target')))
              .getSingle();
      expect(indicatorTarget.goalId, slot4.id);
      expect(indicatorTarget.valueScaled, 4);
      final weeklyTarget = await (version17.select(
        version17.weeklyIndicatorTargetRevisions,
      )..where((table) => table.id.equals('legacy-weekly-target'))).getSingle();
      expect(weeklyTarget.goalId, slot4.id);
      expect(weeklyTarget.valueScaled, 4);

      expect(
        await (version17.select(
          version17.goalActivities,
        )..where((table) => table.profileId.equals(profile.id))).get(),
        hasLength(6),
      );
      expect(
        await (version17.select(
          version17.goalOutboxOperations,
        )..where((table) => table.profileId.equals(profile.id))).get(),
        hasLength(6),
      );
      final migratedDefinition =
          await (version17.select(version17.lifeIndicatorDefinitions)..where(
                (table) =>
                    table.profileId.equals(profile.id) &
                    table.indicatorKey.equals('meaningful_connections'),
              ))
              .getSingle();
      expect(migratedDefinition.label, 'Ministering Visits Custom');
      await version17.close();

      final reopened = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 17,
      );
      expect(
        await (reopened.select(
          reopened.goals,
        )..where((table) => table.profileId.equals(profile.id))).get(),
        hasLength(6),
      );
      expect(
        await (reopened.select(
          reopened.goalActivities,
        )..where((table) => table.profileId.equals(profile.id))).get(),
        hasLength(6),
      );
      expect(
        await (reopened.select(
          reopened.goalOutboxOperations,
        )..where((table) => table.profileId.equals(profile.id))).get(),
        hasLength(6),
      );
      await reopened.close();
    } finally {
      sqliteDatabase.close();
    }
  });
}

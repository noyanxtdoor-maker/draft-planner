import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
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

  test(
    'MP-16: v16/v17 legacy Budget/Ministering identity converges through the '
    'current bootstrap without recrossing',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();
      try {
        // 1. v16-era approved definitions with DEFAULT labels so the v17
        // migration produces the exact legacy identity evidence.
        final version16 = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 16,
        );
        final profile = await buildTestRepository(
          database: version16,
        ).completeOnboarding();
        final now = DateTime.utc(2026, 8, 2, 12);
        // Legacy target revisions keyed by the pre-cross indicators.
        await version16
            .into(version16.indicatorGoalRevisions)
            .insert(
              IndicatorGoalRevisionsCompanion.insert(
                id: 'mp16-legacy-indicator-target',
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
                operationId: 'mp16-legacy-indicator-operation',
                createdAtUtc: now,
              ),
            );
        await version16
            .into(version16.weeklyIndicatorTargetRevisions)
            .insert(
              WeeklyIndicatorTargetRevisionsCompanion.insert(
                id: 'mp16-legacy-weekly-target',
                profileId: profile.id,
                indicatorKey: 'budget_review',
                goalId: const Value<String?>(null),
                periodStartDate: '2026-07-27',
                state: 'explicit',
                valueScaled: const Value<int?>(4),
                valueScale: 0,
                unit: 'count',
                supersedesRevisionId: const Value<String?>(null),
                operationId: 'mp16-legacy-weekly-operation',
                createdAtUtc: now,
              ),
            );
        await version16.close();

        // 2. v17 creates deterministic Goal IDs from the legacy seed order:
        // position 3 -> goal:4 (Ministering Visit) and position 4 -> goal:5
        // (Budget Review), with immutable created activity/outbox evidence and
        // re-keyed legacy target ownership.
        final version17 = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 17,
        );
        final goals17 = await (version17.select(
          version17.goals,
        )..where((table) => table.profileId.equals(profile.id))).get();
        expect(goals17, hasLength(6));
        final g4 = goals17.singleWhere(
          (goal) => goal.id == '${profile.id}:goal:4',
        );
        final g5 = goals17.singleWhere(
          (goal) => goal.id == '${profile.id}:goal:5',
        );
        expect(g4.indicatorKey, 'meaningful_connections');
        expect(g4.activeSlotIndex, 4);
        expect(g4.title, 'Ministering Visit');
        expect(g5.indicatorKey, 'budget_review');
        expect(g5.activeSlotIndex, 5);
        expect(g5.title, 'Budget Review');

        final activities = await (version17.select(
          version17.goalActivities,
        )..where((table) => table.profileId.equals(profile.id))).get();
        final g4Created = activities.singleWhere(
          (row) => row.operationId == '${profile.id}:goal:4:created',
        );
        final g5Created = activities.singleWhere(
          (row) => row.operationId == '${profile.id}:goal:5:created',
        );
        expect(g4Created.action, 'created');
        expect(g4Created.newValue, 'Ministering Visit');
        expect(g5Created.action, 'created');
        expect(g5Created.newValue, 'Budget Review');

        final outbox = await (version17.select(
          version17.goalOutboxOperations,
        )..where((table) => table.profileId.equals(profile.id))).get();
        final g4Payload = jsonDecode(
          outbox
              .singleWhere(
                (row) => row.operationId == '${profile.id}:goal:4:created',
              )
              .payloadJson,
        ) as Map<String, Object?>;
        final g5Payload = jsonDecode(
          outbox
              .singleWhere(
                (row) => row.operationId == '${profile.id}:goal:5:created',
              )
              .payloadJson,
        ) as Map<String, Object?>;
        expect(g4Payload['slot'], 4);
        expect(g4Payload['title'], 'Ministering Visit');
        expect(g5Payload['slot'], 5);
        expect(g5Payload['title'], 'Budget Review');

        final indicatorTarget = await (version17.select(
          version17.indicatorGoalRevisions,
        )..where((table) => table.id.equals('mp16-legacy-indicator-target')))
            .getSingle();
        expect(indicatorTarget.goalId, g4.id);
        expect(indicatorTarget.valueScaled, 4);
        final weeklyTarget = await (version17.select(
          version17.weeklyIndicatorTargetRevisions,
        )..where((table) => table.id.equals('mp16-legacy-weekly-target')))
            .getSingle();
        expect(weeklyTarget.goalId, g5.id);
        expect(weeklyTarget.valueScaled, 4);
        await version17.close();

        // 3. Advance to the current schema and run the current bootstrap.
        final current = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        );
        final currentClock = FixedClock(DateTime.utc(2026, 8, 14, 12));
        // Seed the canonical Event Types + mapping rows (the device always has
        // them; the migration path never seeds them on its own).
        await DriftEventTypeRepository(
          database: current,
          clock: currentClock,
        ).readEventTypes(profileId: profile.id);
        final repository = DriftGoalRepository(
          database: current,
          clock: currentClock,
          identifiers: const UuidIdentifierSource(),
        );
        // 3a. The FIRST current bootstrap reproduces the historical crossover
        // exactly: legacy rows carry no fixed assignment key (v19 added the
        // column without backfill), so the canonical slot loop selects them by
        // deterministic ID and rewrites their keys/slots. This is the proven
        // defect mechanism the MP-16 helper is keyed to.
        await repository.ensureCanonicalGoals(profile.id);
        final firstRun = await (current.select(
          current.goals,
        )..where((table) => table.profileId.equals(profile.id))).get();
        expect(
          firstRun.singleWhere((goal) => goal.id == g4.id).activeSlotIndex,
          4,
        );
        expect(
          firstRun.singleWhere((goal) => goal.id == g4.id).indicatorKey,
          'budget_review',
        );
        expect(
          firstRun.singleWhere((goal) => goal.id == g5.id).activeSlotIndex,
          5,
        );
        expect(
          firstRun.singleWhere((goal) => goal.id == g5.id).indicatorKey,
          'meaningful_connections',
        );
        // 3b. The NEXT bootstrap run applies the exact history-keyed
        // reconciliation: the crossed keys/slots now match the predicate and
        // the immutable v17 creation evidence proves the historical identity.
        await repository.ensureCanonicalGoals(profile.id);

        // 4. Desired MP-16 state: durable IDs keep their historical semantics
        // under the current canonical slot order.
        final after = await (current.select(
          current.goals,
        )..where((table) => table.profileId.equals(profile.id))).get();
        final g4After = after.singleWhere((goal) => goal.id == g4.id);
        final g5After = after.singleWhere((goal) => goal.id == g5.id);
        expect(g5After.activeSlotIndex, 4);
        expect(g5After.indicatorKey, 'budget_review');
        expect(g5After.assignedEventTypeStableKey, 'budget_review');
        expect(g4After.activeSlotIndex, 5);
        expect(g4After.indicatorKey, 'meaningful_connections');
        expect(g4After.assignedEventTypeStableKey, 'meaningful_connection');
        // Titles/icons/timestamps are preserved.
        expect(g4After.title, 'Ministering Visit');
        expect(g5After.title, 'Budget Review');
        expect(g4After.iconId, g4.iconId);
        expect(g5After.iconId, g5.iconId);
        expect(g4After.createdAtUtc, g4.createdAtUtc);
        expect(g5After.createdAtUtc, g5.createdAtUtc);
        // The derived position-3 definition label converges to the preserved
        // G4 title through the existing synchronization path.
        final definition = await (current.select(
          current.lifeIndicatorDefinitions,
        )..where(
              (table) =>
                  table.profileId.equals(profile.id) &
                  table.indicatorKey.equals('meaningful_connections'),
            ))
            .getSingle();
        expect(definition.label, 'Ministering Visit');
        await current.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );
}

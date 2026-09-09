import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/presentation/event_type_picker_dialog.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

import '../support/test_dependencies.dart';

void main() {
  const profileId = '357caa4f-5383-4cb0-947e-69dc3ef06936';
  const goalIds = [
    '13c00925-3c47-4fc6-8374-cb6ee5d73d8a',
    '7517a22c-5357-43dc-8704-3759ae727203',
  ];
  final clock = FixedClock(DateTime.utc(2026, 9, 9, 2));
  final fixture = Platform.environment['LINKAGE_REPAIRED_COPY'];
  Future<AppDatabase> copiedDatabase() async {
    final dir = Directory.systemTemp.createTempSync('linkage-proof-');
    final file = File(fixture!).copySync('${dir.path}/proof.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });
    return db;
  }

  Future<Map<String, List<Map<String, Object?>>>> rows(AppDatabase db) async {
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'goals',
      'activity_types',
      'activity_type_indicator_mappings',
      'calendar_events',
      'calendar_event_exceptions',
      'outcome_reports',
      'activity_ledger_entries',
      'indicator_goal_revisions',
      'goal_activities',
      'goal_outbox_operations',
      'weekly_plan_goal_memberships',
      'goal_achievement_events',
    ]) {
      result[table] =
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((r) => r.data)
              .toList();
    }
    return result;
  }

  testWidgets(
    'repaired v46 exact IDs resolve normal colors and picker hides retired duplicates without rewriting history',
    (tester) async {
      final db = await copiedDatabase();
      final before = await rows(db);
      final startup = buildTestRepository(database: db);
      final privacy = TestPrivacyDependencies(database: db);
      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);
      final goals = DriftGoalRepository(
        database: db,
        clock: clock,
        identifiers: const UuidIdentifierSource(),
      );
      final types = DriftEventTypeRepository(database: db, clock: clock);
      for (var i = 0; i < 2; i++) {
        final goal = (await goals.readGoal(
          profileId: profileId,
          goalId: goalIds[i],
        ))!;
        final slot = CanonicalGoalSlot.bySlot(i + 1);
        expect(goal.assignedEventTypeStableKey, slot.eventTypeStableKey);
        expect(goal.indicatorKey, slot.indicatorKey);
        expect(
          (await types.readEventType(
            profileId: profileId,
            eventTypeId: slot.eventTypeId,
          ))!.isCreationVisible,
          isTrue,
        );
        final retired = (await types.readEventType(
          profileId: profileId,
          eventTypeId: 'goal:${goalIds[i]}',
        ))!;
        expect(retired.isCreationVisible, isFalse);
        expect(
          retired.isArchived,
          isFalse,
          reason: 'Dormancy is presentation-only; history rows are retained',
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('linkage-picker'),
          overrides: [
            eventTypeRepositoryProvider.overrideWithValue(types),
            startupRepositoryProvider.overrideWithValue(startup),
            diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(startupControllerProvider);
                return Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        showEventTypePicker(context: context, ref: ref),
                    child: const Text('Choose'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      for (final id in goalIds) {
        expect(find.byKey(Key('event-type-option-goal:$id')), findsNothing);
      }
      final job = find.byKey(const Key('event-type-option-job_application'));
      final scripture = find.byKey(
        const Key('event-type-option-scripture_study'),
      );
      final task = find.byKey(const Key('event-type-option-task'));
      expect(
        tester.getTopLeft(job).dy,
        lessThan(tester.getTopLeft(scripture).dy),
      );
      expect(
        tester.getTopLeft(scripture).dy,
        lessThan(tester.getTopLeft(task).dy),
      );
      for (final entry in {
        'job_application': 0xFFEBC766,
        'scripture_study': 0xFFDE9EDA,
      }.entries) {
        final icon = tester.widget<Container>(
          find.byKey(Key('event-type-icon-${entry.key}')),
        );
        expect((icon.decoration! as BoxDecoration).color, Color(entry.value));
      }
      expect(find.text('Sample 1'), findsOneWidget);
      expect(find.text('sample2'), findsOneWidget);
      expect(find.text('Sample1'), findsNothing);
      await tester.tap(find.byKey(const Key('event-type-picker-cancel')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await goals.ensureCanonicalGoals(profileId);
      await goals.ensureCanonicalGoals(profileId);
      expect(
        await rows(db),
        before,
        reason:
            'Startup, reads, selector and repeated bootstrap must preserve every historical row',
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        46,
      );
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(tester.takeException(), isNull);
    },
    skip: fixture == null,
  );

  test(
    'save and new Goal creation use normal slot types and never generate per-Goal Event Types',
    () async {
      final db = await copiedDatabase();
      final repo = DriftGoalRepository(
        database: db,
        clock: clock,
        identifiers: const UuidIdentifierSource(),
      );
      final originalTypes = await db.select(db.activityTypes).get();
      final originalEvents = await db.select(db.calendarEvents).get();
      const amount = IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count');
      for (var i = 0; i < 2; i++) {
        final existing = (await repo.readGoal(
          profileId: profileId,
          goalId: goalIds[i],
        ))!;
        await repo.saveGoal(
          profileId: profileId,
          goalId: existing.id,
          title: existing.title,
          targets: const GoalTargets(daily: amount, weekly: amount),
          operationId: 'copy-save-$i',
        );
        expect(
          (await repo.readGoal(
            profileId: profileId,
            goalId: existing.id,
          ))!.assignedEventTypeStableKey,
          CanonicalGoalSlot.bySlot(i + 1).eventTypeStableKey,
        );
      }
      final created = await repo.createGoal(
        profileId: profileId,
        role: GoalRole.weekly,
        title: 'Copy-only new Goal',
        targets: const GoalTargets(weekly: amount),
        expectedSlotIndex: 3,
        operationId: 'copy-create',
      );
      expect(
        created.assignedEventTypeStableKey,
        CanonicalGoalSlot.bySlot(3).eventTypeStableKey,
      );
      expect(created.indicatorKey, CanonicalGoalSlot.bySlot(3).indicatorKey);
      await repo.ensureCanonicalGoals(profileId);
      expect(await db.select(db.activityTypes).get(), originalTypes);
      expect(await db.select(db.calendarEvents).get(), originalEvents);
    },
    skip: fixture == null,
  );
}

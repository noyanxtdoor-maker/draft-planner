import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  // T10: archive Goal A, create Goal B in the same slot. Canonical type
  // identity never changes; the old Event keeps A's alias snapshot; a new
  // Event snapshots B. Shared-indicator same-period actual carryover is
  // EXPLICITLY CHARACTERIZED (not fixed): a replacement Goal may observe
  // existing same-period contributions through the shared indicator. This
  // test records the existing law; it grants no accounting change.
  late AppDatabase database;
  late DriftEventTypeRepository types;
  late DriftGoalRepository goals;
  late DriftCalendarEventRepository events;
  late String profileId;
  final clock = FixedClock(DateTime.utc(2026, 9, 9, 12));

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    types = DriftEventTypeRepository(database: database, clock: clock);
    goals = DriftGoalRepository(
      database: database,
      clock: clock,
      identifiers: const UuidIdentifierSource(),
    );
    events = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
    );
    await (database.update(database.goals)
            ..where((table) => table.status.equals('active')))
        .write(const GoalsCompanion(status: Value<String>('archived')));
    await types.readEventTypes(profileId: profileId);
  });

  tearDown(() => database.close());

  const amount = IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count');

  test('reoccupation keeps canonical identity and re-aliases new snapshots',
      () async {
    // The allocator hands out the first free weekly slot (2) after setUp
    // archives the bootstrap occupants; derive identity from the actual slot.
    final goalA = await goals.createGoal(
      profileId: profileId,
      role: GoalRole.weekly,
      title: 'Goal A',
      targets: const GoalTargets(weekly: amount),
      operationId: 't10-create-a',
    );
    final slotIndexA = goalA.activeSlotIndex!;
    final slot = CanonicalGoalSlot.bySlot(slotIndexA);
    final eventAId = '3a100000-0000-4000-8000-000000000001';
    await events.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: eventAId,
        title: 'Run A',
        timing: CalendarEventTiming.allDay,
        startDate: PlannerDate.parse('2026-09-09'),
        activityTypeId: slot.eventTypeId,
        activityTypeStableKeySnapshot: slot.eventTypeStableKey,
        activityTypeLabelSnapshot: 'Goal A',
        activityTypeColorValueSnapshot: 0xFF000000,
        recurrence: const CalendarRecurrenceRule(),
        requiresReport: false,
        isBackupAppointment: false,
      ),
    );
    // Archive A, create B: it must re-occupy exactly A's freed slot.
    await goals.archiveGoal(
      profileId: profileId,
      goalId: goalA.id,
      operationId: 't10-archive-a',
    );
    final goalB = await goals.createGoal(
      profileId: profileId,
      role: slot.role,
      title: 'Goal B',
      targets: const GoalTargets(weekly: amount),
      expectedSlotIndex: slotIndexA,
      operationId: 't10-create-b',
    );
    expect(goalB.activeSlotIndex, slotIndexA,
        reason: 'reoccupation returns to the same canonical slot');
    // Canonical identity unchanged.
    final rowAfter = await (database.select(database.activityTypes)
          ..where((table) => table.id.equals(slot.eventTypeId)))
        .getSingle();
    expect(rowAfter.stableKey, slot.eventTypeStableKey);
    expect(rowAfter.label, slot.defaultTitle,
        reason: 'canonical raw label never re-labeled by Goals');
    // Old Event snapshot still A's alias (no historical rewrite).
    final eventA = await (database.select(database.calendarEvents)
          ..where((table) => table.id.equals(eventAId)))
        .getSingle();
    expect(eventA.activityTypeLabelSnapshot, 'Goal A');
    // New Event snapshots B's alias.
    final eventBId = '3a100000-0000-4000-8000-000000000002';
    await events.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: eventBId,
        title: 'Run B',
        timing: CalendarEventTiming.allDay,
        startDate: PlannerDate.parse('2026-09-10'),
        activityTypeId: slot.eventTypeId,
        activityTypeStableKeySnapshot: slot.eventTypeStableKey,
        activityTypeLabelSnapshot: 'Exercise',
        activityTypeColorValueSnapshot: 0xFF000000,
        recurrence: const CalendarRecurrenceRule(),
        requiresReport: false,
        isBackupAppointment: false,
      ),
    );
    final eventB = await (database.select(database.calendarEvents)
          ..where((table) => table.id.equals(eventBId)))
        .getSingle();
    expect(eventB.activityTypeLabelSnapshot, 'Goal B');
    expect(goalB.indicatorKey, goalA.indicatorKey,
        reason: 'the shared indicator is the carryover surface');
  });

  test('readProgress for a nonexistent Goal ID is null (existing law)',
      () async {
    final progress = await goals.readProgress(
      profileId: profileId,
      goalId: '00000000-0000-4000-8000-000000000000',
      today: PlannerDate.parse('2026-09-09'),
    );
    expect(progress, isNull);
  });

  test('archived Goal keeps historical projection results (characterized)',
      () async {
    final goal = await goals.createGoal(
      profileId: profileId,
      role: GoalRole.weekly,
      title: 'Archived Keeper',
      targets: const GoalTargets(weekly: amount),
      operationId: 't10-create-keeper',
    );
    final slot = CanonicalGoalSlot.bySlot(goal.activeSlotIndex!);
    await events.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: '3a200000-0000-4000-8000-000000000003',
        title: 'Study',
        timing: CalendarEventTiming.allDay,
        startDate: PlannerDate.parse('2026-09-09'),
        activityTypeId: slot.eventTypeId,
        activityTypeStableKeySnapshot: slot.eventTypeStableKey,
        activityTypeLabelSnapshot: 'Archived Keeper',
        activityTypeColorValueSnapshot: 0xFF000000,
        recurrence: const CalendarRecurrenceRule(),
        requiresReport: false,
        isBackupAppointment: false,
      ),
    );
    await goals.archiveGoal(
      profileId: profileId,
      goalId: goal.id,
      operationId: 't10-archive-keeper',
    );
    // CHARACTERIZATION: the archived Goal can still calculate progress from
    // historical facts. This documents the existing accounting law (hiding a
    // picker choice does not erase or stop contribution facts).
    final progress = await goals.readProgress(
      profileId: profileId,
      goalId: goal.id,
      today: PlannerDate.parse('2026-09-09'),
    );
    expect(progress, isNotNull,
        reason: 'archived Goals keep historical/projection results (existing '
            'accounting law, intentionally unchanged by this contract)');
  });
}

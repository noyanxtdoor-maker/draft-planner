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
    // completeOnboarding seeds six bootstrap Goals occupying every slot.
    // Archive them ALL so each test controls its own occupancy; the archived
    // bootstrap rows keep history readable exactly like production archives.
    await (database.update(database.goals)
            ..where((table) => table.status.equals('active')))
        .write(const GoalsCompanion(status: Value<String>('archived')));
    await types.readEventTypes(profileId: profileId);
  });

  tearDown(() => database.close());

  const amount = IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count');

  Future<Goal> createOccupiedGoal({
    required int slotIndex,
    required String title,
  }) async {
    final slot = CanonicalGoalSlot.bySlot(slotIndex);
    return goals.createGoal(
      profileId: profileId,
      role: slot.role,
      title: title,
      targets: const GoalTargets(weekly: amount),
      expectedSlotIndex: slotIndex,
      operationId: 't08-create-$slotIndex-$title',
    );
  }

  CalendarEventDraft draft({
    required String id,
    required String title,
    required String typeId,
    required String stableKey,
    required String label,
    String startDate = '2026-09-09',
  }) {
    return CalendarEventDraft(
      id: id,
      title: title,
      timing: CalendarEventTiming.allDay,
      startDate: PlannerDate.parse(startDate),
      activityTypeId: typeId,
      activityTypeStableKeySnapshot: stableKey,
      activityTypeLabelSnapshot: label,
      activityTypeColorValueSnapshot: 0xFF000000,
      recurrence: const CalendarRecurrenceRule(),
      requiresReport: false,
      isBackupAppointment: false,
    );
  }

  test('new Event with live occupant stores the Goal-title alias', () async {
    await createOccupiedGoal(slotIndex: 1, title: 'Sample1');
    final slot = CanonicalGoalSlot.bySlot(1);
    final eventId = 'e1000000-0000-4000-8000-000000000001';
    await events.saveEvent(
      profileId: profileId,
      draft: draft(
        id: eventId,
        title: 'Apply somewhere',
        typeId: slot.eventTypeId,
        stableKey: slot.eventTypeStableKey,
        label: 'Job Application',
      ),
    );
    final row = await (database.select(database.calendarEvents)
          ..where((table) => table.id.equals(eventId)))
        .getSingle();
    expect(row.activityTypeStableKeySnapshot, slot.eventTypeStableKey);
    expect(row.activityTypeId, slot.eventTypeId);
    expect(row.activityTypeLabelSnapshot, 'Sample1',
        reason: 'the live Goal title alias wins over any supplied label');
  });

  test('new Event without a live occupant is rejected and writes nothing',
      () async {
    // No Goal occupies slot 3 in this profile.
    final slot = CanonicalGoalSlot.bySlot(3);
    final eventId = 'e2000000-0000-4000-8000-000000000002';
    await expectLater(
      events.saveEvent(
        profileId: profileId,
        draft: draft(
          id: eventId,
          title: 'Run',
          typeId: slot.eventTypeId,
          stableKey: slot.eventTypeStableKey,
          label: 'Exercise',
        ),
      ),
      throwsA(isA<CalendarEventValidationException>()),
    );
    expect(
      await database.select(database.calendarEvents).get(),
      isEmpty,
    );
  });

  test('same-type edit of a hidden slot type is preserved, never gated',
      () async {
    await createOccupiedGoal(slotIndex: 1, title: 'Sample1');
    final slot = CanonicalGoalSlot.bySlot(1);
    final eventId = 'e3000000-0000-4000-8000-000000000003';
    await events.saveEvent(
      profileId: profileId,
      draft: draft(
        id: eventId,
        title: 'Apply somewhere',
        typeId: slot.eventTypeId,
        stableKey: slot.eventTypeStableKey,
        label: 'Sample1',
      ),
    );
    // Empty the slot (archive) — the type becomes hidden for NEW selection.
    final goal = (await goals.readActiveGoals(profileId)).single;
    await goals.archiveGoal(
      profileId: profileId,
      goalId: goal.id,
      operationId: 't08-archive-1',
    );
    final storedLabelBefore = (await (database.select(database.calendarEvents)
              ..where((table) => table.id.equals(eventId)))
            .getSingle())
        .activityTypeLabelSnapshot;
    // Same-type edit must succeed and keep the stored snapshot byte-identical.
    await events.saveEvent(
      profileId: profileId,
      draft: draft(
        id: eventId,
        title: 'Renamed Event',
        typeId: slot.eventTypeId,
        stableKey: slot.eventTypeStableKey,
        label: 'Sample1',
      ),
    );
    final row = await (database.select(database.calendarEvents)
          ..where((table) => table.id.equals(eventId)))
        .getSingle();
    expect(row.title, 'Renamed Event');
    expect(row.activityTypeLabelSnapshot, storedLabelBefore);
    expect(row.activityTypeStableKeySnapshot, slot.eventTypeStableKey);
  });

  test('deliberate type change to a hidden slot type is rejected', () async {
    await createOccupiedGoal(slotIndex: 1, title: 'Sample1');
    final occupied = CanonicalGoalSlot.bySlot(1);
    final hidden = CanonicalGoalSlot.bySlot(3);
    final eventId = 'e4000000-0000-4000-8000-000000000004';
    await events.saveEvent(
      profileId: profileId,
      draft: draft(
        id: eventId,
        title: 'Apply somewhere',
        typeId: occupied.eventTypeId,
        stableKey: occupied.eventTypeStableKey,
        label: 'Sample1',
      ),
    );
    await expectLater(
      events.saveEvent(
        profileId: profileId,
        draft: draft(
          id: eventId,
          title: 'Run instead',
          typeId: hidden.eventTypeId,
          stableKey: hidden.eventTypeStableKey,
          label: 'Exercise',
        ),
      ),
      throwsA(isA<CalendarEventValidationException>()),
    );
  });

  test('null type Event keeps legacy behavior', () async {
    final eventId = 'e5000000-0000-4000-8000-000000000005';
    await events.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: eventId,
        title: 'No type',
        timing: CalendarEventTiming.allDay,
        startDate: PlannerDate.parse('2026-09-09'),
        recurrence: const CalendarRecurrenceRule(),
        requiresReport: false,
        isBackupAppointment: false,
      ),
    );
    final row = await (database.select(database.calendarEvents)
          ..where((table) => table.id.equals(eventId)))
        .getSingle();
    expect(row.activityTypeId, isNull);
    expect(row.activityTypeLabelSnapshot, isNull);
  });

  test('duplicate of a hidden-type Event is rejected without any write',
      () async {
    await createOccupiedGoal(slotIndex: 1, title: 'Sample1');
    final slot = CanonicalGoalSlot.bySlot(1);
    final eventId = 'e6000000-0000-4000-8000-000000000006';
    await events.saveEvent(
      profileId: profileId,
      draft: draft(
        id: eventId,
        title: 'Apply somewhere',
        typeId: slot.eventTypeId,
        stableKey: slot.eventTypeStableKey,
        label: 'Sample1',
      ),
    );
    final goal = (await goals.readActiveGoals(profileId)).single;
    await goals.archiveGoal(
      profileId: profileId,
      goalId: goal.id,
      operationId: 't08-archive-dup',
    );
    final eventsBefore = await database.select(database.calendarEvents).get();
    await expectLater(
      events.duplicateEvent(
        profileId: profileId,
        eventId: eventId,
        originalDate: PlannerDate.parse('2026-09-09'),
        duplicateId: 'e6000000-0000-4000-8000-000000000007',
        operationId: 't08-dup-1',
      ),
      throwsA(isA<CalendarEventValidationException>()),
    );
    final eventsAfter = await database.select(database.calendarEvents).get();
    expect(eventsAfter.length, eventsBefore.length,
        reason: 'no duplicate row may land');
  });
}

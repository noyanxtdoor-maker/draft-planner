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
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  // T07 (repository layer): stale/hidden initial selections are rejected on
  // write while saved preferences stay untouched; preservation of existing
  // types and unrelated settings writes keep working.
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
    // Archive the bootstrap Goals so all six slots start EMPTY.
    await (database.update(database.goals)
            ..where((table) => table.status.equals('active')))
        .write(const GoalsCompanion(status: Value<String>('archived')));
    await types.readEventTypes(profileId: profileId);
  });

  tearDown(() => database.close());

  const amount = IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count');

  CalendarEventDraft draftWithType({
    required String id,
    required String typeId,
    required String stableKey,
  }) {
    return CalendarEventDraft(
      id: id,
      title: 'Guarded Event',
      timing: CalendarEventTiming.allDay,
      startDate: PlannerDate.parse('2026-09-09'),
      activityTypeId: typeId,
      activityTypeStableKeySnapshot: stableKey,
      activityTypeLabelSnapshot: 'label',
      activityTypeColorValueSnapshot: 0xFF000000,
      recurrence: const CalendarRecurrenceRule(),
      requiresReport: false,
      isBackupAppointment: false,
    );
  }

  test('hidden canonical type is rejected for a NEW Event; Other still works',
      () async {
    final hidden = CanonicalGoalSlot.bySlot(4);
    final otherType = (await types.readEventTypes(profileId: profileId))
        .singleWhere((type) => type.stableKey == SystemEventTypeKeys.other);
    await expectLater(
      events.saveEvent(
        profileId: profileId,
        draft: draftWithType(
          id: '4d700000-0000-4000-8000-000000000001',
          typeId: hidden.eventTypeId,
          stableKey: hidden.eventTypeStableKey,
        ),
      ),
      throwsA(isA<CalendarEventValidationException>()),
    );
    // A non-canonical type (Other) never needs a slot occupant.
    await events.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: '4d700000-0000-4000-8000-000000000002',
        title: 'Other Event',
        timing: CalendarEventTiming.allDay,
        startDate: PlannerDate.parse('2026-09-09'),
        activityTypeId: otherType.id,
        recurrence: const CalendarRecurrenceRule(),
        requiresReport: false,
        isBackupAppointment: false,
      ),
    );
  });

  test('creating a Goal reveals its type; archiving retains but forbids new',
      () async {
    final slot = CanonicalGoalSlot.bySlot(6);
    final otherType = (await types.readEventTypes(profileId: profileId))
        .singleWhere((type) => type.stableKey == SystemEventTypeKeys.other);
    await goals.createGoal(
      profileId: profileId,
      role: slot.role,
      title: 'Temple Goal',
      targets: const GoalTargets(monthly: amount),
      expectedSlotIndex: 6,
      operationId: 't07-create-6',
    );
    final eventId = '4d700000-0000-4000-8000-000000000003';
    await events.saveEvent(
      profileId: profileId,
      draft: draftWithType(
        id: eventId,
        typeId: slot.eventTypeId,
        stableKey: slot.eventTypeStableKey,
      ),
    );
    // With the Goal LIVE, the slot type is a valid deliberate default.
    final settings = await types.readPlannerSettings(profileId: profileId);
    await types.savePlannerSettings(
      profileId: profileId,
      settings: settings.copyWith(defaultEventTypeId: slot.eventTypeId),
    );
    // Archive the Goal: the type becomes hidden for NEW selections.
    await goals.archiveGoal(
      profileId: profileId,
      goalId: (await goals.readActiveGoals(profileId)).single.id,
      operationId: 't07-archive-6',
    );
    // Retaining the ALREADY-STORED hidden default while changing unrelated
    // settings must still succeed (no passive mutation, no failure).
    final stored = await types.readPlannerSettings(profileId: profileId);
    expect(stored.defaultEventTypeId, slot.eventTypeId);
    await types.savePlannerSettings(
      profileId: profileId,
      settings: stored.copyWith(
        timelineHourHeight: stored.timelineHourHeight + 1,
      ),
    );
    // Switching away to a non-canonical type is a valid NEW selection.
    await types.savePlannerSettings(
      profileId: profileId,
      settings: stored.copyWith(defaultEventTypeId: otherType.id),
    );
    // A NEW deliberate default pointing back at the now-hidden type fails.
    await expectLater(
      types.savePlannerSettings(
        profileId: profileId,
        settings: stored.copyWith(defaultEventTypeId: slot.eventTypeId),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/data/drift_map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';

import '../../support/test_dependencies.dart';

void main() {
  test(
    'P4 bounded range preserves recurrence, cancellation, and +90 edge',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profileId = (await buildTestRepository(
        database: database,
      ).completeOnboarding()).id;
      final repository = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 9, 1, 4)),
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      );
      expect(repository, isA<CalendarEventRangeSource>());

      const repeatingId = '11111111-1111-4111-8111-111111111111';
      const edgeId = '22222222-2222-4222-8222-222222222222';
      const outsideId = '33333333-3333-4333-8333-333333333333';
      const start = PlannerDate(year: 2026, month: 9, day: 1);
      const cancelledDate = PlannerDate(year: 2026, month: 9, day: 3);
      const end = PlannerDate(year: 2026, month: 11, day: 30);

      await repository.saveEvent(
        profileId: profileId,
        draft: const CalendarEventDraft(
          id: repeatingId,
          title: 'Daily follow-up',
          timing: CalendarEventTiming.allDay,
          startDate: start,
          requiresReport: false,
          recurrence: CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.daily,
            endMode: CalendarRecurrenceEndMode.onDate,
            endDate: PlannerDate(year: 2026, month: 9, day: 5),
          ),
        ),
      );
      await repository.cancelEvent(
        profileId: profileId,
        eventId: repeatingId,
        originalDate: cancelledDate,
        scope: CalendarEventEditScope.occurrence,
        operationId: '44444444-4444-4444-8444-444444444444',
      );
      await repository.saveEvent(
        profileId: profileId,
        draft: const CalendarEventDraft(
          id: edgeId,
          title: 'Horizon edge',
          timing: CalendarEventTiming.allDay,
          startDate: end,
          requiresReport: false,
        ),
      );
      await repository.saveEvent(
        profileId: profileId,
        draft: const CalendarEventDraft(
          id: outsideId,
          title: 'Outside horizon',
          timing: CalendarEventTiming.allDay,
          startDate: PlannerDate(year: 2026, month: 12, day: 1),
          requiresReport: false,
        ),
      );

      final range = await (repository as CalendarEventRangeSource).readRange(
        profileId: profileId,
        startDate: start,
        endDate: end,
      );
      final scheduledRepeating = range
          .where(
            (item) =>
                item.eventId == repeatingId &&
                item.state == PlannerEventState.scheduled,
          )
          .toList(growable: false);

      expect(scheduledRepeating.map((item) => item.date.iso8601), <String>[
        '2026-09-01',
        '2026-09-02',
        '2026-09-04',
        '2026-09-05',
      ]);
      expect(
        range.any(
          (item) =>
              item.eventId == repeatingId &&
              item.originalDate == cancelledDate &&
              item.state == PlannerEventState.cancelled,
        ),
        isTrue,
      );
      expect(range.any((item) => item.eventId == edgeId), isTrue);
      expect(range.any((item) => item.eventId == outsideId), isFalse);
    },
  );

  test(
    'final Maps Events layer projects only today scheduled located occurrences',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profileId = (await buildTestRepository(
        database: database,
      ).completeOnboarding()).id;
      const today = PlannerDate(year: 2026, month: 9, day: 1);
      final clock = FixedClock(DateTime.utc(2026, 9, 1, 4));
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      );
      final maps = DriftMapCoordinateRepository(
        database: database,
        clock: clock,
      );

      Future<void> save({
        required String id,
        required String title,
        required PlannerDate date,
        CalendarEventStatus status = CalendarEventStatus.scheduled,
        CalendarRecurrenceRule recurrence = const CalendarRecurrenceRule(),
        bool located = true,
      }) async {
        await calendar.saveEvent(
          profileId: profileId,
          draft: CalendarEventDraft(
            id: id,
            title: title,
            timing: CalendarEventTiming.allDay,
            startDate: date,
            status: status,
            requiresReport: false,
            recurrence: recurrence,
          ),
        );
        if (located) {
          await maps.setCoordinate(
            profileId: profileId,
            owner: MapCoordinateOwner.event,
            recordId: id,
            coordinate: const MapCoordinate(latitude: 16.69, longitude: 121.55),
          );
        }
      }

      const todayId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const recurringId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      const tomorrowId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      const pastId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
      const completedId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
      const noCoordinateId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
      const cancelledId = '12121212-1212-4212-8212-121212121212';
      const movedId = '13131313-1313-4313-8313-131313131313';
      await save(id: todayId, title: 'Today one-time', date: today);
      await save(
        id: recurringId,
        title: 'Today recurring',
        date: today.addDays(-2),
        recurrence: const CalendarRecurrenceRule(
          frequency: CalendarRecurrenceFrequency.daily,
        ),
      );
      await save(id: tomorrowId, title: 'Tomorrow', date: today.addDays(1));
      await save(id: pastId, title: 'Past', date: today.addDays(-1));
      await save(
        id: completedId,
        title: 'Completed today',
        date: today,
        status: CalendarEventStatus.completedHappened,
      );
      await save(
        id: noCoordinateId,
        title: 'No coordinate',
        date: today,
        located: false,
      );
      await save(id: cancelledId, title: 'Cancelled today', date: today);
      await calendar.cancelEvent(
        profileId: profileId,
        eventId: cancelledId,
        originalDate: today,
        scope: CalendarEventEditScope.series,
        operationId: '14141414-1414-4414-8414-141414141414',
      );
      await save(
        id: movedId,
        title: 'Moved away',
        date: today,
        recurrence: const CalendarRecurrenceRule(
          frequency: CalendarRecurrenceFrequency.daily,
        ),
      );
      await calendar.rescheduleEvent(
        profileId: profileId,
        eventId: movedId,
        originalDate: today,
        scope: CalendarEventEditScope.occurrence,
        replacement: CalendarEventDraft(
          id: '15151515-1515-4515-8515-151515151515',
          title: 'Moved away',
          timing: CalendarEventTiming.allDay,
          startDate: today.addDays(1),
          requiresReport: false,
        ),
        operationId: '16161616-1616-4616-8616-161616161616',
      );
      final rawMarkers = await maps.readMarkers(profileId);

      final rawEventIds = rawMarkers
          .where((marker) => marker.owner == MapCoordinateOwner.event)
          .map((marker) => marker.recordId)
          .toSet();
      final items = await (calendar as CalendarEventRangeSource).readRange(
        profileId: profileId,
        startDate: today,
        endDate: today,
      );
      final visible = items
          .where(
            (item) =>
                item.state == PlannerEventState.scheduled &&
                item.eventId != null &&
                rawEventIds.contains(item.eventId),
          )
          .toList(growable: false);

      expect(visible.map((item) => item.eventId).toSet(), <String>{
        todayId,
        recurringId,
      });
      expect(visible.every((item) => item.date == today), isTrue);
      expect(visible.every((item) => item.originalDate != null), isTrue);
      final dates = _MapTestDate(today);
      final container = ProviderContainer(
        overrides: [
          mapProfileIdProvider.overrideWithValue(profileId),
          mapCoordinateRepositoryProvider.overrideWithValue(maps),
          // The unchanged repository stream is covered by its own tests;
          // exercise the real date/focus projections over this canonical read.
          mapMarkersProvider.overrideWith((ref) => Stream.value(rawMarkers)),
          calendarEventRepositoryProvider.overrideWithValue(calendar),
          plannerDateSourceProvider.overrideWithValue(dates),
        ],
      );
      addTearDown(container.dispose);
      // Production Maps actively watches these projections. Riverpod 3 may
      // pause unobserved streams, so keep the same active subscriptions here.
      final rawSubscription = container.listen(mapMarkersProvider, (_, _) {});
      final baseSubscription = container.listen(
        mapEventMarkersProvider,
        (_, _) {},
      );
      final focusSubscription = container.listen(
        mapFocusedEventMarkersProvider,
        (_, _) {},
      );
      addTearDown(rawSubscription.close);
      addTearDown(baseSubscription.close);
      addTearDown(focusSubscription.close);
      await container.pump();
      final base = await container.read(mapEventMarkersProvider.future);
      expect(base.map((m) => m.recordId).toSet(), {todayId, recurringId});
      final tomorrow = today.addDays(1);
      final focused = await calendar.readOccurrence(
        profileId: profileId,
        eventId: tomorrowId,
        originalDate: tomorrow,
      );
      container
          .read(mapTransientFocusProvider.notifier)
          .focusEventOccurrence(
            eventId: tomorrowId,
            occurrenceId: focused!.id,
            originalDate: tomorrow,
            renderedDate: tomorrow,
            coordinate: const MapCoordinate(latitude: 16.69, longitude: 121.55),
          );
      final exception = await container.read(
        mapFocusedEventMarkersProvider.future,
      );
      expect(exception.single.recordId, tomorrowId);
      expect(exception.single.outsideCurrentFilter, isTrue);
      expect(
        (await container.read(
          mapEventMarkersProvider.future,
        )).any((m) => m.recordId == tomorrowId),
        isFalse,
      );
      dates.value = tomorrow;
      container.read(mapLocalDayProvider.notifier).refresh();
      final nextBase = await container.read(mapEventMarkersProvider.future);
      expect(nextBase.any((m) => m.recordId == tomorrowId), isTrue);
      expect(nextBase.any((m) => m.recordId == todayId), isFalse);
      expect(
        await container.read(mapFocusedEventMarkersProvider.future),
        isEmpty,
      );
    },
  );
}

final class _MapTestDate implements PlannerDateSource {
  _MapTestDate(this.value);
  PlannerDate value;
  @override
  PlannerDate today() => value;
}

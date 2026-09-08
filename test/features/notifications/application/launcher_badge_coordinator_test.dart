import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/notifications/launcher_badge_gateway.dart';
import 'package:rmplanner/features/notifications/application/launcher_badge_coordinator.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';

void main() {
  final now = DateTime.utc(2026, 9, 6, 10);
  const today = PlannerDate(year: 2026, month: 9, day: 6);

  test('canonical Event and Task states produce exact badge counts', () async {
    final events = _Events();
    final tasks = _Tasks();
    final gateway = _Badge();
    final coordinator = LauncherBadgeCoordinator(
      calendarSource: events,
      taskSource: tasks,
      gateway: gateway,
    );

    expect(
      await coordinator.refresh(
        profileId: 'profile',
        today: today,
        nowUtc: now,
      ),
      0,
    );
    expect(gateway.counts, <int>[0]);

    events.items = <PlannerCalendarItem>[
      _event(id: 'event-occurrence', start: now.add(const Duration(hours: 1))),
    ];
    expect(
      await coordinator.refresh(
        profileId: 'profile',
        today: today,
        nowUtc: now,
      ),
      1,
    );

    events.items = const <PlannerCalendarItem>[];
    tasks.ids = <String>['task-a'];
    expect(
      await coordinator.refresh(
        profileId: 'profile',
        today: today,
        nowUtc: now,
      ),
      1,
    );

    events.items = <PlannerCalendarItem>[
      _event(id: 'event-occurrence', start: now.add(const Duration(hours: 1))),
    ];
    expect(
      await coordinator.refresh(
        profileId: 'profile',
        today: today,
        nowUtc: now,
      ),
      2,
    );
  });

  test(
    'reported, cancelled, deleted, and duplicate projections are excluded',
    () async {
      final events = _Events()
        ..items = <PlannerCalendarItem>[
          _event(
            id: 'reported',
            start: now.add(const Duration(hours: 1)),
            hasOutcomeReport: true,
          ),
          _event(
            id: 'cancelled',
            start: now.add(const Duration(hours: 2)),
            state: PlannerEventState.cancelled,
          ),
          _event(id: 'recurring-one', start: now.add(const Duration(hours: 3))),
          _event(id: 'recurring-one', start: now.add(const Duration(hours: 3))),
        ];
      final gateway = _Badge();
      final coordinator = LauncherBadgeCoordinator(
        calendarSource: events,
        taskSource: _Tasks(),
        gateway: gateway,
      );

      expect(
        await coordinator.refresh(
          profileId: 'profile',
          today: today,
          nowUtc: now,
        ),
        1,
      );
      expect(gateway.counts, <int>[1]);

      events.items = const <PlannerCalendarItem>[];
      expect(
        await coordinator.refresh(
          profileId: 'profile',
          today: today,
          nowUtc: now,
        ),
        0,
        reason: 'a deleted occurrence is absent from canonical range truth',
      );
    },
  );

  test(
    'repeated refresh is an idempotent projection of canonical count',
    () async {
      final gateway = _Badge();
      final coordinator = LauncherBadgeCoordinator(
        calendarSource: _Events()
          ..items = <PlannerCalendarItem>[
            _event(id: 'event-a', start: now.add(const Duration(hours: 1))),
          ],
        taskSource: _Tasks()..ids = <String>['task-a'],
        gateway: gateway,
      );

      await coordinator.refresh(
        profileId: 'profile',
        today: today,
        nowUtc: now,
      );
      await coordinator.refresh(
        profileId: 'profile',
        today: today,
        nowUtc: now,
      );

      expect(gateway.counts, <int>[2, 2]);
    },
  );
}

PlannerCalendarItem _event({
  required String id,
  required DateTime start,
  PlannerEventState state = PlannerEventState.scheduled,
  bool hasOutcomeReport = false,
}) => PlannerCalendarItem(
  id: id,
  eventId: 'source-$id',
  originalDate: PlannerDate.fromDateTime(start),
  title: id,
  date: PlannerDate.fromDateTime(start),
  timing: PlannerEventTiming.timed,
  state: state,
  requiresReport: true,
  hasOutcomeReport: hasOutcomeReport,
  startUtc: start,
  endUtc: start.add(const Duration(hours: 1)),
);

final class _Events implements CalendarEventRangeSource {
  List<PlannerCalendarItem> items = const <PlannerCalendarItem>[];

  @override
  Future<List<PlannerCalendarItem>> readRange({
    required String profileId,
    required PlannerDate startDate,
    required PlannerDate endDate,
  }) async => items;
}

final class _Tasks implements PlannerBadgeTaskSource {
  List<String> ids = const <String>[];

  @override
  Future<List<String>> readActionableBadgeTasks({
    required String profileId,
    required PlannerDate startDate,
    required PlannerDate endDate,
  }) async => ids;
}

final class _Badge implements LauncherBadgeGateway {
  final List<int> counts = <int>[];

  @override
  Future<void> setCount(int count) async {
    counts.add(count);
  }
}

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/data/drift_weekly_planning_repository.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);

  test('Weekly Planning reads the canonical weekly target and preserves '
      'Events and Tasks', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final clock = _MutableClock(DateTime.utc(2026, 7, 27, 12));
    final timeZones = IanaCalendarEventTimeZones(
      displayTimeZoneId: 'Asia/Manila',
    );
    final reporting = DriftOutcomeReportingRepository(
      database: database,
      clock: clock,
    );
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: timeZones,
      reportSource: reporting,
    );
    final indicators = DriftIndicatorRepository(
      database: database,
      clock: clock,
      calendarEvents: calendar,
    );
    final repository = DriftWeeklyPlanningRepository(
      database: database,
      clock: clock,
      identifiers: _Ids(),
      timeZones: timeZones,
      indicators: indicators,
    );

    await database
        .into(database.plannerTasks)
        .insert(
          PlannerTasksCompanion.insert(
            id: 'task-preserved',
            profileId: profile.id,
            title: 'Prepare applications',
            dueDate: Value<String?>(monday.addDays(2).iso8601),
            requiresReport: const Value<bool>(true),
            createdAtUtc: clock.nowUtc(),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
    await database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'event-preserved',
            profileId: profile.id,
            title: 'Application session',
            timing: 'allDay',
            startDate: monday.addDays(1).iso8601,
            requiresReport: const Value<bool>(true),
            createdAtUtc: clock.nowUtc(),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
    await indicators.saveGoal(
      profileId: profile.id,
      draft: IndicatorGoalRevisionDraft(
        id: '81000000-0000-4000-8000-000000000001',
        operationId: '81000000-0000-4000-8000-000000000002',
        indicatorKey: 'job_applications',
        period: IndicatorGoalPeriod.weekly(monday),
        value: const IndicatorAmount(scaledValue: 2, scale: 0, unit: 'count'),
      ),
    );

    final created = await repository.openOrCreate(
      profileId: profile.id,
      date: monday.addDays(3),
    );
    final jobs = created.indicators.firstWhere(
      (item) => item.indicatorKey == 'job_applications',
    );
    expect(created.period.start, monday);
    expect(jobs.target.isSet, isTrue);
    expect(jobs.target.display, '2');
    expect(created.indicators, hasLength(6));

    await indicators.saveGoal(
      profileId: profile.id,
      draft: IndicatorGoalRevisionDraft(
        id: '81000000-0000-4000-8000-000000000003',
        operationId: '81000000-0000-4000-8000-000000000004',
        indicatorKey: 'job_applications',
        period: IndicatorGoalPeriod.weekly(monday),
        value: const IndicatorAmount(scaledValue: 3, scale: 0, unit: 'count'),
      ),
    );
    final reopened = await repository.openOrCreate(
      profileId: profile.id,
      date: monday,
    );
    expect(reopened.id, created.id);
    expect(
      reopened.indicators
          .firstWhere((item) => item.indicatorKey == 'job_applications')
          .target
          .display,
      '3',
    );
    expect(
      (await database.select(database.plannerTasks).get()).single.id,
      'task-preserved',
    );
    expect(
      (await database.select(database.calendarEvents).get()).single.id,
      'event-preserved',
    );
  });

  test(
    'A1.3: concurrent ensurePeriod calls yield exactly one profile+period row',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final clock = _MutableClock(DateTime.utc(2026, 7, 27, 12));
      final timeZones = IanaCalendarEventTimeZones(
        displayTimeZoneId: 'Asia/Manila',
      );
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: clock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: timeZones,
        reportSource: reporting,
      );
      final indicators = DriftIndicatorRepository(
        database: database,
        clock: clock,
        calendarEvents: calendar,
      );
      final repository = DriftWeeklyPlanningRepository(
        database: database,
        clock: clock,
        identifiers: _Ids(),
        timeZones: timeZones,
        indicators: indicators,
      );

      // Repeated and concurrent lightweight ensures must never create
      // duplicate rows for the same profile + period.
      await Future.wait(<Future<void>>[
        repository.ensurePeriod(
          profileId: profile.id,
          periodStart: monday,
        ),
        repository.ensurePeriod(
          profileId: profile.id,
          periodStart: monday,
        ),
      ]);
      await repository.ensurePeriod(
        profileId: profile.id,
        periodStart: monday,
      );
      await repository.ensurePeriod(
        profileId: profile.id,
        periodStart: monday.addDays(7),
      );

      final rows = await (database.select(database.weeklyPlans)).get();
      expect(rows, hasLength(2));
      final current = rows.where(
        (row) => row.periodStartDate == monday.iso8601,
      );
      expect(current, hasLength(1));

      // The existence check agrees and stays read-only.
      expect(
        await repository.periodExists(
          profileId: profile.id,
          periodStart: monday,
        ),
        isTrue,
      );
      expect(
        await repository.periodExists(
          profileId: profile.id,
          periodStart: monday.addDays(14),
        ),
        isFalse,
      );
    },
  );

  test(
    'Weekly Planning write guard rolls back only its new plan row',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final clock = _MutableClock(DateTime.utc(2026, 7, 27, 12));
      final timeZones = IanaCalendarEventTimeZones(
        displayTimeZoneId: 'Asia/Manila',
      );
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: clock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: timeZones,
        reportSource: reporting,
      );
      final indicators = DriftIndicatorRepository(
        database: database,
        clock: clock,
        calendarEvents: calendar,
      );
      final repository = DriftWeeklyPlanningRepository(
        database: database,
        clock: clock,
        identifiers: _Ids(),
        timeZones: timeZones,
        indicators: indicators,
        writeGuard: const _FailingGuard(),
      );

      await expectLater(
        repository.openOrCreate(profileId: profile.id, date: monday),
        throwsStateError,
      );
      expect(await database.select(database.weeklyPlans).get(), isEmpty);
    },
  );
}

final class _MutableClock implements AppClock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _Ids implements IdentifierSource {
  int _value = 0;

  @override
  String nextUuid() {
    _value += 1;
    return 'weekly-id-$_value';
  }
}

final class _FailingGuard implements WeeklyPlanningWriteGuard {
  const _FailingGuard();

  @override
  Future<void> beforeCommit() async {
    throw StateError('Injected weekly planning write failure');
  }
}

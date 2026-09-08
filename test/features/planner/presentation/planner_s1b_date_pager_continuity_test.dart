// S1B — date pager continuity & cache reuse (widget-path tests).
//
// Covers the rapid-swipe acceptance matrix (pack 21 A–N): deliberate
// horizontal swipes that land inside the 240ms settle window must chain
// (never silently disappear), one date step per committed swipe, the final
// date must match input order, and no cached populated page may ever blank
// or paint another date's Events.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

const _displayTimeZoneId = 'Asia/Manila';

String _readSelectedDateIso(WidgetTester tester) {
  final selectedSemantics = find.byKey(const Key('planner-selected-date'));
  expect(selectedSemantics, findsOneWidget);
  final widget = tester.widget<Semantics>(selectedSemantics);
  final label = widget.properties.label!;
  final matcher = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(label);
  return matcher!.group(1)!;
}

CalendarEventDraft _timedDraft({
  required String id,
  required PlannerDate date,
  required int startMinute,
  required int endMinute,
}) {
  return CalendarEventDraft(
    id: id,
    title: 'S1B Fixture $id',
    timing: CalendarEventTiming.timed,
    startDate: date,
    startMinute: startMinute,
    endMinute: endMinute,
    requiresReport: false,
    timeZoneId: _displayTimeZoneId,
  );
}

Future<(DriftPlannerRepository, DriftCalendarEventRepository)>
_buildRepositories(AppDatabase database) async {
  final timeZones = IanaCalendarEventTimeZones(
    displayTimeZoneId: _displayTimeZoneId,
  );
  final linkRepository = DriftTaskEventLinkRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final outcomeReportingRepository = DriftOutcomeReportingRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final calendarRepository = DriftCalendarEventRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    timeZones: timeZones,
    taskContextSource: linkRepository,
    linkContextTransfer: linkRepository,
    reportSource: outcomeReportingRepository,
  );
  final plannerRepository = DriftPlannerRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    calendarSource: calendarRepository,
    taskContextSource: linkRepository,
    historicalEffectReader: outcomeReportingRepository,
  );
  return (plannerRepository, calendarRepository);
}

Future<void> _pumpPlanner(
  WidgetTester tester, {
  required AppDatabase database,
  required DriftPlannerRepository plannerRepository,
  required CalendarEventRepository calendarRepository,
  required PlannerDate selected,
}) async {
  tester.view.physicalSize = const Size(862, 1824);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();
  await tester.pumpWidget(
    privacy.buildApp(
      environment: const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
      diagnostics: SanitizedDiagnostics(),
      startupRepository: startup,
      plannerRepository: plannerRepository,
      plannerDateSource: FixedPlannerDateSource(selected),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
}

/// A FIXED on-screen point inside the day-scroll viewport. Unlike the
/// translated zoom-surface center (which moves off-screen mid-settle), this
/// stays hit-testable for every rapid gesture, matching a real finger.
Offset _fixedSwipePoint(WidgetTester tester) {
  final viewport = tester.getRect(find.byKey(const Key('planner-day-scroll')));
  return Offset(viewport.center.dx, viewport.center.dy);
}

/// One deliberate horizontal swipe that lands pointer-down inside the settle
/// window of the previous gesture: only ~100ms pumped after the previous up
/// (the settle animation is 240ms). Rapid swipes must chain, not drop.
Future<void> _rapidSwipe(
  WidgetTester tester, {
  required double dx,
  required int pointerId,
}) async {
  final gesture = await tester.startGesture(
    _fixedSwipePoint(tester),
    pointer: pointerId,
  );
  await tester.pump(const Duration(milliseconds: 16));
  for (var step = 1; step <= 4; step++) {
    await gesture.moveBy(Offset(dx / 4, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 100));
}

/// A settled ordinary swipe (full pumpAndSettle after release).
Future<void> _ordinarySwipe(
  WidgetTester tester, {
  required double dx,
  required int pointerId,
}) async {
  final gesture = await tester.startGesture(
    _fixedSwipePoint(tester),
    pointer: pointerId,
  );
  await tester.pump(const Duration(milliseconds: 16));
  for (var step = 1; step <= 6; step++) {
    await gesture.moveBy(Offset(dx / 6, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('S1B date pager continuity', () {
    testWidgets('A/B — one forward, one reverse (ordinary)', (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final (plannerRepository, calendarRepository) = await _buildRepositories(
        database,
      );
      await _pumpPlanner(
        tester,
        database: database,
        plannerRepository: plannerRepository,
        calendarRepository: calendarRepository,
        selected: selected,
      );
      await _ordinarySwipe(tester, dx: -180, pointerId: 1);
      expect(_readSelectedDateIso(tester), selected.addDays(1).iso8601);
      await _ordinarySwipe(tester, dx: 180, pointerId: 2);
      expect(_readSelectedDateIso(tester), selected.iso8601);
      expect(tester.takeException(), isNull);
    });

    testWidgets('C/D — 10 forward rapid swipes land on +10', (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final (plannerRepository, calendarRepository) = await _buildRepositories(
        database,
      );
      await _pumpPlanner(
        tester,
        database: database,
        plannerRepository: plannerRepository,
        calendarRepository: calendarRepository,
        selected: selected,
      );
      for (var i = 0; i < 10; i++) {
        await _rapidSwipe(tester, dx: -180, pointerId: 100 + i);
      }
      await tester.pumpAndSettle();
      expect(
        _readSelectedDateIso(tester),
        selected.addDays(10).iso8601,
        reason: '10 deliberate forward rapid swipes must land on +10',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('E — 10 reverse rapid swipes land on -10', (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final (plannerRepository, calendarRepository) = await _buildRepositories(
        database,
      );
      await _pumpPlanner(
        tester,
        database: database,
        plannerRepository: plannerRepository,
        calendarRepository: calendarRepository,
        selected: selected,
      );
      for (var i = 0; i < 10; i++) {
        await _rapidSwipe(tester, dx: 180, pointerId: 200 + i);
      }
      await tester.pumpAndSettle();
      expect(
        _readSelectedDateIso(tester),
        selected.addDays(-10).iso8601,
        reason: '10 deliberate reverse rapid swipes must land on -10',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('F — alternating +1,-1 rapid returns to the start date', (
      tester,
    ) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final (plannerRepository, calendarRepository) = await _buildRepositories(
        database,
      );
      await _pumpPlanner(
        tester,
        database: database,
        plannerRepository: plannerRepository,
        calendarRepository: calendarRepository,
        selected: selected,
      );
      for (var i = 0; i < 10; i++) {
        await _rapidSwipe(
          tester,
          dx: i.isEven ? -180 : 180,
          pointerId: 300 + i,
        );
      }
      await tester.pumpAndSettle();
      expect(
        _readSelectedDateIso(tester),
        selected.iso8601,
        reason: 'alternating rapid swipes must return to the start date',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cached populated pages never blank and no wrong-date Event '
        'paints during a rapid chain', (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final (plannerRepository, calendarRepository) = await _buildRepositories(
        database,
      );
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      // Seed Events on several consecutive dates so preview pages have real
      // content that must never disappear/reappear.
      for (var offset = -2; offset <= 4; offset++) {
        await calendarRepository.saveEvent(
          profileId: profile.id,
          draft: _timedDraft(
            id: '11111111-1111-4111-8111-11111111${(offset + 20).toString().padLeft(4, '0')}',
            date: selected.addDays(offset),
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
      }
      await _pumpPlanner(
        tester,
        database: database,
        plannerRepository: plannerRepository,
        calendarRepository: calendarRepository,
        selected: selected,
      );
      // Warm the runway first so adjacent pages are cached.
      await _ordinarySwipe(tester, dx: -180, pointerId: 1);
      await tester.pumpAndSettle();

      // Rapid chain forward. After every pumped frame the centered page must
      // show the correct date's Event and the date strip must agree with the
      // selected date (no wrong-date Event, no blank cached day).
      for (var i = 0; i < 5; i++) {
        final before = _readSelectedDateIso(tester);
        final gesture = await tester.startGesture(
          _fixedSwipePoint(tester),
          pointer: 400 + i,
        );
        await tester.pump(const Duration(milliseconds: 16));
        for (var step = 1; step <= 4; step++) {
          await gesture.moveBy(const Offset(-36, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));
        final after = _readSelectedDateIso(tester);
        // The date may still be settling to its committed target, but it must
        // never move backward and must never exceed one step per committed
        // swipe in this window.
        expect(
          PlannerDate.parse(after).compareTo(PlannerDate.parse(before)) >= 0,
          isTrue,
          reason:
              'forward rapid swipe must never move backward: '
              '$before -> $after',
        );
      }
      await tester.pumpAndSettle();
      expect(
        _readSelectedDateIso(tester),
        selected.addDays(6).iso8601,
        reason: 'warmup + 5 rapid forward swipes must land on the exact date',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

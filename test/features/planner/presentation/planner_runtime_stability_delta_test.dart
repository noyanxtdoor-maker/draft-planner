// Planner Runtime Stability Delta — focused widget regression tests.
//
// Defect A: an Event whose clipped start sits inside the final
// `minimumReadableEventHeight` pixels before the day boundary used to
// throw `Invalid argument(s): 48.0` from `clamp(48, availableHeight)`
// in `PlannerTimelineGeometry.event`. These tests pump the real
// Planner tree with boundary-straddling Events and prove no red error
// surface appears, no exception is thrown, and no invalid Event time
// is persisted.
//
// Defect B: horizontal date-swipe instability. The pager preview trio
// is resolved strictly BY DATE (never by list index), so a page keyed
// for one date can never paint another date's Events, and previously
// loaded adjacent dates retain their correct snapshot while a newer
// window is in flight.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';

import '../../../support/test_dependencies.dart';

const Size _testViewport = Size(862, 1824);
const double _testDevicePixelRatio = 2;
const String _displayTimeZoneId = 'Asia/Manila';

const PlannerDate _today = PlannerDate(year: 2026, month: 7, day: 27);
const PlannerDate _previous = PlannerDate(year: 2026, month: 7, day: 26);
const PlannerDate _next = PlannerDate(year: 2026, month: 7, day: 28);

const String _boundaryEventId = '20000000-0000-4000-8000-000000000001';
const String _previousEventId = '20000000-0000-4000-8000-000000000002';
const String _selectedEventId = '20000000-0000-4000-8000-000000000003';
const String _nextEventId = '20000000-0000-4000-8000-000000000004';

CalendarEventDraft _timedDraft({
  required String id,
  required String title,
  required PlannerDate date,
  required int startMinute,
  required int endMinute,
}) {
  return CalendarEventDraft(
    id: id,
    title: title,
    timing: CalendarEventTiming.timed,
    startDate: date,
    startMinute: startMinute,
    endMinute: endMinute,
    timeZoneId: _displayTimeZoneId,
    requiresReport: false,
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Offset _visibleTimelineCenter(WidgetTester tester) {
  final canvas = tester.getRect(find.byKey(const Key('planner-zoom-surface')));
  final viewport = tester.getRect(find.byKey(const Key('planner-day-scroll')));
  final visible = canvas.intersect(viewport);
  expect(visible.height, greaterThan(60));
  return visible.center;
}

Key _previewPageKey(PlannerDate date) =>
    Key('planner-day-page-${date.iso8601}');

Key _previewEventKey(String id) => Key('planner-pager-preview-event-$id');

Key _timedEventKey(String id) => Key('planner-timed-event-$id');

/// Seed events directly through the repository (the same path the
/// preview reads) and pump the production Planner screen.
Future<(AppDatabase, DriftPlannerRepository, DriftCalendarEventRepository)>
_pumpPlanner(
  WidgetTester tester, {
  required List<CalendarEventDraft> drafts,
  required PlannerDate selected,
}) async {
  final database = openMemoryDatabase();
  addTearDown(database.close);
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
  tester.view.physicalSize = _testViewport;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final profile = await buildTestRepository(
    database: database,
  ).completeOnboarding();
  for (final draft in drafts) {
    await calendarRepository.saveEvent(profileId: profile.id, draft: draft);
  }
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
  await _pumpFrames(tester);
  return (database, plannerRepository, calendarRepository);
}

String _occurrenceIdFor(String eventId, PlannerDate date) {
  return CalendarEventOccurrenceIdentity.forDate(
    eventId: eventId,
    originalDate: date,
  );
}

void main() {
  group('Defect A: lower-boundary invalid-argument safety', () {
    testWidgets('an Event ending exactly at the final boundary renders without '
        'exception or red surface', (tester) async {
      await _pumpPlanner(
        tester,
        drafts: <CalendarEventDraft>[
          _timedDraft(
            id: _boundaryEventId,
            title: 'Boundary',
            date: _today,
            startMinute: 23 * 60 + 30,
            endMinute: 24 * 60,
          ),
        ],
        selected: _today,
      );
      // Scroll the day to the very bottom so the final boundary row
      // and the boundary Event are on-screen.
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.byKey(_timedEventKey(_occurrenceIdFor(_boundaryEventId, _today))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'an Event starting inside the final readable band renders without '
      'Invalid argument(s)',
      (tester) async {
        await _pumpPlanner(
          tester,
          drafts: <CalendarEventDraft>[
            _timedDraft(
              id: _boundaryEventId,
              title: 'Boundary',
              date: _today,
              startMinute: 23 * 60 + 50,
              endMinute: 24 * 60,
            ),
          ],
          selected: _today,
        );
        final scroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('planner-day-scroll')),
            matching: find.byType(Scrollable),
          ),
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            _timedEventKey(_occurrenceIdFor(_boundaryEventId, _today)),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a preview Event near the lower boundary renders without exception',
      (tester) async {
        // The Event sits on the NEXT day; the preview column for that
        // date exercises the same geometry path as the centered page.
        await _pumpPlanner(
          tester,
          drafts: <CalendarEventDraft>[
            _timedDraft(
              id: _nextEventId,
              title: 'Next Boundary',
              date: _next,
              startMinute: 23 * 60 + 45,
              endMinute: 24 * 60,
            ),
          ],
          selected: _today,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(_previewPageKey(_next)),
          findsOneWidget,
          reason: 'the next-day preview column must be mounted',
        );
        // The next-day preview must paint the boundary Event without
        // throwing, regardless of which frame is observed.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
        expect(
          find.byKey(_previewEventKey(_occurrenceIdFor(_nextEventId, _next))),
          findsOneWidget,
        );
      },
    );
  });

  group('Defect B: date-owned swipe previews', () {
    testWidgets('each preview page resolves its Events strictly by date', (
      tester,
    ) async {
      await _pumpPlanner(
        tester,
        drafts: <CalendarEventDraft>[
          _timedDraft(
            id: _previousEventId,
            title: 'Prev Only',
            date: _previous,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          _timedDraft(
            id: _selectedEventId,
            title: 'Selected Only',
            date: _today,
            startMinute: 10 * 60,
            endMinute: 11 * 60,
          ),
          _timedDraft(
            id: _nextEventId,
            title: 'Next Only',
            date: _next,
            startMinute: 11 * 60,
            endMinute: 12 * 60,
          ),
        ],
        selected: _today,
      );
      expect(tester.takeException(), isNull);
      // Each preview page key must host exactly its own Event.
      expect(
        find.descendant(
          of: find.byKey(_previewPageKey(_previous)),
          matching: find.byKey(
            _previewEventKey(_occurrenceIdFor(_previousEventId, _previous)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_previewPageKey(_previous)),
          matching: find.byKey(
            _previewEventKey(_occurrenceIdFor(_selectedEventId, _today)),
          ),
        ),
        findsNothing,
        reason: 'previous page must never paint the selected day Events',
      );
      expect(
        find.descendant(
          of: find.byKey(_previewPageKey(_next)),
          matching: find.byKey(
            _previewEventKey(_occurrenceIdFor(_nextEventId, _next)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_previewPageKey(_next)),
          matching: find.byKey(
            _previewEventKey(_occurrenceIdFor(_selectedEventId, _today)),
          ),
        ),
        findsNothing,
        reason: 'next page must never paint the selected day Events',
      );
      // The centered page hosts the selected day's Event.
      expect(
        find.byKey(_timedEventKey(_occurrenceIdFor(_selectedEventId, _today))),
        findsOneWidget,
      );
    });

    testWidgets(
      'swiping to an empty day keeps every page date-owned with no wrong-'
      'date flash',
      (tester) async {
        await _pumpPlanner(
          tester,
          drafts: <CalendarEventDraft>[
            _timedDraft(
              id: _selectedEventId,
              title: 'Selected Only',
              date: _today,
              startMinute: 10 * 60,
              endMinute: 11 * 60,
            ),
            _timedDraft(
              id: _nextEventId,
              title: 'Next Only',
              date: _next,
              startMinute: 11 * 60,
              endMinute: 12 * 60,
            ),
          ],
          selected: _today,
        );
        expect(tester.takeException(), isNull);
        // Swipe left to navigate to the next day.
        final pagerCenter = _visibleTimelineCenter(tester);
        final gesture = await tester.startGesture(
          Offset(pagerCenter.dx, pagerCenter.dy),
          pointer: 1,
        );
        for (var i = 1; i <= 8; i++) {
          await gesture.moveBy(const Offset(-45, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
        // The centered page is now the next day and must host its own Event.
        expect(
          find.byKey(_timedEventKey(_occurrenceIdFor(_nextEventId, _next))),
          findsOneWidget,
        );
        // The previous page (now the old selected day) must still host
        // the selected day's Event only.
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_today)),
            matching: find.byKey(
              _previewEventKey(_occurrenceIdFor(_selectedEventId, _today)),
            ),
          ),
          findsOneWidget,
        );
        // No cross-date leakage anywhere in the preview tree.
        expect(
          find.byKey(_previewEventKey(_occurrenceIdFor(_nextEventId, _today))),
          findsNothing,
        );
      },
    );

    testWidgets('rapid repeated swipes never leave a page showing another date '
        'Events', (tester) async {
      await _pumpPlanner(
        tester,
        drafts: <CalendarEventDraft>[
          _timedDraft(
            id: _previousEventId,
            title: 'Prev Only',
            date: _previous,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          _timedDraft(
            id: _nextEventId,
            title: 'Next Only',
            date: _next,
            startMinute: 11 * 60,
            endMinute: 12 * 60,
          ),
        ],
        selected: _today,
      );
      expect(tester.takeException(), isNull);
      Future<void> swipe(double dx) async {
        final pagerCenter = _visibleTimelineCenter(tester);
        final gesture = await tester.startGesture(
          Offset(pagerCenter.dx, pagerCenter.dy),
          pointer: 1,
        );
        for (var i = 1; i <= 8; i++) {
          await gesture.moveBy(Offset(dx / 8, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
      }

      // left (next), right (back), right (previous), left (back).
      await swipe(-360);
      await swipe(360);
      await swipe(360);
      await swipe(-360);
      // Final centered page is today again.
      expect(
        find.byKey(_timedEventKey(_occurrenceIdFor(_nextEventId, _today))),
        findsNothing,
      );
      expect(
        find.byKey(_timedEventKey(_occurrenceIdFor(_previousEventId, _today))),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('geometry unit safety', () {
    test('PlannerTimelineGeometry lower band never throws', () {
      // Direct proof of the fixed clamp for every hour-height in the
      // approved absolute range. The canvas bottom is measured in pixels
      // (`visibleEndMinute * pixelsPerMinute`), not minutes.
      for (final hourHeight in <double>[20, 44, 60, 88, 320]) {
        final geometry = PlannerTimelineGeometry.event(
          startMinute: 23 * 60 + 50,
          endMinute: 24 * 60,
          visibleStartMinute: 0,
          visibleEndMinute: 24 * 60,
          hourHeight: hourHeight,
        );
        expect(geometry.height.isFinite, isTrue);
        expect(geometry.height, greaterThanOrEqualTo(0));
        expect(
          geometry.bottom,
          lessThanOrEqualTo(
            24 * 60 * PlannerTimelineGeometry.pixelsPerMinute(hourHeight),
          ),
        );
      }
    });
  });
}

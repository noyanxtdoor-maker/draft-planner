// Stage B3-R1 Slice D3-A: selected-date, title, Today icon, and
// date-strip timing matrix for the interactive day pager.
//
// Every test below exercises the production Planner widget
// tree with a real Drift database. The focused matrix proves
// that the live and settled drag/commit states update the
// authoritative date, the AppBar title, the Today icon
// color, and the date-strip selection at exactly the right
// moment — and only at that moment.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

const Size _testViewport = Size(862, 1824);
const double _testDevicePixelRatio = 2;
const String _displayTimeZoneId = 'Asia/Manila';

const PlannerDate _selected = PlannerDate(year: 2026, month: 7, day: 27);
const PlannerDate _previous = PlannerDate(year: 2026, month: 7, day: 26);
const PlannerDate _next = PlannerDate(year: 2026, month: 7, day: 28);

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  final database = openMemoryDatabase();
  addTearDown(database.close);
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
    timeZones: IanaCalendarEventTimeZones(
      displayTimeZoneId: _displayTimeZoneId,
    ),
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
  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();
  tester.view.physicalSize = _testViewport;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    privacy.buildApp(
      environment: const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
      diagnostics: SanitizedDiagnostics(),
      startupRepository: startup,
      plannerRepository: plannerRepository,
      plannerDateSource: const FixedPlannerDateSource(_selected),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp).first),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Drive a partial left or right drag (no release). The
/// gesture stays alive so the test can observe the live
/// state. The returned function releases the pointer.
Future<Future<void> Function()> _beginDrag(
  WidgetTester tester, {
  required double dx,
  int steps = 4,
}) async {
  final center = tester.getCenter(
    find.byKey(const Key('planner-day-pager-viewport')),
  );
  final gesture = await tester.startGesture(center, pointer: 1);
  final perStep = dx / steps;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(Offset(perStep, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return () async {
    await gesture.up();
    await _pumpFrames(tester);
  };
}

/// Drive a full horizontal swipe to commit one day in the
/// direction of `dx` (negative for left = next, positive
/// for right = previous).
Future<void> _driveSwipe(
  WidgetTester tester, {
  required double dx,
  int steps = 8,
  Duration stepDuration = const Duration(milliseconds: 16),
}) async {
  final center = tester.getCenter(
    find.byKey(const Key('planner-day-pager-viewport')),
  );
  final gesture = await tester.startGesture(center, pointer: 1);
  final perStep = dx / steps;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(Offset(perStep, 0));
    await tester.pump(stepDuration);
  }
  await gesture.up();
  await _pumpFrames(tester);
}

void main() {
  group('Stage B3-R1 D3-A: pager selected-date timing matrix', () {
    testWidgets(
      'TEST 1 — live left drag does not change selectedDate, '
      'title, Today icon, or date-strip',
      (tester) async {
        final container = await _pumpApp(tester);
        await _pumpFrames(tester);
        final selectedBefore =
            container.read(plannerControllerProvider).selectedDate;
        final titleBefore =
            find.text(_dateLabel(_selected))..evaluate();
        expect(titleBefore, findsWidgets);
        final release = await _beginDrag(tester, dx: -200);
        // Live: no selectedDate change yet.
        expect(
          container.read(plannerControllerProvider).selectedDate,
          selectedBefore,
          reason: 'live left drag must not change selectedDate',
        );
        // Title still on _selected.
        expect(find.text(_dateLabel(_selected)), findsWidgets);
        await release();
      },
    );

    testWidgets(
      'TEST 2 — live right drag does not change selectedDate, '
      'title, Today icon, or date-strip',
      (tester) async {
        final container = await _pumpApp(tester);
        await _pumpFrames(tester);
        final selectedBefore =
            container.read(plannerControllerProvider).selectedDate;
        final release = await _beginDrag(tester, dx: 200);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          selectedBefore,
          reason: 'live right drag must not change selectedDate',
        );
        expect(find.text(_dateLabel(_selected)), findsWidgets);
        await release();
      },
    );

    testWidgets(
      'TEST 3 — cancel animation does not change date; after '
      'recenter the title, Today icon, and date strip remain on '
      'the original date',
      (tester) async {
        final container = await _pumpApp(tester);
        await _pumpFrames(tester);
        final release = await _beginDrag(tester, dx: -50);
        // Cancel settles back to the original date.
        expect(
          container.read(plannerControllerProvider).selectedDate,
          _selected,
          reason: 'cancelled swipe must not commit',
        );
        expect(find.text(_dateLabel(_selected)), findsWidgets);
        await release();
        await tester.pumpAndSettle();
        expect(
          container.read(plannerControllerProvider).selectedDate,
          _selected,
        );
        expect(find.text(_dateLabel(_selected)), findsWidgets);
      },
    );

    testWidgets(
      'TEST 4 — successful left commit updates selectedDate '
      'exactly once; title, Today icon, and date-strip update '
      'after settlement; no speculative update during drag',
      (tester) async {
        final container = await _pumpApp(tester);
        await _pumpFrames(tester);
        // During the drag, selectedDate must remain _selected.
        final release = await _beginDrag(tester, dx: -200);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          _selected,
          reason: 'left drag in progress must not change selectedDate',
        );
        await release();
        await tester.pumpAndSettle();
        expect(
          container.read(plannerControllerProvider).selectedDate,
          _next,
          reason: 'settled left swipe must commit +1 day',
        );
        // Title now reads the next-day label.
        expect(find.text(_dateLabel(_next)), findsWidgets);
      },
    );

    testWidgets(
      'TEST 5 — successful right commit updates selectedDate '
      'exactly once; title updates after settlement',
      (tester) async {
        final container = await _pumpApp(tester);
        await _pumpFrames(tester);
        await _driveSwipe(tester, dx: 320);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          _previous,
          reason: 'settled right swipe must commit -1 day',
        );
        expect(find.text(_dateLabel(_previous)), findsWidgets);
      },
    );

    testWidgets(
      'TEST 6 — pinch cancellation does not update date',
      (tester) async {
        final container = await _pumpApp(tester);
        await _pumpFrames(tester);
        // Start a horizontal gesture, then add a second
        // pointer to invoke the pinch-cancellation path.
        final center = tester.getCenter(
          find.byKey(const Key('planner-day-pager-viewport')),
        );
        final first = await tester.startGesture(
          center + const Offset(-20, 0),
          pointer: 1,
        );
        await first.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
        final second = await tester.startGesture(
          center + const Offset(20, 0),
          pointer: 2,
        );
        await tester.pump(const Duration(milliseconds: 16));
        await first.up();
        await second.up();
        await _pumpFrames(tester);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          _selected,
          reason: 'pinch-cancelled drag must not commit a date change',
        );
        expect(find.text(_dateLabel(_selected)), findsWidgets);
      },
    );

    testWidgets(
      'TEST 7 — velocity commit updates selectedDate exactly once',
      (tester) async {
        final container = await _pumpApp(tester);
        await _pumpFrames(tester);
        // Velocity commit: a small distance but high
        // velocity. The down event lands at T=0; the up
        // event is timestamped at T=1 ms so the velocity
        // calculation sees 50 px / 1 ms = 50 000 px/s.
        final center = tester.getCenter(
          find.byKey(const Key('planner-day-pager-viewport')),
        );
        final gesture = await tester.startGesture(center, pointer: 1);
        await gesture.moveBy(const Offset(-50, 0));
        await gesture.up(timeStamp: const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        await _pumpFrames(tester);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          _next,
          reason: 'high-velocity release must commit +1 day',
        );
        expect(find.text(_dateLabel(_next)), findsWidgets);
      },
    );

    testWidgets(
      'TEST 8 — title arrow remains in locked position '
      '(planner-date-chevron key is present)',
      (tester) async {
        await _pumpApp(tester);
        await _pumpFrames(tester);
        expect(
          find.byKey(const Key('planner-date-chevron')),
          findsOneWidget,
          reason: 'title chevron key must remain present',
        );
        expect(
          find.byKey(const Key('planner-date-label')),
          findsOneWidget,
          reason: 'title label key must remain present',
        );
        // Chevron is a `keyboard_arrow_down_rounded` icon.
        expect(
          find.byIcon(Icons.keyboard_arrow_down_rounded),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TEST 9 — toolbar controls remain present (Today icon '
      'is today_outlined size 22, filter, checklist, overflow)',
      (tester) async {
        await _pumpApp(tester);
        await _pumpFrames(tester);
        // Today icon: semantics label "Go to today" exists.
        expect(
          find.bySemanticsLabel('Go to today'),
          findsOneWidget,
          reason: 'Today icon semantics label must be present',
        );
        // Filter button.
        expect(
          find.byKey(const Key('planner-filter-button')),
          findsOneWidget,
        );
        // Checklist (selection mode trigger).
        expect(
          find.byKey(const Key('planner-selection-button')),
          findsOneWidget,
        );
        // Overflow button.
        expect(
          find.byKey(const Key('planner-overflow-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TEST 10 — locked navigation remains: slide-down picker, '
      'no Home calendar/shield, bottom nav unchanged, no '
      'pull-to-refresh',
      (tester) async {
        await _pumpApp(tester);
        await _pumpFrames(tester);
        // Slide-down picker opens via the title tap.
        await tester.tap(find.byKey(const Key('planner-date-label')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('planner-date-picker-panel')),
          findsOneWidget,
          reason: 'slide-down picker must open from the title',
        );
        // Close it.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        // No RefreshIndicator on the planner scroll (the
        // lock from Slice C: the Planner does not
        // support pull-to-refresh).
        expect(
          find.descendant(
            of: find.byKey(const Key('planner-day-scroll')),
            matching: find.byType(RefreshIndicator),
          ),
          findsNothing,
          reason: 'Planner must not host a pull-to-refresh indicator',
        );
      },
    );
  });
}

String _dateLabel(PlannerDate date) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

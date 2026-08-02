// Stage B3-R1 Slice D3-A2: interaction-safety tests for the
// interactive day pager.
//
// Every test here exercises the production Planner widget tree
// with a real Drift database. Adjacent pages are off-screen at
// rest; the tests drive a partial horizontal swipe (or a real
// settling animation) so that an adjacent preview column is
// actually visible before any interaction is attempted.
//
// The production code is already known to wrap every preview
// event block in `IgnorePointer` and to render the empty preview
// surface without any active gesture handlers. These tests prove
// that contract from the outside: an attempted tap on a visible
// preview event, an attempted long-press move, an attempted
// resize, and an attempted empty-time tap must NOT open a route,
// fire a database mutation, or consume an operation identifier.
//
// Database table assertions compare Drift row counts before and
// after every destructive-attempt scenario across:
//
//   - calendarEvents
//   - calendarEventExceptions
//   - calendarEventOperations
//   - outcomeReports
//   - plannerTasks
//   - taskEventLinks
//   - activityLedgerEntries
//
// No Actual or contribution record may be created and no
// operation identifier may be consumed during any blocked
// scenario.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart' as db;
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

const _displayTimeZoneId = 'Asia/Manila';

const _previous = PlannerDate(year: 2026, month: 7, day: 26);
const _selected = PlannerDate(year: 2026, month: 7, day: 27);
const _next = PlannerDate(year: 2026, month: 7, day: 28);

const _previousEventId = 'aaaa1111-aaaa-4aaa-8aaa-aaaa1111aaaa';
const _selectedEventId = 'bbbb2222-bbbb-4bbb-8bbb-bbbb2222bbbb';
const _nextEventId = 'cccc3333-cccc-4ccc-8ccc-cccc3333cccc';

// The Planner renders Calendar Events by their OCCURRENCE id
// (a UUID v5 derived from eventId + originalDate). Both the
// centered timeline and the adjacent preview column use this
// same id, so every test below must look the occurrence id up
// from the planner domain helper rather than reusing the
// CalendarEvent row id directly.
String _occurrenceId(String eventId, PlannerDate date) {
  return CalendarEventOccurrenceIdentity.forDate(
    eventId: eventId,
    originalDate: date,
  );
}

CalendarEventDraft _draft({
  required String id,
  required PlannerDate date,
  int startMinute = 9 * 60,
  int endMinute = 11 * 60,
}) {
  return CalendarEventDraft(
    id: id,
    title: 'Safety fixture $id',
    timing: CalendarEventTiming.timed,
    startDate: date,
    startMinute: startMinute,
    endMinute: endMinute,
    requiresReport: false,
    timeZoneId: _displayTimeZoneId,
  );
}

class _SafetyHarness {
  _SafetyHarness({
    required this.database,
    required this.plannerRepository,
    required this.calendarRepository,
  });

  final db.AppDatabase database;
  final DriftPlannerRepository plannerRepository;
  final DriftCalendarEventRepository calendarRepository;

  Future<void> seedEvents() async {
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    await calendarRepository.saveEvent(
      profileId: profile.id,
      draft: _draft(id: _previousEventId, date: _previous),
    );
    await calendarRepository.saveEvent(
      profileId: profile.id,
      draft: _draft(id: _selectedEventId, date: _selected),
    );
    await calendarRepository.saveEvent(
      profileId: profile.id,
      draft: _draft(id: _nextEventId, date: _next),
    );
  }

  Future<int> _count(String table) async {
    switch (table) {
      case 'calendar_events':
        return (await database.select(database.calendarEvents).get()).length;
      case 'calendar_event_exceptions':
        return (await database.select(database.calendarEventExceptions).get())
            .length;
      case 'calendar_event_operations':
        return (await database.select(database.calendarEventOperations).get())
            .length;
      case 'outcome_reports':
        return (await database.select(database.outcomeReports).get()).length;
      case 'planner_tasks':
        return (await database.select(database.plannerTasks).get()).length;
      case 'task_event_links':
        return (await database.select(database.taskEventLinks).get()).length;
      case 'activity_ledger_entries':
        return (await database.select(database.activityLedgerEntries).get())
            .length;
    }
    throw StateError('unknown table $table');
  }

  Future<Map<String, int>> snapshotCounts() async {
    return <String, int>{
      'calendar_events': await _count('calendar_events'),
      'calendar_event_exceptions': await _count('calendar_event_exceptions'),
      'calendar_event_operations': await _count('calendar_event_operations'),
      'outcome_reports': await _count('outcome_reports'),
      'planner_tasks': await _count('planner_tasks'),
      'task_event_links': await _count('task_event_links'),
      'activity_ledger_entries': await _count('activity_ledger_entries'),
    };
  }

  /// Return the latest operation `createdAtUtc`. The repository
  /// emits a fresh id every time it persists an Event or accepts
  /// a destructive operation. If a destructive attempt is
  /// silently accepted during a blocked scenario, this timestamp
  /// advances and the comparison will fire.
  Future<DateTime?> latestOperationTimestamp() async {
    final rows = await database.select(database.calendarEventOperations).get();
    if (rows.isEmpty) return null;
    DateTime latest = rows.first.createdAtUtc;
    for (final row in rows.skip(1)) {
      if (row.createdAtUtc.isAfter(latest)) {
        latest = row.createdAtUtc;
      }
    }
    return latest;
  }

  Future<Map<String, int>> actualAndContributionSnapshot() async {
    // Actual = outcome_reports; Contribution =
    // activity_ledger_entries. These two specifically cover the
    // no-Actual-row and no-contribution-row invariants from the
    // prompt.
    final actuals =
        (await database.select(database.outcomeReports).get()).length;
    final contributions =
        (await database.select(database.activityLedgerEntries).get()).length;
    return <String, int>{'actuals': actuals, 'contributions': contributions};
  }
}

_SafetyHarness _buildHarness() {
  final database = openMemoryDatabase();
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
  return _SafetyHarness(
    database: database,
    plannerRepository: plannerRepository,
    calendarRepository: calendarRepository,
  );
}

Future<void> _pumpPlannerWithSeededEvents(
  WidgetTester tester, {
  required _SafetyHarness harness,
}) async {
  await harness.seedEvents();
  tester.view.physicalSize = const Size(862, 1824);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final privacy = TestPrivacyDependencies(database: harness.database);
  final startup = buildTestRepository(
    database: harness.database,
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
      plannerRepository: harness.plannerRepository,
      plannerDateSource: const FixedPlannerDateSource(_selected),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
  // Settle the preview FutureBuilder for the previous/next trio.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

/// Begin a partial horizontal drag (no release). The pager
/// remains in the live-drag state with the adjacent preview
/// column partially visible. Returns the live gesture handle.
Future<TestGesture> _beginPartialDrag(
  WidgetTester tester, {
  required double dx,
  int steps = 6,
}) async {
  final pagerCenter = tester.getCenter(
    find.byKey(const Key('planner-day-pager-viewport')),
  );
  final gesture = await tester.startGesture(pagerCenter, pointer: 1);
  final perStep = dx / steps;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(Offset(perStep, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

/// Advance the frame pump without releasing the gesture. Used
/// while a live drag is mid-flight so the production tree
/// resolves any pending layout before we attempt an interaction.
Future<void> _pumpWhileLiveDrag(WidgetTester tester, {int frames = 4}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Read the visible rectangle of the preview event block for
/// the next day. Returns `null` when the preview block is not
/// in the widget tree.
Rect? _previewEventRect(WidgetTester tester) {
  final blockFinder = find.byKey(
    Key('planner-pager-preview-event-${_occurrenceId(_nextEventId, _next)}'),
  );
  if (blockFinder.evaluate().isEmpty) return null;
  return tester.getRect(blockFinder);
}

/// Read the visible rectangle of the centered event block for
/// the currently selected date.
Rect _centeredEventRect(WidgetTester tester) {
  return tester.getRect(
    find.byKey(
      Key('planner-timed-event-${_occurrenceId(_selectedEventId, _selected)}'),
    ),
  );
}

void main() {
  group('Stage B3-R1 D3-A2: interactive pager interaction-safety', () {
    testWidgets('TEST 1 — adjacent visible Event tap is blocked', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final beforeCounts = await harness.snapshotCounts();
      final beforeOps = await harness.latestOperationTimestamp();
      final beforeActual = await harness.actualAndContributionSnapshot();
      expect(
        find.byKey(
          Key(
            'planner-pager-preview-event-${_occurrenceId(_nextEventId, _next)}',
          ),
        ),
        findsOneWidget,
        reason: 'next-day preview Event must be rendered',
      );
      // Begin a left drag far enough to expose the next
      // preview column, then keep the gesture held.
      final gesture = await _beginPartialDrag(tester, dx: -200);
      await _pumpWhileLiveDrag(tester);
      final previewRect = _previewEventRect(tester);
      expect(
        previewRect,
        isNotNull,
        reason: 'next preview Event must be visible during a partial drag',
      );
      // Tap on the visible portion of the preview Event.
      await tester.tapAt(previewRect!.center);
      await tester.pump();
      await _pumpWhileLiveDrag(tester);
      // No Event detail screen has been pushed.
      expect(
        find.text('No active Event Types are available.'),
        findsNothing,
        reason: 'no Event Type picker may open from a preview tap',
      );
      expect(tester.takeException(), isNull);
      // selectedDate must NOT have changed mid-drag.
      // The selected-date strip button is a Semantics widget
      // whose label embeds the ISO date.
      final semantics = tester.getSemantics(
        find.byKey(const Key('planner-selected-date')),
      );
      expect(
        semantics.label,
        contains('2026-07-27'),
        reason: 'partial drag must not commit a date change',
      );
      // Release the gesture so the test can complete cleanly.
      await gesture.up();
      await tester.pumpAndSettle();
      // No DB mutation, no operation consumption.
      final afterCounts = await harness.snapshotCounts();
      expect(
        afterCounts,
        beforeCounts,
        reason: 'blocked adjacent Event tap must not touch any Drift table',
      );
      final afterOps = await harness.latestOperationTimestamp();
      expect(
        afterOps,
        beforeOps,
        reason: 'no operation identifier may be consumed',
      );
      final afterActual = await harness.actualAndContributionSnapshot();
      expect(
        afterActual,
        beforeActual,
        reason: 'no Actual or contribution record may be created',
      );
    });

    testWidgets('TEST 2 — adjacent visible Event move is blocked', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final beforeCounts = await harness.snapshotCounts();
      final beforeOps = await harness.latestOperationTimestamp();
      final gesture = await _beginPartialDrag(tester, dx: -220);
      await _pumpWhileLiveDrag(tester);
      final previewRect = _previewEventRect(tester);
      expect(previewRect, isNotNull);
      // While the live drag is still held, attempt a vertical
      // move gesture over the preview event block. The preview
      // subtree has no move handler.
      final moveStart = previewRect!.center;
      final moveGesture = await tester.startGesture(moveStart, pointer: 3);
      await moveGesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await moveGesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await moveGesture.up();
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final calendarEvent =
          (await harness.database.select(harness.database.calendarEvents).get())
              .firstWhere((row) => row.id == _nextEventId);
      expect(
        calendarEvent.startMinute,
        9 * 60,
        reason: 'preview Event start minute must not have moved',
      );
      expect(
        calendarEvent.endMinute,
        11 * 60,
        reason: 'preview Event end minute must not have moved',
      );
      final afterCounts = await harness.snapshotCounts();
      expect(afterCounts, beforeCounts);
      final afterOps = await harness.latestOperationTimestamp();
      expect(afterOps, beforeOps);
    });

    testWidgets('TEST 3 — adjacent visible Event resize is blocked', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final beforeCounts = await harness.snapshotCounts();
      final beforeOps = await harness.latestOperationTimestamp();
      final gesture = await _beginPartialDrag(tester, dx: -220);
      await _pumpWhileLiveDrag(tester);
      final previewRect = _previewEventRect(tester);
      expect(previewRect, isNotNull);
      // Attempt a downward resize drag from the bottom edge of
      // the visible preview Event. The preview subtree has no
      // resize handler.
      final resizeStart = Offset(
        previewRect!.center.dx,
        previewRect.bottom - 4,
      );
      final resizeGesture = await tester.startGesture(resizeStart, pointer: 4);
      await resizeGesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await resizeGesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await resizeGesture.up();
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final calendarEvent =
          (await harness.database.select(harness.database.calendarEvents).get())
              .firstWhere((row) => row.id == _nextEventId);
      expect(
        calendarEvent.endMinute,
        11 * 60,
        reason: 'preview Event end minute must not have resized',
      );
      final afterCounts = await harness.snapshotCounts();
      expect(afterCounts, beforeCounts);
      final afterOps = await harness.latestOperationTimestamp();
      expect(afterOps, beforeOps);
    });

    testWidgets('TEST 4 — adjacent visible empty-time creation is blocked', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final beforeCounts = await harness.snapshotCounts();
      final beforeOps = await harness.latestOperationTimestamp();
      final gesture = await _beginPartialDrag(tester, dx: -240);
      await _pumpWhileLiveDrag(tester);
      final previewColumn = find.byKey(
        Key('planner-day-page-${_next.iso8601}'),
      );
      final columnRect = tester.getRect(previewColumn);
      final previewRect = _previewEventRect(tester);
      expect(previewRect, isNotNull);
      // Tap well above the preview Event (within the preview
      // column's visible area, but not on the Event block).
      final emptySpot = Offset(
        columnRect.left + columnRect.width * 0.7,
        // ~5 % from the top of the visible preview column —
        // well above the 09:00 preview Event which sits at
        // roughly 20 % from the top of the visible hour
        // window.
        columnRect.top + columnRect.height * 0.05,
      );
      expect(
        emptySpot.dy < previewRect!.top,
        isTrue,
        reason:
            'the chosen tap target must lie above the visible preview Event',
      );
      await tester.tapAt(emptySpot);
      await tester.pump();
      await _pumpWhileLiveDrag(tester);
      expect(tester.takeException(), isNull);
      // No Event Type picker or editor must be on screen.
      expect(
        find.text('No active Event Types are available.'),
        findsNothing,
        reason: 'no Event Type picker must open from a preview tap',
      );
      expect(
        find.text('Recommended'),
        findsNothing,
        reason: 'no recommended badge may be rendered from a preview tap',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      final afterCounts = await harness.snapshotCounts();
      expect(
        afterCounts,
        beforeCounts,
        reason: 'blocked empty-tap must not create any new Drift rows',
      );
      final afterOps = await harness.latestOperationTimestamp();
      expect(afterOps, beforeOps);
    });

    testWidgets('TEST 5 — centered-page interaction is blocked during '
        'live drag', (tester) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final beforeCounts = await harness.snapshotCounts();
      final beforeOps = await harness.latestOperationTimestamp();
      final gesture = await _beginPartialDrag(tester, dx: -120);
      await _pumpWhileLiveDrag(tester);
      final centeredRect = _centeredEventRect(tester);
      await tester.tapAt(centeredRect.center);
      await tester.pump();
      await _pumpWhileLiveDrag(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('No active Event Types are available.'),
        findsNothing,
        reason: 'no Event Type picker may open mid-drag',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      final afterCounts = await harness.snapshotCounts();
      expect(
        afterCounts,
        beforeCounts,
        reason:
            'centered-page interaction during live drag must not '
            'mutate any Drift table',
      );
      final afterOps = await harness.latestOperationTimestamp();
      expect(afterOps, beforeOps);
    });

    testWidgets('TEST 6 — interaction is blocked during settlement', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final beforeCounts = await harness.snapshotCounts();
      final beforeOps = await harness.latestOperationTimestamp();
      final pagerCenter = tester.getCenter(
        find.byKey(const Key('planner-day-pager-viewport')),
      );
      final gesture = await tester.startGesture(pagerCenter, pointer: 1);
      const dx = -260.0;
      const steps = 6;
      final perStep = dx / steps;
      for (var i = 1; i <= steps; i++) {
        await gesture.moveBy(Offset(perStep, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      // Pump less than the 240 ms settlement duration so we are
      // still mid-animation.
      await tester.pump(const Duration(milliseconds: 80));
      final previewRect = _previewEventRect(tester);
      if (previewRect != null) {
        await tester.tapAt(previewRect.center);
      } else {
        final centered = find.byKey(
          Key('planner-timed-event-${_occurrenceId(_nextEventId, _next)}'),
        );
        if (centered.evaluate().isNotEmpty) {
          await tester.tapAt(tester.getCenter(centered));
        }
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      final afterCounts = await harness.snapshotCounts();
      expect(
        afterCounts,
        beforeCounts,
        reason:
            'interaction during settlement must not mutate any Drift '
            'table (a legitimate commit may bump rows during '
            'pumpAndSettle, but settlement must NOT have done so '
            'before we sampled)',
      );
      final afterOps = await harness.latestOperationTimestamp();
      // The commit may have advanced the operation sequence
      // exactly once via the commit pipeline. What matters is
      // that the mid-settlement tap did not add a SECOND
      // operation.
      if (beforeOps != null && afterOps != null) {
        expect(
          afterOps.isAfter(beforeOps),
          isTrue,
          reason:
              'a legitimate commit must consume at least one '
              'operation id (so the comparison is meaningful)',
        );
        expect(
          afterOps.difference(beforeOps).inSeconds < 5,
          isTrue,
          reason:
              'mid-settlement tap must not cause a large gap in '
              'operation timestamps',
        );
      }
    });

    testWidgets('TEST 7 — cancelled drag does not release a delayed tap', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final beforeCounts = await harness.snapshotCounts();
      final beforeOps = await harness.latestOperationTimestamp();
      final centeredRect = _centeredEventRect(tester);
      final gesture = await tester.startGesture(
        centeredRect.center,
        pointer: 1,
      );
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      for (var i = 0; i < 18; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(
        find.text('No active Event Types are available.'),
        findsNothing,
        reason:
            'no Event Type picker may open from a cancelled drag '
            'over an Event',
      );
      final afterCounts = await harness.snapshotCounts();
      expect(
        afterCounts,
        beforeCounts,
        reason: 'cancelled drag must not cause any Drift mutation',
      );
      final afterOps = await harness.latestOperationTimestamp();
      expect(
        afterOps,
        beforeOps,
        reason: 'no operation identifier may be consumed by a cancel',
      );
    });

    testWidgets('TEST 8 — interaction is restored after cancel', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final pagerCenter = tester.getCenter(
        find.byKey(const Key('planner-day-pager-viewport')),
      );
      final swipe = await tester.startGesture(pagerCenter, pointer: 1);
      await swipe.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await swipe.up();
      await tester.pumpAndSettle();
      final centeredRect = _centeredEventRect(tester);
      await tester.tapAt(centeredRect.center);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('event-detail-title')),
        findsOneWidget,
        reason: 'centered Event detail must open after a cancelled swipe',
      );
      await tester.tap(find.byKey(const Key('event-status-control')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('event-status-option-scheduled')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-status-option-completedHappened')),
        findsOneWidget,
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Did Not Attempt'), findsOneWidget);
      expect(find.text('Did Not Attend'), findsNothing);
      expect(find.text('Did Not Happen'), findsNothing);
      await tester.tap(find.byKey(const Key('event-status-option-scheduled')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('event-detail-sheet-edit-icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-detail-sheet-overflow-icon')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('event-detail-title')), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      for (final removedAction in <String>[
        'Link or manage Tasks',
        'Edit',
        'Reschedule',
        'Cancel',
        'Open Report',
        'View Activity History',
      ]) {
        expect(find.text(removedAction), findsNothing, reason: removedAction);
      }

      await tester.tap(
        find.byKey(const Key('event-detail-sheet-overflow-icon')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-overflow-duplicate')), findsOneWidget);
      expect(find.byKey(const Key('event-overflow-delete')), findsOneWidget);
      expect(find.byKey(const Key('event-overflow-change-type')), findsNothing);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('event-detail-sheet-overflow-icon')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-overflow-delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-delete-event')), findsOneWidget);
      await tester.tap(find.text('Keep Event'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-detail-title')), findsOneWidget);
    });

    testWidgets('TEST 9 — interaction is restored after commit', (
      tester,
    ) async {
      final harness = _buildHarness();
      addTearDown(harness.database.close);
      await _pumpPlannerWithSeededEvents(tester, harness: harness);
      final pagerCenter = tester.getCenter(
        find.byKey(const Key('planner-day-pager-viewport')),
      );
      final swipe = await tester.startGesture(pagerCenter, pointer: 1);
      const dx = -260.0;
      const steps = 6;
      final perStep = dx / steps;
      for (var i = 1; i <= steps; i++) {
        await swipe.moveBy(Offset(perStep, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await swipe.up();
      await tester.pumpAndSettle();
      final blockFinder = find.byKey(
        Key('planner-timed-event-${_occurrenceId(_nextEventId, _next)}'),
      );
      expect(
        blockFinder,
        findsOneWidget,
        reason: 'the previously next-day Event must be centered after commit',
      );
      final blockRect = tester.getRect(blockFinder);
      await tester.tapAt(blockRect.center);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('event-detail-title')),
        findsOneWidget,
        reason:
            'newly-centered Event detail must open after a successful '
            'commit',
      );
    });

    testWidgets(
      'TEST 10 — second pointer cancels paging without Event action',
      (tester) async {
        final harness = _buildHarness();
        addTearDown(harness.database.close);
        await _pumpPlannerWithSeededEvents(tester, harness: harness);
        final beforeCounts = await harness.snapshotCounts();
        final beforeOps = await harness.latestOperationTimestamp();
        final beforeActual = await harness.actualAndContributionSnapshot();
        final beforeSemantics = tester.getSemantics(
          find.byKey(const Key('planner-selected-date')),
        );
        final beforeDate = beforeSemantics.label;
        final pagerCenter = tester.getCenter(
          find.byKey(const Key('planner-day-pager-viewport')),
        );
        final first = await tester.startGesture(pagerCenter, pointer: 1);
        await first.moveBy(const Offset(-80, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await first.moveBy(const Offset(-60, 0));
        await tester.pump(const Duration(milliseconds: 16));
        // Add a second finger — the pinch coordinator must
        // cancel the swipe and recenter the pager.
        final second = await tester.startGesture(
          pagerCenter + const Offset(40, 40),
          pointer: 2,
        );
        await tester.pump();
        // Spread the two pointers apart to confirm a real
        // two-pointer gesture has been seen.
        await first.moveBy(const Offset(-40, 0));
        await second.moveBy(const Offset(40, 0));
        await tester.pump();
        await first.up();
        await second.up();
        for (var i = 0; i < 18; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // selectedDate must not have changed.
        final afterSemantics = tester.getSemantics(
          find.byKey(const Key('planner-selected-date')),
        );
        final afterDate = afterSemantics.label;
        expect(
          afterDate,
          beforeDate,
          reason: 'a two-pointer gesture must not commit a date change',
        );
        final afterCounts = await harness.snapshotCounts();
        expect(
          afterCounts,
          beforeCounts,
          reason: 'a two-pointer cancel must not mutate any Drift table',
        );
        final afterOps = await harness.latestOperationTimestamp();
        expect(
          afterOps,
          beforeOps,
          reason: 'a two-pointer cancel must not consume an operation id',
        );
        final afterActual = await harness.actualAndContributionSnapshot();
        expect(
          afterActual,
          beforeActual,
          reason: 'no Actual or contribution record may be created',
        );
      },
    );
  });
}

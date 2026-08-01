// Stage B3-R1 Slice D3-A1 production-tree tests for the
// interactive day pager.
//
// These tests exercise the real Planner widget tree (not a
// stripped-down harness) and target the production pager
// coordinates, thresholds, and lifecycle invariants:
//
//   TEST 1 — three pages exist and the current page is
//            centered with no double offset;
//   TEST 2 — a live left drag (before release) translates the
//            current page to the left and shows the next page,
//            without committing the selected date;
//   TEST 3 — a live right drag (before release) translates the
//            current page to the right and shows the previous
//            page, without committing the selected date;
//   TEST 4 — a settled left swipe commits +1 day and a settled
//            right swipe commits -1 day, exactly once per
//            gesture, with no two-day skip, and the pager
//            recenters after each commit;
//   TEST 5 — a release below the distance threshold AND below
//            the 700 logical pixels per second velocity
//            threshold cancels; a release below the distance
//            threshold BUT above 700 logical pixels per second
//            commits exactly one day;
//   TEST 6 — a vertical drag scrolls the timeline without
//            paging; starting a horizontal gesture and then
//            adding a second pointer recenters the pager, leaves
//            the selected date unchanged, and lets the pinch
//            remain authoritative for the hour-height zoom.
//
// The tests are designed to run against the production
// Planner tree. The shared coordinator, the locked pinch
// coordinator, the centered current timeline, and the
// `_pagerController` lifecycle are all exercised in place.

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

/// One-page test width: the existing horizontal swipe tests
/// pump an 862×1824 viewport so the surface is wide enough
/// for a clean left/right drag and a finite, positive pager
/// width. Keeping the same size means the live offset is
/// expressed in the same logical pixels the production tree
/// uses on a physical device.
const Size kPagerTestViewport = Size(862, 1824);
const double kPagerTestDevicePixelRatio = 2;

void main() {
  const displayTimeZoneId = 'Asia/Manila';
  const selected = PlannerDate(year: 2026, month: 7, day: 27);
  const previous = PlannerDate(year: 2026, month: 7, day: 26);
  const next = PlannerDate(year: 2026, month: 7, day: 28);

  /// Wire a memory-backed Planner stack and pump the real
  /// production app. Returns the [ProviderContainer] so tests
  /// can read the live [PlannerState] after a drag.
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
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
        displayTimeZoneId: displayTimeZoneId,
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
    tester.view.physicalSize = kPagerTestViewport;
    tester.view.devicePixelRatio = kPagerTestDevicePixelRatio;
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
        plannerDateSource: const FixedPlannerDateSource(selected),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
  }

  /// Read the live translation applied to the pager strip. The
  /// strip is the `Transform.translate` that carries the
  /// three-column Row. The translation equals
  /// `-(viewportWidth) + liveDragOffset`, so a value of
  /// `-viewportWidth` means the current page is centered.
  double readPagerTranslationX(WidgetTester tester) {
    final finder = find.byKey(const Key('planner-day-pager-strip'));
    expect(
      finder,
      findsOneWidget,
      reason: 'pager strip must be in the tree',
    );
    final transform = tester.widget<Transform>(finder);
    return transform.transform.getTranslation().x;
  }

  /// Read the live pager translation and normalize it back to
  /// the spec's `liveDragOffset` invariant: 0 at rest, negative
  /// for a left drag, positive for a right drag. The pager
  /// renders `Transform.translate` with
  /// `offset: Offset(-viewportWidth + _liveDragOffset, 0)`, so
  /// adding the viewport width back yields the raw offset.
  double readLiveDragOffset(WidgetTester tester) {
    final translationX = readPagerTranslationX(tester);
    final viewportWidth = tester.getSize(
      find.byKey(const Key('planner-day-pager-viewport')),
    ).width;
    return translationX + viewportWidth;
  }

  /// Drive a single-finger horizontal swipe at the screen
  /// center. Negative `dx` is a left swipe; positive `dx` is a
  /// right swipe.
  Future<void> driveHorizontalSwipe(
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
    // Drive a few explicit frames so the settle animation
    // (240 ms) and the rebuild have a chance to run. The
    // Planner screen owns a one-minute Timer for the
    // current-time indicator, which `pumpAndSettle` never
    // resolves; explicit frame pumps avoid that hang while
    // still giving the AnimationController enough time to
    // reach its end.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Drive a single-finger horizontal gesture that pauses
  /// before release so the live (pre-release) translation can
  /// be observed. The returned function releases the pointer
  /// when awaited.
  Future<Future<void> Function()> beginHorizontalDrag(
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
      // Drive a few explicit frames so the settle animation
      // (240 ms) and the rebuild have a chance to run. The
      // Planner screen owns a one-minute Timer for the
      // current-time indicator, which `pumpAndSettle` never
      // resolves; explicit frame pumps avoid that hang while
      // still giving the AnimationController enough time to
      // reach its end.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    };
  }

  /// Drive a few explicit frames so a settle animation can
  /// run to completion. The Planner screen owns a one-minute
  /// Timer for the current-time indicator, which
  /// `pumpAndSettle` never resolves; explicit frame pumps
  /// avoid that hang while still giving the
  /// AnimationController enough time to reach its end. 30
  /// frames at 16 ms ≈ 480 ms is comfortably more than the
  /// 240 ms settle duration.
  Future<void> pumpSettleFrames(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('Stage B3-R1 D3-A1: interactive day pager', () {
    testWidgets(
      'TEST 1 — three pages exist and the current page is '
      'centered with no double offset',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);
        expect(
          find.byKey(Key('planner-day-page-${previous.iso8601}')),
          findsOneWidget,
          reason: 'previous page must exist',
        );
        expect(
          find.byKey(Key('planner-day-page-${selected.iso8601}')),
          findsOneWidget,
          reason: 'current page must exist',
        );
        expect(
          find.byKey(Key('planner-day-page-${next.iso8601}')),
          findsOneWidget,
          reason: 'next page must exist',
        );
        final liveDragOffset = readLiveDragOffset(tester);
        expect(
          liveDragOffset.abs() < 0.5,
          isTrue,
          reason:
              'at rest the pager must not carry any live offset '
              '(was $liveDragOffset, must be 0)',
        );
        // The PlannerState must still be the original selected
        // date — the centered page is the actual current day.
        final state = container.read(plannerControllerProvider);
        expect(state.selectedDate, selected);
      },
    );

    testWidgets(
      'TEST 2 — a live left drag translates the current page '
      'leftward and reveals the next page without committing '
      'the selected date',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);
        // 60 logical pixels in 6 steps at 32 ms = 312 px/s
        // — well under the 700 px/s velocity threshold, and
        // well under the 22%-of-width distance threshold
        // (189.6 at 862 logical pixels). The release must
        // therefore cancel without committing.
        final release = await beginHorizontalDrag(
          tester,
          dx: -60,
          steps: 6,
        );
        // Before release: the live offset must be negative
        // (leftward) and the selected date must not have moved.
        final liveDragOffset = readLiveDragOffset(tester);
        expect(
          liveDragOffset < 0,
          isTrue,
          reason:
              'a live left drag must produce a negative '
              'liveDragOffset (was $liveDragOffset)',
        );
        expect(
          liveDragOffset.abs() > 10,
          isTrue,
          reason:
              'the drag must clear the direction-lock distance '
              '(was ${liveDragOffset.abs()})',
        );
        final stateBeforeRelease =
            container.read(plannerControllerProvider);
        expect(stateBeforeRelease.selectedDate, selected);
        await release();
        final stateAfter = container.read(plannerControllerProvider);
        expect(
          stateAfter.selectedDate,
          selected,
          reason:
              'a release below the distance threshold and below '
              '700 px/s velocity must not commit a day change',
        );
        final settledOffset = readLiveDragOffset(tester);
        expect(
          settledOffset.abs() < 0.5,
          isTrue,
          reason:
              'the pager must recenter after a cancel '
              '(was $settledOffset)',
        );
      },
    );

    testWidgets(
      'TEST 3 — a live right drag translates the current page '
      'rightward and reveals the previous page without '
      'committing the selected date',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);
        // 60 logical pixels in 6 steps at 32 ms = 312 px/s
        // — under both the 22% distance threshold and the
        // 700 px/s velocity threshold.
        final release = await beginHorizontalDrag(tester, dx: 60, steps: 6);
        final liveDragOffset = readLiveDragOffset(tester);
        expect(
          liveDragOffset > 0,
          isTrue,
          reason:
              'a live right drag must produce a positive '
              'liveDragOffset (was $liveDragOffset)',
        );
        expect(
          liveDragOffset.abs() > 10,
          isTrue,
          reason:
              'the drag must clear the direction-lock distance '
              '(was ${liveDragOffset.abs()})',
        );
        final stateBeforeRelease =
            container.read(plannerControllerProvider);
        expect(stateBeforeRelease.selectedDate, selected);
        await release();
        final stateAfter = container.read(plannerControllerProvider);
        expect(
          stateAfter.selectedDate,
          selected,
          reason:
              'a release below the velocity threshold must not '
              'commit a day change',
        );
        final settledOffset = readLiveDragOffset(tester);
        expect(
          settledOffset.abs() < 0.5,
          isTrue,
          reason: 'the pager must recenter after a cancel',
        );
      },
    );

    testWidgets(
      'TEST 4 — settled left swipe commits +1 day; settled '
      'right swipe commits -1 day, exactly once per gesture, '
      'and the pager recenters after each commit',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);

        // Left swipe: large enough to clear the 22%-of-width
        // distance threshold. 22% of 862 is 189.6, so 320 is
        // unambiguously above the threshold without requiring
        // a velocity boost.
        await driveHorizontalSwipe(tester, dx: -320);
        final stateLeft = container.read(plannerControllerProvider);
        expect(
          stateLeft.selectedDate,
          next,
          reason: 'a settled left swipe must commit +1 day',
        );
        expect(
          readLiveDragOffset(tester).abs() < 0.5,
          isTrue,
          reason:
              'the pager must recenter after a successful left '
              'commit',
        );

        // Right swipe: same distance, opposite direction. The
        // second commit must not two-day skip; it must land on
        // the original selected date.
        await driveHorizontalSwipe(tester, dx: 320);
        final stateRight = container.read(plannerControllerProvider);
        expect(
          stateRight.selectedDate,
          selected,
          reason: 'a settled right swipe must commit -1 day',
        );
        expect(
          readLiveDragOffset(tester).abs() < 0.5,
          isTrue,
          reason:
              'the pager must recenter after a successful right '
              'commit',
        );

        // A second consecutive right swipe must commit
        // exactly one day, landing on the previous date.
        await driveHorizontalSwipe(tester, dx: 320);
        final stateTwice = container.read(plannerControllerProvider);
        expect(
          stateTwice.selectedDate,
          previous,
          reason:
              'a second right swipe must commit -1 day, not '
              'two-day skip',
        );
      },
    );

    testWidgets(
      'TEST 5 — releases below the distance AND velocity '
      'thresholds cancel; releases below the distance '
      'threshold but above 700 logical px/s commit exactly one '
      'day',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);

        // Cancel: a small drag below both thresholds. The
        // distance threshold at 862 logical pixels is
        // max(0.22 * 862, 72) ≈ 189.6; 50 is comfortably below.
        // A 50 px sweep over 4 steps at 16 ms per step
        // (~780 px/s) is below 700... we make it even slower
        // to be safe.
        final center = tester.getCenter(
          find.byKey(const Key('planner-day-pager-viewport')),
        );
        final cancelGesture = await tester.startGesture(
          center,
          pointer: 1,
        );
        for (var i = 0; i < 4; i++) {
          await cancelGesture.moveBy(const Offset(-12, 0));
          await tester.pump(const Duration(milliseconds: 40));
        }
        await cancelGesture.up();
        await pumpSettleFrames(tester);
        final stateAfterCancel =
            container.read(plannerControllerProvider);
        expect(
          stateAfterCancel.selectedDate,
          selected,
          reason:
              'a release below both thresholds must not commit',
        );
        expect(
          readLiveDragOffset(tester).abs() < 0.5,
          isTrue,
          reason: 'the pager must recenter after a cancel',
        );

        // Velocity commit: a small distance (50 logical
        // pixels) but a high velocity. We dispatch the down
        // at the current test clock, then drive the move and
        // the up with an explicit 1 ms timestamp on the up
        // so the elapsed time from the down to the up is
        // exactly 1 ms and the velocity is 50 px/ms =
        // 50 000 px/s.
        final velocityGesture = await tester.startGesture(
          center,
          pointer: 1,
        );
        await velocityGesture.moveBy(const Offset(-50, 0));
        // The down was dispatched at T=0; the up carries an
        // explicit 1 ms timestamp so the velocity calculation
        // sees exactly 1 ms of elapsed time.
        await velocityGesture.up(
          timeStamp: const Duration(milliseconds: 1),
        );
        // A single 1 ms pump dispatches the move and the up
        // events and advances the test clock so any
        // post-event rebuilds and the recenter animation can
        // settle.
        await tester.pump(const Duration(milliseconds: 1));
        await pumpSettleFrames(tester);
        final stateAfterVelocity =
            container.read(plannerControllerProvider);
        expect(
          stateAfterVelocity.selectedDate,
          next,
          reason:
              'a release below the distance threshold but above '
              '700 logical px/s must commit exactly one day',
        );
        expect(
          readLiveDragOffset(tester).abs() < 0.5,
          isTrue,
          reason:
              'the pager must recenter after a velocity commit',
        );
      },
    );

    testWidgets(
      'TEST 6 — vertical drag scrolls without paging; '
      'horizontal gesture followed by a second pointer '
      'recenters, leaves the date unchanged, and the pinch '
      'remains authoritative for hour-height zoom',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);

        // Vertical drag: 220 logical pixels downward with
        // minimal horizontal jitter. Must NOT commit a day
        // change and must NOT leave the pager with a live
        // offset.
        final center = tester.getCenter(
          find.byKey(const Key('planner-day-pager-viewport')),
        );
        final verticalGesture = await tester.startGesture(
          center,
          pointer: 1,
        );
        for (var i = 0; i < 8; i++) {
          await verticalGesture.moveBy(const Offset(0, 28));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await verticalGesture.up();
        await pumpSettleFrames(tester);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          selected,
          reason: 'a vertical drag must not page',
        );
        expect(
          readLiveDragOffset(tester).abs() < 0.5,
          isTrue,
          reason: 'the pager must recenter after a vertical drag',
        );

        // Horizontal gesture + second pointer: start a
        // horizontal drag, then add a second pointer. The
        // second pointer must recenter the pager (the pinch
        // cancels horizontal intent) and must NOT commit a
        // day change.
        final first = await tester.startGesture(
          center,
          pointer: 1,
        );
        for (var i = 0; i < 4; i++) {
          await first.moveBy(const Offset(-30, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Live offset should now be negative — the drag
        // crossed the direction lock.
        final liveDuringHorizontal = readLiveDragOffset(tester);
        expect(
          liveDuringHorizontal < 0,
          isTrue,
          reason:
              'a horizontal gesture past the direction lock '
              'must produce a negative liveDragOffset',
        );
        // Add a second pointer: pinch owns the gesture and the
        // pager recenters.
        final second = await tester.startGesture(
          center + const Offset(20, 0),
          pointer: 2,
        );
        // Drive a small move on the second pointer so the
        // pager's _onPointerMove re-checks the pinch
        // pointer count and recenters if the second pointer
        // arrived after the pager's own pointer-down.
        await second.moveBy(const Offset(0, 1));
        // Pump enough frames to dispatch the second pointer's
        // down + move events AND to let any recenter animation
        // (240 ms) run to completion.
        await pumpSettleFrames(tester);
        final liveAfterSecondPointer = readLiveDragOffset(tester);
        expect(
          liveAfterSecondPointer.abs() < 0.5,
          isTrue,
          reason:
              'a second pointer must recenter the pager '
              '(was $liveAfterSecondPointer)',
        );
        // Lift the second pointer; then lift the first. The
        // date must not have moved.
        await second.up();
        await tester.pump();
        await first.up();
        await pumpSettleFrames(tester);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          selected,
          reason: 'pinch-cancel must not commit a day change',
        );
        expect(
          readLiveDragOffset(tester).abs() < 0.5,
          isTrue,
          reason: 'the pager must recenter after the pinch',
        );

        // The D2 pinch coordinator owns the hour-height
        // zoom. We assert that the screen still responds to a
        // follow-up horizontal drag after the pinch, which
        // proves the pinch did not leave the gesture system
        // in a bad state. (The pinch-driven zoom itself is
        // covered by the existing physical-pinch and
        // pinch-zoom tests; this test only asserts that the
        // pager's lifecycle still works afterwards.)
        await driveHorizontalSwipe(tester, dx: -320);
        expect(
          container.read(plannerControllerProvider).selectedDate,
          next,
          reason:
              'after a pinch-cancel, a clean horizontal swipe '
              'must still commit a day change',
        );
      },
    );

    testWidgets(
      'TEST 7 — left drag produces negative liveDragOffset and '
      'physically shifts the current-day column leftward, '
      'revealing the next-day column from the right edge of '
      'the clip',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);

        // Pre-drag: current page's left edge should be near
        // the pager viewport's left edge (the column fills
        // the visible width and is centered). Use a small
        // tolerance to allow for one logical pixel of layout
        // jitter. We won't assert strictly on the center
        // because the mounted pager sits inside a padded
        // SingleChildScrollView.
        final viewportLeft = tester.getTopLeft(
          find.byKey(const Key('planner-day-pager-viewport')),
        ).dx;
        final initialCurrentLeft = tester.getTopLeft(
          find.byKey(Key('planner-day-page-${selected.iso8601}')),
        ).dx;
        expect(
          (initialCurrentLeft - viewportLeft).abs() < 4,
          isTrue,
          reason:
              'before a drag the current page must be flush '
              'with the left edge of the pager viewport '
              '(current left was $initialCurrentLeft vs '
              'viewport left $viewportLeft)',
        );

        // Left drag: 80 px leftward, 4 steps at 16 ms each.
        // Clears the direction lock, stays below the
        // 22%-of-width distance threshold.
        final release = await beginHorizontalDrag(
          tester,
          dx: -80,
          steps: 4,
        );
        // Live offset: negative.
        final liveDragOffset = readLiveDragOffset(tester);
        expect(
          liveDragOffset < 0,
          isTrue,
          reason:
              'a live left drag must produce a negative '
              'liveDragOffset (was $liveDragOffset)',
        );
        // The current-day column should now have a left edge
        // left of the viewport left by an amount close to
        // |liveDragOffset|.
        final draggedCurrentLeft = tester.getTopLeft(
          find.byKey(
            Key('planner-day-page-${selected.iso8601}'),
          ),
        ).dx;
        final shift = viewportLeft - draggedCurrentLeft;
        expect(
          shift > 30,
          isTrue,
          reason:
              'a left drag must shift the current column '
              'leftward (was $shift px left of the viewport '
              'left edge)',
        );
        // The next-day column should now be visible — its
        // rendered GlobalRect must overlap the clip rect.
        final nextRect = tester.getRect(
          find.byKey(Key('planner-day-page-${next.iso8601}')),
        );
        expect(
          nextRect.left < viewportLeft + tester.getSize(
            find.byKey(const Key('planner-day-pager-viewport')),
          ).width,
          isTrue,
          reason:
              'the next-day column must enter from the right '
              'edge during a left drag (was '
              '${nextRect.left})',
        );
        // The previous-day column must be sliding off-screen
        // to the left.
        final prevRect = tester.getRect(
          find.byKey(Key('planner-day-page-${previous.iso8601}')),
        );
        expect(
          prevRect.right < viewportLeft,
          isTrue,
          reason:
              'the previous-day column must be off-screen '
              'left during a left drag (right edge was '
              '${prevRect.right})',
        );
        // No commit during a live drag.
        expect(
          container.read(plannerControllerProvider).selectedDate,
          selected,
          reason: 'live drag must not commit a date change',
        );
        await release();
      },
    );

    testWidgets(
      'TEST 8 — right drag produces positive liveDragOffset '
      'and physically shifts the current-day column rightward, '
      'revealing the previous-day column from the left edge of '
      'the clip',
      (tester) async {
        final container = await pumpApp(tester);
        await pumpSettleFrames(tester);

        final viewportLeft = tester.getTopLeft(
          find.byKey(const Key('planner-day-pager-viewport')),
        ).dx;
        final viewportWidth = tester.getSize(
          find.byKey(const Key('planner-day-pager-viewport')),
        ).width;
        final release = await beginHorizontalDrag(
          tester,
          dx: 80,
          steps: 4,
        );
        final liveDragOffset = readLiveDragOffset(tester);
        expect(
          liveDragOffset > 0,
          isTrue,
          reason:
              'a live right drag must produce a positive '
              'liveDragOffset (was $liveDragOffset)',
        );
        final draggedCurrentLeft = tester.getTopLeft(
          find.byKey(
            Key('planner-day-page-${selected.iso8601}'),
          ),
        ).dx;
        final shift = draggedCurrentLeft - viewportLeft;
        expect(
          shift > 30,
          isTrue,
          reason:
              'a right drag must shift the current column '
              'rightward (was $shift px right of the viewport '
              'left edge)',
        );
        // The previous-day column should now be visible.
        final prevRect = tester.getRect(
          find.byKey(Key('planner-day-page-${previous.iso8601}')),
        );
        expect(
          prevRect.right > viewportLeft,
          isTrue,
          reason:
              'the previous-day column must enter from the '
              'left edge during a right drag (right edge '
              '${prevRect.right} vs viewport left '
              '$viewportLeft)',
        );
        // The next-day column should now be sliding off the
        // right edge.
        final nextRect = tester.getRect(
          find.byKey(Key('planner-day-page-${next.iso8601}')),
        );
        expect(
          nextRect.left > viewportLeft + viewportWidth,
          isTrue,
          reason:
              'the next-day column must be partly off-screen '
              'right during a right drag (left edge was '
              '${nextRect.left})',
        );
        expect(
          container.read(plannerControllerProvider).selectedDate,
          selected,
          reason: 'live drag must not commit a date change',
        );
        await release();
      },
    );
  });
}

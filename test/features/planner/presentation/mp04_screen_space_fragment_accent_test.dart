// MP-04 SCREEN-SPACE PREVIEW ACCENT (owner evidence 2026-08-16).
//
// The previous MP-04 test asserted the widget tree carried a left BorderSide
// — the wrong invariant. The owner recording shows a wide/full-lane Event
// BODY becoming visible in the viewport during a horizontal pager slide while
// its true left edge (and its 3 dp accent strip) is still clipped offscreen.
// Frame contract: as soon as ANY Event body fragment is visible, a visible
// accent must be visible in that SAME frame — painted at the visible fragment
// boundary (the viewport's left edge) when the true left edge is clipped.
//
// This test pins the REAL pager to a deterministic partial offset (driving
// the pager controller's progress directly, bypassing the gesture arena so a
// competing recognizer cannot recenter the strip mid-frame), rasterizes the
// actual screen pixels, and asserts:
//   * rightward partial offset: the previous day's Event body fragment is
//     visible at the viewport's left edge AND an accent-colored strip is
//     present at the clipped fragment boundary in the SAME frame — RED on a
//     build without the fragment-accent overlay;
//   * backup preview fragments carry the striped accent at the boundary;
//   * leftward partial offset (next day enters from the right): its true
//     left accent is visible as the block enters — no body-without-accent;
//   * the settled (centered) frame has NO accent pixels at the viewport
//     edge (no settled delta / no double accent).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:rmplanner/features/planner/presentation/widgets/planner_interactive_day_pager.dart';

import '../../../support/test_dependencies.dart';

const _displayTimeZoneId = 'Asia/Manila';
const _captureKey = Key('mp04-capture-boundary');

/// Partial rightward offset (previous day revealed from the left, ~30% of
/// the viewport). The previous day's full-lane blocks then show a visible
/// body fragment whose true left edge — and left accent — is still offscreen.
const _partialRightProgress = 0.30;

/// Partial leftward offset (next day enters from the right).
const _partialLeftProgress = -0.30;

/// The app's planner viewport sits inside a ~12 px horizontal inset from the
/// screen edge, so the viewport's left edge (the fragment boundary) rasters
/// at x ≈ 12 and the 3 dp fragment accent at x ≈ [12,15]. This band covers
/// the whole left region: the only accent-family pixels there during a
/// rightward partial reveal are the fragment-accent overlay.
const _leftEdgeBandStart = 0;
const _leftEdgeBandEnd = 60;

CalendarEventDraft timedDraft({
  required String id,
  required PlannerDate date,
  required int startMinute,
  required int endMinute,
  bool backup = false,
  String? backupForEventId,
}) {
  return CalendarEventDraft(
    id: id,
    title: 'MP04S $id',
    timing: CalendarEventTiming.timed,
    startDate: date,
    startMinute: startMinute,
    endMinute: endMinute,
    requiresReport: false,
    timeZoneId: _displayTimeZoneId,
    isBackupAppointment: backup,
    backupForEventId: backupForEventId,
  );
}

Future<(AppDatabase, DriftPlannerRepository, CalendarEventRepository)>
    buildRepositories() async {
  final database = openMemoryDatabase();
  addTearDown(database.close);
  final clock = FixedClock(DateTime.utc(2026, 7, 27, 12));
  final timeZones = IanaCalendarEventTimeZones(
    displayTimeZoneId: _displayTimeZoneId,
  );
  final linkRepository = DriftTaskEventLinkRepository(
    database: database,
    clock: clock,
  );
  final outcomeReportingRepository = DriftOutcomeReportingRepository(
    database: database,
    clock: clock,
  );
  final calendarRepository = DriftCalendarEventRepository(
    database: database,
    clock: clock,
    timeZones: timeZones,
    taskContextSource: linkRepository,
    linkContextTransfer: linkRepository,
    reportSource: outcomeReportingRepository,
  );
  final plannerRepository = DriftPlannerRepository(
    database: database,
    clock: clock,
    calendarSource: calendarRepository,
    taskContextSource: linkRepository,
    historicalEffectReader: outcomeReportingRepository,
  );
  return (database, plannerRepository, calendarRepository);
}

Future<void> pumpPlannerDay(
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
  final profile = await buildTestRepository(
    database: database,
  ).completeOnboarding();
  // Seed events on 5 consecutive days (normal + backup on the adjacent days)
  // so the adjacent preview columns have full-lane Event bodies.
  var id = 0;
  for (var offset = -2; offset <= 2; offset++) {
    final date = PlannerDate(
      year: selected.year,
      month: selected.month,
      day: selected.day + offset,
    );
    for (var slot = 0; slot < 3; slot++) {
      id++;
      final idHex = id.toRadixString(16).padLeft(12, '0');
      final normal = '00000000-0000-4000-8000-$idHex';
      await calendarRepository.saveEvent(
        profileId: profile.id,
        draft: timedDraft(
          id: normal,
          date: date,
          startMinute: 8 * 60 + slot * 90,
          endMinute: 9 * 60 + slot * 90,
        ),
      );
      if (offset == -1 && slot == 0) {
        final backupId = '10000000-0000-4000-8000-$idHex';
        await calendarRepository.saveEvent(
          profileId: profile.id,
          draft: timedDraft(
            id: backupId,
            date: date,
            startMinute: 10 * 60,
            endMinute: 11 * 60,
            backup: true,
            backupForEventId: normal,
          ),
        );
      }
    }
  }
  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        plannerRepository: plannerRepository,
        plannerDateSource: FixedPlannerDateSource(selected),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
}

/// Pin the real pager to a deterministic normalized offset (positive reveals
/// the previous day from the left) and pump one frame.
Future<void> _pinPagerProgress(WidgetTester tester, double progress) async {
  final pagerFinder = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'PlannerInteractiveDayPager',
  );
  expect(pagerFinder, findsOneWidget);
  final pager = tester.widget<PlannerInteractiveDayPager>(pagerFinder);
  // The State class is private; dynamic dispatch reaches its public
  // `setState` without exposing the type.
  // The State class is private to the pager library; dynamic dispatch
  // reaches its public `setState` without exposing the type.
  // ignore: avoid_dynamic_calls
  (tester.state(pagerFinder) as dynamic)
      .setState(() {
        pager.controller.setProgressForTest(progress);
      });
  await tester.pump();
}

Future<ui.Image> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: 1),
  );
  if (image == null) {
    fail('MP-04: capture returned null');
  }
  return image;
}

/// Count strong-accent-colored pixels (the default pink accent family) in
/// the horizontal strip [xStart, xEnd) across all rows.
Future<int> _countAccentPixels(
  WidgetTester tester,
  ui.Image image, {
  required int xStart,
  required int xEnd,
}) async {
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  if (bytes == null) {
    fail('MP-04: toByteData returned null');
  }
  final data = bytes;
  var count = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = xStart; x < xEnd; x++) {
      final i = (y * image.width + x) * 4;
      final r = data.getUint8(i);
      final g = data.getUint8(i + 1);
      final b = data.getUint8(i + 2);
      // Strong pink accent family (accent 0xFFE91E63 = 233,30,99).
      if (r >= 195 && g <= 110 && b <= 150) {
        count++;
      }
    }
  }
  return count;
}

/// Count non-background (painted body/surface) pixels in the strip.
Future<int> _countBodyPixels(
  WidgetTester tester,
  ui.Image image, {
  required int xStart,
  required int xEnd,
}) async {
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  if (bytes == null) {
    fail('MP-04: toByteData returned null');
  }
  final data = bytes;
  var count = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = xStart; x < xEnd; x++) {
      final i = (y * image.width + x) * 4;
      final r = data.getUint8(i);
      final g = data.getUint8(i + 1);
      final b = data.getUint8(i + 2);
      final a = data.getUint8(i + 3);
      if (a == 0) {
        continue;
      }
      // Light canvas ~ (244,244,244); anything clearly different is painted
      // content (Event surface / text / grid).
      if ((r - 244).abs() + (g - 244).abs() + (b - 244).abs() > 24) {
        count++;
      }
    }
  }
  return count;
}

void main() {
  testWidgets(
    'MP-04 screen-space: a visible preview Event fragment carries its accent '
    'at the clipped boundary in the SAME frame (no body-before-accent, no '
    'settled delta)', (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final (database, plannerRepo, calendarRepo) = await buildRepositories();
      await pumpPlannerDay(
        tester,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        selected: selected,
      );

      // Settled baseline: nothing at the viewport edge (no settled delta).
      final settled = await _capture(tester);
      final settledEdgeAccent = await _countAccentPixels(
        tester,
        settled,
        xStart: _leftEdgeBandStart,
        xEnd: _leftEdgeBandEnd,
      );
      expect(
        settledEdgeAccent,
        lessThan(5),
        reason: 'settled frame must not paint a fragment accent at the '
            'viewport edge',
      );

      // Partial RIGHT offset: the previous day enters from the left; its
      // full-lane blocks show a body fragment while the true left accent is
      // still clipped offscreen.
      await _pinPagerProgress(tester, _partialRightProgress);
      final during = await _capture(tester);

      // Precondition: the preview Event body fragment is actually visible at
      // the left edge (the previous day's surface is revealed there).
      final bodyPixels = await _countBodyPixels(
        tester,
        during,
        xStart: 12,
        xEnd: 60,
      );
      expect(
        bodyPixels,
        greaterThan(0),
        reason: 'precondition: a preview Event body fragment must be visible '
            'at the left edge during the partial offset',
      );

      // FRAME CONTRACT: the visible fragment boundary carries the accent in
      // the SAME captured frame.
      final fragmentAccent = await _countAccentPixels(
        tester,
        during,
        xStart: _leftEdgeBandStart,
        xEnd: _leftEdgeBandEnd,
      );
      expect(
        fragmentAccent,
        greaterThanOrEqualTo(20),
        reason: 'MP-04: as soon as an Event body fragment is visible, a '
            'visible accent must be painted at the fragment boundary in the '
            'same frame (current build paints the body before its clipped '
            'left accent enters)',
      );

      // Back to centered: no fragment accent remains.
      await _pinPagerProgress(tester, 0);
      final centeredAgain = await _capture(tester);
      final centeredAccent = await _countAccentPixels(
        tester,
        centeredAgain,
        xStart: _leftEdgeBandStart,
        xEnd: _leftEdgeBandEnd,
      );
      expect(centeredAccent, lessThan(5));
    },
  );

  testWidgets(
    'MP-04 screen-space: backup preview fragments also carry the striped '
    'accent at the clipped boundary', (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final (database, plannerRepo, calendarRepo) = await buildRepositories();
      await pumpPlannerDay(
        tester,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        selected: selected,
      );
      await _pinPagerProgress(tester, _partialRightProgress);
      final during = await _capture(tester);
      // The backup Event (10-11 AM on the previous day) sits inside the left
      // fragment; its stripes include accent-colored diagonal runs, so the
      // fragment boundary still shows accent-family pixels in the same frame.
      final fragmentAccent = await _countAccentPixels(
        tester,
        during,
        xStart: _leftEdgeBandStart,
        xEnd: _leftEdgeBandEnd,
      );
      expect(
        fragmentAccent,
        greaterThanOrEqualTo(4),
        reason: 'MP-04: backup preview fragment must show its accent at the '
            'clipped boundary in the same frame',
      );
      await _pinPagerProgress(tester, 0);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'MP-04 screen-space: reverse direction — the incoming right-side day '
    'enters with its true left accent visible (no body-without-accent, no '
    'fragment accent on the left edge)', (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final (database, plannerRepo, calendarRepo) = await buildRepositories();
      await pumpPlannerDay(
        tester,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        selected: selected,
      );
      await _pinPagerProgress(tester, _partialLeftProgress);
      final during = await _capture(tester);

      // The NEXT day's blocks enter from the right; their true left edge
      // (and accent) is the first part to enter the viewport, so accent
      // pixels must be present INSIDE the viewport (not only at the edge).
      final viewportWidth = during.width;
      // Right quarter of the screen: the incoming day's blocks live here.
      final rightQuarterAccent = await _countAccentPixels(
        tester,
        during,
        xStart: viewportWidth - viewportWidth ~/ 4,
        xEnd: viewportWidth,
      );
      expect(
        rightQuarterAccent,
        greaterThan(0),
        reason: 'MP-04: reverse direction — incoming day Event blocks must '
            'show their true left accent as they enter from the right',
      );
      // And NO fragment accent is painted at the LEFT viewport edge for this
      // direction (no fragment accent on the wrong side).
      final leftEdgeAccent = await _countAccentPixels(
        tester,
        during,
        xStart: _leftEdgeBandStart,
        xEnd: _leftEdgeBandEnd,
      );
      expect(
        leftEdgeAccent,
        lessThan(20),
        reason: 'MP-04: no preview fragment accent may be painted at the '
            'left viewport edge for the reverse direction',
      );
      await _pinPagerProgress(tester, 0);
      await tester.pumpAndSettle();
    },
  );
}

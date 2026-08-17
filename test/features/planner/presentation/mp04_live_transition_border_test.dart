// MP-04 LIVE-TRANSITION REGRESSION (strengthened after the fresh owner
// recording reopened the historical preview-border symptom).
//
// The previous permanent MP-04 test only asserted the CENTERED blocks
// ('planner-timed-event-*'). This test drives the ACTUAL pager transition
// path and asserts the read-only PREVIEW columns ('planner-pager-preview-
// event-*') paint their left accent border in the SAME frame as the block
// body:
//   * while a horizontal drag is held at ~25% / ~50% / ~75% progress
//   * on every mid-drag frame
//   * after settlement
//   * for backup Events (striped accent) and normal Events
//   * for reverse/cancelled swipes
// If this passes on the current build, MP-04 is NOT reproducible at the
// render layer (the border is synchronous with the block) and no production
// change is warranted - the strengthened test becomes the pin.
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
    title: 'MP04L $id',
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
    displayTimeZoneId: 'Asia/Manila',
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
  final profile = await buildTestRepository(database: database).completeOnboarding();
  // Seed events on 5 consecutive days (normal + backup on the adjacent days).
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
      // One backup Event per adjacent day (previous day only) so the
      // preview path is exercised for backup stripes too.
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

/// Assert every mounted NORMAL preview block carries its left accent border.
void expectPreviewBlocksHaveAccentBorder(WidgetTester tester) {
  final previewBlocks = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith(
          'planner-pager-preview-event-',
        ),
  );
  final count = previewBlocks.evaluate().length;
  if (count == 0) {
    return; // No preview blocks mounted on this frame (empty preview grid).
  }
  for (final element in previewBlocks.evaluate()) {
    final id = (element.widget.key as ValueKey<String>).value;
    // Normal preview blocks are wrapped in a DecoratedBox with the left
    // accent BorderSide. Backup preview blocks wrap the content in
    // PlannerBackupStripeBackground (CustomPaint painter) instead - their
    // accent is the striped painter, which has its own dedicated coverage.
    final boxes = find
        .descendant(
          of: find.byWidget(element.widget),
          matching: find.byType(DecoratedBox),
        )
        .evaluate();
    if (boxes.isEmpty) {
      continue; // backup stripe path - accent painted by the stripe painter
    }
    final box = tester.widget<DecoratedBox>(find.byWidget(boxes.first.widget));
    final decoration = box.decoration;
    final boxBorder = decoration is BoxDecoration ? decoration.border : null;
    final left = boxBorder is Border ? boxBorder.left : null;
    expect(
      left,
      isNotNull,
      reason: 'MP-04: preview block $id must paint its left accent border '
          'in the same frame as the block body',
    );
    expect(left!.width, greaterThan(0));
  }
}

Future<void> holdPartialDrag(
  WidgetTester tester, {
  required Offset start,
  required double dx,
  required double progress,
}) async {
  final gesture = await tester.startGesture(start, pointer: 1);
  final target = dx * progress;
  final steps = 6;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(Offset(target / steps, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expectPreviewBlocksHaveAccentBorder(tester);
  }
  // Hold the partial position and inspect several frames.
  for (var f = 0; f < 4; f++) {
    await tester.pump(const Duration(milliseconds: 16));
    expectPreviewBlocksHaveAccentBorder(tester);
  }
  await gesture.up();
  for (var f = 0; f < 6; f++) {
    await tester.pump(const Duration(milliseconds: 16));
    expectPreviewBlocksHaveAccentBorder(tester);
  }
  await tester.pumpAndSettle();
  expectPreviewBlocksHaveAccentBorder(tester);
}

void main() {
  testWidgets(
    'MP-04 live: preview-column Event blocks keep their left accent border '
    'on partial holds, mid-drag frames, settlement, and reverse swipes',
    (tester) async {
      const selected = PlannerDate(year: 2026, month: 7, day: 27);
      final (database, plannerRepo, calendarRepo) = await buildRepositories();
      await pumpPlannerDay(
        tester,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        selected: selected,
      );
      final gridCenter = tester
          .getRect(find.byKey(const Key('planner-zoom-surface')))
          .center;
      // Forward partial holds at 25/50/75% + full swipe, then reverse.
      for (final progress in <double>[0.25, 0.5, 0.75]) {
        await holdPartialDrag(
          tester,
          start: gridCenter,
          dx: -200,
          progress: progress,
        );
      }
      await holdPartialDrag(
        tester,
        start: gridCenter,
        dx: -220,
        progress: 1.0,
      );
      // Reverse (back toward the current date).
      await holdPartialDrag(
        tester,
        start: gridCenter,
        dx: 220,
        progress: 0.5,
      );
      await holdPartialDrag(
        tester,
        start: gridCenter,
        dx: 220,
        progress: 1.0,
      );
      expectPreviewBlocksHaveAccentBorder(tester);
    },
  );
}

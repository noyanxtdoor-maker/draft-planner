// MP-04 REGRESSION: date-swipe Event accent border stability.
//
// MP-04 was NOT reproduced on the current build (aa03417): the deterministic
// harness below drives >=20 left/right date swipes across event-rich days and
// asserts that EVERY normal (non-backup) timed Event block carries its left
// accent border synchronously in the same frame as the block - in both the
// mid-drag preview state and the settled state. This pins the currently
// correct invariant; no production fix was warranted (see the combined
// forensic audit).
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
  CalendarRecurrenceRule recurrence = const CalendarRecurrenceRule(),
}) {
  return CalendarEventDraft(
    id: id,
    title: 'MP04 Fixture $id',
    timing: CalendarEventTiming.timed,
    startDate: date,
    startMinute: startMinute,
    endMinute: endMinute,
    requiresReport: false,
    timeZoneId: _displayTimeZoneId,
    recurrence: recurrence,
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
  final profile = await buildTestRepository(database: database).completeOnboarding();      // Seed 2-3 events on each of 5 consecutive days around the selected date.
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
          await calendarRepository.saveEvent(
            profileId: profile.id,
            draft: timedDraft(
              id: '00000000-0000-4000-8000-$idHex',
              date: date,
              startMinute: 8 * 60 + slot * 90,
              endMinute: 9 * 60 + slot * 90,
            ),
          );
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

Rect visibleZoomCenter(WidgetTester tester) {
  return tester.getRect(find.byKey(const Key('planner-zoom-surface')));
}

/// Assert every currently mounted NORMAL (non-backup) timed Event block
/// carries a left accent BorderSide in the same build as its content.
void expectAllNormalBlocksHaveAccentBorder(WidgetTester tester) {
  final blocks = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('planner-timed-event-'),
  );
  final count = blocks.evaluate().length;
  if (count == 0) {
    return; // No normal events mounted on this frame (e.g., empty preview).
  }
  for (final element in blocks.evaluate()) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = box.decoration;
    final boxBorder = decoration is BoxDecoration ? decoration.border : null;
    final left = boxBorder is Border ? boxBorder.left : null;
    expect(
      left,
      isNotNull,
      reason: 'every normal Event block must paint its left accent border '
          'in the same frame as the block (element ${element.widget.key})',
    );
    expect(left!.width, greaterThan(0));
  }
}

Future<void> driveHorizontalSwipe(
  WidgetTester tester, {
  required Offset start,
  required double dx,
  int steps = 8,
}) async {
  final gesture = await tester.startGesture(start, pointer: 1);
  final perStep = dx / steps;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(Offset(perStep, 0));
    await tester.pump(const Duration(milliseconds: 16));
    // MP-04: inspect the border on EVERY mid-drag preview frame.
    expectAllNormalBlocksHaveAccentBorder(tester);
  }
  await gesture.up();
  // Settled state: inspect several frames after the transition.
  for (var f = 0; f < 6; f++) {
    await tester.pump(const Duration(milliseconds: 16));
    expectAllNormalBlocksHaveAccentBorder(tester);
  }
  await tester.pumpAndSettle();
  expectAllNormalBlocksHaveAccentBorder(tester);
}

void main() {
  testWidgets(
    'MP-04: >=20 date swipes keep the Event left accent border on '
    'every preview and settled frame',
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
      final gridCenter = visibleZoomCenter(tester).center;
      // 24 transitions: alternate left/right, including return-to-current
      // patterns (left x2 then right x2 repeats).
      for (var i = 0; i < 24; i++) {
        final dx = (i % 4 < 2) ? -180.0 : 180.0;
        await driveHorizontalSwipe(
          tester,
          start: gridCenter,
          dx: dx,
        );
      }
      expectAllNormalBlocksHaveAccentBorder(tester);
    },
  );
}

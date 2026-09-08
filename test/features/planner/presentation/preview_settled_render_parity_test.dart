// PREVIEW -> SETTLED RENDER PARITY (owner 2026-08-16, audit-first).
//
// Owner physical result: when swiping to another date, the incoming preview
// still looks like a "preview version" and then changes into the actual
// settled date.
//
// Forensic audit (NEXT_TRANSFER_R1_PREVIEW_PARITY_FORENSIC_AUDIT_2026-08-16)
// compared the two renderers at the code level. They share the exact same
// Event projection (PlannerDisplayGeometry.resolve -> placements, same
// horizontal geometry constants, same color resolver, same content policy,
// same block decoration) and the same grid (civil-day 0..24, same label
// positions, same divider color, same current-time geometry). The ONLY
// confirmed shared-surface visual delta is the HOUR-LABEL OPACITY:
//   preview:  AppTheme.onFillTextOf(context, 0xB3 / 0xFF)   (= 0.702)
//   settled:  AppTheme.onFillTextOf(context, 0.54)
// In Light both resolve to onSurface translucencies 0.70 vs 0.54; in Dark
// they resolve to white70 (0xB3FFFFFF) vs white54 (0x8AFFFFFF). At commit
// the labels change opacity — exactly the "preview changes into the settled
// date" artifact.
//
// LOCKED CONTRACT: after horizontal translation is normalized, the
// destination-date PREVIEW visual must match the SETTLED visual. The only
// allowed settle-time changes are page translation reaching zero, date
// selection committing, and interactivity activating — never a visual
// reinterpretation.
//
// This test renders the REAL pager (full app harness, same as the MP-04
// screen-space test), reads the ACTUAL hour-label Text widgets in the
// preview columns and the settled timeline at rest, and asserts the label
// style color is identical between preview and settled for the same hour.
// RED on the current build (0.70 vs 0.54), GREEN after the one-line fix.
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

final _hourLabelPattern = RegExp(r'^\d{1,2}( AM| PM|:00)$');

CalendarEventDraft timedDraft({
  required String id,
  required PlannerDate date,
  required int startMinute,
  required int endMinute,
}) {
  return CalendarEventDraft(
    id: id,
    title: 'PARITY $id',
    timing: CalendarEventTiming.timed,
    startDate: date,
    startMinute: startMinute,
    endMinute: endMinute,
    requiresReport: false,
    timeZoneId: _displayTimeZoneId,
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
  // Seed one full-lane Event per day (selected + adjacent) so the preview
  // columns and the settled timeline both render a real day.
  var id = 0;
  for (var offset = -1; offset <= 1; offset++) {
    final date = PlannerDate(
      year: selected.year,
      month: selected.month,
      day: selected.day + offset,
    );
    id++;
    final idHex = id.toRadixString(16).padLeft(12, '0');
    await calendarRepository.saveEvent(
      profileId: profile.id,
      draft: timedDraft(
        id: '00000000-0000-4000-8000-$idHex',
        date: date,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
      ),
    );
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

void main() {
  testWidgets(
    'preview hour labels render with the SAME style color as the settled '
    'timeline hour labels (no visual reinterpretation at settle)',
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

      // The settled timeline is the authoritative current page.
      final settledSection = find.byKey(const Key('timed-events-section'));
      expect(settledSection, findsOneWidget);

      // Collect every hour-label Text (e.g. "8 AM", "11 PM", "08:00") with
      // its screen-space x and its resolved style color.
      final labels = <({Text text, double dx, double dy, Color? color})>[];
      for (final element in tester.elementList(find.byType(Text))) {
        final text = element.widget as Text;
        final data = text.data;
        if (data == null || !_hourLabelPattern.hasMatch(data)) {
          continue;
        }
        final topLeft = tester.getTopLeft(find.byWidget(text));
        labels.add((
          text: text,
          dx: topLeft.dx,
          dy: topLeft.dy,
          color: text.style?.color,
        ));
      }

      // Partition by x: previous preview column (offscreen left), settled
      // timeline (in view), next preview column (offscreen right).
      final settled = labels
          .where((l) => l.dx >= 0 && l.dx < 200)
          .toList()
        ..sort((a, b) => a.dy.compareTo(b.dy));
      final previousPreview = labels
          .where((l) => l.dx < 0)
          .toList()
        ..sort((a, b) => a.dy.compareTo(b.dy));
      final nextPreview = labels
          .where((l) => l.dx > 380)
          .toList()
        ..sort((a, b) => a.dy.compareTo(b.dy));

      expect(
        settled.length,
        greaterThanOrEqualTo(10),
        reason: 'precondition: the settled timeline must render hour labels',
      );
      expect(
        previousPreview.length,
        greaterThanOrEqualTo(10),
        reason: 'precondition: the previous preview column must render hour '
            'labels',
      );
      expect(
        nextPreview.length,
        greaterThanOrEqualTo(10),
        reason: 'precondition: the next preview column must render hour '
            'labels',
      );

      // Same hour rank => same label string; assert the style color matches
      // the settled color for every rank in both directions.
      for (var i = 0; i < settled.length; i++) {
        final settledLabel = settled[i];
        final previousLabel = previousPreview[i];
        final nextLabel = nextPreview[i];
        expect(
          previousLabel.text.data,
          settledLabel.text.data,
          reason: 'hour label text must match between preview and settled',
        );
        expect(
          previousLabel.color,
          settledLabel.color,
          reason: 'previous-preview hour label at rank $i must use the '
              'settled label color (preview renders 0.70, settled 0.54 — '
              'the label visibly changes at settle)',
        );
        expect(
          nextLabel.color,
          settledLabel.color,
          reason: 'next-preview hour label at rank $i must use the settled '
              'label color',
        );
      }
    },
  );
}

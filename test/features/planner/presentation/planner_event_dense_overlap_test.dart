import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Real Day-canvas regression for the owner-observed narrow five-column Event
/// collision. It exercises saved Events through the same repository, provider,
/// collision allocator, and `_TimelineEventBlock` route as production.
void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'five concurrent Events fit the 400dp Planner Day canvas without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(400, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startupRepository = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      final profile = await startupRepository.completeOnboarding();
      final links = DriftTaskEventLinkRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      final reports = DriftOutcomeReportingRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
        taskContextSource: links,
        linkContextTransfer: links,
        reportSource: reports,
      );
      final planner = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        calendarSource: calendar,
        taskContextSource: links,
        historicalEffectReader: reports,
      );

      for (var index = 0; index < 5; index++) {
        await calendar.saveEvent(
          profileId: profile.id,
          draft: CalendarEventDraft(
            id: '90000000-0000-4000-8000-00000000000$index',
            title: index.isEven
                ? 'Report status fixture ${index + 1}'
                : 'Statusless fixture ${index + 1}',
            timing: CalendarEventTiming.timed,
            startDate: selected,
            startMinute: 18 * 60,
            endMinute: 19 * 60,
            timeZoneId: 'Asia/Manila',
            requiresReport: index.isEven,
          ),
        );
      }

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startupRepository,
          plannerRepository: planner,
          calendarEventRepository: calendar,
          plannerDateSource: const FixedPlannerDateSource(selected),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();

      for (var index = 0; index < 5; index++) {
        final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
          eventId: '90000000-0000-4000-8000-00000000000$index',
          originalDate: selected,
        );
        expect(
          find.byKey(Key('planner-timed-event-$occurrenceId')),
          findsOneWidget,
        );
      }
      expect(
        tester.takeException(),
        isNull,
        reason:
            'five narrow collision columns must not overflow the Event block',
      );

      // A collision-column reflow must use the same current geometry as the
      // time grid in this frame. A wider viewport changes the five lanes
      // directly: there is no delayed Event transform or height/column settle.
      const firstEventId = '90000000-0000-4000-8000-000000000000';
      final firstOccurrence = CalendarEventOccurrenceIdentity.forDate(
        eventId: firstEventId,
        originalDate: selected,
      );
      final firstBlock = find.byKey(
        Key('planner-timed-event-$firstOccurrence'),
      );
      expect(firstBlock, findsOneWidget);
      final initialPositioned = tester.widget<Positioned>(firstBlock);
      final initialWidth = initialPositioned.width;
      tester.view.physicalSize = const Size(480, 844);
      await tester.pump();
      final resizedPositioned = tester.widget<Positioned>(firstBlock);
      expect(
        resizedPositioned.width,
        isNot(initialWidth),
        reason:
            'the Event column must use the new timeline width in the same frame',
      );
      expect(
        find.byKey(Key('event-geometry-$firstEventId')),
        findsNothing,
        reason: 'Event geometry must not be wrapped in a catch-up transition',
      );
      expect(
        find.byKey(Key('planner-timed-event-$firstOccurrence')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

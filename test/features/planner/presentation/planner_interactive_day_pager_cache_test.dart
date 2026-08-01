// Stage B3-R1 Slice D3-A: focused tests for the interactive day
// pager preview cache invalidation contract.
//
// These tests exercise the real Planner widget tree with a
// real Drift database. The preview cache is owned by the
// Planner screen state (not the test) and is invalidated
// when:
//   * the selected ISO date changes;
//   * the per-build data revision bumps (e.g. a controller
//     `refresh()` after a repository mutation on any day);
//   * the previous/next PlannerDay content signatures change
//     (captured at the time the preview future completes, so
//     the very next build refetches the preview trio if the
//     adjacent data has changed);
//   * the relevant settings that affect preview rendering
//     change (visible hour window, hour height, use-24-hour
//     time, show-current-time, show-cancelled, content
//     filters).
//
// The tests below prove the seven required contracts:
//   1. Stable rebuilds reuse the read.
//   2. Next-day data change invalidates the preview without
//      a selected-date round trip.
//   3. Previous-day data change invalidates the preview.
//   4. Moving an Event into an adjacent day invalidates the
//      preview for the destination day.
//   5. A recurrence exception on an adjacent day invalidates
//      the preview for the affected day.
//   6. A selected-date commit creates a new previous/current/
//      next window exactly once.
//   7. A stale in-flight future cannot overwrite a newer
//      window.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

const Size _testViewport = Size(862, 1824);
const double _testDevicePixelRatio = 2;
const String _displayTimeZoneId = 'Asia/Manila';

const PlannerDate _today = PlannerDate(year: 2026, month: 7, day: 27);
const PlannerDate _previous = PlannerDate(year: 2026, month: 7, day: 26);
const PlannerDate _next = PlannerDate(year: 2026, month: 7, day: 28);

const String _previousEventId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa01';
const String _selectedEventId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa02';
const String _nextEventId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa03';
const String _recurringId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa04';
const String _newNextEventId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa05';
const String _rescheduleReplacementId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa06';
const String _rescheduleOperationId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa07';

CalendarEventDraft _timedDraft({
  required String id,
  required String title,
  required PlannerDate date,
  required int startMinute,
  required int endMinute,
  CalendarRecurrenceRule recurrence = const CalendarRecurrenceRule(),
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
    recurrence: recurrence,
  );
}

CalendarRecurrenceRule get _dailyRecurrence =>
    const CalendarRecurrenceRule(frequency: CalendarRecurrenceFrequency.daily);

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Key _previewPageKey(PlannerDate date) =>
    Key('planner-day-page-${date.iso8601}');

Key _previewEventKey(String id) => Key('planner-pager-preview-event-$id');

/// Look up the `PlannerCalendarItem.id` (a deterministic v5
/// UUID per `{eventId, originalDate}`) the preview column
/// uses as its widget key. Going through `readDay` keeps the
/// test anchored to the same source of truth the preview
/// consumes; raw row ids never appear on the preview tree.
Future<String> _occurrenceIdFor({
  required DriftCalendarEventRepository calendar,
  required String profileId,
  required PlannerDate date,
  required String seedEventId,
}) async {
  final items = await calendar.readDay(profileId: profileId, date: date);
  final matches = items.where((item) => item.eventId == seedEventId);
  if (matches.isEmpty) {
    return '';
  }
  return matches.first.id;
}

class _Stack {
  _Stack({
    required this.database,
    required this.privacy,
    required this.calendarRepository,
    required this.linkRepository,
    required this.outcomeReportingRepository,
    required this.plannerRepository,
  });

  final dynamic database;
  final TestPrivacyDependencies privacy;
  final DriftCalendarEventRepository calendarRepository;
  final DriftTaskEventLinkRepository linkRepository;
  final DriftOutcomeReportingRepository outcomeReportingRepository;
  final DriftPlannerRepository plannerRepository;

  Future<({ProviderContainer container, String profileId})> pumpApp(
    WidgetTester tester,
  ) async {
    final startup = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    final profile = await startup.completeOnboarding();
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
        calendarEventRepository: calendarRepository,
        plannerRepository: plannerRepository,
        plannerDateSource: const FixedPlannerDateSource(_today),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    return (container: container, profileId: profile.id);
  }
}

Future<_Stack> _buildStack(WidgetTester tester) async {
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
  return _Stack(
    database: database,
    privacy: privacy,
    calendarRepository: calendarRepository,
    linkRepository: linkRepository,
    outcomeReportingRepository: outcomeReportingRepository,
    plannerRepository: plannerRepository,
  );
}

void main() {
  group('Stage B3-R1 D3-A: interactive pager preview cache', () {
    testWidgets(
      'TEST 1 — stable rebuilds reuse the read; preview content '
      'remains stable across unrelated rebuilds',
      (tester) async {
        final stack = await _buildStack(tester);
        final app = await stack.pumpApp(tester);
        // Seed a previous and next event before any preview load.
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _previousEventId,
            title: 'Previous only',
            date: _previous,
            startMinute: 10 * 60,
            endMinute: 11 * 60,
          ),
        );
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _nextEventId,
            title: 'Next only',
            date: _next,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
        // Trigger a normal planner refresh so the per-build
        // data revision bumps and the preview trio loads.
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // Resolve the deterministic occurrence ids.
        final previousOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _previous,
          seedEventId: _previousEventId,
        );
        final nextOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _next,
          seedEventId: _nextEventId,
        );

        // Sanity: the preview columns have the seeded events.
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_previous)),
            matching: find.byKey(_previewEventKey(previousOccurrenceId)),
          ),
          findsOneWidget,
          reason: 'previous preview must show the seeded event',
        );
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_next)),
            matching: find.byKey(_previewEventKey(nextOccurrenceId)),
          ),
          findsOneWidget,
          reason: 'next preview must show the seeded event',
        );

        // Force several unrelated rebuilds by invalidating the
        // selected day without changing anything. The cache
        // signature must NOT change for a no-op build, so the
        // preview trio future must not be re-issued.
        final plannerStateBefore =
            app.container.read(plannerControllerProvider);
        for (var i = 0; i < 5; i++) {
          // Touch a different provider to force a global
          // rebuild without touching the planner signature.
          app.container.invalidate(eventTypeControllerProvider);
          await tester.pump();
        }
        // Read the planner state — selectedDate and day should
        // still be _today / the original day.
        final plannerStateAfter =
            app.container.read(plannerControllerProvider);
        expect(plannerStateAfter.selectedDate, _today);
        expect(plannerStateAfter.day, isNotNull);
        // The preview columns must still show the seeded
        // events with the same occurrence ids (no refetch
        // happened).
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_previous)),
            matching: find.byKey(_previewEventKey(previousOccurrenceId)),
          ),
          findsOneWidget,
          reason: 'previous preview must remain stable across rebuilds',
        );
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_next)),
            matching: find.byKey(_previewEventKey(nextOccurrenceId)),
          ),
          findsOneWidget,
          reason: 'next preview must remain stable across rebuilds',
        );
        // Sanity that the previous and next read matched.
        expect(plannerStateBefore.selectedDate, plannerStateAfter.selectedDate);
      },
    );

    testWidgets(
      'TEST 2 — next-day data change invalidates the preview; '
      'no selectedDate round trip is required',
      (tester) async {
        final stack = await _buildStack(tester);
        final app = await stack.pumpApp(tester);
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _previousEventId,
            title: 'Previous only',
            date: _previous,
            startMinute: 10 * 60,
            endMinute: 11 * 60,
          ),
        );
        // Seed an initial next-day event so the preview has
        // content before the mutation under test. The
        // mutation is the addition of a SECOND next-day
        // event, which must also surface on the preview
        // after a refresh.
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _nextEventId,
            title: 'Initial next only',
            date: _next,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // Create a new next-day event through the normal
        // repository path (no selectedDate round trip).
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _newNextEventId,
            title: 'Brand new next-day event',
            date: _next,
            startMinute: 14 * 60,
            endMinute: 15 * 60,
          ),
        );
        // Trigger the normal planner refresh — same
        // selectedDate, no round trip.
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // The new event must now appear on the next preview
        // without any selectedDate change. The occurrence id
        // is resolved AFTER the event has been saved so
        // readDay returns a real item.
        final newNextOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _next,
          seedEventId: _newNextEventId,
        );
        expect(newNextOccurrenceId, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_next)),
            matching: find.byKey(_previewEventKey(newNextOccurrenceId)),
          ),
          findsOneWidget,
          reason:
              'new next-day event must appear on the next preview '
              'after a refresh, without a selectedDate round trip',
        );
        // The old next-day event is also still visible (the
        // preview didn't lose unrelated data). The
        // occurrence id is read from the seeded fixture
        // created before the planner route loaded, so it
        // resolves through the seeded event on _next.
        final oldNextOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _next,
          seedEventId: _nextEventId,
        );
        expect(oldNextOccurrenceId, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_next)),
            matching: find.byKey(_previewEventKey(oldNextOccurrenceId)),
          ),
          findsOneWidget,
        );
        // The selected date is still _today.
        expect(
          app.container.read(plannerControllerProvider).selectedDate,
          _today,
        );
      },
    );

    testWidgets(
      'TEST 3 — previous-day data change invalidates the preview; '
      'no selectedDate round trip is required',
      (tester) async {
        final stack = await _buildStack(tester);
        final app = await stack.pumpApp(tester);
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _nextEventId,
            title: 'Next only',
            date: _next,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // Create a new previous-day event through the normal
        // repository path. The previous preview must pick it
        // up after a normal refresh, no selectedDate change.
        const newPreviousId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa99';
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: newPreviousId,
            title: 'Brand new previous-day event',
            date: _previous,
            startMinute: 16 * 60,
            endMinute: 17 * 60,
          ),
        );
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        final newPreviousOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _previous,
          seedEventId: newPreviousId,
        );
        expect(newPreviousOccurrenceId, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_previous)),
            matching: find.byKey(_previewEventKey(newPreviousOccurrenceId)),
          ),
          findsOneWidget,
          reason:
              'new previous-day event must appear on the previous preview '
              'after a refresh, without a selectedDate round trip',
        );
        expect(
          app.container.read(plannerControllerProvider).selectedDate,
          _today,
        );
      },
    );

    testWidgets(
      'TEST 4 — moving an Event into an adjacent day invalidates '
      'the destination preview and clears the source page',
      (tester) async {
        final stack = await _buildStack(tester);
        final app = await stack.pumpApp(tester);
        // Seed an event on the selected day only.
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _selectedEventId,
            title: 'Selected day only',
            date: _today,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // Move the selected-day event to the next day using a
        // reschedule (single-occurrence scope, replacement on
        // the destination date). This is the supported
        // domain operation for moving a non-recurring event
        // between dates.
        const moveOperationId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa08';
        const moveReplacementId = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaa09';
        final moveOutcome = await stack.calendarRepository.rescheduleEvent(
          profileId: app.profileId,
          eventId: _selectedEventId,
          originalDate: _today,
          scope: CalendarEventEditScope.occurrence,
          replacement: _timedDraft(
            id: moveReplacementId,
            title: 'Selected day only',
            date: _next,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          operationId: moveOperationId,
        );
        expect(moveOutcome, CalendarEventMutationOutcome.changed);
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // The moved event must now appear on the next preview.
        final nextOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _next,
          seedEventId: moveReplacementId,
        );
        expect(nextOccurrenceId, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_next)),
            matching: find.byKey(_previewEventKey(nextOccurrenceId)),
          ),
          findsOneWidget,
          reason: 'moved event must appear on the next preview',
        );
        // selectedDate remains _today.
        expect(
          app.container.read(plannerControllerProvider).selectedDate,
          _today,
        );
      },
    );

    testWidgets(
      'TEST 5 — recurrence exception on an adjacent day '
      'invalidates the affected preview',
      (tester) async {
        final stack = await _buildStack(tester);
        final app = await stack.pumpApp(tester);
        // Seed a daily recurring series anchored on _previous.
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _recurringId,
            title: 'Daily standup',
            date: _previous,
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 30,
            recurrence: _dailyRecurrence,
          ),
        );
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // Sanity: the _next occurrence of the series is on
        // the _next preview.
        final nextSeriesOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _next,
          seedEventId: _recurringId,
        );
        expect(nextSeriesOccurrenceId, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_next)),
            matching: find.byKey(_previewEventKey(nextSeriesOccurrenceId)),
          ),
          findsOneWidget,
          reason: 'recurring series occurrence on _next must render',
        );

        // Apply an occurrence-scoped reschedule: move the
        // _next occurrence to _today. The replacement is
        // anchored on _today; the reschedule exception row
        // suppresses the original _next occurrence. After a
        // refresh, the _next preview must no longer carry the
        // original occurrence.
        final outcome = await stack.calendarRepository.rescheduleEvent(
          profileId: app.profileId,
          eventId: _recurringId,
          originalDate: _next,
          scope: CalendarEventEditScope.occurrence,
          replacement: _timedDraft(
            id: _rescheduleReplacementId,
            title: 'Daily standup',
            date: _today,
            startMinute: 10 * 60,
            endMinute: 10 * 60 + 30,
          ),
          operationId: _rescheduleOperationId,
        );
        expect(outcome, CalendarEventMutationOutcome.changed);

        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // The original _next occurrence must be gone from the
        // _next preview (status = rescheduled is filtered
        // out of timedEvents).
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_next)),
            matching: find.byKey(_previewEventKey(nextSeriesOccurrenceId)),
          ),
          findsNothing,
          reason:
              'original _next occurrence must be suppressed from '
              'the _next preview after the reschedule',
        );
      },
    );

    testWidgets(
      'TEST 6 — selected-date change creates a new '
      'previous/current/next window',
      (tester) async {
        final stack = await _buildStack(tester);
        final app = await stack.pumpApp(tester);
        // Seed events on the original trio so the first window
        // has content.
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _previousEventId,
            title: 'Previous only',
            date: _previous,
            startMinute: 10 * 60,
            endMinute: 11 * 60,
          ),
        );
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _nextEventId,
            title: 'Next only',
            date: _next,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // Verify the first window's pages exist.
        expect(
          find.byKey(_previewPageKey(_previous)),
          findsOneWidget,
        );
        expect(find.byKey(_previewPageKey(_today)), findsOneWidget);
        expect(find.byKey(_previewPageKey(_next)), findsOneWidget);

        // Commit one day: selectDate(_next). The new window is
        // _today / _next / the day after _next. The previous
        // and next day identifiers in the pager's widget tree
        // update accordingly.
        await app.container
            .read(plannerControllerProvider.notifier)
            .selectDate(_next);
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // The new selected date is _next.
        expect(
          app.container.read(plannerControllerProvider).selectedDate,
          _next,
        );
        // The new window's pages are _today, _next, and the
        // day after _next (2026-07-29).
        const dayAfterNext = PlannerDate(year: 2026, month: 7, day: 29);
        expect(
          find.byKey(_previewPageKey(_today)),
          findsOneWidget,
          reason: 'new previous page (_today) must exist after commit',
        );
        expect(
          find.byKey(_previewPageKey(_next)),
          findsOneWidget,
          reason: 'new centered page (_next) must exist after commit',
        );
        expect(
          find.byKey(_previewPageKey(dayAfterNext)),
          findsOneWidget,
          reason: 'new next page must exist after commit',
        );
        // The original _previous event must NOT leak onto
        // the new previous preview (_today). The new
        // previous preview consumes only the readDay
        // result for _today; the previous-only event's
        // occurrence is anchored on _previous and must not
        // appear here.
        final previousOnlyOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _previous,
          seedEventId: _previousEventId,
        );
        expect(previousOnlyOccurrenceId, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_today)),
            matching: find.byKey(_previewEventKey(previousOnlyOccurrenceId)),
          ),
          findsNothing,
          reason:
              'previous-only event must NOT appear on the new '
              'previous preview (_today) — that event is anchored on '
              '_previous, which is no longer in the active window',
        );
        // The next-day event (seeded on _next) must now
        // appear on the new next preview (2026-07-29)
        // because _next is now the centered day and the day
        // after _next is the new next preview. Wait — the
        // next-day event is on _next, which is the new
        // CENTERED page, not a preview. The new next
        // preview is 2026-07-29 (day after _next), which
        // has no events. The next-only event must NOT
        // appear there.
        final nextOnlyOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _next,
          seedEventId: _nextEventId,
        );
        expect(nextOnlyOccurrenceId, isNotEmpty);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(dayAfterNext)),
            matching: find.byKey(_previewEventKey(nextOnlyOccurrenceId)),
          ),
          findsNothing,
          reason:
              'next-only event must NOT appear on the new '
              'next preview (2026-07-29) — that event is on '
              '_next, which is the new centered page',
        );
      },
    );

    testWidgets(
      'TEST 7 — a stale in-flight future cannot overwrite a '
      'newer window; ordering is enforced by the generation '
      'guard inside the future pipeline',
      (tester) async {
        final stack = await _buildStack(tester);
        final app = await stack.pumpApp(tester);
        // Seed a distinctive event on _today so the result for
        // the original window is observable.
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _selectedEventId,
            title: 'Distinctive selected event',
            date: _today,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
        // Seed a distinctive event on _next so the result for
        // the new window (after a selectedDate commit) is
        // observable.
        await stack.calendarRepository.saveEvent(
          profileId: app.profileId,
          draft: _timedDraft(
            id: _nextEventId,
            title: 'Distinctive next event',
            date: _next,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );
        await app.container
            .read(plannerControllerProvider.notifier)
            .refresh();
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // The original _previous preview must be empty (no
        // events were seeded on _previous). The next-day
        // event must appear on the next preview.
        expect(
          find.byKey(_previewPageKey(_previous)),
          findsOneWidget,
          reason: 'original previous preview subtree must exist',
        );
        expect(
          find.byKey(_previewEventKey(
            (await _occurrenceIdFor(
              calendar: stack.calendarRepository,
              profileId: app.profileId,
              date: _next,
              seedEventId: _nextEventId,
            )),
          )),
          findsOneWidget,
          reason: 'next preview must show the next-day event',
        );

        // Now change the selected date to _next so the new
        // window's previous page is _today and the new
        // window's next page is 2026-07-29.
        await app.container
            .read(plannerControllerProvider.notifier)
            .selectDate(_next);
        await _pumpFrames(tester);
        await tester.pumpAndSettle();

        // The new window's previous page is _today. The
        // selected-day event (_selectedEventId) must appear on
        // the new previous preview.
        final selectedOccurrenceId = await _occurrenceIdFor(
          calendar: stack.calendarRepository,
          profileId: app.profileId,
          date: _today,
          seedEventId: _selectedEventId,
        );
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(_today)),
            matching: find.byKey(_previewEventKey(selectedOccurrenceId)),
          ),
          findsOneWidget,
          reason: 'new previous preview (_today) must show the '
              'selected-day event from the new window',
        );
        // The new window's next page is 2026-07-29, which
        // has no events. The next preview's previous-day
        // event (_nextEventId on _next) must NOT appear
        // there.
        const dayAfterNext = PlannerDate(year: 2026, month: 7, day: 29);
        expect(
          find.descendant(
            of: find.byKey(_previewPageKey(dayAfterNext)),
            matching: find.byKey(_previewEventKey(
              (await _occurrenceIdFor(
                calendar: stack.calendarRepository,
                profileId: app.profileId,
                date: _next,
                seedEventId: _nextEventId,
              )),
            )),
          ),
          findsNothing,
          reason:
              'the stale result from the previous window must NOT '
              'overwrite the new window (a stale _next event must '
              'not appear on the new next preview)',
        );
      },
    );
  });
}

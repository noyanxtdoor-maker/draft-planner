import 'dart:async';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_timeline_view.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_resolver.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_report_status.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const contactId = 'c6000000-0000-4000-8000-000000000201';
  const secondContactId = 'c6000000-0000-4000-8000-000000000202';
  const emptyContactId = 'c6000000-0000-4000-8000-000000000203';
  const today = PlannerDate(year: 2026, month: 8, day: 25);

  testWidgets(
    'Aa Gomez shape: Timeline refresh resolves duplicate legacy snapshots without moving the reader',
    (tester) async {
      final clock = _MutableClock(DateTime.utc(2026, 8, 25, 8));
      final ticks = StreamController<DateTime>();
      addTearDown(ticks.close);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final privacy = TestPrivacyDependencies(database: database);
      final contacts = DriftContactRepository(
        database: database,
        clock: clock,
        identifiers: UuidIdentifierSource(),
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: contactId,
          firstName: 'C6',
          lastName: 'Refresh',
          displayName: 'C6 Refresh',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: emptyContactId,
          firstName: 'Empty',
          lastName: 'Timeline',
          displayName: 'Empty Timeline',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: secondContactId,
          firstName: 'Other',
          lastName: 'Timeline',
          displayName: 'Other Timeline',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      const eventId = 'c6000000-0000-4000-8000-000000000221';
      await calendar.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Boundary event',
          timing: CalendarEventTiming.timed,
          startDate: today,
          startMinute: 16 * 60,
          endMinute: 16 * 60 + 30,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
        ),
      );
      await contacts.setEventPeople(
        profileId: profile.id,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[contactId],
      );
      const secondEventId = 'c6000000-0000-4000-8000-000000000222';
      await calendar.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: secondEventId,
          title: 'Other contact future',
          timing: CalendarEventTiming.timed,
          startDate: PlannerDate(year: 2026, month: 8, day: 26),
          startMinute: 10 * 60,
          endMinute: 10 * 60 + 30,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
        ),
      );
      await contacts.setEventPeople(
        profileId: profile.id,
        eventId: secondEventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[secondContactId],
      );
      const primaryFutureEventId = 'c6000000-0000-4000-8000-000000000223';
      await calendar.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: primaryFutureEventId,
          title: 'Primary future event',
          timing: CalendarEventTiming.timed,
          startDate: PlannerDate(year: 2026, month: 8, day: 26),
          startMinute: 11 * 60,
          endMinute: 11 * 60 + 30,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
        ),
      );
      await contacts.setEventPeople(
        profileId: profile.id,
        eventId: primaryFutureEventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[contactId],
      );
      const recurringEventId = 'c6000000-0000-4000-8000-000000000224';
      await calendar.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: recurringEventId,
          title: 'Long recurring event',
          timing: CalendarEventTiming.timed,
          startDate: PlannerDate(year: 2026, month: 8, day: 10),
          startMinute: 17 * 60 + 30,
          endMinute: 18 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
          recurrence: CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.daily,
          ),
        ),
      );
      await contacts.setEventPeople(
        profileId: profile.id,
        eventId: recurringEventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[contactId],
      );
      for (var index = 0; index < 8; index++) {
        final id = 'c6000000-0000-4000-8000-00000000023$index';
        await calendar.saveEvent(
          profileId: profile.id,
          draft: CalendarEventDraft(
            id: id,
            title: 'Historical $index',
            timing: CalendarEventTiming.timed,
            startDate: PlannerDate(year: 2026, month: 8, day: 16 - index),
            startMinute: 9 * 60,
            endMinute: 9 * 60 + 30,
            timeZoneId: 'Asia/Manila',
            requiresReport: false,
          ),
        );
        await contacts.setEventPeople(
          profileId: profile.id,
          eventId: id,
          occurrenceId: DriftContactRepository.seriesOccurrenceId,
          contactIds: const <String>[contactId],
        );
      }
      const duplicateEventId = 'c6000000-0000-4000-8000-000000000230';
      const duplicateDate = PlannerDate(year: 2026, month: 8, day: 16);
      final duplicateOccurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: duplicateEventId,
        originalDate: duplicateDate,
      );
      // Reproduce the inherited pre-index shape without changing production
      // schema: many factual rows describe one historical participant tuple.
      await database.customStatement(
        'DROP INDEX IF EXISTS event_occurrence_participant_unique',
      );
      for (var index = 0; index < 98; index++) {
        await database
            .into(database.eventOccurrenceParticipants)
            .insert(
              EventOccurrenceParticipantsCompanion.insert(
                id: 'c6-ui-duplicate-$index',
                profileId: profile.id,
                eventId: duplicateEventId,
                occurrenceId: duplicateOccurrenceId,
                originalDate: duplicateDate.iso8601,
                contactId: contactId,
                displayNameSnapshot: 'C6 Refresh',
                createdAtUtc: clock.value,
              ),
            );
      }
      await (database.update(
        database.calendarEvents,
      )..where((table) => table.id.equals(duplicateEventId))).write(
        const CalendarEventsCompanion(
          timeZoneId: Value<String?>('Legacy/Unknown'),
        ),
      );
      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(today),
          contactRepository: contacts,
          extraOverrides: <Override>[
            contactTimelineClockProvider.overrideWith((ref) => ticks.stream),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-contacts')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C6 Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Boundary event'), findsOneWidget);

      clock.value = DateTime.utc(2026, 8, 25, 8, 31);
      ticks.add(clock.value);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Boundary event'), findsNothing);

      await tester.tap(find.text('Timeline'));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.text('Long recurring event'), findsWidgets);
      final timelineContainer = ProviderScope.containerOf(
        tester.element(find.byType(NextTransferApp)),
      );
      expect(
        timelineContainer
            .read(contactTimelineProvider(contactId))
            .requireValue
            .timelineFuture
            .where((entry) => entry.eventId == primaryFutureEventId),
        hasLength(1),
      );
      await (database.update(
        database.calendarEvents,
      )..where((table) => table.id.equals(primaryFutureEventId))).write(
        const CalendarEventsCompanion(status: Value<String>('cancelled')),
      );
      await tester.pumpAndSettle();
      expect(
        timelineContainer
            .read(contactTimelineProvider(contactId))
            .requireValue
            .timelineFuture
            .where((entry) => entry.eventId == primaryFutureEventId),
        isEmpty,
        reason:
            'The production Timeline provider must reread from the Event '
            'table notification without a clock tick.',
      );
      final timelineScroller = find.descendant(
        of: find.byKey(const Key('contact-timeline-list')),
        matching: find.byType(Scrollable),
      );
      final timelineList = find.byKey(const Key('contact-timeline-list'));
      expect(
        tester.widget(timelineList),
        isA<CustomScrollView>(),
        reason:
            'The real Contact Detail route must use the approved sticky '
            'Timeline viewport.',
      );
      final timelineViewport = tester.getRect(timelineScroller);
      expect(timelineViewport.width, greaterThan(0));
      expect(timelineViewport.height, greaterThan(0));
      expect(
        timelineViewport.overlaps(tester.getRect(find.text('Future').first)),
        isTrue,
        reason: 'The Future header must physically paint inside the viewport.',
      );
      expect(
        timelineViewport.overlaps(
          tester.getRect(find.text('Long recurring event').first),
        ),
        isTrue,
        reason: 'At least one Timeline card must have visible paint bounds.',
      );
      expect(find.text('Long recurring event').hitTestable(), findsWidgets);
      await tester.drag(timelineScroller, const Offset(0, -260));
      await tester.pumpAndSettle();
      final offsetBeforeRefresh = tester
          .state<ScrollableState>(timelineScroller)
          .position
          .pixels;
      expect(offsetBeforeRefresh, greaterThan(0));

      // Hold the real repository read pending while a clock dependency reload
      // is active. The resolved ListView must remain mounted throughout.
      final scrollableStateBeforeRefresh = tester.state<ScrollableState>(
        timelineScroller,
      );
      final transactionStarted = Completer<void>();
      final releaseTransaction = Completer<void>();
      final heldTransaction = database.transaction(() async {
        await (database.update(
          database.calendarEvents,
        )..where((table) => table.id.equals(recurringEventId))).write(
          const CalendarEventsCompanion(
            title: Value<String>('Long recurring event updated'),
          ),
        );
        transactionStarted.complete();
        await releaseTransaction.future;
      });
      await transactionStarted.future;
      ticks.add(clock.value);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Long recurring event'), findsWidgets);
      expect(
        identical(
          tester.state<ScrollableState>(timelineScroller),
          scrollableStateBeforeRefresh,
        ),
        isTrue,
      );
      expect(
        tester.state<ScrollableState>(timelineScroller).position.pixels,
        closeTo(offsetBeforeRefresh, 0.5),
      );
      releaseTransaction.complete();
      await heldTransaction;
      await tester.pumpAndSettle();
      expect(find.text('Long recurring event updated'), findsWidgets);
      expect(
        identical(
          tester.state<ScrollableState>(timelineScroller),
          scrollableStateBeforeRefresh,
        ),
        isTrue,
      );
      expect(
        tester.state<ScrollableState>(timelineScroller).position.pixels,
        closeTo(offsetBeforeRefresh, 0.5),
      );
      // Recreating the real Timeline tab must still produce a valid viewport
      // with an intersecting, hit-testable factual card. The restoration does
      // not retain a separate cross-disposal Timeline controller/state.
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(tester.widget(timelineList), isA<CustomScrollView>());
      final reopenedScroller = find.descendant(
        of: timelineList,
        matching: find.byType(Scrollable),
      );
      final reopenedPosition = tester
          .state<ScrollableState>(reopenedScroller)
          .position;
      expect(
        reopenedPosition.pixels,
        inInclusiveRange(
          reopenedPosition.minScrollExtent,
          reopenedPosition.maxScrollExtent,
        ),
      );
      final reopenedViewport = tester.getRect(reopenedScroller);
      final visibleTimelineCard = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            (key.value.startsWith('timeline-card-') ||
                key.value.startsWith('timeline-task-card-'));
      }).hitTestable();
      expect(visibleTimelineCard, findsWidgets);
      expect(
        reopenedViewport.overlaps(tester.getRect(visibleTimelineCard.first)),
        isTrue,
      );
      expect(
        await (database.select(database.eventOccurrenceParticipants)..where(
              (table) =>
                  table.eventId.equals(duplicateEventId) &
                  table.occurrenceId.equals(duplicateOccurrenceId) &
                  table.contactId.equals(contactId),
            ))
            .get(),
        hasLength(98),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NextTransferApp)),
      );
      container
          .read(appRouterProvider)
          .go(RoutePaths.contactDetail(secondContactId));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.text('Boundary event'),
        findsNothing,
        reason: 'A different Contact must never settle with retained data.',
      );
      if (find.byKey(const Key('contact-timeline-list')).evaluate().isEmpty) {
        await tester.tap(find.text('Timeline'));
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pumpAndSettle();
      }
      expect(find.text('Other contact future'), findsOneWidget);
      final switchedScroller = find.descendant(
        of: find.byKey(const Key('contact-timeline-list')),
        matching: find.byType(Scrollable),
      );
      final switchedViewport = tester.getRect(switchedScroller);
      expect(
        switchedViewport.overlaps(
          tester.getRect(find.text('Other contact future').first),
        ),
        isTrue,
      );
      expect(find.text('Other contact future').hitTestable(), findsOneWidget);

      container
          .read(appRouterProvider)
          .go(RoutePaths.contactDetail(emptyContactId));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Other contact future'), findsNothing);
      if (find.byKey(const Key('contact-timeline-list')).evaluate().isEmpty) {
        await tester.tap(find.text('Timeline'));
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pumpAndSettle();
      }
      expect(find.text('Record Created'), findsOneWidget);
      final emptyScroller = find.descendant(
        of: find.byKey(const Key('contact-timeline-list')),
        matching: find.byType(Scrollable),
      );
      final emptyViewport = tester.getRect(emptyScroller);
      expect(
        emptyViewport.overlaps(tester.getRect(find.text('History').first)),
        isTrue,
        reason: 'A factually empty Contact still paints the History header.',
      );
      expect(
        emptyViewport.overlaps(tester.getRect(find.text('Record Created'))),
        isTrue,
        reason: 'Record Created must prevent a blank factual Timeline.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'C6: Profile shows nearest three, centered See more, and Timeline reverses them',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const profileToday = PlannerDate(year: 2026, month: 8, day: 30);

      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final privacy = TestPrivacyDependencies(database: database);
      final contacts = DriftContactRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 30, 4)),
        identifiers: UuidIdentifierSource(),
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 30, 4)),
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: contactId,
          firstName: 'C6',
          lastName: 'Visible',
          displayName: 'C6 Visible',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      final events = <(String, String, PlannerDate, int)>[
        (
          'c6000000-0000-4000-8000-000000000211',
          'Event Sep 2',
          const PlannerDate(year: 2026, month: 9, day: 2),
          18 * 60,
        ),
        (
          'c6000000-0000-4000-8000-000000000212',
          'Event Sep 1',
          const PlannerDate(year: 2026, month: 9, day: 1),
          13 * 60 + 30,
        ),
      ];
      for (final event in events) {
        await calendar.saveEvent(
          profileId: profile.id,
          draft: CalendarEventDraft(
            id: event.$1,
            title: event.$2,
            timing: CalendarEventTiming.timed,
            startDate: event.$3,
            startMinute: event.$4,
            endMinute: event.$4 + 30,
            timeZoneId: 'Asia/Manila',
            requiresReport: false,
          ),
        );
        await contacts.setEventPeople(
          profileId: profile.id,
          eventId: event.$1,
          occurrenceId: DriftContactRepository.seriesOccurrenceId,
          contactIds: const <String>[contactId],
        );
      }

      final createdAt = DateTime.utc(2026, 8, 25, 2);
      Future<void> seedTask({
        required String id,
        required String title,
        String? dueDate,
        int? dueMinute,
        PlannerTaskStatus status = PlannerTaskStatus.incomplete,
      }) async {
        await database
            .into(database.plannerTasks)
            .insert(
              PlannerTasksCompanion.insert(
                id: id,
                profileId: profile.id,
                title: title,
                dueDate: dueDate == null
                    ? const Value<String>.absent()
                    : Value<String>(dueDate),
                dueMinute: Value<int?>(dueMinute),
                status: Value<String>(status.name),
                createdAtUtc: createdAt,
                updatedAtUtc: createdAt,
              ),
            );
        await database
            .into(database.taskContactLinks)
            .insert(
              TaskContactLinksCompanion.insert(
                id: 'profile-link-$id',
                profileId: profile.id,
                taskId: id,
                contactId: contactId,
                createdAtUtc: createdAt,
              ),
            );
      }

      await seedTask(
        id: 'profile-task-aug31',
        title: 'Task Aug 31',
        dueDate: '2026-08-31',
        dueMinute: 9 * 60,
      );
      await seedTask(
        id: 'profile-task-sep4',
        title: 'Task Sep 4',
        dueDate: '2026-09-04',
        dueMinute: 9 * 60,
      );
      await seedTask(
        id: 'profile-task-overdue',
        title: 'Overdue Task Aug 27',
        dueDate: '2026-08-27',
      );
      await seedTask(id: 'profile-task-undated', title: 'Undated Task');
      await seedTask(
        id: 'profile-task-completed',
        title: 'Completed Task',
        dueDate: '2026-09-03',
        status: PlannerTaskStatus.completed,
      );

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(profileToday),
          contactRepository: contacts,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-contacts')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C6 Visible'));
      await tester.pumpAndSettle();

      expect(find.text('Task Aug 31'), findsOneWidget);
      expect(find.text('Event Sep 1'), findsOneWidget);
      expect(find.text('Event Sep 2'), findsOneWidget);
      expect(find.text('Task Sep 4'), findsNothing);
      expect(find.text('Overdue Task Aug 27'), findsNothing);
      expect(find.text('Undated Task'), findsNothing);
      expect(find.text('Completed Task'), findsNothing);
      final more = find.byKey(const Key('profile-upcoming-see-more'));
      expect(more, findsOneWidget);
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(more).dx,
        closeTo(tester.view.physicalSize.width / 2, 1),
        reason: 'The affordance is physically centered, not left aligned.',
      );

      final visibleItemOrder = <String>[
        'Task Aug 31',
        'Event Sep 1',
        'Event Sep 2',
        'See more →',
      ].map((label) => tester.getTopLeft(find.text(label).first).dy).toList();
      for (var index = 1; index < visibleItemOrder.length; index++) {
        expect(
          visibleItemOrder[index],
          greaterThan(visibleItemOrder[index - 1]),
        );
      }
      expect(
        find.byKey(const Key('profile-upcoming-task-profile-task-sep4')),
        findsNothing,
        reason: 'Tasks must not render as a second list below See more.',
      );

      await tester.tap(
        find.byKey(const Key('profile-upcoming-task-profile-task-aug31')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-detail-title')), findsOneWidget);
      expect(find.text('Task Aug 31'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile-next-event')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-detail-title')), findsOneWidget);
      expect(find.text('Event Sep 1'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact-timeline-list')), findsOneWidget);
      final order = <String>[
        'Task Sep 4',
        'Event Sep 2',
        'Event Sep 1',
        'Task Aug 31',
      ];
      final positions = order
          .map((title) => tester.getTopLeft(find.text(title).first).dy)
          .toList(growable: false);
      for (var index = 1; index < positions.length; index++) {
        expect(positions[index], greaterThan(positions[index - 1]));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('C6: Common Events does not render an empty shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommonEventsPanel(patterns: <CommonEventPattern>[]),
        ),
      ),
    );
    expect(find.byKey(const Key('common-events-panel')), findsNothing);
  });

  testWidgets(
    'Contact Timeline: Common Happened Events sits above Future and History',
    (tester) async {
      const date = PlannerDate(year: 2026, month: 8, day: 25);
      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 26, 10),
            title: 'Future event',
            eventId: 'future-event',
            originalDate: date,
            occurrenceId: 'future-event:2026-08-25',
            isUpcoming: true,
          ),
        ],
        history: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 24, 10),
            title: 'History event',
            eventId: 'history-event',
            originalDate: date,
            occurrenceId: 'history-event:2026-08-25',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                const CommonEventsPanel(
                  patterns: <CommonEventPattern>[
                    CommonEventPattern(
                      eventId: 'common-event',
                      title: 'Repeated visit',
                      weekdayLabel: 'Monday',
                      startMinuteLabel: '10:00 AM',
                      count: 3,
                    ),
                  ],
                ),
                Expanded(
                  child: ContactTimelineView(
                    timeline: timeline,
                    eventColorsByTypeId: const <String, EventColorPreference>{},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final futureTop = tester.getTopLeft(find.text('Future event')).dy;
      final commonTop = tester
          .getTopLeft(find.byKey(const Key('common-events-panel')))
          .dy;
      final historyTop = tester.getTopLeft(find.text('History')).dy;
      expect(commonTop, lessThan(futureTop));
      expect(commonTop, lessThan(historyTop));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Restored Contact Timeline defers the banner and paints temple visit as a normal Event card',
    (tester) async {
      const date = PlannerDate(year: 2026, month: 9, day: 14);
      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 9, 14, 9),
            title: 'Temple Visit',
            eventId: 'temple-event',
            originalDate: date,
            occurrenceId: 'temple-event:2026-09-14',
            activityTypeStableKey: SystemEventTypeKeys.templeVisit,
            isUpcoming: true,
          ),
        ],
        history: const <ContactTimelineEntry>[],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: timeline,
              eventColorsByTypeId: const <String, EventColorPreference>{},
            ),
          ),
        ),
      );

      expect(find.text('Scheduled Temple Visit: Sep 14, 2026'), findsNothing);
      expect(find.text('Temple Visit'), findsOneWidget);
      expect(
        find.byKey(const Key('timeline-card-temple-event:2026-09-14')),
        findsOneWidget,
      );
      expect(
        tester.widget(find.byKey(const Key('contact-timeline-list'))),
        isA<CustomScrollView>(),
      );
    },
  );

  testWidgets(
    'Contact Timeline: History uses the canonical Planner report-status colors',
    (tester) async {
      const date = PlannerDate(year: 2026, month: 8, day: 24);
      final timeline = ContactTimeline(
        upcoming: const <ContactTimelineEntry>[],
        history: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 24, 9),
            title: 'DNA event',
            status: CalendarEventStatus.didNotHappen,
            statusLabel: 'Did Not Attempt',
          ),
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 24, 10),
            title: 'Missed event',
            status: CalendarEventStatus.partiallyCompleted,
            statusLabel: 'Missed',
          ),
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 24, 11),
            title: 'Completed event',
            status: CalendarEventStatus.completedHappened,
            statusLabel: 'Completed',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: timeline,
              eventColorsByTypeId: const <String, EventColorPreference>{},
            ),
          ),
        ),
      );

      Color labelColor(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;
      final context = tester.element(find.text('Did Not Attempt'));
      expect(
        labelColor('Did Not Attempt'),
        PlannerEventReportStatus.labelColorFor(
          context,
          PlannerReportStatusKind.didNotAttempt,
        ),
      );
      expect(
        labelColor('Missed'),
        PlannerEventReportStatus.labelColorFor(
          context,
          PlannerReportStatusKind.missedAttempted,
        ),
      );
      expect(
        labelColor('Completed'),
        PlannerEventReportStatus.labelColorFor(
          context,
          PlannerReportStatusKind.completed,
        ),
      );
    },
  );

  testWidgets('C6: Timeline Event color resolves from Planner preferences', (
    tester,
  ) async {
    Color? resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            resolved = PlannerEventColorResolver.accentColorForIdentity(
              context,
              activityTypeId: 'event-type',
              activityTypeColorValue: 0xFF00FF00,
              preferencesByTypeId: const <String, EventColorPreference>{
                'event-type': EventColorPreference(
                  accentArgb: 0xFFAA00FF,
                  surfaceArgb: 0xFF330044,
                ),
              },
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, const Color(0xFFAA00FF));
  });

  testWidgets(
    'C6 Pass C: Future shows Scheduled while History keeps canonical outcomes on one spine',
    (tester) async {
      const date = PlannerDate(year: 2026, month: 8, day: 25);
      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 17),
            title: 'Future event',
            subtitle: '5:00 PM – 5:30 PM',
            status: CalendarEventStatus.scheduled,
            statusLabel: 'Scheduled',
            eventId: 'future',
            originalDate: date,
            occurrenceId: 'future:2026-08-25',
            isUpcoming: true,
          ),
        ],
        history: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 15),
            title: 'Normal passed event',
            status: CalendarEventStatus.scheduled,
            eventId: 'normal',
            originalDate: date,
            occurrenceId: 'normal:2026-08-25',
          ),
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 14),
            title: 'Reported event',
            status: CalendarEventStatus.completedHappened,
            statusLabel: 'Completed',
            eventId: 'completed',
            originalDate: date,
            occurrenceId: 'completed:2026-08-25',
          ),
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 13),
            title: 'Awaiting event',
            status: CalendarEventStatus.scheduled,
            statusLabel: 'Unreported',
            eventId: 'unreported',
            originalDate: date,
            occurrenceId: 'unreported:2026-08-25',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: timeline,
              eventColorsByTypeId: <String, EventColorPreference>{},
            ),
          ),
        ),
      );

      expect(find.text('Future event'), findsOneWidget);
      expect(find.text('5:00 PM – 5:30 PM'), findsOneWidget);
      expect(find.text('Normal passed event'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Unreported'), findsOneWidget);
      expect(
        find.text('Scheduled'),
        findsOneWidget,
        reason: 'Only the Future Event card retains the Scheduled label.',
      );
      expect(
        find.byKey(const Key('timeline-history-spine-connector')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('timeline-section-divider-future-history')),
        findsNothing,
      );
      final dividerFinder = find.byKey(
        const Key('timeline-section-header-divider-history'),
      );
      expect(dividerFinder, findsOneWidget);
      final dividerRect = tester.getRect(dividerFinder);
      final headerRect = tester.getRect(
        find.byKey(const Key('timeline-section-history')),
      );
      expect(dividerRect.left, greaterThanOrEqualTo(headerRect.left + 16));
      expect(dividerRect.right, lessThanOrEqualTo(headerRect.right - 16));
      expect(dividerRect.height, 1);
      final futureStyle = tester.widget<Text>(find.text('Future')).style!;
      final historyStyle = tester.widget<Text>(find.text('History')).style!;
      expect(futureStyle.fontSize, 16);
      expect(futureStyle.fontWeight, FontWeight.w600);
      expect(futureStyle.letterSpacing ?? 0, 0);
      expect(historyStyle.color, futureStyle.color);
    },
  );

  testWidgets(
    'C6 Pass A: Future and History are year-aware on independent spines',
    (tester) async {
      ContactTimelineEntry entry({
        required int year,
        required int month,
        required int day,
        required String title,
        required bool upcoming,
      }) {
        final date = PlannerDate(year: year, month: month, day: day);
        return ContactTimelineEntry(
          kind: ContactTimelineKind.eventOccurrence,
          date: date,
          chronology: DateTime(year, month, day, upcoming ? 18 : 9),
          title: title,
          subtitle: upcoming ? '6:00 PM – 6:30 PM' : null,
          eventId: title,
          originalDate: date,
          occurrenceId: '$title:$year-$month-$day',
          isUpcoming: upcoming,
        );
      }

      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          entry(
            year: 2026,
            month: 12,
            day: 28,
            title: 'Future 2026',
            upcoming: true,
          ),
          entry(
            year: 2027,
            month: 1,
            day: 12,
            title: 'Future 2027',
            upcoming: true,
          ),
        ],
        history: <ContactTimelineEntry>[
          entry(
            year: 2026,
            month: 8,
            day: 25,
            title: 'History 2026',
            upcoming: false,
          ),
          entry(
            year: 2025,
            month: 12,
            day: 18,
            title: 'History 2025',
            upcoming: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: timeline,
              eventColorsByTypeId: const <String, EventColorPreference>{},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('timeline-future-year-2027')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-future-year-2026')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-history-year-2026')),
        findsOneWidget,
      );
      expect(find.text('Future 2027'), findsOneWidget);
      expect(find.text('Future 2026'), findsOneWidget);
      expect(find.text('History 2026'), findsOneWidget);
      expect(
        find.byKey(const Key('timeline-spine-gap-Future 2027:2027-1-12')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-spine-gap-Future 2026:2026-12-28')),
        findsNothing,
        reason: 'The final Future entry must not connect into History.',
      );
      await tester.scrollUntilVisible(
        find.text('History 2025'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('timeline-history-year-2025')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-history-spine-connector')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('timeline-section-divider-future-history')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('timeline-section-header-divider-history')),
        findsOneWidget,
      );
      expect(find.text('History 2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _MutableClock implements AppClock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

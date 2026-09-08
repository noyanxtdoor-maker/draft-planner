import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_detail_screen.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);
  const eventId = '88888888-8888-4888-8888-888888888889';
  const contactId = '88888888-8888-4888-8888-888888888890';
  const inheritedSeriesContactId = '88888888-8888-4888-8888-888888888891';

  Future<AppDatabase> pumpApp(
    WidgetTester tester, {
    required CalendarEventDraft draft,
    bool linkContact = false,
    bool seedSeriesContact = false,
    bool seedParticipantSnapshot = false,
    DateTime? clockUtc,
  }) async {
    final effectiveClockUtc = clockUtc ?? DateTime.utc(2026, 7, 27, 12);
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startupRepository = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    final profile = await startupRepository.completeOnboarding();
    final linkRepository = DriftTaskEventLinkRepository(
      database: database,
      clock: FixedClock(effectiveClockUtc),
    );
    final calendarRepository = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(effectiveClockUtc),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      taskContextSource: linkRepository,
      linkContextTransfer: linkRepository,
    );
    final plannerRepository = DriftPlannerRepository(
      database: database,
      clock: FixedClock(effectiveClockUtc),
      calendarSource: calendarRepository,
      taskContextSource: linkRepository,
    );
    final contactRepository = DriftContactRepository(
      database: database,
      clock: FixedClock(effectiveClockUtc),
      identifiers: UuidIdentifierSource(),
    );
    await contactRepository.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: contactId,
        firstName: 'Scoped',
        lastName: 'Person',
        displayName: 'Scoped Person',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
      ),
    );
    await contactRepository.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: inheritedSeriesContactId,
        firstName: 'Series',
        lastName: 'Person',
        displayName: 'Series Person',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
      ),
    );
    await calendarRepository.saveEvent(profileId: profile.id, draft: draft);
    if (seedSeriesContact) {
      await contactRepository.setEventPeople(
        profileId: profile.id,
        eventId: draft.id,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[inheritedSeriesContactId],
      );
    }
    if (linkContact) {
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: draft.id,
        originalDate: draft.startDate,
      );
      await contactRepository.setEventPeople(
        profileId: profile.id,
        eventId: draft.id,
        occurrenceId: occurrenceId,
        originalDate: draft.startDate,
        contactIds: const <String>[contactId],
      );
      if (seedParticipantSnapshot) {
        await database
            .into(database.eventOccurrenceParticipants)
            .insert(
              EventOccurrenceParticipantsCompanion.insert(
                id: 'saved-event-unlink-snapshot',
                profileId: profile.id,
                eventId: draft.id,
                occurrenceId: occurrenceId,
                originalDate: draft.startDate.iso8601,
                contactId: contactId,
                displayNameSnapshot: 'Scoped Person',
                createdAtUtc: effectiveClockUtc,
              ),
            );
      }
    }
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startupRepository,
        plannerRepository: plannerRepository,
        calendarEventRepository: calendarRepository,
        contactRepository: contactRepository,
        plannerDateSource: const FixedPlannerDateSource(selected),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    final plannerScroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('planner-day-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    plannerScroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    return database;
  }

  CalendarEventDraft weeklyDraft({String title = 'Weekly Review'}) {
    return CalendarEventDraft(
      id: eventId,
      title: title,
      timing: CalendarEventTiming.timed,
      startDate: selected,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      timeZoneId: 'Asia/Manila',
      requiresReport: false,
      recurrence: const CalendarRecurrenceRule(
        frequency: CalendarRecurrenceFrequency.weekly,
      ),
    );
  }

  Future<void> openEditFromPlanner(WidgetTester tester) async {
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: selected,
    );
    await tester.tap(find.byKey(Key('planner-timed-event-$occurrenceId')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('event-detail-sheet-edit-icon')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('event-detail-sheet-edit-icon')));
    await tester.pumpAndSettle();
  }

  Future<void> addScopedPerson(WidgetTester tester) async {
    final addPeople = find.byKey(const Key('add-people-button'));
    await tester.scrollUntilVisible(
      addPeople,
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('calendar-event-form-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(addPeople);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-people-$contactId')));
    await tester.tap(find.byKey(const Key('add-people-done')));
    await tester.pump(const Duration(milliseconds: 600));
    final formScrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('calendar-event-form-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    formScrollable.position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'Event Preview Contact row opens the exact canonical Contact Profile',
    (tester) async {
      await pumpApp(tester, draft: weeklyDraft(), linkContact: true);
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: selected,
      );
      await tester.tap(find.byKey(Key('planner-timed-event-$occurrenceId')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('event-preview-contact-$contactId')),
      );
      await tester.pump(const Duration(milliseconds: 800));
      final detail = tester.widget<ContactDetailScreen>(
        find.byType(ContactDetailScreen),
      );
      expect(detail.contactId, contactId);
    },
  );

  testWidgets(
    'saved Event edit removes an exact-only Contact after People load and '
    'cannot be resurrected by its preserved historical participant snapshot',
    (tester) async {
      final database = await pumpApp(
        tester,
        draft: weeklyDraft(),
        linkContact: true,
        seedParticipantSnapshot: true,
        clockUtc: DateTime.utc(2026, 7, 27, 2),
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: selected,
      );
      await openEditFromPlanner(tester);
      final removePerson = find.byKey(
        const Key('remove-event-person-$contactId'),
      );
      await tester.scrollUntilVisible(
        removePerson,
        500,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('calendar-event-form-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(removePerson, findsOneWidget);
      await tester.tap(removePerson);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('event-scope-this')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      if (find
          .byKey(const Key('event-detail-sheet-edit-icon'))
          .evaluate()
          .isEmpty) {
        await tester.tap(find.byKey(Key('planner-timed-event-$occurrenceId')));
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(
        find.byKey(const Key('event-detail-sheet-edit-icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-preview-contact-$contactId')),
        findsNothing,
      );
      final links = await database.select(database.eventContactLinks).get();
      final snapshots = await database
          .select(database.eventOccurrenceParticipants)
          .get();
      expect(
        links.where(
          (row) =>
              row.contactId == contactId &&
              row.occurrenceId == occurrenceId &&
              row.status == 'removed',
        ),
        hasLength(1),
      );
      expect(
        links.where(
          (row) => row.contactId == contactId && row.status == 'active',
        ),
        isEmpty,
      );
      expect(
        snapshots.where(
          (row) =>
              row.contactId == contactId && row.occurrenceId == occurrenceId,
        ),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('event-detail-sheet-close')));
      await tester.pump(const Duration(milliseconds: 500));
      await openEditFromPlanner(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('add-people-button')),
        500,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('calendar-event-form-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(removePerson, findsNothing);
    },
  );

  testWidgets(
    'Delta 4.1 D4.1-02: repeating preview Edit opens the form immediately '
    '(no scope chooser); Save with a change shows the chooser; This event '
    'only updates only that occurrence',
    (tester) async {
      final database = await pumpApp(
        tester,
        draft: weeklyDraft(),
        seedSeriesContact: true,
      );
      await openEditFromPlanner(tester);
      await addScopedPerson(tester);

      // The form is open first.  No recurrence chooser before the form.
      expect(find.byKey(const Key('save-event-button')), findsOneWidget);
      expect(find.text('Change repeating event'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Renamed occurrence',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-event-button')));
      // Fixed pumps: while the scope chooser is up the Save button shows a
      // spinner, so pumpAndSettle would never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The scope chooser appears only now, on Save.
      expect(find.text('Change repeating event'), findsOneWidget);
      expect(find.byKey(const Key('event-scope-this')), findsOneWidget);
      expect(find.byKey(const Key('event-scope-all')), findsOneWidget);
      expect(find.byKey(const Key('event-scope-cancel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-scope-this')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Only the selected occurrence changes; the series master stays.
      final master = await database.select(database.calendarEvents).getSingle();
      expect(master.title, 'Weekly Review');
      final exceptions = await database
          .select(database.calendarEventExceptions)
          .get();
      expect(exceptions, hasLength(1));
      expect(exceptions.single.title, 'Renamed occurrence');
      expect(exceptions.single.status, CalendarEventStatus.scheduled.name);
      expect(exceptions.single.originalDate, selected.iso8601);
      final operations = await database
          .select(database.calendarEventOperations)
          .get();
      expect(operations.single.command, 'edit:occurrence');
      final links = await database.select(database.eventContactLinks).get();
      final seriesLinks = links
          .where(
            (link) =>
                link.occurrenceId == DriftContactRepository.seriesOccurrenceId,
          )
          .toList();
      expect(seriesLinks, hasLength(1));
      expect(seriesLinks.single.contactId, inheritedSeriesContactId);
      final occurrenceLinks = links
          .where(
            (link) =>
                link.occurrenceId != DriftContactRepository.seriesOccurrenceId,
          )
          .toList();
      expect(
        occurrenceLinks,
        hasLength(1),
        reason:
            'an inherited Contact that remains selected needs no occurrence '
            'override; only the newly added Contact is persisted as a delta.',
      );
      expect(occurrenceLinks.single.contactId, contactId);
      expect(
        occurrenceLinks.first.occurrenceId,
        CalendarEventOccurrenceIdentity.forDate(
          eventId: eventId,
          originalDate: selected,
        ),
      );
      expect(
        occurrenceLinks.every((link) => link.originalDate == selected.iso8601),
        isTrue,
      );
    },
  );

  testWidgets(
    'Delta 4.1 D4.1-02: repeating Save with All events updates the series '
    'master and no exception is created',
    (tester) async {
      final database = await pumpApp(tester, draft: weeklyDraft());
      await openEditFromPlanner(tester);
      await addScopedPerson(tester);
      expect(find.text('Change repeating event'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Renamed series',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Change repeating event'), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-scope-all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final master = await database.select(database.calendarEvents).getSingle();
      expect(master.title, 'Renamed series');
      expect(master.recurrenceFrequency, 'weekly');
      expect(master.recurrenceEndMode, 'never');
      expect(master.recurrencePatternJson, isNull);
      final exceptions = await database
          .select(database.calendarEventExceptions)
          .get();
      expect(exceptions, isEmpty);
      final operations = await database
          .select(database.calendarEventOperations)
          .get();
      expect(operations.single.command, 'edit:series');
      final links = await database.select(database.eventContactLinks).get();
      expect(links, hasLength(1));
      expect(links.single.eventId, eventId);
      expect(
        links.single.occurrenceId,
        DriftContactRepository.seriesOccurrenceId,
      );
      expect(links.single.originalDate, isNull);
    },
  );

  testWidgets(
    'Delta 4.2F: editing a legacy count-ended series preserves its count rule',
    (tester) async {
      final database = await pumpApp(
        tester,
        draft: weeklyDraft().copyWith(
          recurrence: const CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.weekly,
            endMode: CalendarRecurrenceEndMode.afterCount,
            occurrenceCount: 4,
          ),
        ),
      );
      await openEditFromPlanner(tester);
      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Legacy count retained',
      );
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Change repeating event'), findsOneWidget);
      await tester.tap(find.byKey(const Key('event-scope-all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final master = await database.select(database.calendarEvents).getSingle();
      expect(master.title, 'Legacy count retained');
      expect(master.recurrenceFrequency, 'weekly');
      expect(master.recurrenceEndMode, 'afterCount');
      expect(master.recurrenceCount, 4);
      expect(master.recurrencePatternJson, isNull);
    },
  );

  testWidgets(
    'Delta 4.1 D4.1-02: Cancel on the scope chooser persists nothing and '
    'keeps the edit form with its draft',
    (tester) async {
      final database = await pumpApp(tester, draft: weeklyDraft());
      await openEditFromPlanner(tester);

      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Should not persist',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Change repeating event'), findsOneWidget);

      await tester.tap(find.byKey(const Key('event-scope-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // No mutation, no operation, no exception; the form is still open with
      // the draft text intact.
      final master = await database.select(database.calendarEvents).getSingle();
      expect(master.title, 'Weekly Review');
      expect(
        await database.select(database.calendarEventExceptions).get(),
        isEmpty,
      );
      expect(
        await database.select(database.calendarEventOperations).get(),
        isEmpty,
      );
      expect(find.byKey(const Key('save-event-button')), findsOneWidget);
      final titleField = tester.widget<TextFormField>(
        find.byKey(const Key('event-title-field')),
      );
      expect(titleField.controller!.text, 'Should not persist');
    },
  );

  testWidgets(
    'Delta 4.1 D4.1-02: repeating Edit with no change and Back shows no '
    'scope chooser and persists nothing',
    (tester) async {
      final database = await pumpApp(tester, draft: weeklyDraft());
      await openEditFromPlanner(tester);
      expect(find.text('Change repeating event'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Change repeating event'), findsNothing);
      expect(find.byKey(const Key('save-event-button')), findsNothing);
      expect(
        await database.select(database.calendarEventOperations).get(),
        isEmpty,
      );
      expect(
        await database.select(database.calendarEventExceptions).get(),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Delta 4.1 D4.1-02: a normal non-repeating preview Edit opens the form '
    'and saves directly with no scope chooser',
    (tester) async {
      final database = await pumpApp(
        tester,
        draft: weeklyDraft().copyWith(
          title: 'Standalone Event',
          recurrence: const CalendarRecurrenceRule(),
        ),
      );
      await openEditFromPlanner(tester);
      expect(find.byKey(const Key('save-event-button')), findsOneWidget);
      expect(find.text('Change repeating event'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Standalone renamed',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Change repeating event'), findsNothing);
      final master = await database.select(database.calendarEvents).getSingle();
      expect(master.title, 'Standalone renamed');
      expect(
        await database.select(database.calendarEventExceptions).get(),
        isEmpty,
      );
    },
  );
}

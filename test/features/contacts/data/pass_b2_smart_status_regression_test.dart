import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

/// Pass B2 regression lock: exercise Smart Status through persisted Contacts
/// and Event participation.  These are deliberately black-box repository
/// tests; presentation must never reimplement the history classifier.
void main() {
  final clock = FixedClock(DateTime.utc(2026, 8, 3, 12));
  const today = PlannerDate(year: 2026, month: 8, day: 3);

  Future<
    (AppDatabase, DriftContactRepository, DriftCalendarEventRepository, String)
  >
  arrange() async {
    final database = openMemoryDatabase();
    final profile = await buildTestRepository(database: database)
        .completeOnboarding();
    return (
      database,
      DriftContactRepository(
        database: database,
        clock: clock,
        identifiers: UuidIdentifierSource(),
      ),
      DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      ),
      profile.id,
    );
  }

  ContactDraft contact(String id) => ContactDraft(
        id: id,
        firstName: id,
        lastName: 'Contact',
        displayName: '$id Contact',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
      );

  Future<void> addInteraction({
    required DriftCalendarEventRepository calendar,
    required DriftContactRepository contacts,
    required String profileId,
    required String contactId,
    required int serial,
    required int daysAgo,
    CalendarEventStatus status = CalendarEventStatus.scheduled,
  }) async {
    final value = DateTime.utc(2026, 8, 3).subtract(Duration(days: daysAgo));
    final eventId = '00000000-0000-4000-8000-${serial.toString().padLeft(12, '0')}';
    await calendar.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: eventId,
        title: 'Interaction $serial',
        timing: CalendarEventTiming.timed,
        startDate: PlannerDate(year: value.year, month: value.month, day: value.day),
        startMinute: 600,
        endMinute: 660,
        timeZoneId: 'Asia/Manila',
        requiresReport: false,
        status: status,
        recurrence: const CalendarRecurrenceRule(
          frequency: CalendarRecurrenceFrequency.none,
        ),
      ),
    );
    await contacts.setEventPeople(
      profileId: profileId,
      eventId: eventId,
      occurrenceId: 'series',
      contactIds: <String>[contactId],
    );
  }

  Future<List<ContactSummary>> aggregate(
    DriftContactRepository contacts,
    String profileId,
  ) => contacts.readContacts(
    profileId: profileId,
    criteria: const ContactFilterCriteria(),
    sortBy: ContactSortBy.name,
    today: today,
    standardView: const ContactStandardView(filter: ContactStandardFilter.status),
  );

  test('B2 direct: smart activation is off at three active Contacts and on at four',
      () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>['qualifying', 'padding-1', 'padding-2']) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    for (final entry in <int>[25, 18, 10, 2].indexed) {
      await addInteraction(
        calendar: calendar,
        contacts: contacts,
        profileId: profileId,
        contactId: 'qualifying',
        serial: entry.$1 + 1,
        daysAgo: entry.$2,
      );
    }
    final below = await aggregate(contacts, profileId);
    final belowQualifying = below.singleWhere(
      (item) => item.contact.id == 'qualifying',
    );
    expect(belowQualifying.smartStatus, isNull);

    await contacts.createContact(
      profileId: profileId,
      draft: contact('padding-3'),
    );
    final atThreshold = await aggregate(contacts, profileId);
    final atThresholdQualifying = atThreshold.singleWhere(
      (item) => item.contact.id == 'qualifying',
    );
    expect(
      atThresholdQualifying.smartStatus,
      ContactSmartStatus.frequentConnection,
    );
  });

  test('B2 direct: smart thresholds, priority, one-place assignment, and factual fallback', () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>['reconnected', 'frequent', 'regular', 'soon', 'fallback']) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    var serial = 1;
    Future<void> dates(String id, List<int> days) async {
      for (final day in days) {
        await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: id, serial: serial++, daysAgo: day);
      }
    }
    // This qualifies both reconnect and Frequent; reconnect must win.
    await dates('reconnected', <int>[150, 25, 18, 10, 2]);
    // This qualifies both Frequent and Regular; Frequent must win.
    await dates('frequent', <int>[60, 30, 20, 10, 1]);
    await dates('regular', <int>[80, 45, 20]);
    await dates('soon', <int>[150, 100, 60]);

    final rows = await aggregate(contacts, profileId);
    final byId = <String, ContactSummary>{for (final row in rows) row.contact.id: row};
    expect(byId['reconnected']!.smartStatus, ContactSmartStatus.recentlyReconnected);
    expect(byId['frequent']!.smartStatus, ContactSmartStatus.frequentConnection);
    expect(byId['regular']!.smartStatus, ContactSmartStatus.regularConnection);
    expect(byId['soon']!.smartStatus, ContactSmartStatus.reconnectSoon);
    expect(byId['fallback']!.smartStatus, isNull);
    expect(byId['fallback']!.statusBucket, ContactStatusBucket.notInteractedYet);
    expect(rows.map((row) => row.contact.id).toSet(), hasLength(rows.length));
  });

  test('B2 direct: Frequent requires four distinct dates and Reconnect Soon requires three', () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>[
      'frequent-four',
      'frequent-three',
      'soon-two',
      'padding-1',
      'padding-2',
      'padding-3',
    ]) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    var serial = 50;
    Future<void> dates(String id, List<int> days) async {
      for (final day in days) {
        await addInteraction(
          calendar: calendar,
          contacts: contacts,
          profileId: profileId,
          contactId: id,
          serial: serial++,
          daysAgo: day,
        );
      }
    }

    await dates('frequent-four', <int>[30, 20, 10, 1]);
    await dates('frequent-three', <int>[29, 19, 9]);
    await dates('soon-two', <int>[100, 60]);

    final byId = <String, ContactSummary>{
      for (final row in await aggregate(contacts, profileId)) row.contact.id: row,
    };
    expect(
      byId['frequent-four']!.smartStatus,
      ContactSmartStatus.frequentConnection,
    );
    expect(
      byId['frequent-three']!.smartStatus,
      isNot(ContactSmartStatus.frequentConnection),
    );
    expect(
      byId['soon-two']!.smartStatus,
      isNot(ContactSmartStatus.reconnectSoon),
    );
  });

  test('B2 direct: qualifying status truth and distinct-date thresholds are shared by Recent Contact', () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>['qualifying', 'excluded', 'deduped', 'other']) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    var serial = 100;
    for (final entry in <(CalendarEventStatus, int)>[
      (CalendarEventStatus.scheduled, 3),
      (CalendarEventStatus.completedHappened, 2),
      (CalendarEventStatus.partiallyCompleted, 1),
    ]) {
      await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'qualifying', serial: serial++, daysAgo: entry.$2, status: entry.$1);
    }
    for (final status in <CalendarEventStatus>[CalendarEventStatus.didNotHappen, CalendarEventStatus.cancelled, CalendarEventStatus.rescheduled]) {
      await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'excluded', serial: serial++, daysAgo: 10, status: status);
    }
    // Four qualifying records on the same date are one date, not Frequent.
    for (var i = 0; i < 4; i++) {
      await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'deduped', serial: serial++, daysAgo: 10);
    }
    final rows = await aggregate(contacts, profileId);
    final byId = <String, ContactSummary>{for (final row in rows) row.contact.id: row};
    expect(byId['qualifying']!.latestQualifyingInteractionDate, isNotNull);
    expect(byId['excluded']!.latestQualifyingInteractionDate, isNull);
    expect(byId['deduped']!.smartStatus, isNot(ContactSmartStatus.frequentConnection));

    final contacted = await contacts.readContacts(profileId: profileId, criteria: const ContactFilterCriteria(), sortBy: ContactSortBy.name, today: today, standardView: const ContactStandardView(filter: ContactStandardFilter.recentlyContacted));
    final noRecent = await contacts.readContacts(profileId: profileId, criteria: const ContactFilterCriteria(), sortBy: ContactSortBy.name, today: today, standardView: const ContactStandardView(filter: ContactStandardFilter.noRecentContact));
    expect(contacted.map((row) => row.contact.id), containsAll(<String>['qualifying', 'deduped']));
    expect(contacted.map((row) => row.contact.id), isNot(contains('excluded')));
    expect(noRecent.map((row) => row.contact.id), contains('excluded'));
  });

  test('B2 direct: locked reconnect, Regular span/latest, and Reconnect Soon window boundaries', () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>[
      'gap90',
      'gap89',
      'regular30',
      'regularSpan29',
      'regularLatest31',
      'soon91',
      'padding',
    ]) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    var serial = 300;
    Future<void> dates(String id, List<int> days) async {
      for (final day in days) {
        await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: id, serial: serial++, daysAgo: day);
      }
    }
    await dates('gap90', <int>[120, 30]); // exactly 90 days, return <=30.
    await dates('gap89', <int>[119, 30]); // 89 days must not reconnect.
    await dates('regular30', <int>[60, 45, 30]);
    // Latest is exactly 30 days ago; only the 29-day span fails.
    await dates('regularSpan29', <int>[59, 45, 30]);
    // Span is exactly 30 days; only the latest-date condition fails.
    await dates('regularLatest31', <int>[61, 45, 31]);
    await dates('soon91', <int>[170, 120, 91]);
    final byId = <String, ContactSummary>{for (final row in await aggregate(contacts, profileId)) row.contact.id: row};
    expect(byId['gap90']!.smartStatus, ContactSmartStatus.recentlyReconnected);
    expect(byId['gap89']!.smartStatus, isNot(ContactSmartStatus.recentlyReconnected));
    expect(byId['regular30']!.smartStatus, ContactSmartStatus.regularConnection);
    expect(byId['regularSpan29']!.smartStatus, isNot(ContactSmartStatus.regularConnection));
    expect(byId['regularLatest31']!.smartStatus, isNot(ContactSmartStatus.regularConnection));
    expect(byId['soon91']!.smartStatus, isNot(ContactSmartStatus.reconnectSoon));
  });

  test('B2 direct: later qualifying interactions preserve but do not extend a reconnect window', () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>['active-window', 'expired-window', 'padding-1', 'padding-2', 'padding-3']) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'active-window', serial: 400, daysAgo: 110);
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'active-window', serial: 401, daysAgo: 20);
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'active-window', serial: 402, daysAgo: 5);
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'expired-window', serial: 403, daysAgo: 130);
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'expired-window', serial: 404, daysAgo: 40);
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'expired-window', serial: 405, daysAgo: 5);
    final rows = <String, ContactSummary>{for (final row in await aggregate(contacts, profileId)) row.contact.id: row};
    expect(rows['active-window']!.smartStatus, ContactSmartStatus.recentlyReconnected);
    expect(rows['expired-window']!.smartStatus, isNot(ContactSmartStatus.recentlyReconnected));
  });

  test('B2 direct: Recently Viewed and Recently Created remain independent of Smart Status', () async {
    final (database, contacts, _, profileId) = await arrange();
    addTearDown(database.close);
    await contacts.createContact(profileId: profileId, draft: contact('viewed'));
    await contacts.createContact(profileId: profileId, draft: contact('created'));
    await (database.update(database.contacts)..where((row) => row.id.equals('viewed'))).write(
      ContactsCompanion(lastViewedAtUtc: Value(DateTime.utc(2026, 8, 1)), createdAtUtc: Value(DateTime.utc(2026, 1, 1))),
    );
    final viewed = await contacts.readContacts(profileId: profileId, criteria: const ContactFilterCriteria(), sortBy: ContactSortBy.name, today: today, standardView: const ContactStandardView(filter: ContactStandardFilter.recentlyViewed));
    final created = await contacts.readContacts(profileId: profileId, criteria: const ContactFilterCriteria(), sortBy: ContactSortBy.name, today: today, standardView: const ContactStandardView(filter: ContactStandardFilter.recentlyCreated));
    expect(viewed.map((row) => row.contact.id), contains('viewed'));
    expect(created.map((row) => row.contact.id), contains('created'));
    expect(created.map((row) => row.contact.id), isNot(contains('viewed')));
  });

  test('B2 direct: an effective exception status overrides its qualifying master', () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>['overridden', 'padding-1', 'padding-2', 'padding-3']) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    const eventId = '00000000-0000-4000-8000-000000000500';
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'overridden', serial: 500, daysAgo: 5);
    final date = const PlannerDate(year: 2026, month: 7, day: 29);
    await database.into(database.calendarEventExceptions).insert(CalendarEventExceptionsCompanion.insert(
      id: 'exception-500', profileId: profileId, eventId: eventId,
      occurrenceId: CalendarEventOccurrenceIdentity.forDate(eventId: eventId, originalDate: date),
      originalDate: date.toString(), effectiveDate: date.toString(), title: 'Interaction 500',
      timing: CalendarEventTiming.timed.name, status: CalendarEventStatus.cancelled.name,
      createdAtUtc: DateTime.utc(2026, 8, 3),
    ));
    final row = (await aggregate(contacts, profileId)).singleWhere((item) => item.contact.id == 'overridden');
    expect(row.latestQualifyingInteractionDate, isNull);
  });

  test('B2 direct: frozen historical participant survives later People removal and keeps canonical status truth', () async {
    final (database, contacts, calendar, profileId) = await arrange();
    addTearDown(database.close);
    for (final id in <String>['historical', 'padding-1', 'padding-2', 'padding-3']) {
      await contacts.createContact(profileId: profileId, draft: contact(id));
    }
    const eventId = '00000000-0000-4000-8000-000000000600';
    await addInteraction(calendar: calendar, contacts: contacts, profileId: profileId, contactId: 'historical', serial: 600, daysAgo: 10);
    await contacts.setEventPeople(profileId: profileId, eventId: eventId, occurrenceId: 'series', contactIds: const <String>[]);
    const date = PlannerDate(year: 2026, month: 7, day: 24);
    await database.into(database.eventOccurrenceParticipants).insert(
      EventOccurrenceParticipantsCompanion.insert(
        id: 'snapshot-600', profileId: profileId, eventId: eventId,
        occurrenceId: CalendarEventOccurrenceIdentity.forDate(eventId: eventId, originalDate: date),
        originalDate: date.toString(), contactId: 'historical',
        displayNameSnapshot: 'historical Contact', createdAtUtc: DateTime.utc(2026, 8, 3),
      ),
    );
    final retained = (await aggregate(contacts, profileId)).singleWhere((item) => item.contact.id == 'historical');
    expect(retained.latestQualifyingInteractionDate, date.asLocalDate);
    final contacted = await contacts.readContacts(profileId: profileId, criteria: const ContactFilterCriteria(), sortBy: ContactSortBy.name, today: today, standardView: const ContactStandardView(filter: ContactStandardFilter.recentlyContacted));
    expect(contacted.map((item) => item.contact.id), contains('historical'));
  });
}

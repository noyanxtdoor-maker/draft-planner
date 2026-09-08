import 'package:drift/drift.dart';
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

void main() {
  const today = PlannerDate(year: 2026, month: 8, day: 30);
  const future = PlannerDate(year: 2026, month: 9, day: 2);

  Future<
    ({
      AppDatabase database,
      DriftContactRepository contacts,
      DriftCalendarEventRepository calendar,
      String profileId,
    })
  >
  arrange() async {
    final database = openMemoryDatabase();
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 30, 2)),
      identifiers: UuidIdentifierSource(),
    );
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 30, 2)),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      duplicateContextTransfer: contacts,
    );
    return (
      database: database,
      contacts: contacts,
      calendar: calendar,
      profileId: profile.id,
    );
  }

  Future<void> createContact(
    DriftContactRepository contacts,
    String profileId,
    String id,
  ) => contacts.createContact(
    profileId: profileId,
    draft: ContactDraft(
      id: id,
      firstName: id,
      lastName: '',
      displayName: id,
      preferredContactMethod: ContactPreferredMethod.message,
      isFavorite: false,
    ),
  );

  test(
    'Slice A: a scheduled exception cannot revive a cancelled master and the '
    'Event remains a separate cancelled factual record',
    () async {
      final harness = await arrange();
      addTearDown(harness.database.close);
      const eventId = 'a0000000-0000-4000-8000-000000000001';
      const contactId = 'a-contact';
      await createContact(harness.contacts, harness.profileId, contactId);
      await harness.calendar.saveEvent(
        profileId: harness.profileId,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Cancelled master',
          timing: CalendarEventTiming.timed,
          startDate: future,
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: true,
          status: CalendarEventStatus.cancelled,
        ),
      );
      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[contactId],
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: future,
      );
      await harness.database
          .into(harness.database.calendarEventExceptions)
          .insert(
            CalendarEventExceptionsCompanion.insert(
              id: 'scheduled-exception',
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: occurrenceId,
              originalDate: future.iso8601,
              effectiveDate: future.iso8601,
              title: 'Cancelled master',
              timing: CalendarEventTiming.timed.name,
              startMinute: const Value<int?>(10 * 60),
              endMinute: const Value<int?>(11 * 60),
              timeZoneId: const Value<String?>('Asia/Manila'),
              requiresReport: const Value<bool>(true),
              status: CalendarEventStatus.scheduled.name,
              createdAtUtc: DateTime.utc(2026, 8, 30, 2),
            ),
          );

      final occurrence = await harness.calendar.readOccurrence(
        profileId: harness.profileId,
        eventId: eventId,
        originalDate: future,
      );
      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );

      expect(occurrence!.isStructurallyCancelled, isTrue);
      expect(timeline.upcoming, isEmpty);
      expect(
        timeline.history.where(
          (entry) => entry.kind == ContactTimelineKind.eventOccurrence,
        ),
        isEmpty,
      );
      expect(timeline.cancelledEvents, hasLength(1));
      expect(timeline.cancelledEvents.single.occurrenceId, occurrenceId);
      expect(timeline.cancelledEvents.single.isStructurallyCancelled, isTrue);
    },
  );

  test('Slice B: occurrence People resolve series plus exact active/removed '
      'deltas while series membership remains unchanged', () async {
    final harness = await arrange();
    addTearDown(harness.database.close);
    const eventId = 'b0000000-0000-4000-8000-000000000001';
    const inheritedKept = 'b-kept';
    const inheritedRemoved = 'b-removed';
    const occurrenceAdded = 'b-added';
    for (final id in <String>[
      inheritedKept,
      inheritedRemoved,
      occurrenceAdded,
    ]) {
      await createContact(harness.contacts, harness.profileId, id);
    }
    await harness.calendar.saveEvent(
      profileId: harness.profileId,
      draft: const CalendarEventDraft(
        id: eventId,
        title: 'People deltas',
        timing: CalendarEventTiming.timed,
        startDate: future,
        startMinute: 12 * 60,
        endMinute: 13 * 60,
        timeZoneId: 'Asia/Manila',
        requiresReport: false,
        recurrence: CalendarRecurrenceRule(
          frequency: CalendarRecurrenceFrequency.weekly,
        ),
      ),
    );
    await harness.contacts.setEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: DriftContactRepository.seriesOccurrenceId,
      contactIds: const <String>[inheritedKept, inheritedRemoved],
    );
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: future,
    );
    await harness.contacts.setEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: occurrenceId,
      originalDate: future,
      contactIds: const <String>[inheritedKept, occurrenceAdded],
    );

    final exact = await harness.contacts.readEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: occurrenceId,
      today: today,
    );
    final series = await harness.contacts.readEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: DriftContactRepository.seriesOccurrenceId,
      today: today,
    );
    final rows = await (harness.database.select(
      harness.database.eventContactLinks,
    )..where((row) => row.eventId.equals(eventId))).get();

    expect(exact.map((person) => person.contact.id).toSet(), <String>{
      inheritedKept,
      occurrenceAdded,
    });
    expect(series.map((person) => person.contact.id).toSet(), <String>{
      inheritedKept,
      inheritedRemoved,
    });
    expect(
      rows.where(
        (row) =>
            row.occurrenceId == occurrenceId && row.contactId == inheritedKept,
      ),
      isEmpty,
    );
    expect(
      rows
          .singleWhere(
            (row) =>
                row.occurrenceId == occurrenceId &&
                row.contactId == inheritedRemoved,
          )
          .status,
      'removed',
    );
    expect(
      rows
          .singleWhere(
            (row) =>
                row.occurrenceId == occurrenceId &&
                row.contactId == occurrenceAdded,
          )
          .status,
      'active',
    );
  });

  test('Slice C: duplicate copies coordinates and effective Contacts to a new '
      'standalone identity without reusing source relationships', () async {
    final harness = await arrange();
    addTearDown(harness.database.close);
    const sourceId = 'c0000000-0000-4000-8000-000000000001';
    const duplicateId = 'c0000000-0000-4000-8000-000000000002';
    const duplicateCId = 'c0000000-0000-4000-8000-000000000004';
    const duplicateDId = 'c0000000-0000-4000-8000-000000000006';
    const contactId = 'c-contact';
    await createContact(harness.contacts, harness.profileId, contactId);
    await harness.calendar.saveEvent(
      profileId: harness.profileId,
      draft: const CalendarEventDraft(
        id: sourceId,
        title: 'Mapped visit',
        timing: CalendarEventTiming.timed,
        startDate: future,
        startMinute: 14 * 60,
        endMinute: 15 * 60,
        timeZoneId: 'Asia/Manila',
        locationText: 'Canonical address',
        requiresReport: false,
      ),
    );
    await (harness.database.update(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals(sourceId))).write(
      const CalendarEventsCompanion(
        latitude: Value<double?>(14.5995),
        longitude: Value<double?>(120.9842),
        coordinateSource: Value<String?>('user-pin'),
      ),
    );
    await harness.contacts.setEventPeople(
      profileId: harness.profileId,
      eventId: sourceId,
      occurrenceId: DriftContactRepository.seriesOccurrenceId,
      contactIds: const <String>[contactId],
    );

    await harness.calendar.duplicateEvent(
      profileId: harness.profileId,
      eventId: sourceId,
      originalDate: future,
      duplicateId: duplicateId,
      operationId: 'c0000000-0000-4000-8000-000000000003',
    );
    await harness.calendar.duplicateEvent(
      profileId: harness.profileId,
      eventId: duplicateId,
      originalDate: future,
      duplicateId: duplicateCId,
      operationId: 'c0000000-0000-4000-8000-000000000005',
    );
    await harness.calendar.duplicateEvent(
      profileId: harness.profileId,
      eventId: duplicateCId,
      originalDate: future,
      duplicateId: duplicateDId,
      operationId: 'c0000000-0000-4000-8000-000000000007',
    );

    final duplicate = await (harness.database.select(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals(duplicateId))).getSingle();
    final duplicatePeople = await harness.contacts.readEventPeople(
      profileId: harness.profileId,
      eventId: duplicateId,
      occurrenceId: DriftContactRepository.seriesOccurrenceId,
      today: today,
    );
    final sourceLinks = await (harness.database.select(
      harness.database.eventContactLinks,
    )..where((row) => row.eventId.equals(sourceId))).get();
    final duplicateLinks = await (harness.database.select(
      harness.database.eventContactLinks,
    )..where((row) => row.eventId.equals(duplicateId))).get();
    final allEvents = await harness.database
        .select(harness.database.calendarEvents)
        .get();
    final allLinks = await harness.database
        .select(harness.database.eventContactLinks)
        .get();

    expect(duplicate.parentEventId, sourceId);
    expect(duplicate.latitude, 14.5995);
    expect(duplicate.longitude, 120.9842);
    expect(duplicate.coordinateSource, 'user-pin');
    expect(duplicate.locationText, 'Canonical address');
    expect(duplicate.status, CalendarEventStatus.scheduled.name);
    expect(
      duplicate.recurrenceFrequency,
      CalendarRecurrenceFrequency.none.name,
    );
    expect(duplicatePeople.single.contact.id, contactId);
    expect(sourceLinks.single.eventId, sourceId);
    expect(duplicateLinks.single.eventId, duplicateId);
    expect(duplicateLinks.single.occurrenceId, 'series');
    expect(duplicateLinks.single.id, isNot(sourceLinks.single.id));
    expect(allEvents.map((row) => row.id).toSet(), <String>{
      sourceId,
      duplicateId,
      duplicateCId,
      duplicateDId,
    });
    expect(allLinks.map((row) => row.eventId).toSet(), hasLength(4));
    expect(allLinks.map((row) => row.id).toSet(), hasLength(4));
  });

  test('E1 entire-series removal reconciles redundant and legacy exact active '
      'rows for only the explicitly removed Contact', () async {
    final harness = await arrange();
    addTearDown(harness.database.close);
    const eventId = 'e1000000-0000-4000-8000-000000000001';
    const removedId = 'e1-removed';
    const keptSeriesId = 'e1-kept-series';
    const keptOverrideId = 'e1-kept-override';
    for (final id in <String>[removedId, keptSeriesId, keptOverrideId]) {
      await createContact(harness.contacts, harness.profileId, id);
    }
    await harness.calendar.saveEvent(
      profileId: harness.profileId,
      draft: const CalendarEventDraft(
        id: eventId,
        title: 'Series People reconciliation',
        timing: CalendarEventTiming.timed,
        startDate: future,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        timeZoneId: 'Asia/Manila',
        requiresReport: false,
        recurrence: CalendarRecurrenceRule(
          frequency: CalendarRecurrenceFrequency.weekly,
        ),
      ),
    );
    await harness.contacts.setEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: DriftContactRepository.seriesOccurrenceId,
      contactIds: const <String>[removedId, keptSeriesId],
    );
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: future,
    );
    for (final item in <({String id, String contactId})>[
      (id: 'e1-redundant-removed', contactId: removedId),
      (id: 'e1-legitimate-override', contactId: keptOverrideId),
    ]) {
      await harness.database
          .into(harness.database.eventContactLinks)
          .insert(
            EventContactLinksCompanion.insert(
              id: item.id,
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: Value<String>(occurrenceId),
              originalDate: Value<String>(future.iso8601),
              contactId: item.contactId,
              status: const Value<String>('active'),
              createdAtUtc: DateTime.utc(2026, 8, 30, 2),
              updatedAtUtc: DateTime.utc(2026, 8, 30, 2),
            ),
          );
    }

    await harness.contacts.setEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: DriftContactRepository.seriesOccurrenceId,
      contactIds: const <String>[keptSeriesId],
      explicitlyRemovedSeriesContactIds: const <String>[removedId],
    );

    final rows = await (harness.database.select(
      harness.database.eventContactLinks,
    )..where((row) => row.eventId.equals(eventId))).get();
    expect(
      rows.where(
        (row) =>
            row.contactId == removedId &&
            row.occurrenceId == DriftContactRepository.seriesOccurrenceId &&
            row.status == 'removed',
      ),
      hasLength(1),
      reason:
          'An entire-series unlink needs a durable negative state so a '
          'preserved participant snapshot cannot revive the Contact.',
    );
    expect(
      rows.where((row) => row.contactId == removedId && row.status == 'active'),
      isEmpty,
    );
    expect(
      rows.where(
        (row) =>
            row.contactId == keptSeriesId &&
            row.occurrenceId == DriftContactRepository.seriesOccurrenceId,
      ),
      hasLength(1),
    );
    expect(
      rows.where(
        (row) =>
            row.contactId == keptOverrideId &&
            row.occurrenceId == occurrenceId &&
            row.status == 'active',
      ),
      hasLength(1),
    );
  });

  test(
    'E1 exact removal suppresses a future effective snapshot while preserving '
    'the series membership on neighboring recurrence dates',
    () async {
      final harness = await arrange();
      addTearDown(harness.database.close);
      const eventId = 'e1000000-0000-4000-8000-000000000002';
      const contactId = 'e1-occurrence-contact';
      await createContact(harness.contacts, harness.profileId, contactId);
      await harness.calendar.saveEvent(
        profileId: harness.profileId,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Occurrence People delta',
          timing: CalendarEventTiming.timed,
          startDate: future,
          startMinute: 11 * 60,
          endMinute: 12 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
          recurrence: CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.weekly,
          ),
        ),
      );
      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[contactId],
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: future,
      );
      await harness.database
          .into(harness.database.eventOccurrenceParticipants)
          .insert(
            EventOccurrenceParticipantsCompanion.insert(
              id: 'e1-future-snapshot',
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: occurrenceId,
              originalDate: future.iso8601,
              contactId: contactId,
              displayNameSnapshot: 'Occurrence Contact',
              createdAtUtc: DateTime.utc(2026, 8, 30, 2),
            ),
          );
      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: occurrenceId,
        originalDate: future,
        contactIds: const <String>[],
      );

      final exact = await harness.contacts.readEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: occurrenceId,
        today: today,
      );
      final series = await harness.contacts.readEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        today: today,
      );
      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );

      expect(exact, isEmpty);
      expect(series.map((person) => person.contact.id), contains(contactId));
      expect(
        timeline.timelineFuture.where(
          (entry) => entry.occurrenceId == occurrenceId,
        ),
        isEmpty,
      );
    },
  );

  test(
    'saved occurrence unlink writes a durable exact tombstone when the only '
    'active relationship was exact and preserves the factual snapshot',
    () async {
      final harness = await arrange();
      addTearDown(harness.database.close);
      const eventId = 'e1000000-0000-4000-8000-000000000003';
      const contactId = 'e1-exact-only-contact';
      await createContact(harness.contacts, harness.profileId, contactId);
      await harness.calendar.saveEvent(
        profileId: harness.profileId,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Exact only People unlink',
          timing: CalendarEventTiming.timed,
          startDate: future,
          startMinute: 13 * 60,
          endMinute: 14 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
        ),
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: future,
      );
      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: occurrenceId,
        originalDate: future,
        contactIds: const <String>[contactId],
      );
      await harness.database
          .into(harness.database.eventOccurrenceParticipants)
          .insert(
            EventOccurrenceParticipantsCompanion.insert(
              id: 'e1-exact-only-snapshot',
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: occurrenceId,
              originalDate: future.iso8601,
              contactId: contactId,
              displayNameSnapshot: 'Exact Only Contact',
              createdAtUtc: DateTime.utc(2026, 8, 30, 2),
            ),
          );

      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: occurrenceId,
        originalDate: future,
        contactIds: const <String>[],
      );

      final people = await harness.contacts.readEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: occurrenceId,
        today: today,
      );
      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      final links =
          await (harness.database.select(harness.database.eventContactLinks)
                ..where(
                  (row) =>
                      row.eventId.equals(eventId) &
                      row.occurrenceId.equals(occurrenceId) &
                      row.contactId.equals(contactId),
                ))
              .get();
      final snapshots =
          await (harness.database.select(
                harness.database.eventOccurrenceParticipants,
              )..where(
                (row) =>
                    row.eventId.equals(eventId) &
                    row.occurrenceId.equals(occurrenceId) &
                    row.contactId.equals(contactId),
              ))
              .get();

      expect(people, isEmpty);
      expect(links.where((row) => row.status == 'active'), isEmpty);
      expect(links.where((row) => row.status == 'removed'), hasLength(1));
      expect(snapshots, hasLength(1));
      expect(
        timeline.timelineFuture.where(
          (entry) => entry.occurrenceId == occurrenceId,
        ),
        isEmpty,
      );
    },
  );

  test(
    'entire-series unlink suppresses future snapshots, preserves another '
    'Contact exact override, and re-add replaces the series tombstone',
    () async {
      final harness = await arrange();
      addTearDown(harness.database.close);
      const eventId = 'e1000000-0000-4000-8000-000000000004';
      const removedId = 'e1-series-snapshot-contact';
      const overrideId = 'e1-series-override-contact';
      await createContact(harness.contacts, harness.profileId, removedId);
      await createContact(harness.contacts, harness.profileId, overrideId);
      await harness.calendar.saveEvent(
        profileId: harness.profileId,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Series durable unlink',
          timing: CalendarEventTiming.timed,
          startDate: future,
          startMinute: 15 * 60,
          endMinute: 16 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
          recurrence: CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.weekly,
          ),
        ),
      );
      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[removedId],
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: future,
      );
      for (final contactId in <String>[removedId, overrideId]) {
        await harness.database
            .into(harness.database.eventContactLinks)
            .insert(
              EventContactLinksCompanion.insert(
                id: 'e1-series-exact-$contactId',
                profileId: harness.profileId,
                eventId: eventId,
                occurrenceId: Value<String>(occurrenceId),
                originalDate: Value<String>(future.iso8601),
                contactId: contactId,
                status: const Value<String>('active'),
                createdAtUtc: DateTime.utc(2026, 8, 30, 2),
                updatedAtUtc: DateTime.utc(2026, 8, 30, 2),
              ),
            );
      }
      await harness.database
          .into(harness.database.eventOccurrenceParticipants)
          .insert(
            EventOccurrenceParticipantsCompanion.insert(
              id: 'e1-series-future-snapshot',
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: occurrenceId,
              originalDate: future.iso8601,
              contactId: removedId,
              displayNameSnapshot: 'Series Snapshot Contact',
              createdAtUtc: DateTime.utc(2026, 8, 30, 2),
            ),
          );

      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[],
        explicitlyRemovedSeriesContactIds: const <String>[removedId],
      );

      var links = await (harness.database.select(
        harness.database.eventContactLinks,
      )..where((row) => row.eventId.equals(eventId))).get();
      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: removedId,
        today: today,
      );
      expect(
        links.where(
          (row) =>
              row.contactId == removedId &&
              row.occurrenceId == DriftContactRepository.seriesOccurrenceId &&
              row.status == 'removed',
        ),
        hasLength(1),
      );
      expect(
        links.where(
          (row) => row.contactId == removedId && row.status == 'active',
        ),
        isEmpty,
      );
      expect(
        links.where(
          (row) =>
              row.contactId == overrideId &&
              row.occurrenceId == occurrenceId &&
              row.status == 'active',
        ),
        hasLength(1),
      );
      expect(
        timeline.timelineFuture.where(
          (entry) => entry.occurrenceId == occurrenceId,
        ),
        isEmpty,
      );

      await harness.contacts.setEventPeople(
        profileId: harness.profileId,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[removedId],
      );
      links = await (harness.database.select(
        harness.database.eventContactLinks,
      )..where((row) => row.eventId.equals(eventId))).get();
      expect(
        links.where(
          (row) =>
              row.contactId == removedId &&
              row.occurrenceId == DriftContactRepository.seriesOccurrenceId &&
              row.status == 'active',
        ),
        hasLength(1),
      );
      expect(
        links.where(
          (row) => row.contactId == removedId && row.status == 'removed',
        ),
        isEmpty,
      );
    },
  );

  test('explicit historical occurrence unlink overrides its preserved snapshot '
      'without erasing another Contact or factual Event history', () async {
    final harness = await arrange();
    addTearDown(harness.database.close);
    const eventId = 'e1000000-0000-4000-8000-000000000005';
    const removedId = 'historical-removed-contact';
    const retainedId = 'historical-retained-contact';
    const historical = PlannerDate(year: 2026, month: 8, day: 29);
    await createContact(harness.contacts, harness.profileId, removedId);
    await createContact(harness.contacts, harness.profileId, retainedId);
    await harness.calendar.saveEvent(
      profileId: harness.profileId,
      draft: const CalendarEventDraft(
        id: eventId,
        title: 'Historical People correction',
        notes: 'Factual notes remain',
        timing: CalendarEventTiming.timed,
        startDate: historical,
        startMinute: 13 * 60,
        endMinute: 14 * 60,
        timeZoneId: 'Asia/Manila',
        requiresReport: false,
      ),
    );
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: historical,
    );
    await harness.contacts.setEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: occurrenceId,
      originalDate: historical,
      contactIds: const <String>[removedId, retainedId],
    );
    for (final contactId in <String>[removedId, retainedId]) {
      await harness.database
          .into(harness.database.eventOccurrenceParticipants)
          .insert(
            EventOccurrenceParticipantsCompanion.insert(
              id: 'historical-snapshot-$contactId',
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: occurrenceId,
              originalDate: historical.iso8601,
              contactId: contactId,
              displayNameSnapshot: contactId,
              createdAtUtc: DateTime.utc(2026, 8, 30, 2),
            ),
          );
    }

    await harness.contacts.setEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: occurrenceId,
      originalDate: historical,
      contactIds: const <String>[retainedId],
    );

    final people = await harness.contacts.readEventPeople(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: occurrenceId,
      today: today,
    );
    final preview = await harness.contacts.readEventParticipantPresentation(
      profileId: harness.profileId,
      eventId: eventId,
      occurrenceId: occurrenceId,
      historical: true,
    );
    final removedTimeline = await harness.contacts.readTimeline(
      profileId: harness.profileId,
      contactId: removedId,
      today: today,
    );
    final retainedTimeline = await harness.contacts.readTimeline(
      profileId: harness.profileId,
      contactId: retainedId,
      today: today,
    );
    final links =
        await (harness.database.select(harness.database.eventContactLinks)
              ..where(
                (row) =>
                    row.eventId.equals(eventId) &
                    row.occurrenceId.equals(occurrenceId),
              ))
            .get();
    final snapshots =
        await (harness.database.select(
              harness.database.eventOccurrenceParticipants,
            )..where(
              (row) =>
                  row.eventId.equals(eventId) &
                  row.occurrenceId.equals(occurrenceId),
            ))
            .get();
    final event = await (harness.database.select(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();

    expect(
      links.where(
        (row) => row.contactId == removedId && row.status == 'removed',
      ),
      hasLength(1),
    );
    expect(
      links.where(
        (row) => row.contactId == removedId && row.status == 'active',
      ),
      isEmpty,
    );
    expect(
      snapshots.map((row) => row.id),
      containsAll(<String>[
        'historical-snapshot-$removedId',
        'historical-snapshot-$retainedId',
      ]),
      reason: 'the factual snapshots that predate unlink remain stored',
    );
    expect(people.map((person) => person.contact.id), <String>[retainedId]);
    expect(preview.map((person) => person.contactId), <String>[retainedId]);
    expect(
      removedTimeline.history.where(
        (entry) => entry.occurrenceId == occurrenceId,
      ),
      isEmpty,
    );
    expect(
      retainedTimeline.history.where(
        (entry) => entry.occurrenceId == occurrenceId,
      ),
      hasLength(1),
    );
    expect(event.notes, 'Factual notes remain');
    expect(event.startDate, historical.iso8601);
    expect(event.startMinute, 13 * 60);
    expect(event.endMinute, 14 * 60);
  });
}

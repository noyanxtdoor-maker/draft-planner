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
  final clock = FixedClock(DateTime.utc(2026, 8, 3, 12));
  const today = PlannerDate(year: 2026, month: 8, day: 3);
  final identifiers = UuidIdentifierSource();

  DriftContactRepository createContacts(AppDatabase database) {
    return DriftContactRepository(
      database: database,
      clock: clock,
      identifiers: identifiers,
    );
  }

  DriftCalendarEventRepository createCalendar(AppDatabase database) {
    return DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
    );
  }

  Future<
    (AppDatabase, DriftContactRepository, DriftCalendarEventRepository, String)
  >
  arrange() async {
    final database = openMemoryDatabase();
    final startup = buildTestRepository(database: database);
    final profile = await startup.completeOnboarding();
    return (
      database,
      createContacts(database),
      createCalendar(database),
      profile.id,
    );
  }

  ContactDraft draftFor({
    required String id,
    String first = 'Marilyn',
    String last = 'Gomez',
    String? phone,
    String? email,
    String? note,
  }) {
    return ContactDraft(
      id: id,
      firstName: first,
      lastName: last,
      displayName: '$first $last'.trim(),
      preferredContactMethod: ContactPreferredMethod.message,
      isFavorite: false,
      methods: <ContactMethodDraft>[
        if (phone != null)
          ContactMethodDraft(type: ContactMethodType.phone, value: phone),
        if (email != null)
          ContactMethodDraft(type: ContactMethodType.email, value: email),
      ],
      initialNoteText: note,
    );
  }

  test('create, edit, archive, and restore keep one stable identity', () async {
    final (database, contacts, _, profileId) = await arrange();
    addTearDown(database.close);

    final created = await contacts.createContact(
      profileId: profileId,
      draft: draftFor(
        id: 'contact-marilyn',
        phone: '+1 555 0100',
        note: 'Met at the retreat.',
      ),
    );
    expect(created.id, 'contact-marilyn');
    expect(created.displayName, 'Marilyn Gomez');
    expect(created.lifecycleState, ContactLifecycleState.active);
    expect(created.source, ContactSource.manual);

    final detail = await contacts.readContactDetail(
      profileId: profileId,
      contactId: 'contact-marilyn',
    );
    expect(detail.methods.single.type, ContactMethodType.phone);
    expect(detail.notes.single.noteText, 'Met at the retreat.');

    await contacts.setFavorite(
      profileId: profileId,
      contactId: 'contact-marilyn',
      favorite: true,
    );
    await contacts.archiveContact(
      profileId: profileId,
      contactId: 'contact-marilyn',
    );
    final archived = await contacts.readContactDetail(
      profileId: profileId,
      contactId: 'contact-marilyn',
    );
    expect(archived.contact.lifecycleState, ContactLifecycleState.archived);
    expect(archived.contact.isFavorite, isTrue);

    final restored = await contacts.restoreContact(
      profileId: profileId,
      contactId: 'contact-marilyn',
    );
    expect(restored.id, 'contact-marilyn');
    expect(restored.lifecycleState, ContactLifecycleState.active);
    expect(restored.isFavorite, isTrue);
  });

  test(
    'groups carry the identity color and membership survives renames',
    () async {
      final (database, contacts, _, profileId) = await arrange();
      addTearDown(database.close);

      final group = await contacts.createGroup(
        profileId: profileId,
        name: 'Family',
        colorValue: 0xFFE91E63,
      );
      await contacts.createContact(
        profileId: profileId,
        draft: draftFor(id: 'contact-ashley', first: 'Ashley', last: 'Gomez'),
      );
      await contacts.setContactGroups(
        profileId: profileId,
        contactId: 'contact-ashley',
        groupIds: <String>[group.id],
        primaryGroupId: group.id,
      );
      final summary = await contacts.readContacts(
        profileId: profileId,
        criteria: const ContactFilterCriteria(),
        sortBy: ContactSortBy.name,
        today: today,
      );
      final ashley = summary.singleWhere(
        (s) => s.contact.id == 'contact-ashley',
      );
      expect(ashley.primaryGroup?.id, group.id);
      expect(ashley.colorValue.value, 0xFFE91E63);

      await contacts.updateGroup(
        profileId: profileId,
        groupId: group.id,
        name: 'Extended Family',
        colorValue: 0xFF4CAF50,
      );
      final renamed = await contacts.readContactDetail(
        profileId: profileId,
        contactId: 'contact-ashley',
      );
      expect(renamed.groups.single.name, 'Extended Family');
      expect(renamed.primaryGroupId, group.id);

      // Archiving a group keeps it on existing Contacts (contact history is
      // untouched) but it can no longer be anyone's primary group.
      await contacts.archiveGroup(profileId: profileId, groupId: group.id);
      final afterArchive = await contacts.readContactDetail(
        profileId: profileId,
        contactId: 'contact-ashley',
      );
      expect(afterArchive.groups.single.id, group.id);
      expect(afterArchive.primaryGroupId, isNull);
      final allGroups = await contacts.readGroups(
        profileId,
        includeArchived: true,
      );
      expect(allGroups.singleWhere((g) => g.id == group.id).isArchived, isTrue);
    },
  );

  test(
    'RELEASE-BLOCKING: removing a Contact from a future series keeps their '
    'past occurrence on the Timeline (occurrence snapshot stability)',
    () async {
      final (database, contacts, calendar, profileId) = await arrange();
      addTearDown(database.close);

      await contacts.createContact(
        profileId: profileId,
        draft: draftFor(id: 'contact-marilyn'),
      );

      // Weekly Dinner starting Saturday 2026-07-25 with Marilyn on the series.
      await calendar.saveEvent(
        profileId: profileId,
        draft: CalendarEventDraft(
          id: '11111111-1111-4111-8111-111111111111',
          title: 'Dinner with Family',
          timing: CalendarEventTiming.timed,
          startDate: const PlannerDate(year: 2026, month: 7, day: 25),
          startMinute: 18 * 60,
          endMinute: 19 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
          recurrence: const CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.weekly,
          ),
        ),
      );
      await contacts.setEventPeople(
        profileId: profileId,
        eventId: '11111111-1111-4111-8111-111111111111',
        occurrenceId: 'series',
        contactIds: <String>['contact-marilyn'],
      );

      final before = await contacts.readTimeline(
        profileId: profileId,
        contactId: 'contact-marilyn',
        today: today,
      );
      expect(
        before.history.map((e) => e.date.iso8601),
        containsAll(<String>['2026-07-25', '2026-08-01']),
      );
      expect(
        before.upcoming.map((e) => e.date.iso8601),
        contains('2026-08-08'),
      );

      // The user edits the FUTURE series and removes Marilyn.
      await contacts.setEventPeople(
        profileId: profileId,
        eventId: '11111111-1111-4111-8111-111111111111',
        occurrenceId: 'series',
        contactIds: const <String>[],
      );

      final after = await contacts.readTimeline(
        profileId: profileId,
        contactId: 'contact-marilyn',
        today: today,
      );
      expect(after.upcoming, isEmpty);
      // Historical participation MUST remain — this is the release gate.
      expect(
        after.history.map((e) => e.date.iso8601),
        containsAll(<String>['2026-07-25', '2026-08-01']),
      );
      // No duplicate occurrence entries from link + snapshot.
      final augustFirst = after.history
          .where((e) => e.date.iso8601 == '2026-08-01')
          .toList();
      expect(augustFirst, hasLength(1));

      // The frozen occurrence still resolves its people.
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: '11111111-1111-4111-8111-111111111111',
        originalDate: const PlannerDate(year: 2026, month: 8, day: 1),
      );
      final people = await contacts.readEventPeople(
        profileId: profileId,
        eventId: '11111111-1111-4111-8111-111111111111',
        occurrenceId: occurrenceId,
        today: today,
      );
      expect(
        people.map((summary) => summary.contact.id),
        contains('contact-marilyn'),
      );
    },
  );

  test(
    'merge preserves links, timeline, notes, and historical identity',
    () async {
      final (database, contacts, calendar, profileId) = await arrange();
      addTearDown(database.close);

      await contacts.createContact(
        profileId: profileId,
        draft: draftFor(
          id: 'contact-a',
          first: 'Marilyn',
          last: 'Gomez',
          phone: '+1 555 0100',
        ),
      );
      await contacts.createContact(
        profileId: profileId,
        draft: draftFor(
          id: 'contact-b',
          first: 'Marilyn',
          last: 'Gomez',
          phone: '+1 555 0100',
        ),
      );
      await contacts.addNote(
        profileId: profileId,
        contactId: 'contact-b',
        text: 'Met at the retreat.',
      );

      await calendar.saveEvent(
        profileId: profileId,
        draft: CalendarEventDraft(
          id: '22222222-2222-4222-8222-222222222222',
          title: 'Lunch Meeting',
          timing: CalendarEventTiming.timed,
          startDate: const PlannerDate(year: 2026, month: 7, day: 28),
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
        ),
      );
      await contacts.setEventPeople(
        profileId: profileId,
        eventId: '22222222-2222-4222-8222-222222222222',
        occurrenceId: 'series',
        contactIds: <String>['contact-a', 'contact-b'],
      );

      final candidates = await contacts.readDuplicateCandidates(profileId);
      expect(candidates, isNotEmpty);
      expect(
        candidates.any(
          (group) => group.map((c) => c.id).toSet().containsAll(<String>[
            'contact-a',
            'contact-b',
          ]),
        ),
        isTrue,
      );

      final plan = await contacts.readMergePlan(
        profileId: profileId,
        survivorId: 'contact-a',
        absorbedIds: <String>['contact-b'],
      );
      expect(plan.survivor.id, 'contact-a');
      expect(plan.absorbed.single.id, 'contact-b');

      final merged = await contacts.mergeContacts(
        profileId: profileId,
        survivorId: 'contact-a',
        absorbedIds: <String>['contact-b'],
        choices: const ContactMergeChoices(<String, String>{}),
      );
      expect(merged.id, 'contact-a');

      // Event links survive under the survivor without duplication.
      final people = await contacts.readEventPeople(
        profileId: profileId,
        eventId: '22222222-2222-4222-8222-222222222222',
        occurrenceId: 'series',
        today: today,
      );
      expect(people.map((s) => s.contact.id), <String>['contact-a']);

      // The absorbed identity is traceable, not deleted as data loss.
      final absorbed = await contacts.readContactDetail(
        profileId: profileId,
        contactId: 'contact-b',
      );
      expect(absorbed.contact.mergedIntoContactId, 'contact-a');

      // Timeline under the survivor includes the past occurrence and both notes
      // (the absorbed note is preserved).
      final timeline = await contacts.readTimeline(
        profileId: profileId,
        contactId: 'contact-a',
        today: today,
      );
      expect(timeline.history.map((e) => e.title), contains('Lunch Meeting'));
      final detail = await contacts.readContactDetail(
        profileId: profileId,
        contactId: 'contact-a',
      );
      expect(
        detail.notes.map((n) => n.noteText),
        contains('Met at the retreat.'),
      );
    },
  );

  test(
    'device import is selected-only and flags duplicates without merging',
    () async {
      final (database, contacts, _, profileId) = await arrange();
      addTearDown(database.close);

      await contacts.createContact(
        profileId: profileId,
        draft: draftFor(
          id: 'existing',
          first: 'Marilyn',
          last: 'Gomez',
          phone: '+1 555 0100',
        ),
      );

      final result = await contacts.importDeviceContacts(
        profileId: profileId,
        drafts: const <DeviceContactDraft>[
          DeviceContactDraft(
            displayName: 'Marilyn Gomez',
            firstName: 'Marilyn',
            lastName: 'Gomez',
            phones: <String>['+1 555 0100'],
          ),
          DeviceContactDraft(
            displayName: 'Simon Rufino',
            firstName: 'Simon',
            lastName: 'Rufino',
            phones: <String>['+1 555 0200'],
          ),
        ],
      );
      expect(result.createdCount, 1);
      expect(result.skippedCount, 1);
      expect(result.duplicateContactIds, contains('Marilyn Gomez'));

      final summaries = await contacts.readContacts(
        profileId: profileId,
        criteria: const ContactFilterCriteria(),
        sortBy: ContactSortBy.name,
        today: today,
      );
      expect(summaries, hasLength(2));
      final simon = summaries.singleWhere(
        (s) => s.contact.firstName == 'Simon',
      );
      expect(simon.contact.source, ContactSource.deviceImport);
    },
  );

  test('saved filters persist criteria and are deletable', () async {
    final (database, contacts, _, profileId) = await arrange();
    addTearDown(database.close);

    final saved = await contacts.saveSavedFilter(
      profileId: profileId,
      draft: const SavedContactFilterDraft(
        name: 'Family weekend',
        criteria: ContactFilterCriteria(groupIds: <String>['family']),
        sortBy: ContactSortBy.recentlyAdded,
      ),
    );
    final filters = await contacts.readSavedFilters(profileId);
    expect(filters.single.id, saved.id);
    expect(filters.single.name, 'Family weekend');
    expect(filters.single.criteria.groupIds, <String>['family']);
    expect(filters.single.sortBy, ContactSortBy.recentlyAdded);

    await contacts.deleteSavedFilter(profileId: profileId, filterId: saved.id);
    expect(await contacts.readSavedFilters(profileId), isEmpty);
  });

  test('search matches names, phone, email, groups, and tags', () async {
    final (database, contacts, _, profileId) = await arrange();
    addTearDown(database.close);

    final group = await contacts.createGroup(
      profileId: profileId,
      name: 'Work',
      colorValue: 0xFF2196F3,
    );
    await contacts.createContact(
      profileId: profileId,
      draft: draftFor(
        id: 'c-1',
        first: 'Ashley',
        last: 'Gomez',
        phone: '+1 555 0300',
      ),
    );
    await contacts.setContactGroups(
      profileId: profileId,
      contactId: 'c-1',
      groupIds: <String>[group.id],
      primaryGroupId: group.id,
    );
    await contacts.createContact(
      profileId: profileId,
      draft: draftFor(
        id: 'c-2',
        first: 'Simon',
        last: 'Rufino',
        email: 'simon@example.com',
      ),
    );

    final byName = await contacts.searchContacts(
      profileId: profileId,
      query: 'ash',
      today: today,
    );
    expect(byName.map((s) => s.contact.id), contains('c-1'));

    final byPhone = await contacts.searchContacts(
      profileId: profileId,
      query: '0300',
      today: today,
    );
    expect(byPhone.map((s) => s.contact.id), contains('c-1'));

    final byEmail = await contacts.searchContacts(
      profileId: profileId,
      query: 'simon@example',
      today: today,
    );
    expect(byEmail.map((s) => s.contact.id), contains('c-2'));

    final byGroup = await contacts.searchContacts(
      profileId: profileId,
      query: 'work',
      today: today,
    );
    expect(byGroup.map((s) => s.contact.id), contains('c-1'));
  });
}

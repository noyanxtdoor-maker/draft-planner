import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test('A5 Notes writes preserve every non-Notes persisted owner', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 14)),
      identifiers: UuidIdentifierSource(),
    );
    final family = await contacts.createGroup(
      profileId: profile.id,
      name: 'Family',
      colorValue: 0xFF1565C0,
    );
    final friends = await contacts.createGroup(
      profileId: profile.id,
      name: 'Friends',
      colorValue: 0xFF6A1B9A,
    );
    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: _contactId,
        firstName: 'Maria',
        lastName: 'Santos',
        displayName: 'Maria Santos',
        preferredContactMethod: ContactPreferredMethod.email,
        isFavorite: true,
        addressText: '11 Original Street',
        source: ContactSource.deviceImport,
        tagNames: <String>['Dormant tag'],
        methods: <ContactMethodDraft>[
          ContactMethodDraft(
            type: ContactMethodType.phone,
            value: '+639170000001',
            label: 'Mobile',
            isPrimary: true,
            receivesTexts: true,
            hasWhatsApp: true,
          ),
          ContactMethodDraft(
            type: ContactMethodType.phone,
            value: '+639170000002',
            label: 'Work',
          ),
          ContactMethodDraft(
            type: ContactMethodType.email,
            value: 'maria@example.com',
            label: 'Work',
            isPrimary: true,
          ),
          ContactMethodDraft(
            type: ContactMethodType.social,
            value: 'maria.santos',
            label: 'instagram',
            isPrimary: true,
          ),
        ],
      ),
    );
    await contacts.setContactGroups(
      profileId: profile.id,
      contactId: _contactId,
      groupIds: <String>[family.id, friends.id],
      primaryGroupId: family.id,
    );
    await contacts.setAvailability(
      profileId: profile.id,
      contactId: _contactId,
      windows: const <ContactAvailability>[
        ContactAvailability(weekday: 1, startMinute: 540, endMinute: 600),
        ContactAvailability(weekday: 5, startMinute: 780, endMinute: 900),
      ],
    );
    await contacts.addNote(
      profileId: profile.id,
      contactId: _contactId,
      text: 'First historical note',
    );
    await contacts.addNote(
      profileId: profile.id,
      contactId: _contactId,
      text: 'Second historical note',
    );
    await contacts.archiveContact(profileId: profile.id, contactId: _contactId);

    final maps = DriftMapCoordinateRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 14)),
    );
    const coordinate = MapCoordinate(latitude: 14.5995, longitude: 120.9842);
    await maps.setCoordinate(
      profileId: profile.id,
      owner: MapCoordinateOwner.contact,
      recordId: _contactId,
      coordinate: coordinate,
    );
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 14)),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
    );
    await calendar.saveEvent(
      profileId: profile.id,
      draft: const CalendarEventDraft(
        id: _eventId,
        title: 'A5 link',
        timing: CalendarEventTiming.timed,
        startDate: PlannerDate(year: 2026, month: 8, day: 30),
        startMinute: 600,
        endMinute: 660,
        timeZoneId: 'Asia/Manila',
        requiresReport: false,
      ),
    );
    await contacts.setEventPeople(
      profileId: profile.id,
      eventId: _eventId,
      occurrenceId: 'series',
      contactIds: const <String>[_contactId],
    );
    final planner = DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 14)),
    );
    await planner.saveTask(
      profileId: profile.id,
      draft: const PlannerTaskDraft(
        id: _taskId,
        title: 'A5 link',
        dueDate: PlannerDate(year: 2026, month: 8, day: 31),
        requiresReport: false,
      ),
    );
    await contacts.setTaskContacts(
      profileId: profile.id,
      taskId: _taskId,
      contactIds: const <String>[_contactId],
    );

    final before = await _snapshot(database, maps, profile.id);
    final first = before.notes.singleWhere(
      (note) => note.noteText == 'First historical note',
    );
    final second = before.notes.singleWhere(
      (note) => note.noteText == 'Second historical note',
    );
    await contacts.updateNote(
      profileId: profile.id,
      noteId: first.id,
      text: 'Edited historical note',
    );
    await contacts.addNote(
      profileId: profile.id,
      contactId: _contactId,
      text: 'Added history note',
    );
    await contacts.deleteNote(profileId: profile.id, noteId: second.id);

    final after = await _snapshot(database, maps, profile.id);
    expect(after.contact, before.contact);
    expect(after.methods, before.methods);
    expect(after.groups, before.groups);
    expect(after.tags, before.tags);
    expect(after.availability, before.availability);
    expect(after.coordinate, before.coordinate);
    expect(after.eventLinks, before.eventLinks);
    expect(after.taskLinks, before.taskLinks);
    expect(after.eventLinks.single.eventId, _eventId);
    expect(after.eventLinks.single.contactId, _contactId);
    expect(after.taskLinks.single.taskId, _taskId);
    expect(after.taskLinks.single.contactId, _contactId);
    expect(after.notes, hasLength(2));
    expect(
      after.notes.where((note) => note.id == first.id).single.noteText,
      'Edited historical note',
    );
    expect(after.notes.where((note) => note.id == second.id), isEmpty);
    expect(
      after.notes.map((note) => note.noteText),
      contains('Added history note'),
    );
  });
}

const _contactId = 'a5-preserve';
const _eventId = '33333333-3333-4333-8333-333333333333';
const _taskId = 'a5-linked-task';

Future<
  ({
    ContactRow contact,
    List<ContactMethodRow> methods,
    List<ContactGroupMembershipRow> groups,
    List<ContactTagMembershipRow> tags,
    List<ContactAvailabilityRow> availability,
    List<ContactNoteRow> notes,
    List<EventContactLinkRow> eventLinks,
    List<TaskContactLinkRow> taskLinks,
    MapCoordinate? coordinate,
  })
>
_snapshot(
  AppDatabase database,
  DriftMapCoordinateRepository maps,
  String profileId,
) async => (
  contact: await (database.select(
    database.contacts,
  )..where((row) => row.id.equals(_contactId))).getSingle(),
  methods: await (database.select(
    database.contactMethods,
  )..where((row) => row.contactId.equals(_contactId))).get(),
  groups: await (database.select(
    database.contactGroupMemberships,
  )..where((row) => row.contactId.equals(_contactId))).get(),
  tags: await (database.select(
    database.contactTagMemberships,
  )..where((row) => row.contactId.equals(_contactId))).get(),
  availability: await (database.select(
    database.contactAvailabilities,
  )..where((row) => row.contactId.equals(_contactId))).get(),
  notes: await (database.select(
    database.contactNotes,
  )..where((row) => row.contactId.equals(_contactId))).get(),
  eventLinks: await (database.select(
    database.eventContactLinks,
  )..where((row) => row.contactId.equals(_contactId))).get(),
  taskLinks: await (database.select(
    database.taskContactLinks,
  )..where((row) => row.contactId.equals(_contactId))).get(),
  coordinate: await maps.readCoordinate(
    profileId: profileId,
    owner: MapCoordinateOwner.contact,
    recordId: _contactId,
  ),
);

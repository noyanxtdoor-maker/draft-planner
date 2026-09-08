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
  test(
    'A2 address and canonical Contact coordinate mutate independently',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final clock = FixedClock(DateTime.utc(2026, 8, 24, 14));
      final contacts = DriftContactRepository(
        database: database,
        clock: clock,
        identifiers: UuidIdentifierSource(),
      );
      final maps = DriftMapCoordinateRepository(
        database: database,
        clock: clock,
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: 'a2-contact',
          firstName: 'Maria',
          lastName: 'Santos',
          displayName: 'Maria Santos',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: true,
          addressText: 'First Address',
          tagNames: <String>['Dormant Tag'],
          methods: <ContactMethodDraft>[
            ContactMethodDraft(
              type: ContactMethodType.phone,
              value: '+63 917 555 0100',
              label: 'Mobile',
              receivesTexts: true,
              hasWhatsApp: true,
              isPrimary: true,
            ),
          ],
        ),
      );
      const pin = MapCoordinate(latitude: 14.5995, longitude: 120.9842);
      await maps.setCoordinate(
        profileId: profile.id,
        owner: MapCoordinateOwner.contact,
        recordId: 'a2-contact',
        coordinate: pin,
      );

      await contacts.updateContactAddress(
        profileId: profile.id,
        contactId: 'a2-contact',
        addressText: 'Second Address',
      );
      expect(
        await maps.readCoordinate(
          profileId: profile.id,
          owner: MapCoordinateOwner.contact,
          recordId: 'a2-contact',
        ),
        pin,
        reason: 'address edits never derive, clear, or rewrite coordinates',
      );

      await contacts.updateContactAddress(
        profileId: profile.id,
        contactId: 'a2-contact',
        addressText: '',
      );
      expect(
        await maps.readCoordinate(
          profileId: profile.id,
          owner: MapCoordinateOwner.contact,
          recordId: 'a2-contact',
        ),
        pin,
        reason: 'clearing address preserves the saved Contact coordinate',
      );

      await maps.clearCoordinate(
        profileId: profile.id,
        owner: MapCoordinateOwner.contact,
        recordId: 'a2-contact',
      );
      final detail = await contacts.readContactDetail(
        profileId: profile.id,
        contactId: 'a2-contact',
      );
      expect(detail.contact.addressText, isNull);
      expect(detail.contact.isFavorite, isTrue);
      expect(detail.tags.single.name, 'Dormant Tag');
      expect(detail.methods.single.id, isNotEmpty);
      expect(detail.methods.single.receivesTexts, isTrue);
      expect(detail.methods.single.hasWhatsApp, isTrue);
    },
  );

  test(
    'A2 address mutation preserves every protected persisted relationship',
    () async {
      final fixture = await _arrangeProtectedContact();
      addTearDown(fixture.database.close);
      final before = await _readProtectedRows(fixture.database);

      await fixture.contacts.updateContactAddress(
        profileId: fixture.profileId,
        contactId: _contactId,
        addressText: 'Updated Address',
      );

      await _expectProtectedRowsUnchanged(
        database: fixture.database,
        contacts: fixture.contacts,
        maps: fixture.maps,
        profileId: fixture.profileId,
        before: before,
        expectedAddress: 'Updated Address',
        expectedCoordinate: _initialPin,
      );
    },
  );

  test(
    'A2 canonical coordinate mutation and clear preserve protected records',
    () async {
      final fixture = await _arrangeProtectedContact();
      addTearDown(fixture.database.close);
      final before = await _readProtectedRows(fixture.database);
      const movedPin = MapCoordinate(latitude: 14.6095, longitude: 120.9942);

      await fixture.maps.setCoordinate(
        profileId: fixture.profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
        coordinate: movedPin,
      );
      await _expectProtectedRowsUnchanged(
        database: fixture.database,
        contacts: fixture.contacts,
        maps: fixture.maps,
        profileId: fixture.profileId,
        before: before,
        expectedAddress: 'Original Address',
        expectedCoordinate: movedPin,
      );

      await fixture.maps.clearCoordinate(
        profileId: fixture.profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
      );
      await _expectProtectedRowsUnchanged(
        database: fixture.database,
        contacts: fixture.contacts,
        maps: fixture.maps,
        profileId: fixture.profileId,
        before: before,
        expectedAddress: 'Original Address',
        expectedCoordinate: null,
      );
    },
  );
}

const _contactId = 'a2-protected-contact';
const _eventId = '11111111-1111-4111-8111-111111111111';
const _taskId = 'a2-protected-task';
const _initialPin = MapCoordinate(latitude: 14.5995, longitude: 120.9842);

Future<
  ({
    AppDatabase database,
    DriftContactRepository contacts,
    DriftMapCoordinateRepository maps,
    String profileId,
  })
>
_arrangeProtectedContact() async {
  final database = openMemoryDatabase();
  final profile = await buildTestRepository(
    database: database,
  ).completeOnboarding();
  final clock = FixedClock(DateTime.utc(2026, 8, 24, 14));
  final contacts = DriftContactRepository(
    database: database,
    clock: clock,
    identifiers: UuidIdentifierSource(),
  );
  final maps = DriftMapCoordinateRepository(database: database, clock: clock);
  final calendar = DriftCalendarEventRepository(
    database: database,
    clock: clock,
    timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
  );
  final planner = DriftPlannerRepository(database: database, clock: clock);

  await contacts.createContact(
    profileId: profile.id,
    draft: const ContactDraft(
      id: _contactId,
      firstName: 'Maria',
      lastName: 'Santos',
      displayName: 'Maria Santos',
      preferredContactMethod: ContactPreferredMethod.message,
      isFavorite: true,
      addressText: 'Original Address',
      source: ContactSource.deviceImport,
      tagNames: <String>['Dormant Tag'],
      methods: <ContactMethodDraft>[
        ContactMethodDraft(
          type: ContactMethodType.phone,
          value: '+63 917 555 0100',
          label: 'Mobile',
          receivesTexts: true,
          hasWhatsApp: true,
          isPrimary: true,
        ),
      ],
    ),
  );
  final primaryGroup = await contacts.createGroup(
    profileId: profile.id,
    name: 'Primary Group',
    colorValue: 0xFF1565C0,
  );
  final secondaryGroup = await contacts.createGroup(
    profileId: profile.id,
    name: 'Dormant Secondary',
    colorValue: 0xFF6A1B9A,
  );
  await contacts.setContactGroups(
    profileId: profile.id,
    contactId: _contactId,
    groupIds: <String>[primaryGroup.id, secondaryGroup.id],
    primaryGroupId: primaryGroup.id,
  );
  await contacts.setAvailability(
    profileId: profile.id,
    contactId: _contactId,
    windows: const <ContactAvailability>[
      ContactAvailability(
        weekday: DateTime.monday,
        startMinute: 540,
        endMinute: 720,
      ),
      ContactAvailability(
        weekday: DateTime.friday,
        startMinute: 780,
        endMinute: 900,
      ),
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
  await maps.setCoordinate(
    profileId: profile.id,
    owner: MapCoordinateOwner.contact,
    recordId: _contactId,
    coordinate: _initialPin,
  );
  await calendar.saveEvent(
    profileId: profile.id,
    draft: const CalendarEventDraft(
      id: _eventId,
      title: 'Contact-linked Event',
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
  await planner.saveTask(
    profileId: profile.id,
    draft: const PlannerTaskDraft(
      id: _taskId,
      title: 'Contact-linked Task',
      dueDate: PlannerDate(year: 2026, month: 8, day: 31),
      requiresReport: false,
    ),
  );
  await contacts.setTaskContacts(
    profileId: profile.id,
    taskId: _taskId,
    contactIds: const <String>[_contactId],
  );
  await contacts.archiveContact(profileId: profile.id, contactId: _contactId);

  return (
    database: database,
    contacts: contacts,
    maps: maps,
    profileId: profile.id,
  );
}

Future<
  ({
    List<ContactGroupMembershipRow> groups,
    List<ContactAvailabilityRow> availability,
    List<ContactNoteRow> notes,
    List<EventContactLinkRow> eventLinks,
    List<TaskContactLinkRow> taskLinks,
  })
>
_readProtectedRows(AppDatabase database) async {
  final groups = await (database.select(
    database.contactGroupMemberships,
  )..where((row) => row.contactId.equals(_contactId))).get();
  final availability = await (database.select(
    database.contactAvailabilities,
  )..where((row) => row.contactId.equals(_contactId))).get();
  final notes = await (database.select(
    database.contactNotes,
  )..where((row) => row.contactId.equals(_contactId))).get();
  final eventLinks = await (database.select(
    database.eventContactLinks,
  )..where((row) => row.contactId.equals(_contactId))).get();
  final taskLinks = await (database.select(
    database.taskContactLinks,
  )..where((row) => row.contactId.equals(_contactId))).get();
  return (
    groups: groups,
    availability: availability,
    notes: notes,
    eventLinks: eventLinks,
    taskLinks: taskLinks,
  );
}

Future<void> _expectProtectedRowsUnchanged({
  required AppDatabase database,
  required DriftContactRepository contacts,
  required DriftMapCoordinateRepository maps,
  required String profileId,
  required ({
    List<ContactGroupMembershipRow> groups,
    List<ContactAvailabilityRow> availability,
    List<ContactNoteRow> notes,
    List<EventContactLinkRow> eventLinks,
    List<TaskContactLinkRow> taskLinks,
  })
  before,
  required String expectedAddress,
  required MapCoordinate? expectedCoordinate,
}) async {
  final detail = await contacts.readContactDetail(
    profileId: profileId,
    contactId: _contactId,
  );
  final after = await _readProtectedRows(database);

  expect(detail.contact.addressText, expectedAddress);
  expect(detail.contact.source, ContactSource.deviceImport);
  expect(detail.contact.lifecycleState, ContactLifecycleState.archived);
  expect(detail.contact.archivedAtUtc, isNotNull);
  expect(after.groups, equals(before.groups));
  expect(after.groups.where((row) => row.isPrimary), hasLength(1));
  expect(after.groups.where((row) => !row.isPrimary), hasLength(1));
  expect(after.availability, equals(before.availability));
  expect(after.notes, equals(before.notes));
  expect(after.notes.map((row) => row.id), hasLength(2));
  expect(after.eventLinks, equals(before.eventLinks));
  expect(after.eventLinks.single.eventId, _eventId);
  expect(after.taskLinks, equals(before.taskLinks));
  expect(after.taskLinks.single.taskId, _taskId);
  expect(
    await maps.readCoordinate(
      profileId: profileId,
      owner: MapCoordinateOwner.contact,
      recordId: _contactId,
    ),
    expectedCoordinate,
  );
}

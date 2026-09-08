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
  const today = PlannerDate(year: 2026, month: 8, day: 24);

  test(
    'A3 search and primary mutation ignore dormant Group membership',
    () async {
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
          id: 'a3-contact',
          firstName: 'Maria',
          lastName: 'Santos',
          displayName: 'Maria Santos',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: true,
        ),
      );
      await contacts.setContactGroups(
        profileId: profile.id,
        contactId: 'a3-contact',
        groupIds: <String>[family.id, friends.id],
        primaryGroupId: family.id,
      );
      await contacts.setContactGroups(
        profileId: profile.id,
        contactId: 'a3-contact',
        groupIds: <String>[friends.id],
        primaryGroupId: friends.id,
      );

      final memberships = await (database.select(
        database.contactGroupMemberships,
      )..where((row) => row.contactId.equals('a3-contact'))).get();
      expect(memberships, hasLength(2));
      expect(
        memberships.singleWhere((row) => row.groupId == friends.id).isPrimary,
        isTrue,
      );
      expect(
        memberships.singleWhere((row) => row.groupId == family.id).isPrimary,
        isFalse,
      );
      expect(
        await contacts.searchContacts(
          profileId: profile.id,
          query: 'Family',
          today: today,
        ),
        isEmpty,
      );
      expect(
        await contacts.searchContacts(
          profileId: profile.id,
          query: 'Friends',
          today: today,
        ),
        hasLength(1),
      );

      await contacts.setContactGroups(
        profileId: profile.id,
        contactId: 'a3-contact',
        groupIds: const <String>[],
        primaryGroupId: null,
      );
      final cleared = await (database.select(
        database.contactGroupMemberships,
      )..where((row) => row.contactId.equals('a3-contact'))).get();
      expect(cleared, hasLength(2));
      expect(cleared.where((row) => row.isPrimary), isEmpty);
      expect(
        await contacts.searchContacts(
          profileId: profile.id,
          query: 'Friends',
          today: today,
        ),
        isEmpty,
      );
    },
  );

  test(
    'A3 no-primary states remain No group without creating or guessing memberships',
    () async {
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
      for (final id in <String>['none', 'legacy-no-primary']) {
        await contacts.createContact(
          profileId: profile.id,
          draft: ContactDraft(
            id: id,
            firstName: id,
            lastName: 'Contact',
            displayName: '$id Contact',
            preferredContactMethod: ContactPreferredMethod.message,
            isFavorite: false,
          ),
        );
      }
      await contacts.setContactGroups(
        profileId: profile.id,
        contactId: 'legacy-no-primary',
        groupIds: <String>[family.id, friends.id],
        primaryGroupId: null,
      );
      for (final id in <String>['none', 'legacy-no-primary']) {
        final detail = await contacts.readContactDetail(
          profileId: profile.id,
          contactId: id,
        );
        expect(detail.primaryGroupId, isNull);
        await contacts.setContactGroups(
          profileId: profile.id,
          contactId: id,
          groupIds: const <String>[],
          primaryGroupId: null,
        );
      }
      final noneRows = await (database.select(
        database.contactGroupMemberships,
      )..where((row) => row.contactId.equals('none'))).get();
      final legacyRows = await (database.select(
        database.contactGroupMemberships,
      )..where((row) => row.contactId.equals('legacy-no-primary'))).get();
      expect(noneRows, isEmpty);
      expect(legacyRows, hasLength(2));
      expect(legacyRows.where((row) => row.isPrimary), isEmpty);
      expect(
        await contacts.searchContacts(
          profileId: profile.id,
          query: 'Family',
          today: today,
        ),
        isEmpty,
      );
    },
  );

  test(
    'A3 primary switch and clear preserve every non-Group persisted owner',
    () async {
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
          id: 'preserve',
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
        contactId: 'preserve',
        groupIds: <String>[family.id, friends.id],
        primaryGroupId: family.id,
      );
      await contacts.setAvailability(
        profileId: profile.id,
        contactId: 'preserve',
        windows: const <ContactAvailability>[
          ContactAvailability(weekday: 1, startMinute: 540, endMinute: 600),
          ContactAvailability(weekday: 5, startMinute: 780, endMinute: 840),
        ],
      );
      await contacts.addNote(
        profileId: profile.id,
        contactId: 'preserve',
        text: 'First',
      );
      await contacts.addNote(
        profileId: profile.id,
        contactId: 'preserve',
        text: 'Second',
      );
      await contacts.archiveContact(
        profileId: profile.id,
        contactId: 'preserve',
      );
      final maps = DriftMapCoordinateRepository(database: database, clock: FixedClock(DateTime.utc(2026, 8, 24, 14)));
      const coordinate = MapCoordinate(latitude: 14.5995, longitude: 120.9842);
      await maps.setCoordinate(profileId: profile.id, owner: MapCoordinateOwner.contact, recordId: 'preserve', coordinate: coordinate);
      final calendar = DriftCalendarEventRepository(database: database, clock: FixedClock(DateTime.utc(2026, 8, 24, 14)), timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'));
      await calendar.saveEvent(profileId: profile.id, draft: const CalendarEventDraft(id: '11111111-1111-4111-8111-111111111111', title: 'A3 link', timing: CalendarEventTiming.timed, startDate: PlannerDate(year: 2026, month: 8, day: 30), startMinute: 600, endMinute: 660, timeZoneId: 'Asia/Manila', requiresReport: false));
      await contacts.setEventPeople(profileId: profile.id, eventId: '11111111-1111-4111-8111-111111111111', occurrenceId: 'series', contactIds: const <String>['preserve']);
      final planner = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 24, 14)),
      );
      await planner.saveTask(profileId: profile.id, draft: const PlannerTaskDraft(id: 'a3-linked-task', title: 'A3 link', dueDate: PlannerDate(year: 2026, month: 8, day: 31), requiresReport: false));
      await contacts.setTaskContacts(profileId: profile.id, taskId: 'a3-linked-task', contactIds: const <String>['preserve']);
      final before = await _a3Snapshot(database);
      await contacts.setContactGroups(
        profileId: profile.id,
        contactId: 'preserve',
        groupIds: <String>[friends.id],
        primaryGroupId: friends.id,
      );
      await _expectA3NonGroupsUnchanged(database, before, maps, profile.id);
      var groups = await _a3Groups(database);
      expect(
        groups.singleWhere((r) => r.groupId == friends.id).isPrimary,
        isTrue,
      );
      expect(
        groups.singleWhere((r) => r.groupId == family.id).isPrimary,
        isFalse,
      );
      await contacts.setContactGroups(
        profileId: profile.id,
        contactId: 'preserve',
        groupIds: const <String>[],
        primaryGroupId: null,
      );
      await _expectA3NonGroupsUnchanged(database, before, maps, profile.id);
      groups = await _a3Groups(database);
      expect(groups, hasLength(2));
      expect(groups.where((r) => r.isPrimary), isEmpty);
    },
  );
}

Future<List<ContactGroupMembershipRow>> _a3Groups(AppDatabase db) => (db.select(
  db.contactGroupMemberships,
)..where((r) => r.contactId.equals('preserve'))).get();
Future<
  ({
    ContactRow contact,
    List<ContactMethodRow> methods,
    List<ContactTagMembershipRow> tags,
    List<ContactAvailabilityRow> availability,
    List<ContactNoteRow> notes,
    List<EventContactLinkRow> eventLinks,
    List<TaskContactLinkRow> taskLinks,
  })
>
_a3Snapshot(AppDatabase db) async => (
  contact: await (db.select(
    db.contacts,
  )..where((r) => r.id.equals('preserve'))).getSingle(),
  methods: await (db.select(
    db.contactMethods,
  )..where((r) => r.contactId.equals('preserve'))).get(),
  tags: await (db.select(
    db.contactTagMemberships,
  )..where((r) => r.contactId.equals('preserve'))).get(),
  availability: await (db.select(
    db.contactAvailabilities,
  )..where((r) => r.contactId.equals('preserve'))).get(),
  notes: await (db.select(
    db.contactNotes,
  )..where((r) => r.contactId.equals('preserve'))).get(),
  eventLinks: await (db.select(db.eventContactLinks)..where((r) => r.contactId.equals('preserve'))).get(),
  taskLinks: await (db.select(db.taskContactLinks)..where((r) => r.contactId.equals('preserve'))).get(),
);
Future<void> _expectA3NonGroupsUnchanged(
  AppDatabase db,
  ({
    ContactRow contact,
    List<ContactMethodRow> methods,
    List<ContactTagMembershipRow> tags,
    List<ContactAvailabilityRow> availability,
    List<ContactNoteRow> notes,
    List<EventContactLinkRow> eventLinks,
    List<TaskContactLinkRow> taskLinks,
  })
  before,
  DriftMapCoordinateRepository maps,
  String profileId,
) async {
  final after = await _a3Snapshot(db);
  expect(after.methods, before.methods);
  expect(after.tags, before.tags);
  expect(after.availability, before.availability);
  expect(after.notes, before.notes);
  expect(after.eventLinks, before.eventLinks);
  expect(after.taskLinks, before.taskLinks);
  expect(before.eventLinks.single.eventId, '11111111-1111-4111-8111-111111111111');
  expect(before.taskLinks.single.taskId, 'a3-linked-task');
  expect(await maps.readCoordinate(profileId: profileId, owner: MapCoordinateOwner.contact, recordId: 'preserve'), const MapCoordinate(latitude: 14.5995, longitude: 120.9842));
  expect(after.contact.firstName, before.contact.firstName);
  expect(after.contact.lastName, before.contact.lastName);
  expect(after.contact.addressText, before.contact.addressText);
  expect(after.contact.source, before.contact.source);
  expect(after.contact.lifecycleState, before.contact.lifecycleState);
  expect(after.contact.archivedAtUtc, before.contact.archivedAtUtc);
  expect(after.contact.isFavorite, before.contact.isFavorite);
  expect(
    after.contact.preferredContactMethod,
    before.contact.preferredContactMethod,
  );
}

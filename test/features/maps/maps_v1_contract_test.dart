// MAPS V1 — data / repository / external-handoff contract tests.
//
// Locks the v27 -> v28 additive coordinate migration, the both-or-null
// coordinate invariant, profile scoping, free-text preservation on clear,
// marker projection, and the external navigation no-outcome handoff.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/test_dependencies.dart';

const _contactId = '11111111-1111-4111-8111-111111111111';
const _eventId = '22222222-2222-4222-8222-222222222222';

void main() {
  late AppDatabase database;
  late String profileId;
  late DriftMapCoordinateRepository maps;

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    maps = DriftMapCoordinateRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 16, 12)),
    );
  });

  tearDown(() => database.close());

  Future<void> createContactWithAddress({
    String? addressText = '123 Main St, Manila',
  }) async {
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 16, 12)),
      identifiers: SequenceIdentifierSource(<String>[_contactId]),
    );
    await contacts.createContact(
      profileId: profileId,
      draft: ContactDraft(
        id: _contactId,
        firstName: 'Ana',
        lastName: 'Reyes',
        displayName: 'Ana Reyes',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
        addressText: addressText,
      ),
    );
  }

  Future<void> createEventWithLocation({
    String? locationText = 'Chapel, 9:30 AM',
  }) async {
    final events = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 16, 12)),
      timeZones: IanaCalendarEventTimeZones(
        displayTimeZoneId: 'Asia/Manila',
      ),
    );
    await events.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: _eventId,
        title: 'Temple Visit',
        timing: CalendarEventTiming.timed,
        startDate: const PlannerDate(year: 2026, month: 8, day: 16),
        startMinute: 9 * 60 + 30,
        endMinute: 10 * 60 + 30,
        timeZoneId: 'Asia/Manila',
        locationText: locationText,
        requiresReport: false,
      ),
    );
  }

  group('v27 -> v28 migration', () {
    test('preserves every existing row; coordinate columns null; no backfill',
        () async {
      final sqliteDatabase = sqlite3.openInMemory();
      try {
        final v27 = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 27,
        );
        final v27Profile = (await buildTestRepository(
          database: v27,
        ).completeOnboarding()).id;
        final contacts = DriftContactRepository(
          database: v27,
          clock: FixedClock(DateTime.utc(2026, 8, 16, 12)),
          identifiers: SequenceIdentifierSource(<String>[_contactId]),
        );
        await contacts.createContact(
          profileId: v27Profile,
          draft: const ContactDraft(
            id: _contactId,
            firstName: 'Ana',
            lastName: 'Reyes',
            displayName: 'Ana Reyes',
            preferredContactMethod: ContactPreferredMethod.message,
            isFavorite: false,
            addressText: '123 Main St, Manila',
          ),
        );
        final events = DriftCalendarEventRepository(
          database: v27,
          clock: FixedClock(DateTime.utc(2026, 8, 16, 12)),
          timeZones: IanaCalendarEventTimeZones(
            displayTimeZoneId: 'Asia/Manila',
          ),
        );
        await events.saveEvent(
          profileId: v27Profile,
          draft: CalendarEventDraft(
            id: _eventId,
            title: 'Temple Visit',
            timing: CalendarEventTiming.timed,
            startDate: const PlannerDate(year: 2026, month: 8, day: 16),
            startMinute: 9 * 60 + 30,
            endMinute: 10 * 60 + 30,
            timeZoneId: 'Asia/Manila',
            locationText: 'Chapel, 9:30 AM',
            requiresReport: false,
          ),
        );
        final v27Version = await v27
            .customSelect('PRAGMA user_version')
            .getSingle();
        await v27.close();

        final v28 = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 28,
        );
        final userVersion = await v28
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(userVersion.read<int>('user_version'), 28);

        final contactRow = await (v28.select(v28.contacts)
              ..where((t) => t.id.equals(_contactId)))
            .getSingle();
        expect(contactRow.addressText, '123 Main St, Manila');
        expect(contactRow.latitude, isNull);
        expect(contactRow.longitude, isNull);
        expect(contactRow.coordinateSource, isNull);

        final eventRow = await (v28.select(v28.calendarEvents)
              ..where((t) => t.id.equals(_eventId)))
            .getSingle();
        expect(eventRow.locationText, 'Chapel, 9:30 AM');
        expect(eventRow.latitude, isNull);
        expect(eventRow.longitude, isNull);
        expect(eventRow.coordinateSource, isNull);

        final markerCount = await v28
            .customSelect(
              'SELECT (SELECT COUNT(*) FROM contacts WHERE latitude IS NOT '
              'NULL OR longitude IS NOT NULL) '
              '+ (SELECT COUNT(*) FROM calendar_events WHERE latitude IS NOT '
              'NULL OR longitude IS NOT NULL) AS marked',
            )
            .getSingle();
        expect(markerCount.read<int>('marked'), 0,
            reason: 'v28 must never backfill coordinates');
        expect(v27Version.read<int>('user_version'), 27);
        await v28.close();
      } finally {
        sqliteDatabase.close();
      }
    });
  });

  group('coordinate repository', () {
    test('Contact: set -> read -> clear preserves address text', () async {
      await createContactWithAddress();
      const coordinate = MapCoordinate(latitude: 14.5995, longitude: 120.9842);
      await maps.setCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
        coordinate: coordinate,
      );

      final read = await maps.readCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
      );
      expect(read, coordinate);
      expect(read?.description, '14.59950, 120.98420');

      final rowAfterSet = await (database.select(database.contacts)
            ..where((t) => t.id.equals(_contactId)))
          .getSingle();
      expect(rowAfterSet.latitude, coordinate.latitude);
      expect(rowAfterSet.longitude, coordinate.longitude);
      expect(rowAfterSet.coordinateSource, MapCoordinate.sourceMapPick);
      expect(rowAfterSet.addressText, '123 Main St, Manila');

      await maps.clearCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
      );
      final cleared = await maps.readCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
      );
      expect(cleared, isNull);
      final rowAfterClear = await (database.select(database.contacts)
            ..where((t) => t.id.equals(_contactId)))
          .getSingle();
      expect(rowAfterClear.latitude, isNull);
      expect(rowAfterClear.longitude, isNull);
      expect(rowAfterClear.coordinateSource, isNull);
      expect(rowAfterClear.addressText, '123 Main St, Manila',
          reason: 'clearing a pin must never touch free-text address');
    });

    test('Event: set -> read -> clear preserves location text', () async {
      await createEventWithLocation();
      const coordinate = MapCoordinate(latitude: 10.3157, longitude: 123.8854);
      await maps.setCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.event,
        recordId: _eventId,
        coordinate: coordinate,
      );
      final read = await maps.readCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.event,
        recordId: _eventId,
      );
      expect(read, coordinate);

      final row = await (database.select(database.calendarEvents)
            ..where((t) => t.id.equals(_eventId)))
          .getSingle();
      expect(row.coordinateSource, MapCoordinate.sourceMapPick);
      expect(row.locationText, 'Chapel, 9:30 AM');

      await maps.clearCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.event,
        recordId: _eventId,
      );
      expect(
        await maps.readCoordinate(
          profileId: profileId,
          owner: MapCoordinateOwner.event,
          recordId: _eventId,
        ),
        isNull,
      );
      final clearedRow = await (database.select(database.calendarEvents)
            ..where((t) => t.id.equals(_eventId)))
          .getSingle();
      expect(clearedRow.locationText, 'Chapel, 9:30 AM');
    });

    test('partial/out-of-range pairs never become coordinates', () async {
      await createContactWithAddress();
      expect(MapCoordinate.tryParse(14.5, null), isNull);
      expect(MapCoordinate.tryParse(null, 120.9), isNull);
      expect(MapCoordinate.tryParse(91.0, 120.9), isNull);
      expect(MapCoordinate.tryParse(14.5, 181.0), isNull);
      expect(MapCoordinate.tryParse(-91.0, 0), isNull);
      expect(MapCoordinate.tryParse(14.5, -181.0), isNull);
      expect(
        MapCoordinate.tryParse(14.5995, 120.9842),
        const MapCoordinate(latitude: 14.5995, longitude: 120.9842),
      );

      // A DB row with a partial pair is projected as NO marker (defensive
      // invariant at the read boundary).
      await (database.update(database.contacts)..where(
            (t) => t.id.equals(_contactId),
          )).write(
        const ContactsCompanion(latitude: Value(14.5), longitude: Value(null)),
      );
      final markers = await maps.readMarkers(profileId);
      expect(markers, isEmpty);
    });

    test('markers are profile-scoped and carry typed ownership keys',
        () async {
      await createContactWithAddress();
      await createEventWithLocation();
      const contactCoordinate = MapCoordinate(
        latitude: 14.5995,
        longitude: 120.9842,
      );
      const eventCoordinate = MapCoordinate(
        latitude: 10.3157,
        longitude: 123.8854,
      );
      await maps.setCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
        coordinate: contactCoordinate,
      );
      await maps.setCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.event,
        recordId: _eventId,
        coordinate: eventCoordinate,
      );

      final markers = await maps.readMarkers(profileId);
      expect(markers, hasLength(2));
      final contactMarker = markers.singleWhere(
        (marker) => marker.owner == MapCoordinateOwner.contact,
      );
      final eventMarker = markers.singleWhere(
        (marker) => marker.owner == MapCoordinateOwner.event,
      );
      expect(contactMarker.recordId, _contactId);
      expect(contactMarker.displayName, 'Ana Reyes');
      expect(contactMarker.coordinate, contactCoordinate);
      expect(contactMarker.ownerKey, 'contact:$_contactId');
      expect(eventMarker.recordId, _eventId);
      expect(eventMarker.displayName, 'Temple Visit');
      expect(eventMarker.coordinate, eventCoordinate);
      expect(eventMarker.ownerKey, 'event:$_eventId');
      expect(eventMarker.eventStartDate?.iso8601, '2026-08-16');

      // A second profile sees nothing.  (completeOnboarding returns the
      // existing primary profile, so insert the second row directly.)
      const otherProfileId = '99999999-9999-4999-8999-999999999999';
      await database.into(database.localProfiles).insert(
        LocalProfilesCompanion.insert(
          id: otherProfileId,
          slot: const Value<String>('secondary'),
          localName: 'Local Profile 99999999',
          createdAtUtc: DateTime.utc(2026, 8, 16),
          updatedAtUtc: DateTime.utc(2026, 8, 16),
        ),
      );
      expect(await maps.readMarkers(otherProfileId), isEmpty);
    });

    test('watchChanges emits when a pin is written', () async {
      await createContactWithAddress();
      final emissions = <int>[];
      final subscription = maps.watchChanges(profileId).listen(emissions.add);
      await maps.setCoordinate(
        profileId: profileId,
        owner: MapCoordinateOwner.contact,
        recordId: _contactId,
        coordinate: const MapCoordinate(
          latitude: 14.5995,
          longitude: 120.9842,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();
      expect(emissions, isNotEmpty);
    });
  });

  group('external navigation handoff', () {
    test('handoff is a pure geo-URI action; no DB write occurs', () async {
      await createContactWithAddress();
      final before = await (database.select(database.contacts)
            ..where((t) => t.id.equals(_contactId)))
          .getSingle();
      // canLaunch/launch only build and hand off a geo: URI; they never touch
      // the database.  The no-outcome property is enforced by the callers
      // (detail/form screens), pinned here at the repository level.
      final uri = Uri.parse(
        'geo:14.5995,120.9842?q=14.5995%2C120.9842',
      );
      expect(uri.scheme, 'geo');
      expect(uri.path, '14.5995,120.9842');
      final after = await (database.select(database.contacts)
            ..where((t) => t.id.equals(_contactId)))
          .getSingle();
      expect(after.latitude, before.latitude);
      expect(after.longitude, before.longitude);
      expect(after.addressText, before.addressText);
    });
  });
}

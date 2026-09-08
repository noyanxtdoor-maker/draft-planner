import 'dart:async';

import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

/// Drift-backed Maps V1 repository.
///
/// Coordinates live directly on the owning `contacts`, `calendar_events`, and
/// `saved_places` rows. Contact/Event pairs are nullable (v28); Saved Places
/// always have a coordinate (v34). The pair
/// invariant (both present or both absent) is enforced on every write, and
/// clearing a pin touches ONLY the coordinate columns — address/location
/// text is never modified.
final class DriftMapCoordinateRepository implements MapCoordinateRepository {
  DriftMapCoordinateRepository({required this.database, required this.clock});

  final AppDatabase database;
  final AppClock clock;

  @override
  Stream<int> watchChanges(String profileId) {
    var generation = 0;
    return database
        .tableUpdates(
          TableUpdateQuery.onAllTables(<ResultSetImplementation>[
            database.contacts,
            database.contactGroupMemberships,
            database.contactGroups,
            database.calendarEvents,
            database.calendarEventExceptions,
            database.outcomeReports,
            database.savedPlaces,
          ]),
        )
        .map((_) => ++generation);
  }

  @override
  Future<void> setCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
    required MapCoordinate coordinate,
  }) async {
    final now = clock.nowUtc();
    switch (owner) {
      case MapCoordinateOwner.contact:
        await (database.update(database.contacts)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(recordId),
            ))
            .write(
              ContactsCompanion(
                latitude: Value<double?>(coordinate.latitude),
                longitude: Value<double?>(coordinate.longitude),
                coordinateSource: Value<String?>(MapCoordinate.sourceMapPick),
                updatedAtUtc: Value<DateTime>(now),
              ),
            );
      case MapCoordinateOwner.event:
        await (database.update(database.calendarEvents)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(recordId),
            ))
            .write(
              CalendarEventsCompanion(
                latitude: Value<double?>(coordinate.latitude),
                longitude: Value<double?>(coordinate.longitude),
                coordinateSource: Value<String?>(MapCoordinate.sourceMapPick),
                updatedAtUtc: Value<DateTime>(now),
              ),
            );
      case MapCoordinateOwner.savedPlace:
        await (database.update(database.savedPlaces)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(recordId),
            ))
            .write(
              SavedPlacesCompanion(
                latitude: Value<double>(coordinate.latitude),
                longitude: Value<double>(coordinate.longitude),
                updatedAtUtc: Value<DateTime>(now),
              ),
            );
    }
  }

  @override
  Future<void> clearCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async {
    final now = clock.nowUtc();
    switch (owner) {
      case MapCoordinateOwner.contact:
        await (database.update(database.contacts)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(recordId),
            ))
            .write(
              ContactsCompanion(
                latitude: const Value<double?>(null),
                longitude: const Value<double?>(null),
                coordinateSource: const Value<String?>(null),
                updatedAtUtc: Value<DateTime>(now),
              ),
            );
      case MapCoordinateOwner.event:
        await (database.update(database.calendarEvents)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(recordId),
            ))
            .write(
              CalendarEventsCompanion(
                latitude: const Value<double?>(null),
                longitude: const Value<double?>(null),
                coordinateSource: const Value<String?>(null),
                updatedAtUtc: Value<DateTime>(now),
              ),
            );
      case MapCoordinateOwner.savedPlace:
        throw StateError('Saved Places must retain a coordinate.');
    }
  }

  @override
  Future<MapCoordinate?> readCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async {
    switch (owner) {
      case MapCoordinateOwner.contact:
        final row =
            await (database.select(database.contacts)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.id.equals(recordId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) {
          return null;
        }
        return MapCoordinate.tryParse(row.latitude, row.longitude);
      case MapCoordinateOwner.event:
        final row =
            await (database.select(database.calendarEvents)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.id.equals(recordId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) {
          return null;
        }
        return MapCoordinate.tryParse(row.latitude, row.longitude);
      case MapCoordinateOwner.savedPlace:
        final row =
            await (database.select(database.savedPlaces)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.id.equals(recordId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (row == null) return null;
        return MapCoordinate.tryParse(row.latitude, row.longitude);
    }
  }

  @override
  Future<List<MapMarker>> readMarkers(String profileId) async {
    final markers = <MapMarker>[];
    final contactRows =
        await (database.select(database.contacts)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.latitude.isNotNull() &
                  table.longitude.isNotNull(),
            ))
            .get();
    for (final row in contactRows) {
      final coordinate = MapCoordinate.tryParse(row.latitude, row.longitude);
      if (coordinate == null) {
        continue;
      }
      markers.add(
        MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: row.id,
          coordinate: coordinate,
          displayName: row.displayName,
        ),
      );
    }
    final eventRows =
        await (database.select(database.calendarEvents)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.latitude.isNotNull() &
                  table.longitude.isNotNull(),
            ))
            .get();
    for (final row in eventRows) {
      final coordinate = MapCoordinate.tryParse(row.latitude, row.longitude);
      if (coordinate == null) {
        continue;
      }
      markers.add(
        MapMarker(
          owner: MapCoordinateOwner.event,
          recordId: row.id,
          coordinate: coordinate,
          displayName: row.title,
          eventOriginalDate: _safeParseDate(row.startDate),
        ),
      );
    }
    final savedPlaceRows =
        await (database.select(database.savedPlaces)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.label),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    for (final row in savedPlaceRows) {
      final mode = SavedPlaceMarkerModePersistence.fromStorage(row.markerMode);
      markers.add(
        MapMarker(
          owner: MapCoordinateOwner.savedPlace,
          recordId: row.id,
          coordinate: MapCoordinate(
            latitude: row.latitude,
            longitude: row.longitude,
          ),
          displayName: row.label,
          colorValue: markerColorHexToArgb(row.markerColor),
          placeMarkerMode: mode,
          placeStandardCategory:
              SavedPlaceStandardCategoryPresentation.fromStorage(
                row.standardCategory,
              ),
          placeEmoji: mode == SavedPlaceMarkerMode.custom
              ? row.customEmoji
              : null,
        ),
      );
    }
    return markers;
  }

  static PlannerDate? _safeParseDate(String raw) {
    try {
      return PlannerDate.parse(raw);
    } on FormatException {
      return null;
    }
  }
}

import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/maps/application/saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart' as domain;

final class DriftSavedPlaceRepository implements SavedPlaceRepository {
  const DriftSavedPlaceRepository({
    required this.database,
    required this.clock,
    required this.identifiers,
  });

  final AppDatabase database;
  final AppClock clock;
  final IdentifierSource identifiers;

  @override
  Stream<List<domain.SavedPlace>> watch(String profileId) {
    final query = database.select(database.savedPlaces)
      ..where((table) => table.profileId.equals(profileId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.label),
        (table) => OrderingTerm.asc(table.createdAtUtc),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Future<List<domain.SavedPlace>> list(String profileId) async {
    final query = database.select(database.savedPlaces)
      ..where((table) => table.profileId.equals(profileId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.label),
        (table) => OrderingTerm.asc(table.createdAtUtc),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return (await query.get()).map(_map).toList(growable: false);
  }

  @override
  Future<domain.SavedPlace?> readById({
    required String profileId,
    required String id,
  }) async {
    final row =
        await (database.select(database.savedPlaces)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) & table.id.equals(id),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<domain.SavedPlace> create({
    required String profileId,
    required domain.SavedPlaceDraft draft,
  }) async {
    final normalized = draft.normalized();
    final now = clock.nowUtc();
    final id = identifiers.nextUuid();
    await database
        .into(database.savedPlaces)
        .insert(
          SavedPlacesCompanion.insert(
            id: id,
            profileId: profileId,
            label: normalized.label,
            latitude: normalized.coordinate.latitude,
            longitude: normalized.coordinate.longitude,
            markerMode: Value<String>(normalized.markerMode.storageKey),
            standardCategory: Value<String?>(
              normalized.markerMode == domain.SavedPlaceMarkerMode.standard
                  ? normalized.standardCategory.storageKey
                  : null,
            ),
            customEmoji: Value<String?>(normalized.customEmoji),
            markerColor: Value<String>(normalized.markerColorHex),
            boundaryColor: Value<String?>(normalized.boundary?.colorHex),
            boundaryVertices: Value<String?>(
              normalized.boundary?.encodeVertices(),
            ),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    return (await readById(profileId: profileId, id: id))!;
  }

  @override
  Future<domain.SavedPlace> update({
    required String profileId,
    required String id,
    required domain.SavedPlaceDraft draft,
  }) async {
    final normalized = draft.normalized();
    final updated =
        await (database.update(database.savedPlaces)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(id),
            ))
            .write(
              SavedPlacesCompanion(
                label: Value<String>(normalized.label),
                latitude: Value<double>(normalized.coordinate.latitude),
                longitude: Value<double>(normalized.coordinate.longitude),
                markerMode: Value<String>(normalized.markerMode.storageKey),
                standardCategory: Value<String?>(
                  normalized.markerMode == domain.SavedPlaceMarkerMode.standard
                      ? normalized.standardCategory.storageKey
                      : null,
                ),
                customEmoji: Value<String?>(normalized.customEmoji),
                markerColor: Value<String>(normalized.markerColorHex),
                boundaryColor: Value<String?>(normalized.boundary?.colorHex),
                boundaryVertices: Value<String?>(
                  normalized.boundary?.encodeVertices(),
                ),
                updatedAtUtc: Value<DateTime>(clock.nowUtc()),
              ),
            );
    if (updated != 1) {
      throw const domain.SavedPlaceValidationException(
        'Saved Place not found.',
      );
    }
    return (await readById(profileId: profileId, id: id))!;
  }

  @override
  Future<void> delete({required String profileId, required String id}) async {
    await (database.delete(database.savedPlaces)..where(
          (table) => table.profileId.equals(profileId) & table.id.equals(id),
        ))
        .go();
  }

  domain.SavedPlace _map(SavedPlace row) {
    final mode = domain.SavedPlaceMarkerModePersistence.fromStorage(
      row.markerMode,
    );
    return domain.SavedPlace(
      id: row.id,
      profileId: row.profileId,
      label: row.label,
      coordinate: MapCoordinate(
        latitude: row.latitude,
        longitude: row.longitude,
      ),
      markerMode: mode,
      standardCategory:
          domain.SavedPlaceStandardCategoryPresentation.fromStorage(
            row.standardCategory,
          ),
      customEmoji: mode == domain.SavedPlaceMarkerMode.custom
          ? row.customEmoji
          : null,
      markerColorHex: domain.normalizeMarkerColorHex(row.markerColor),
      boundary: domain.SavedPlaceBoundary.tryDecodeVertices(
        row.boundaryVertices,
        colorHex: row.boundaryColor ?? domain.defaultBoundaryColorHex,
      ),
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
    );
  }
}

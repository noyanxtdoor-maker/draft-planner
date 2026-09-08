import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/maps/application/map_session_provider.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_repository.dart';

/// Drift-backed, device-scoped Maps preferences repository (VS-15 M6.2).
///
/// Reads and writes the single-row `MapsPreferences` table (schema v37)
/// keyed by the constant 'primary' (Appearance/Privacy precedent). A missing
/// row (fresh install OR v36 upgrade with no user choice yet) resolves the
/// owner-locked defaults; an invalid persisted map type token fails safely
/// to Satellite; an explicit choice always creates the physical row.
final class DriftMapsPreferencesRepository
    implements MapsPreferencesRepository {
  const DriftMapsPreferencesRepository({
    required this.database,
    required this.clock,
  });

  final AppDatabase database;
  final AppClock clock;

  static const String _primaryKey = 'primary';

  @override
  Future<MapsPreferencesModel> readPreferences() async {
    final row = await (database.select(
      database.mapsPreferences,
    )).getSingleOrNull();
    if (row == null) {
      return const MapsPreferencesModel();
    }
    return MapsPreferencesModel(
      mapType: NextTransferMapType.fromStorage(row.mapType),
      groupNearbyMarkers: row.groupNearbyMarkers,
      showContacts: row.showContacts,
      showEvents: row.showEvents,
      showSavedPlaces: row.showSavedPlaces,
      showBoundaries: row.showBoundaries,
    );
  }

  @override
  Future<void> savePreferences(MapsPreferencesModel preferences) async {
    final row = await (database.select(
      database.mapsPreferences,
    )).getSingleOrNull();
    if (row != null &&
        row.mapType == preferences.mapType.storageName &&
        row.groupNearbyMarkers == preferences.groupNearbyMarkers &&
        row.showContacts == preferences.showContacts &&
        row.showEvents == preferences.showEvents &&
        row.showSavedPlaces == preferences.showSavedPlaces &&
        row.showBoundaries == preferences.showBoundaries) {
      // Idempotent no-write: a PHYSICAL row exists and already stores the
      // requested value. A missing row must still write (default row law).
      return;
    }
    await database
        .into(database.mapsPreferences)
        .insertOnConflictUpdate(
          MapsPreferencesCompanion.insert(
            key: const Value<String>(_primaryKey),
            mapType: Value<String>(preferences.mapType.storageName),
            groupNearbyMarkers: Value<bool>(preferences.groupNearbyMarkers),
            showContacts: Value<bool>(preferences.showContacts),
            showEvents: Value<bool>(preferences.showEvents),
            showSavedPlaces: Value<bool>(preferences.showSavedPlaces),
            showBoundaries: Value<bool>(preferences.showBoundaries),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
  }
}

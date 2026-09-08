import 'package:rmplanner/features/maps/application/map_session_provider.dart';

/// Device-scoped Maps presentation preferences (VS-15 M6.2 / schema v37).
///
/// One durable truth for Map Type, marker grouping, and layer visibility.
/// Device-scoped on purpose: switching Local Profile must NOT change the
/// base map type, grouping preference, or layer visibility.
///
/// DEFAULT ROW LAW: a missing physical row resolves the owner-locked
/// defaults below for BOTH fresh and upgraded installs. An explicit user
/// choice must create the physical row even when the resolved value equals
/// the requested value; an idempotent no-write is only allowed when a
/// physical row already stores the requested value.
final class MapsPreferencesModel {
  const MapsPreferencesModel({
    this.mapType = NextTransferMapType.satellite,
    this.groupNearbyMarkers = true,
    this.showContacts = true,
    this.showEvents = true,
    this.showSavedPlaces = true,
    this.showBoundaries = true,
  });

  final NextTransferMapType mapType;
  final bool groupNearbyMarkers;
  final bool showContacts;
  final bool showEvents;
  final bool showSavedPlaces;
  final bool showBoundaries;

  MapsPreferencesModel copyWith({
    NextTransferMapType? mapType,
    bool? groupNearbyMarkers,
    bool? showContacts,
    bool? showEvents,
    bool? showSavedPlaces,
    bool? showBoundaries,
  }) {
    return MapsPreferencesModel(
      mapType: mapType ?? this.mapType,
      groupNearbyMarkers: groupNearbyMarkers ?? this.groupNearbyMarkers,
      showContacts: showContacts ?? this.showContacts,
      showEvents: showEvents ?? this.showEvents,
      showSavedPlaces: showSavedPlaces ?? this.showSavedPlaces,
      showBoundaries: showBoundaries ?? this.showBoundaries,
    );
  }
}

/// Device-scoped read/write path for the Maps preferences.
///
/// The values are persisted in the single-row `MapsPreferences` table
/// (schema v37) so no profile or domain readiness is required to read them
/// before the first frame.
abstract interface class MapsPreferencesRepository {
  /// Returns the current device Maps preferences, or the owner-locked
  /// defaults when no row exists yet. An invalid stored map type token
  /// fails safely to [NextTransferMapType.satellite].
  Future<MapsPreferencesModel> readPreferences();

  /// Atomically persists the complete preference set as one single-row
  /// upsert. Updating one field must preserve all other stored fields, so
  /// callers pass the full model (usually `current.copyWith(field: v)`).
  ///
  /// The write is skipped ONLY when a physical row already exists and every
  /// stored value already matches the requested set (idempotent no-write).
  /// A missing physical row always writes, even when the resolved default
  /// equals the requested value.
  Future<void> savePreferences(MapsPreferencesModel preferences);
}

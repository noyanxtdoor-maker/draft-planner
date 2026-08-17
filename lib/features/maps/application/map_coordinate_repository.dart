import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

/// Which owner table a saved map pin belongs to.  Markers use the stable
/// typed ownership key `contact:<id>` / `event:<id>`.
enum MapCoordinateOwner { contact, event }

extension MapCoordinateOwnerKey on MapCoordinateOwner {
  String get kind => switch (this) {
    MapCoordinateOwner.contact => 'contact',
    MapCoordinateOwner.event => 'event',
  };

  String ownerKey(String recordId) => MapCoordinate.ownerKey(kind, recordId);
}

/// A located record shown as a map marker.  Coordinates are ONLY explicit
/// user map-picks; they are never derived from address/location text and
/// never silently geocoded.
final class MapMarker {
  const MapMarker({
    required this.owner,
    required this.recordId,
    required this.coordinate,
    required this.displayName,
    this.eventStartDate,
  });

  final MapCoordinateOwner owner;
  final String recordId;
  final MapCoordinate coordinate;
  final String displayName;

  /// Present only for Event markers so a marker tap can open the exact
  /// occurrence's detail route.
  final PlannerDate? eventStartDate;

  String get ownerKey => owner.ownerKey(recordId);
}

/// Maps V1 persistence.  A separate, additive repository (not the large
/// Contact/Event repositories) so existing test doubles are untouched.
abstract interface class MapCoordinateRepository {
  /// Coalesced table change stream over the two coordinate-bearing tables,
  /// used by the Maps screen to refresh markers without polling.
  Stream<int> watchChanges(String profileId);

  /// Persists an explicit user map-pick for the record.  Requires a
  /// valid coordinate pair; the pair invariant (both present or both
  /// absent) is enforced here, never partially writable.
  Future<void> setCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
    required MapCoordinate coordinate,
  });

  /// Removes ONLY the coordinate pair + source.  Free text address /
  /// location text is never touched.
  Future<void> clearCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  });

  Future<MapCoordinate?> readCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  });

  /// Every located Contact and Event marker in the profile.
  Future<List<MapMarker>> readMarkers(String profileId);
}

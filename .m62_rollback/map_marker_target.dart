import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';

final class MapMarkerTarget {
  MapMarkerTarget(Iterable<MapMarker> records)
    : members = List.unmodifiable(records);
  final List<MapMarker> members;
  bool get isAggregate => members.length > 1;
  MapCoordinate get coordinate => members.first.coordinate;
  String get key => isAggregate
      ? 'maps-location:${coordinate.latitude}:${coordinate.longitude}'
      : members.single.ownerKey;
}

List<MapMarkerTarget> exactCoordinateTargets(
  Iterable<MapMarker> markers, {
  String? excludedOwnerKey,
}) {
  final locations = <MapCoordinate, List<MapMarker>>{};
  final seen = <String>{};
  for (final marker in markers) {
    if (marker.ownerKey != excludedOwnerKey && seen.add(marker.ownerKey)) {
      locations.putIfAbsent(marker.coordinate, () => []).add(marker);
    }
  }
  return [for (final records in locations.values) MapMarkerTarget(records)];
}

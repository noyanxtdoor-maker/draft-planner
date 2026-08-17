/// MAPS V1 validated coordinate value.
///
/// Coordinates exist ONLY after an explicit user map selection; they are
/// never derived from address/location text and never geocoded silently.
/// The pair invariant (both null or both non-null) is enforced by the
/// repository; this type validates the numeric ranges.
final class MapCoordinate {
  const MapCoordinate({required this.latitude, required this.longitude})
    : assert(latitude >= -90 && latitude <= 90),
      assert(longitude >= -180 && longitude <= 180);

  final double latitude;
  final double longitude;

  /// Stable V1 provenance for explicitly map-picked coordinates.
  static const String sourceMapPick = 'map_pick';

  /// Builds a coordinate only when BOTH values are present and in range.
  static MapCoordinate? tryParse(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }
    if (latitude < -90 || latitude > 90) {
      return null;
    }
    if (longitude < -180 || longitude > 180) {
      return null;
    }
    return MapCoordinate(latitude: latitude, longitude: longitude);
  }

  /// The stable typed marker-ownership key (`contact:<id>` / `event:<id>`).
  static String ownerKey(String kind, String recordId) => '$kind:$recordId';

  String get description => '${latitude.toStringAsFixed(5)}, '
      '${longitude.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) {
    return other is MapCoordinate &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'MapCoordinate($description)';
}

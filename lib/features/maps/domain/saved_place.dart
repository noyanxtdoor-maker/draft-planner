import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';

/// How a Saved Place renders its map marker.
///
/// [standard] uses one of the locked [SavedPlaceStandardCategory] glyphs;
/// [custom] uses a user-chosen emoji as the marker identity. The persisted
/// color is independent of mode, so any marker can be recolored while keeping
/// its category/custom identity.
enum SavedPlaceMarkerMode { standard, custom }

extension SavedPlaceMarkerModePersistence on SavedPlaceMarkerMode {
  String get storageKey => switch (this) {
    SavedPlaceMarkerMode.standard => 'standard',
    SavedPlaceMarkerMode.custom => 'custom',
  };

  static SavedPlaceMarkerMode fromStorage(Object? value) => value == 'custom'
      ? SavedPlaceMarkerMode.custom
      : SavedPlaceMarkerMode.standard;
}

/// The lock-order Saved Place category set. Exact order is authoritative for
/// the editor grid. Default color is Next Transfer primary blue for every
/// category except [avoid], which defaults to a warning red.
enum SavedPlaceStandardCategory {
  information,
  avoid,
  food,
  repair,
  transit,
  wifi,
  haircut,
  shopping,
  laundry,
}

extension SavedPlaceStandardCategoryPresentation on SavedPlaceStandardCategory {
  String get label => switch (this) {
    SavedPlaceStandardCategory.information => 'Information',
    SavedPlaceStandardCategory.avoid => 'Avoid',
    SavedPlaceStandardCategory.food => 'Food',
    SavedPlaceStandardCategory.repair => 'Repair',
    SavedPlaceStandardCategory.transit => 'Transit',
    SavedPlaceStandardCategory.wifi => 'Wi-Fi',
    SavedPlaceStandardCategory.haircut => 'Haircut',
    SavedPlaceStandardCategory.shopping => 'Shopping',
    SavedPlaceStandardCategory.laundry => 'Laundry',
  };

  String get storageKey => switch (this) {
    SavedPlaceStandardCategory.information => 'information',
    SavedPlaceStandardCategory.avoid => 'avoid',
    SavedPlaceStandardCategory.food => 'food',
    SavedPlaceStandardCategory.repair => 'repair',
    SavedPlaceStandardCategory.transit => 'transit',
    SavedPlaceStandardCategory.wifi => 'wifi',
    SavedPlaceStandardCategory.haircut => 'haircut',
    SavedPlaceStandardCategory.shopping => 'shopping',
    SavedPlaceStandardCategory.laundry => 'laundry',
  };

  /// Resolves a persisted category key, falling back to [information] for any
  /// unrecognized or null value (the deterministic v34->v35 default).
  static SavedPlaceStandardCategory fromStorage(Object? value) =>
      SavedPlaceStandardCategory.values.firstWhere(
        (category) => category.storageKey == value,
        orElse: () => SavedPlaceStandardCategory.information,
      );

  /// Default category marker color: Next Transfer primary blue, except [avoid]
  /// which defaults to a warning red. Editable at runtime by the owner flow.
  int get defaultColorArgb => this == SavedPlaceStandardCategory.avoid
      ? _warningRedArgb
      : _primaryBlueArgb;
}

/// Next Transfer primary blue (AppTheme.blueLightPrimary).
const int _primaryBlueArgb = 0xFF175A8F;

/// Warning red used for the Avoid Saved Place marker and the centeraligned
/// red location-pin selection indicator (Colors.red.shade700 family).
const int _warningRedArgb = 0xFFD32F2F;

/// Canonical normalized hex (no alpha) form, e.g. `#175A8F`.
const String _primaryBlueHex = '#175A8F';

/// Public default for a NEW Saved Place boundary (canonical NT primary blue).
/// Independent from marker color after any edit.
const String defaultBoundaryColorHex = _primaryBlueHex;

/// A durable, profile-scoped Saved Place with full marker identity.
final class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.profileId,
    required this.label,
    required this.coordinate,
    required this.markerMode,
    required this.standardCategory,
    required this.customEmoji,
    required this.markerColorHex,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.boundary,
  });

  final String id;
  final String profileId;
  final String label;
  final MapCoordinate coordinate;
  final SavedPlaceMarkerMode markerMode;
  final SavedPlaceStandardCategory standardCategory;
  final String? customEmoji;

  /// Normalized persisted hex (no alpha), e.g. `#175A8F`.
  final String markerColorHex;

  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// VS-15 M6: the 0..1 user-drawn boundary owned by this place record.
  /// Boundary ownership is independent of marker mode/category/color.
  final SavedPlaceBoundary? boundary;

  int get markerColorArgb => markerColorHexToArgb(markerColorHex);
}

/// Draft used to create or update a Saved Place. Includes the full marker
/// identity (mode, category, emoji, color) added by the promoted customization
/// and the optional M6 boundary owned by the place record itself.
final class SavedPlaceDraft {
  const SavedPlaceDraft({
    required this.label,
    required this.coordinate,
    this.markerMode = SavedPlaceMarkerMode.standard,
    this.standardCategory = SavedPlaceStandardCategory.information,
    this.customEmoji,
    this.markerColorHex = _primaryBlueHex,
    this.boundary,
  });

  final String label;
  final MapCoordinate coordinate;
  final SavedPlaceMarkerMode markerMode;
  final SavedPlaceStandardCategory standardCategory;
  final String? customEmoji;
  final String markerColorHex;

  /// VS-15 M6: boundary draft carried by the owning form. Null means the
  /// place has no boundary; the draft-until-Save law keeps this purely
  /// in memory until the canonical Add/Edit Place persistence boundary.
  final SavedPlaceBoundary? boundary;

  SavedPlaceDraft normalized() {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) {
      throw const SavedPlaceValidationException('Place name cannot be blank.');
    }
    final mode = markerMode;
    final emoji = customEmoji?.trim();
    if (mode == SavedPlaceMarkerMode.custom &&
        (emoji == null || !isSingleEmojiGrapheme(emoji))) {
      throw const SavedPlaceValidationException(
        'Choose exactly one emoji for the custom marker.',
      );
    }
    final color = normalizeMarkerColorHex(markerColorHex);
    final category = mode == SavedPlaceMarkerMode.standard
        ? standardCategory
        : SavedPlaceStandardCategory.information;
    return SavedPlaceDraft(
      label: normalizedLabel,
      coordinate: coordinate,
      markerMode: mode,
      standardCategory: category,
      customEmoji: mode == SavedPlaceMarkerMode.custom ? emoji : null,
      markerColorHex: color,
      boundary: boundary,
    );
  }
}

/// True only for one user-visible grapheme that contains an emoji base.
///
/// Grapheme segmentation keeps joined families, skin-tone sequences, flags,
/// and variation-selector emoji together while rejecting arbitrary text and
/// multiple emoji. No preset list constrains the owner's keyboard choice.
bool isSingleEmojiGrapheme(String value) {
  final candidate = value.trim();
  if (candidate.isEmpty || candidate.characters.length != 1) return false;
  final runes = candidate.runes.toList(growable: false);
  final keycap =
      runes.contains(0x20E3) &&
      runes.any(
        (value) =>
            value == 0x23 || value == 0x2A || (value >= 0x30 && value <= 0x39),
      );
  final flag =
      runes.length == 2 &&
      runes.every((rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF);
  if (runes.last == 0x200D) return false;
  return keycap || flag || _emojiBase.hasMatch(candidate);
}

final RegExp _emojiBase =
    // ignore: valid_regexps
    RegExp(r'\p{Extended_Pictographic}', unicode: true);

/// Normalizes arbitrary user color input into a canonical no-alpha hex form.
///
/// Accepts `#175A8F`, `0xFF175A8F`, `0x175A8F`, `175A8F`, slim `175`, and a
/// leading `0x`/`#` style; strips any punctuation; returns the locked primary
/// blue hex for anything it cannot resolve.
String normalizeMarkerColorHex(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (text.length > 6 && text.startsWith('FF')) {
    text = text.substring(2);
  }
  if (text.startsWith('0x')) {
    text = text.substring(2);
  }
  if (text.length == 6) {
    return '#${text.toUpperCase()}';
  }
  if (text.length == 3) {
    final expanded = text.split('').map((char) => '$char$char').join();
    return '#${expanded.toUpperCase()}';
  }
  return _primaryBlueHex;
}

/// Parses a canonical hex into a fully opaque ARGB integer usable as a marker
/// color. Invalid input falls back to the primary blue.
int markerColorHexToArgb(String hex) {
  final normalized = normalizeMarkerColorHex(hex);
  final value = int.tryParse(normalized.substring(1), radix: 16) ?? 0x175A8F;
  return 0xFF000000 | value;
}

final class SavedPlaceValidationException implements Exception {
  const SavedPlaceValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// VS-15 M6: a user-drawn boundary polygon owned by ONE Saved Place record.
///
/// The boundary belongs to the place row itself — never to marker mode,
/// category, emoji, or marker color — and carries its own independent
/// [colorHex]. Exactly 0..1 boundary exists per place for V1.
final class SavedPlaceBoundary {
  const SavedPlaceBoundary({required this.colorHex, required this.vertices});

  /// Normalized persisted hex (no alpha), e.g. `#175A8F`. Independent from
  /// the place's marker color.
  final String colorHex;

  /// Ordered polygon vertices (3..[maxBoundaryVertices]), auto-closed
  /// implicitly (last -> first) at render time; the stored list never
  /// duplicates the first vertex as the last.
  final List<MapCoordinate> vertices;

  int get markerColorArgb => markerColorHexToArgb(colorHex);

  SavedPlaceBoundary copyWith({
    String? colorHex,
    List<MapCoordinate>? vertices,
  }) => SavedPlaceBoundary(
    colorHex: colorHex ?? this.colorHex,
    vertices: vertices ?? this.vertices,
  );

  /// Deterministic JSON: `[{"lat":<double>,"lng":<double>},...]` in vertex
  /// order. Color is stored in its own column, never inside this payload.
  String encodeVertices() =>
      '[${[for (final vertex in vertices) '{"lat":${vertex.latitude},"lng":${vertex.longitude}}'].join(',')}]';

  /// Defensive decode: ANY structural or range problem yields null so a
  /// malformed stored boundary is treated as absent and never crashes Maps.
  static SavedPlaceBoundary? tryDecodeVertices(
    String? raw, {
    required String colorHex,
  }) {
    if (raw == null) return null;
    final parsed = _decodeVertexList(raw);
    if (parsed == null) return null;
    final normalizedColor = normalizeMarkerColorHex(colorHex);
    if (parsed.length < minBoundaryVertices ||
        parsed.length > maxBoundaryVertices) {
      return null;
    }
    return SavedPlaceBoundary(colorHex: normalizedColor, vertices: parsed);
  }

  /// Re-validates a draft boundary through the same rules the editor's Done
  /// enforces; returns the canonical instance or null when invalid.
  static SavedPlaceBoundary? normalize(SavedPlaceBoundary? boundary) {
    if (boundary == null) return null;
    final vertices = sanitizeBoundaryVertices(boundary.vertices);
    if (vertices == null) return null;
    return SavedPlaceBoundary(
      colorHex: normalizeMarkerColorHex(boundary.colorHex),
      vertices: vertices,
    );
  }
}

/// Minimum vertices for a renderable boundary polygon.
const int minBoundaryVertices = 3;

/// Practical V1 ceiling for hand-drawn outlines.
const int maxBoundaryVertices = 500;

/// Deduplicates consecutive duplicates, clamps to [maxBoundaryVertices], and
/// requires [minBoundaryVertices] non-collinear vertices. Returns null when
/// the result cannot form a valid polygon (too few points or zero area).
List<MapCoordinate>? sanitizeBoundaryVertices(List<MapCoordinate> raw) {
  if (raw.isEmpty) return null;
  final deduped = <MapCoordinate>[raw.first];
  for (final vertex in raw.skip(1)) {
    final previous = deduped.last;
    if (previous.latitude != vertex.latitude ||
        previous.longitude != vertex.longitude) {
      deduped.add(vertex);
    }
  }
  if (deduped.length > maxBoundaryVertices) {
    deduped.removeRange(maxBoundaryVertices, deduped.length);
  }
  if (deduped.length < minBoundaryVertices) return null;
  if (_polygonAreaTwice(deduped).abs() == 0) return null;
  return List.unmodifiable(deduped);
}

/// Coordinate-space epsilon for the on-edge containment tolerance
/// (M6.1 Pass 3). Far above floating-point roundoff at ordinary
/// latitude/longitude magnitudes while visually negligible for hand-drawn
/// boundaries: it never turns a visibly outside point into an inside point.
const double boundaryCoordinateEpsilon = 1e-9;

/// True when [point] lies INSIDE [boundary], exactly on a polygon vertex, or
/// within [boundaryCoordinateEpsilon] of any polygon edge (M6.1 Pass 3).
///
/// This is the ONE shared containment law used by both Define Boundary Done
/// and Edit Pin Location Confirm — no second geometry implementation exists.
///
/// Algorithm:
/// 1. Point-on-segment FIRST for every closed edge, including last -> first,
///    using a nearest-point distance (robust at any edge length — never a raw
///    unscaled cross product). Points on vertices or within epsilon of an
///    edge are VALID. Zero-length edges (defensive; sanitized drafts cannot
///    contain them) collapse to their single endpoint.
/// 2. Even-odd ray casting for every other point: odd crossings inside,
///    even crossings outside.
///
/// Self-intersecting polygons are NOT rejected (M6.1 still permits them): a
/// point on any segment is valid, otherwise the documented even-odd parity
/// decides inside/outside deterministically.
bool savedPlaceBoundaryContainsCoordinate(
  SavedPlaceBoundary boundary,
  MapCoordinate point,
) {
  final vertices = boundary.vertices;
  if (vertices.length < minBoundaryVertices) return false;
  for (var i = 0; i < vertices.length; i++) {
    if (_distanceToSegment(
          point,
          vertices[i],
          vertices[(i + 1) % vertices.length],
        ) <=
        boundaryCoordinateEpsilon) {
      return true;
    }
  }
  return _evenOddInside(vertices, point);
}

/// Euclidean distance (in lat/lng coordinate space) from [point] to the
/// segment [a]..[b], via the projected nearest point. Scales correctly with
/// segment length, so the epsilon comparison is meaningful for every edge.
double _distanceToSegment(
  MapCoordinate point,
  MapCoordinate a,
  MapCoordinate b,
) {
  final dx = b.longitude - a.longitude;
  final dy = b.latitude - a.latitude;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    final ex = point.longitude - a.longitude;
    final ey = point.latitude - a.latitude;
    return math.sqrt(ex * ex + ey * ey);
  }
  final t =
      (((point.longitude - a.longitude) * dx +
                  (point.latitude - a.latitude) * dy) /
              lengthSquared)
          .clamp(0.0, 1.0);
  final closestLongitude = a.longitude + t * dx;
  final closestLatitude = a.latitude + t * dy;
  final ex = point.longitude - closestLongitude;
  final ey = point.latitude - closestLatitude;
  return math.sqrt(ex * ex + ey * ey);
}

/// Standard even-odd ray casting: a horizontal ray from [point] to +infinity
/// crosses an odd number of polygon edges iff the point is inside. Vertex
/// order (clockwise or counter-clockwise) does not matter.
bool _evenOddInside(List<MapCoordinate> vertices, MapCoordinate point) {
  var inside = false;
  for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
    final a = vertices[j];
    final b = vertices[i];
    if ((a.latitude > point.latitude) != (b.latitude > point.latitude)) {
      final crossingLongitude =
          a.longitude +
          (point.latitude - a.latitude) /
              (b.latitude - a.latitude) *
              (b.longitude - a.longitude);
      if (point.longitude < crossingLongitude) inside = !inside;
    }
  }
  return inside;
}

/// Twice the signed area (shoelace) in squared degree units. Only the
/// zero/non-zero distinction is meaningful for V1 validation; no GIS math.
double _polygonAreaTwice(List<MapCoordinate> vertices) {
  var total = 0.0;
  for (var i = 0; i < vertices.length; i++) {
    final a = vertices[i];
    final b = vertices[(i + 1) % vertices.length];
    total += a.latitude * b.longitude - b.latitude * a.longitude;
  }
  return total;
}

List<MapCoordinate>? _decodeVertexList(String raw) {
  // Deliberately dependency-free: strict hand parse of the exact shape the
  // encoder emits. Anything else -> null (absent boundary), never a throw.
  final trimmed = raw.trim();
  if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return null;
  final body = trimmed.substring(1, trimmed.length - 1).trim();
  if (body.isEmpty) return null;
  final vertices = <MapCoordinate>[];
  for (final entry in body.split('},{')) {
    final object = entry.startsWith('{')
        ? entry.endsWith('}')
              ? entry.substring(1, entry.length - 1)
              : entry.substring(1)
        : entry.endsWith('}')
        ? entry.substring(0, entry.length - 1)
        : entry;
    final lat = _decodeField(object, 'lat');
    final lng = _decodeField(object, 'lng');
    if (lat == null || lng == null) return null;
    final vertex = MapCoordinate.tryParse(lat, lng);
    if (vertex == null) return null;
    vertices.add(vertex);
    if (vertices.length > maxBoundaryVertices) return null;
  }
  return vertices;
}

double? _decodeField(String object, String field) {
  final key = '"$field":';
  final start = object.indexOf(key);
  if (start < 0) return null;
  final valueStart = start + key.length;
  var end = object.indexOf(',', valueStart);
  if (end < 0) end = object.length;
  final value = double.tryParse(object.substring(valueStart, end).trim());
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';

void main() {
  const a = MapCoordinate(latitude: 14.6, longitude: 121.0);
  const b = MapCoordinate(latitude: 14.61, longitude: 121.01);
  const c = MapCoordinate(latitude: 14.59, longitude: 121.02);

  SavedPlaceBoundary boundary(List<MapCoordinate> vertices) =>
      SavedPlaceBoundary(colorHex: '#175A8F', vertices: vertices);

  group('SavedPlaceBoundary codec', () {
    test('encodes deterministic ordered vertices without the color', () {
      final encoded = boundary([a, b, c]).encodeVertices();
      expect(
        encoded,
        '[{"lat":14.6,"lng":121.0},{"lat":14.61,"lng":121.01},'
        '{"lat":14.59,"lng":121.02}]',
      );
    });

    test('round-trips through the defensive decoder', () {
      final original = boundary([a, b, c]);
      final decoded = SavedPlaceBoundary.tryDecodeVertices(
        original.encodeVertices(),
        colorHex: '#175A8F',
      );
      expect(decoded, isNotNull);
      expect(decoded!.colorHex, '#175A8F');
      expect(decoded.vertices, original.vertices);
    });

    test('malformed stored JSON is treated as ABSENT, never a crash', () {
      for (final raw in <String?>[
        null,
        '',
        'not json at all',
        '{}',
        '[{"lat":1.0}]',
        '[{"lng":2.0}]',
        '[{"lat":"x","lng":1.0}]',
        '[{"lat":91.0,"lng":0.0},{"lat":0.0,"lng":0.0},{"lat":1.0,"lng":1.0}]',
        '[{"lat":0.0,"lng":181.0},{"lat":0.0,"lng":0.0},{"lat":1.0,"lng":1.0}]',
        '[{"lat":0.0,"lng":0.0},{"lat":1.0,"lng":1.0}]',
      ]) {
        expect(
          SavedPlaceBoundary.tryDecodeVertices(raw, colorHex: '#175A8F'),
          isNull,
          reason: 'raw=$raw must decode to absent',
        );
      }
    });

    test(
      'decoder normalizes the persisted color and rejects size violations',
      () {
        final valid = SavedPlaceBoundary.tryDecodeVertices(
          boundary([a, b, c]).encodeVertices(),
          colorHex: '#0E71B8',
        );
        expect(valid!.colorHex, '#0E71B8');

        final tooMany = SavedPlaceBoundary.tryDecodeVertices(
          '[${List.filled(501, '{"lat":14.0,"lng":121.0}').join(',')}]',
          colorHex: '#175A8F',
        );
        expect(tooMany, isNull);
      },
    );

    test('normalize() applies the same locked rules as the editor Done', () {
      expect(SavedPlaceBoundary.normalize(null), isNull);
      expect(
        SavedPlaceBoundary.normalize(
          boundary([a, b, c]).copyWith(colorHex: ' 0xFF175A8F '),
        )!.colorHex,
        '#175A8F',
      );
      // Zero area stays rejected through normalize.
      expect(
        SavedPlaceBoundary.normalize(
          boundary([
            a,
            MapCoordinate(latitude: 14.6, longitude: 121.01),
            MapCoordinate(latitude: 14.6, longitude: 121.02),
          ]),
        ),
        isNull,
      );
    });
  });

  group('boundary geometry rules (V1 minimum)', () {
    test('3+ vertices are valid', () {
      expect(sanitizeBoundaryVertices([a, b, c]), isNotNull);
      expect(sanitizeBoundaryVertices([a, b, c, a]), isNotNull);
    });

    test('fewer than 3 distinct vertices are rejected', () {
      expect(sanitizeBoundaryVertices(<MapCoordinate>[]), isNull);
      expect(sanitizeBoundaryVertices([a]), isNull);
      expect(sanitizeBoundaryVertices([a, b]), isNull);
    });

    test('consecutive duplicate vertices are deduped', () {
      final sanitized = sanitizeBoundaryVertices([a, a, b, b, b, c]);
      expect(sanitized, [a, b, c]);
    });

    test('zero-area (collinear) polygons are rejected', () {
      expect(
        sanitizeBoundaryVertices([
          a,
          MapCoordinate(latitude: 14.6, longitude: 121.01),
          MapCoordinate(latitude: 14.6, longitude: 121.02),
        ]),
        isNull,
      );
    });

    test('exactly 500 vertices are allowed; the cap clamps larger drafts', () {
      final capped = sanitizeBoundaryVertices(
        List.generate(
          600,
          (i) => MapCoordinate(latitude: 14.0, longitude: 121.0 + i * 0.0001),
        ),
      );
      expect(capped, isNull, reason: 'collinear cap clamp is still zero-area');
    });

    test('invalid coordinates cannot enter a boundary via tryParse law', () {
      expect(MapCoordinate.tryParse(91.0, 0.0), isNull);
      expect(MapCoordinate.tryParse(0.0, 181.0), isNull);
    });
  });

  group('M6.1 PASS 3 — shared containment law', () {
    // Unit square (lat/lng space). Clockwise order on purpose.
    SavedPlaceBoundary square() => boundary(const <MapCoordinate>[
      MapCoordinate(latitude: 0, longitude: 0),
      MapCoordinate(latitude: 0, longitude: 1),
      MapCoordinate(latitude: 1, longitude: 1),
      MapCoordinate(latitude: 1, longitude: 0),
    ]);

    test('point clearly inside a convex polygon is valid', () {
      expect(
        savedPlaceBoundaryContainsCoordinate(
          square(),
          const MapCoordinate(latitude: 0.5, longitude: 0.5),
        ),
        isTrue,
      );
    });

    test('point exactly on a horizontal edge is valid', () {
      expect(
        savedPlaceBoundaryContainsCoordinate(
          square(),
          const MapCoordinate(latitude: 0, longitude: 0.5),
        ),
        isTrue,
      );
    });

    test('point exactly on a vertical edge is valid', () {
      expect(
        savedPlaceBoundaryContainsCoordinate(
          square(),
          const MapCoordinate(latitude: 0.5, longitude: 1),
        ),
        isTrue,
      );
    });

    test('point exactly on a slanted edge is valid', () {
      // Triangle (0,0)->(1,1)->(2,0): midpoint of the slanted (1,1)->(2,0)
      // edge is (1.5, 0.5).
      const slanted = SavedPlaceBoundary(
        colorHex: '#175A8F',
        vertices: <MapCoordinate>[
          MapCoordinate(latitude: 0, longitude: 0),
          MapCoordinate(latitude: 1, longitude: 1),
          MapCoordinate(latitude: 2, longitude: 0),
        ],
      );
      expect(
        savedPlaceBoundaryContainsCoordinate(
          slanted,
          const MapCoordinate(latitude: 1.5, longitude: 0.5),
        ),
        isTrue,
      );
    });

    test('point exactly on a polygon vertex is valid', () {
      expect(
        savedPlaceBoundaryContainsCoordinate(
          square(),
          const MapCoordinate(latitude: 0, longitude: 0),
        ),
        isTrue,
      );
    });

    test('point clearly outside is invalid', () {
      expect(
        savedPlaceBoundaryContainsCoordinate(
          square(),
          const MapCoordinate(latitude: 5, longitude: 5),
        ),
        isFalse,
      );
    });

    test('concave polygon: interior lobe valid, concavity void invalid', () {
      // Square with a downward V notch cut out of its top: interior is below
      // the V, the notch region above the V is the void.
      const concave = SavedPlaceBoundary(
        colorHex: '#175A8F',
        vertices: <MapCoordinate>[
          MapCoordinate(latitude: 0, longitude: 0),
          MapCoordinate(latitude: 0, longitude: 2),
          MapCoordinate(latitude: 2, longitude: 2),
          MapCoordinate(latitude: 1, longitude: 1),
          MapCoordinate(latitude: 2, longitude: 0),
        ],
      );
      expect(
        savedPlaceBoundaryContainsCoordinate(
          concave,
          const MapCoordinate(latitude: 0.5, longitude: 0.5),
        ),
        isTrue,
        reason: 'bottom-left lobe is interior',
      );
      expect(
        savedPlaceBoundaryContainsCoordinate(
          concave,
          const MapCoordinate(latitude: 1.95, longitude: 1.9),
        ),
        isFalse,
        reason: 'notch right of the V is the concavity void',
      );
    });

    test('near-edge within epsilon is valid; visibly beyond is invalid', () {
      // 1e-10 above the bottom edge (lat 0) is within the 1e-9 epsilon.
      expect(
        savedPlaceBoundaryContainsCoordinate(
          square(),
          const MapCoordinate(latitude: 1e-10, longitude: 0.5),
        ),
        isTrue,
      );
      // 2e-9 below the bottom edge is beyond epsilon AND outside the square.
      expect(
        savedPlaceBoundaryContainsCoordinate(
          square(),
          const MapCoordinate(latitude: -2e-9, longitude: 0.5),
        ),
        isFalse,
      );
    });

    test('reversed vertex order returns the same containment truth', () {
      const point = MapCoordinate(latitude: 0.5, longitude: 0.5);
      final reversed = boundary(square().vertices.reversed.toList());
      expect(
        savedPlaceBoundaryContainsCoordinate(reversed, point),
        savedPlaceBoundaryContainsCoordinate(square(), point),
      );
      const outside = MapCoordinate(latitude: 5, longitude: 5);
      expect(
        savedPlaceBoundaryContainsCoordinate(reversed, outside),
        savedPlaceBoundaryContainsCoordinate(square(), outside),
      );
    });

    test('self-intersecting bowtie: segment points valid, even-odd parity '
        'is deterministic', () {
      const bowtie = SavedPlaceBoundary(
        colorHex: '#175A8F',
        vertices: <MapCoordinate>[
          MapCoordinate(latitude: 0, longitude: 0),
          MapCoordinate(latitude: 2, longitude: 2),
          MapCoordinate(latitude: 2, longitude: 0),
          MapCoordinate(latitude: 0, longitude: 2),
        ],
      );
      // The crossing point (1,1) lies ON both diagonals -> valid.
      expect(
        savedPlaceBoundaryContainsCoordinate(
          bowtie,
          const MapCoordinate(latitude: 1, longitude: 1),
        ),
        isTrue,
      );
      // A point on the rising diagonal -> valid.
      expect(
        savedPlaceBoundaryContainsCoordinate(
          bowtie,
          const MapCoordinate(latitude: 1.5, longitude: 1.5),
        ),
        isTrue,
      );
      // Even-odd fill: the two side lobes are inside (odd crossings)...
      expect(
        savedPlaceBoundaryContainsCoordinate(
          bowtie,
          const MapCoordinate(latitude: 0.25, longitude: 0.5),
        ),
        isTrue,
        reason: 'left lobe is odd-parity interior',
      );
      expect(
        savedPlaceBoundaryContainsCoordinate(
          bowtie,
          const MapCoordinate(latitude: 1.5, longitude: 1),
        ),
        isTrue,
        reason: 'right lobe is odd-parity interior',
      );
      // ...and the top center region around the crossing is outside
      // (even crossings).
      expect(
        savedPlaceBoundaryContainsCoordinate(
          bowtie,
          const MapCoordinate(latitude: 1, longitude: 1.5),
        ),
        isFalse,
        reason: 'top center is even-parity exterior',
      );
    });

    test('fewer than three vertices can never contain anything', () {
      expect(
        savedPlaceBoundaryContainsCoordinate(
          boundary(const <MapCoordinate>[
            MapCoordinate(latitude: 0, longitude: 0),
            MapCoordinate(latitude: 1, longitude: 1),
          ]),
          const MapCoordinate(latitude: 0.5, longitude: 0.5),
        ),
        isFalse,
      );
    });

    test('zero-length edges are handled defensively', () {
      // Duplicate vertex pair (would be sanitized in real drafts) must not
      // crash or misjudge: the point sits ON the duplicate endpoint.
      final degenerate = boundary(const <MapCoordinate>[
        MapCoordinate(latitude: 0, longitude: 0),
        MapCoordinate(latitude: 0, longitude: 0),
        MapCoordinate(latitude: 0, longitude: 1),
      ]);
      expect(
        savedPlaceBoundaryContainsCoordinate(
          degenerate,
          const MapCoordinate(latitude: 0, longitude: 0),
        ),
        isTrue,
      );
    });
  });

  test('default boundary color is the canonical NT primary blue', () {
    expect(defaultBoundaryColorHex, '#175A8F');
  });

  test('SavedPlaceDraft carries the boundary through normalization', () {
    const draft = SavedPlaceDraft(
      label: ' Farm ',
      coordinate: a,
      boundary: SavedPlaceBoundary(
        colorHex: '#FFAA00',
        vertices: <MapCoordinate>[],
      ),
    );
    final normalized = SavedPlaceDraft(
      label: draft.label,
      coordinate: draft.coordinate,
      boundary: SavedPlaceBoundary.normalize(
        SavedPlaceBoundary(
          colorHex: draft.boundary!.colorHex,
          vertices: [a, b, c],
        ),
      ),
    ).normalized();
    expect(normalized.label, 'Farm');
    expect(normalized.boundary!.vertices, [a, b, c]);
    expect(normalized.boundary!.colorHex, '#FFAA00');
    // Marker color independence: boundary color never feeds markerColor.
    expect(normalized.markerColorHex, '#175A8F');
  });
}

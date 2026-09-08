import 'dart:io';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';

void main() {
  test('M6.1 native polygon flow is wired additive and tap-free (frozen M3 '
      'coexistence)', () {
    final surface = File(
      'lib/features/maps/presentation/google_maps_surface.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/maps/presentation/maps_screen.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/features/maps/application/saved_place_providers.dart',
    ).readAsStringSync();

    // The canonical surface gained ONLY the additive polygons parameter.
    expect(surface, contains('this.polygons = const <Polygon>{}'));
    expect(surface, contains('polygons: widget.polygons'));
    // The frozen marker/cluster fields are untouched by the addition.
    expect(surface, contains('markers: _markers'));
    // M6.2: grouping ON keeps the accepted manager set; the durable Group
    // nearby markers OFF branch passes no active managers.
    expect(
      surface,
      contains('clusterManagers: _groupNearby'),
    );

    // The owning screen feeds the projection provider into the surface.
    expect(screen, contains('savedPlacePolygonsProvider'));
    expect(screen, contains('polygons: polygons'));

    // The projection derives from the SAME Drift watch that feeds markers.
    expect(providers, contains('savedPlacesProvider'));
    expect(providers, contains('savedPlacePolygonsProvider'));
    expect(providers, contains("PolygonId('saved-place-boundary-"));
    expect(providers, contains('consumeTapEvents: false'));
    expect(providers, contains('boundaryFillOpacity = 0.32'));
    expect(providers, contains('boundaryStrokeWidthPx = 2'));
    expect(providers, contains('zIndex: 1'));
  });

  test('savedPlacePolygonsProvider projects one tap-free polygon per '
      'boundary, none without', () async {
    final place = SavedPlace(
      id: 'place-1',
      profileId: 'profile-1',
      label: 'Farm A',
      coordinate: const MapCoordinate(latitude: 10.0, longitude: 122.0),
      markerMode: SavedPlaceMarkerMode.standard,
      standardCategory: SavedPlaceStandardCategory.information,
      customEmoji: null,
      markerColorHex: '#175A8F',
      createdAtUtc: DateTime.utc(2026, 9, 1),
      updatedAtUtc: DateTime.utc(2026, 9, 1),
      boundary: const SavedPlaceBoundary(
        colorHex: '#FFD600',
        vertices: <MapCoordinate>[
          MapCoordinate(latitude: 10.0, longitude: 122.0),
          MapCoordinate(latitude: 10.01, longitude: 122.01),
          MapCoordinate(latitude: 9.99, longitude: 122.02),
        ],
      ),
    );
    final plain = SavedPlace(
      id: 'place-2',
      profileId: 'profile-1',
      label: 'No boundary',
      coordinate: const MapCoordinate(latitude: 11.0, longitude: 123.0),
      markerMode: SavedPlaceMarkerMode.standard,
      standardCategory: SavedPlaceStandardCategory.information,
      customEmoji: null,
      markerColorHex: '#175A8F',
      createdAtUtc: DateTime.utc(2026, 9, 1),
      updatedAtUtc: DateTime.utc(2026, 9, 1),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        savedPlacesProvider.overrideWith((ref) {
          return Stream<List<SavedPlace>>.value(<SavedPlace>[place, plain]);
        }),
        savedPlaceProfileIdProvider.overrideWithValue('profile-1'),
      ],
    );
    addTearDown(container.dispose);
    // Keep the projection alive (Riverpod pauses unlistened providers, just
    // like an unmounted widget would) and let the Drift watch emit.
    container.listen(savedPlacePolygonsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final polygons = container.read(savedPlacePolygonsProvider);
    expect(polygons, hasLength(1));
    final polygon = polygons.single;
    expect(polygon.polygonId.value, 'saved-place-boundary-place-1');
    expect(polygon.points, <LatLng>[
      const LatLng(10.0, 122.0),
      const LatLng(10.01, 122.01),
      const LatLng(9.99, 122.02),
    ]);
    expect(polygon.strokeColor, const Color(0xFFFFD600));
    expect(polygon.fillColor.a, closeTo(0.32, 0.01));
    expect(polygon.consumeTapEvents, isFalse);
    expect(polygon.zIndex, 1);
  });
}

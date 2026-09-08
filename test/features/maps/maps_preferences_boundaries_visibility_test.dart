// VS-15 M6.2 — Boundaries layer visibility with the Define Boundary editor
// exception.
//
// Boundaries OFF hides persisted background polygons in normal Maps mode;
// the moment the same-map Define Boundary editor is active, the working
// draft, vertex handles, and the current place's faint reference stay
// visible regardless of the preference. Tests 44/45/50/51.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/boundary_edit_session.dart';
import 'package:rmplanner/features/maps/application/current_location_service.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_provider.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_repository.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/data/drift_map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';

import '../../support/test_dependencies.dart';
import 'maps_preferences_test_support.dart';

const _placeId = '33333333-3333-4333-8333-333333333333';
const _pin = MapCoordinate(latitude: 14.6, longitude: 121.0);

const _boundary = SavedPlaceBoundary(
  vertices: <MapCoordinate>[
    MapCoordinate(latitude: 14.59, longitude: 120.99),
    MapCoordinate(latitude: 14.61, longitude: 120.99),
    MapCoordinate(latitude: 14.61, longitude: 121.01),
  ],
  colorHex: '#175A8F',
);

void main() {
  Future<ProviderContainer> pumpMaps(
    WidgetTester tester, {
    required List<Override> extraOverrides,
    bool mapBuilder = true,
  }) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final savedPlaces = DriftSavedPlaceRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 9, 4, 12)),
      identifiers: SequenceIdentifierSource(<String>[_placeId]),
    );
    await savedPlaces.create(
      profileId: profile.id,
      draft: const SavedPlaceDraft(
        label: 'My Farm',
        coordinate: _pin,
        boundary: _boundary,
      ),
    );
    final coordinates = DriftMapCoordinateRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 9, 4, 12)),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        mapProfileIdProvider.overrideWithValue(profile.id),
        savedPlaceProfileIdProvider.overrideWithValue(profile.id),
        mapCoordinateRepositoryProvider.overrideWithValue(coordinates),
        savedPlaceRepositoryProvider.overrideWithValue(savedPlaces),
        currentLocationServiceProvider.overrideWithValue(
          const _FakeCurrentLocationService(),
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MapsScreen(
            mapBuilder: mapBuilder
                ? (_, markers) => SizedBox(
                    key: const Key('maps-test-surface'),
                    child: Text('markers=${markers.length}'),
                  )
                : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  SavedPlaceFormSnapshot snapshot() => const SavedPlaceFormSnapshot(
    label: 'My Farm',
    markerMode: SavedPlaceMarkerMode.standard,
    standardCategory: SavedPlaceStandardCategory.food,
    customEmoji: null,
    markerColorHex: '#175A8F',
    boundaryColorHex: '#175A8F',
    boundaryDraft: _boundary,
  );

  SavedPlace savedPlace() => SavedPlace(
    id: _placeId,
    profileId: 'profile',
    label: 'My Farm',
    coordinate: _pin,
    markerMode: SavedPlaceMarkerMode.standard,
    standardCategory: SavedPlaceStandardCategory.food,
    customEmoji: null,
    markerColorHex: '#175A8F',
    createdAtUtc: DateTime.utc(2026, 9, 4, 12),
    updatedAtUtc: DateTime.utc(2026, 9, 4, 12),
    boundary: _boundary,
  );

  testWidgets(
    '44/45. Boundaries OFF hides persisted polygons in normal Maps mode; '
    'ON restores them',
    (tester) async {
      await pumpMaps(
        tester,
        extraOverrides: mapsPreferencesOverrides(
          seed: const MapsPreferencesModel(showBoundaries: false),
        ),
      );
      final surface = tester.widget<GoogleMapsSurface>(
        find.byType(GoogleMapsSurface),
      );
      expect(surface.polygons, isEmpty);
      // The polygon data projection itself is untouched (only presentation
      // hides it).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapsScreen)),
      );
      expect(container.read(savedPlacePolygonsProvider), isNotEmpty);

      await container
          .read(mapsPreferencesProvider.notifier)
          .setShowBoundaries(true);
      await tester.pumpAndSettle();
      final restored = tester.widget<GoogleMapsSurface>(
        find.byType(GoogleMapsSurface),
      );
      expect(restored.polygons, hasLength(1));
    },
  );

  testWidgets(
    '50. Boundaries OFF still keeps the working boundary editor fully '
    'usable: draft, vertex handles, and reference stay visible',
    (tester) async {
      final container = await pumpMaps(
        tester,
        extraOverrides: mapsPreferencesOverrides(
          seed: const MapsPreferencesModel(showBoundaries: false),
        ),
      );
      container
          .read(boundaryEditSessionProvider.notifier)
          .begin(
            origin: BoundaryEditOriginEdit(place: savedPlace()),
            snapshot: snapshot(),
          );
      await tester.pumpAndSettle();
      final session = container.read(boundaryEditSessionProvider);
      expect(session, isNotNull);
      // Draw a few vertices so the draft polygon + vertex handles exist.
      session!.controller
        ..addVertex(_pin)
        ..addVertex(const MapCoordinate(latitude: 14.61, longitude: 121.01))
        ..addVertex(const MapCoordinate(latitude: 14.59, longitude: 121.02));
      await tester.pumpAndSettle();
      final surface = tester.widget<GoogleMapsSurface>(
        find.byType(GoogleMapsSurface),
      );
      // The editor exception keeps the outline composed while Boundaries is
      // OFF: the overlay path runs, so the faint reference + live draft
      // polygons and vertex-handle circles are non-empty, and the working
      // Saved Place marker stays visible.
      expect(surface.polygons, isNotEmpty);
      expect(surface.circles, isNotEmpty);
      expect(find.text('markers=1'), findsOneWidget);
    },
  );

  testWidgets(
    '51. Define Boundary keeps the working Saved Place marker visible even '
    'when Saved Places OFF',
    (tester) async {
      await pumpMaps(
        tester,
        extraOverrides: mapsPreferencesOverrides(
          seed: const MapsPreferencesModel(showSavedPlaces: false),
        ),
      );
      // Normal Maps mode with Saved Places OFF: zero saved-place markers.
      expect(find.text('markers=0'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapsScreen)),
      );
      container
          .read(boundaryEditSessionProvider.notifier)
          .begin(
            origin: const BoundaryEditOriginAdd(coordinate: _pin),
            snapshot: snapshot(),
          );
      await tester.pumpAndSettle();
      final session = container.read(boundaryEditSessionProvider);
      expect(session, isNotNull);
      // Define Boundary exception: while the editor is active the working
      // Saved Place marker (plus the seeded place, which stays visible
      // during editing) is projected even though the layer is OFF.
      expect(find.text('markers=0'), findsNothing);
      expect(find.textContaining('markers='), findsOneWidget);
    },
  );
}

final class _FakeCurrentLocationService implements CurrentLocationService {
  const _FakeCurrentLocationService();

  @override
  Future<CurrentLocationResult> locate() async => CurrentLocationResult.located(
    const MapCoordinate(latitude: 14.7, longitude: 121.1),
  );
}

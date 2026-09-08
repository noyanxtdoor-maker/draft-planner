// VS-15 M7.1 + M7.3 — Saved Places <-> Maps reactive journey hardening.
//
// M7 AUDIT FINDING: the production reactive chain
//   SavedPlace repository -> Drift tableUpdates -> mapMarkersProvider ->
//   saved place markers -> mapProjectedMarkersProvider -> MapsScreen ->
//   GoogleMapsSurface
// is already fully reactive. NO production change is made here; these widget
// tests lock that behavior in over a REAL in-memory Drift database so a
// future "manual refresh" hack or duplicated projection state cannot creep
// back in.
//
// Covered journeys:
//   * ADD: repository create -> marker appears live, canonical identity,
//     single stable owner key, no Maps route recreation.
//   * EDIT: label/category/emoji/color -> the SAME marker updates in place,
//     never a duplicate.
//   * DELETE (repository + the real preview Delete dialog): marker and
//     boundary polygon disappear; selection clears; preview closes; stale
//     group membership reconciles.
//   * BOUNDARY add/edit/remove -> polygons appear/update/disappear through
//     the same savedPlacesProvider watch.
//   * EDIT PIN: single marker relocates to the live coordinate under the
//     same stable place ID.
//   * GROUPING ON: reactive mutation while a group is selected.
//   * GROUPING OFF: mutations keep records individual (no aggregate marker,
//     no cluster manager, null clusterManagerId).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:rmplanner/features/maps/application/current_location_service.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
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

const _placeIdA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _placeIdB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _placeIdC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

const _pin = MapCoordinate(latitude: 14.6, longitude: 121.0);
const _moved = MapCoordinate(latitude: 14.62, longitude: 121.02);
const _far = MapCoordinate(latitude: 14.7, longitude: 121.1);

const _boundaryV1 = SavedPlaceBoundary(
  colorHex: '#175A8F',
  vertices: <MapCoordinate>[
    MapCoordinate(latitude: 14.55, longitude: 120.95),
    MapCoordinate(latitude: 14.55, longitude: 121.05),
    MapCoordinate(latitude: 14.65, longitude: 121.05),
    MapCoordinate(latitude: 14.65, longitude: 120.95),
  ],
);

const _boundaryV2 = SavedPlaceBoundary(
  colorHex: '#FFD600',
  vertices: <MapCoordinate>[
    MapCoordinate(latitude: 14.58, longitude: 120.98),
    MapCoordinate(latitude: 14.58, longitude: 121.02),
    MapCoordinate(latitude: 14.62, longitude: 121.02),
    MapCoordinate(latitude: 14.62, longitude: 120.98),
  ],
);

final class _FakeLocation implements CurrentLocationService {
  const _FakeLocation();

  @override
  Future<CurrentLocationResult> locate() async => CurrentLocationResult.located(
    MapCoordinate(latitude: 14.6, longitude: 121),
  );
}

/// Minimal canvas: the GoogleMap widget mounts and its marker/cluster props
/// are observable without any native side.
final class _CanvasPlatform extends GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int id,
    PlatformViewCreatedCallback created, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) => const ColoredBox(color: Colors.white);

  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream.empty();
}

final class _World {
  _World(this.savedPlaces, this.coordinates, this.profileId);

  final DriftSavedPlaceRepository savedPlaces;
  final DriftMapCoordinateRepository coordinates;
  final String profileId;

  /// Creates through the REAL repository; the Drift SequenceIdentifierSource
  /// yields the next fixed id in test-construction order.
  Future<SavedPlace> create(
    String label, {
    MapCoordinate point = _pin,
    SavedPlaceMarkerMode mode = SavedPlaceMarkerMode.standard,
    SavedPlaceStandardCategory category =
        SavedPlaceStandardCategory.information,
    String? emoji,
    String colorHex = '#175A8F',
    SavedPlaceBoundary? boundary,
  }) {
    final draft = SavedPlaceDraft(
      label: label,
      coordinate: point,
      markerMode: mode,
      standardCategory: category,
      customEmoji: emoji,
      markerColorHex: colorHex,
      boundary: boundary,
    );
    return savedPlaces.create(profileId: profileId, draft: draft.normalized());
  }
}

GoogleMapsSurface _surface(WidgetTester tester) =>
    tester.widget<GoogleMapsSurface>(find.byType(GoogleMapsSurface));
GoogleMap _map(WidgetTester tester) =>
    tester.widget<GoogleMap>(find.byType(GoogleMap));

List<MapMarker> _dataMarkers(WidgetTester tester) => _surface(tester).markers;

Future<ProviderContainer> _pumpMaps(
  WidgetTester tester, {
  required _World world,
  bool groupNearby = true,
}) async {
  tester.view.physicalSize = const Size(431, 912);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: <Override>[
      mapProfileIdProvider.overrideWithValue(world.profileId),
      savedPlaceProfileIdProvider.overrideWithValue(world.profileId),
      savedPlaceRepositoryProvider.overrideWithValue(world.savedPlaces),
      mapCoordinateRepositoryProvider.overrideWithValue(world.coordinates),
      currentLocationServiceProvider.overrideWithValue(const _FakeLocation()),
      initialMapsPreferencesProvider.overrideWithValue(
        MapsPreferencesModel(groupNearbyMarkers: groupNearby),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MapsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    GoogleMapsFlutterPlatform.instance = _CanvasPlatform();
  });

  Future<_World> seed() async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    return _World(
      DriftSavedPlaceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 9, 4, 12)),
        identifiers: SequenceIdentifierSource(<String>[
          _placeIdA,
          _placeIdB,
          _placeIdC,
        ]),
      ),
      DriftMapCoordinateRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 9, 4, 12)),
      ),
      profile.id,
    );
  }

  group('ADD PLACE', () {
    testWidgets('a saved row appears on the live map with canonical identity, '
        'single owner key, and no route recreation', (tester) async {
      final world = await seed();
      final container = await _pumpMaps(tester, world: world);
      expect(_dataMarkers(tester), isEmpty);

      await world.create(
        'Cafe Roma',
        mode: SavedPlaceMarkerMode.custom,
        emoji: '🍕',
        colorHex: '#E65100',
      );
      await tester.pumpAndSettle();

      final markers = _dataMarkers(tester);
      expect(markers, hasLength(1));
      final marker = markers.single;
      expect(marker.owner, MapCoordinateOwner.savedPlace);
      expect(marker.recordId, _placeIdA);
      expect(
        marker.ownerKey,
        MapCoordinate.ownerKey(MapCoordinateOwner.savedPlace.kind, _placeIdA),
      );
      expect(marker.displayName, 'Cafe Roma');
      expect(marker.placeMarkerMode, SavedPlaceMarkerMode.custom);
      expect(marker.placeEmoji, '🍕');
      expect(marker.colorValue, markerColorHexToArgb('#E65100'));
      // The live native map shows exactly the one place marker.
      expect(_map(tester).markers, hasLength(1));
      // The Maps context was not recreated and nothing needed a refresh.
      expect(find.byType(MapsScreen), findsOneWidget);
      expect(find.byType(GoogleMapsSurface), findsOneWidget);
      expect(container.read(mapSavedPlaceMarkersProvider).value, hasLength(1));
    });
  });

  group('EDIT PLACE', () {
    testWidgets('label/category/emoji/color updates the SAME marker in place; '
        'no duplicate old marker', (tester) async {
      final world = await seed();
      await world.create(
        'Old Farm',
        category: SavedPlaceStandardCategory.food,
        colorHex: '#175A8F',
      );
      await _pumpMaps(tester, world: world);
      await tester.pumpAndSettle();
      expect(_dataMarkers(tester), hasLength(1));

      await world.savedPlaces.update(
        profileId: world.profileId,
        id: _placeIdA,
        draft: const SavedPlaceDraft(
          label: 'Renamed Farm',
          coordinate: _pin,
          markerMode: SavedPlaceMarkerMode.custom,
          customEmoji: '🛠️',
          markerColorHex: '#7B1FA2',
        ).normalized(),
      );
      await tester.pumpAndSettle();

      final markers = _dataMarkers(tester);
      expect(markers, hasLength(1), reason: 'never a duplicate old marker');
      final marker = markers.single;
      expect(marker.recordId, _placeIdA);
      expect(
        marker.ownerKey,
        MapCoordinate.ownerKey(MapCoordinateOwner.savedPlace.kind, _placeIdA),
      );
      expect(marker.displayName, 'Renamed Farm');
      expect(marker.placeMarkerMode, SavedPlaceMarkerMode.custom);
      expect(marker.placeEmoji, '🛠️');
      expect(marker.colorValue, markerColorHexToArgb('#7B1FA2'));
      expect(_map(tester).markers, hasLength(1));
    });
  });

  group('EDIT PIN LOCATION', () {
    testWidgets('the single marker relocates to the live coordinate under the '
        'same stable place ID; no stale old-coordinate marker', (tester) async {
      final world = await seed();
      await world.create('Farm', point: _pin);
      await _pumpMaps(tester, world: world);
      await tester.pumpAndSettle();
      expect(_dataMarkers(tester).single.coordinate, _pin);

      await world.coordinates.setCoordinate(
        profileId: world.profileId,
        owner: MapCoordinateOwner.savedPlace,
        recordId: _placeIdA,
        coordinate: _moved,
      );
      await tester.pumpAndSettle();

      final markers = _dataMarkers(tester);
      expect(markers, hasLength(1));
      expect(markers.single.coordinate, _moved);
      expect(markers.single.recordId, _placeIdA);
      expect(
        markers.single.ownerKey,
        MapCoordinate.ownerKey(MapCoordinateOwner.savedPlace.kind, _placeIdA),
      );
      final native = _map(tester).markers;
      expect(native, hasLength(1));
      expect(native.single.position, LatLng(_moved.latitude, _moved.longitude));
    });
  });

  group('BOUNDARY ADD / EDIT / REMOVE', () {
    testWidgets('polygons appear, update, and disappear through the same '
        'savedPlacesProvider watch', (tester) async {
      final world = await seed();
      final container = await _pumpMaps(tester, world: world);

      // ADD BOUNDARY with the place (main form Save persistence boundary).
      await world.create('Farm', point: _pin, boundary: _boundaryV1);
      await tester.pumpAndSettle();
      var polygons = _map(tester).polygons;
      expect(polygons, hasLength(1));
      final polygonId = PolygonId('saved-place-boundary-$_placeIdA');
      expect(polygons.single.polygonId, polygonId);
      expect(polygons.single.points, <LatLng>[
        for (final vertex in _boundaryV1.vertices)
          LatLng(vertex.latitude, vertex.longitude),
      ]);
      expect(
        polygons.single.strokeColor,
        Color(markerColorHexToArgb(_boundaryV1.colorHex)),
      );
      expect(container.read(savedPlacePolygonsProvider), hasLength(1));

      // EDIT BOUNDARY geometry + color.
      await world.savedPlaces.update(
        profileId: world.profileId,
        id: _placeIdA,
        draft: SavedPlaceDraft(
          label: 'Farm',
          coordinate: _pin,
          boundary: _boundaryV2,
        ).normalized(),
      );
      await tester.pumpAndSettle();
      polygons = _map(tester).polygons;
      expect(polygons, hasLength(1), reason: 'same polygon id updates');
      expect(polygons.single.polygonId, polygonId);
      expect(polygons.single.points, <LatLng>[
        for (final vertex in _boundaryV2.vertices)
          LatLng(vertex.latitude, vertex.longitude),
      ]);
      expect(
        polygons.single.strokeColor,
        Color(markerColorHexToArgb(_boundaryV2.colorHex)),
      );

      // REMOVE BOUNDARY: polygon disappears immediately after Save.
      await world.savedPlaces.update(
        profileId: world.profileId,
        id: _placeIdA,
        draft: const SavedPlaceDraft(
          label: 'Farm',
          coordinate: _pin,
        ).normalized(),
      );
      await tester.pumpAndSettle();
      expect(_map(tester).polygons, isEmpty);
      expect(container.read(savedPlacePolygonsProvider), isEmpty);
      expect(_dataMarkers(tester), hasLength(1));
    });
  });

  group('DELETE PLACE', () {
    testWidgets('repository delete removes marker + boundary polygon; '
        'selection clears and preview closes through the real dialog', (
      tester,
    ) async {
      final world = await seed();
      final created = await world.create(
        'Farm',
        point: _pin,
        boundary: _boundaryV1,
      );
      final container = await _pumpMaps(tester, world: world);
      await tester.pumpAndSettle();
      expect(_dataMarkers(tester), hasLength(1));
      expect(_map(tester).polygons, hasLength(1));

      // Select the live marker -> the preview opens.
      _surface(tester).onMarkerTap(_dataMarkers(tester).single);
      await tester.pumpAndSettle();
      expect(
        container.read(mapSelectedMarkerProvider)?.marker.recordId,
        _placeIdA,
      );
      expect(find.byKey(const Key('maps-place-preview-label')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('maps-place-preview-delete-place')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-saved-place-confirm')));
      await tester.pumpAndSettle();

      expect(await world.savedPlaces.list(world.profileId), isEmpty);
      expect(_dataMarkers(tester), isEmpty);
      expect(_map(tester).markers, isEmpty);
      expect(_map(tester).polygons, isEmpty);
      expect(container.read(savedPlacePolygonsProvider), isEmpty);
      // Selection cleared; the preview is closed; no stale record survives.
      expect(container.read(mapSelectedMarkerProvider), isNull);
      expect(
        find.byKey(const Key('maps-place-preview-delete-place')),
        findsNothing,
      );
      expect(find.byType(MapsScreen), findsOneWidget);
      expect(created.id, _placeIdA);
    });
  });

  group('GROUPING ON — reactive mutations', () {
    testWidgets('a deleted group member reduces the selected group to the '
        'surviving individual; no stale aggregate remains', (tester) async {
      final world = await seed();
      await world.create('Alpha', point: _pin);
      await world.create('Beta', point: _pin);
      final container = await _pumpMaps(tester, world: world);
      await tester.pumpAndSettle();

      // Two records at the exact coordinate -> one aggregate native target.
      expect(_dataMarkers(tester), hasLength(2));
      expect(_map(tester).markers, hasLength(1));

      // Open the exact-coordinate group.
      _map(tester).markers.single.onTap!();
      await tester.pumpAndSettle();
      final selection = container.read(mapSelectedMarkerProvider);
      expect(selection, isNotNull);
      expect(selection!.isGroup, isTrue);
      expect(selection.members, hasLength(2));

      // One member is deleted by a reactive write while the group is open.
      await world.savedPlaces.delete(profileId: world.profileId, id: _placeIdB);
      await tester.pumpAndSettle();

      // The group reconciles to the surviving individual.
      final reconciled = container.read(mapSelectedMarkerProvider);
      expect(reconciled, isNotNull);
      expect(reconciled!.isGroup, isFalse);
      expect(
        reconciled.markerKey,
        MapCoordinate.ownerKey(MapCoordinateOwner.savedPlace.kind, _placeIdA),
      );
      expect(_dataMarkers(tester), hasLength(1));
      expect(_map(tester).markers, hasLength(1));
      // The live preview now owns the survivor.
      expect(
        find.byKey(const Key('maps-place-preview-delete-place')),
        findsOneWidget,
      );

      // Delete the survivor through the real preview dialog.
      await tester.tap(
        find.byKey(const Key('maps-place-preview-delete-place')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-saved-place-confirm')));
      await tester.pumpAndSettle();

      expect(_dataMarkers(tester), isEmpty);
      expect(_map(tester).markers, isEmpty);
      // The three per-family cluster managers stay mounted by design (their
      // markers do the clustering); with every member gone no marker is left
      // for them to manage and no stale aggregate can appear.
      final managers = _map(tester).clusterManagers;
      expect(managers, hasLength(3));
      expect(
        managers.map((manager) => manager.clusterManagerId.value),
        containsAll(<String>['maps-people', 'maps-events', 'maps-places']),
      );
      expect(container.read(mapSelectedMarkerProvider), isNull);
      expect(container.read(savedPlacePolygonsProvider), isEmpty);

      // A NEW member added at the same coordinate appears live afterwards.
      await world.create('Gamma', point: _pin);
      await tester.pumpAndSettle();
      expect(_dataMarkers(tester), hasLength(1));
      expect(_map(tester).markers, hasLength(1));
    });
  });

  group('GROUPING OFF — reactive mutations', () {
    testWidgets('records stay individual through move/delete/add: no '
        'aggregate marker, no cluster manager, null clusterManagerId', (
      tester,
    ) async {
      final world = await seed();
      await world.create('Alpha', point: _pin);
      await world.create('Beta', point: _pin);
      final container = await _pumpMaps(
        tester,
        world: world,
        groupNearby: false,
      );
      await tester.pumpAndSettle();

      expect(_map(tester).clusterManagers, isEmpty);
      expect(_dataMarkers(tester), hasLength(2));
      var native = _map(tester).markers;
      expect(native, hasLength(2));
      for (final marker in native) {
        expect(marker.clusterManagerId, isNull);
      }

      // MOVE one record away: it relocates, the other stays put.
      await world.coordinates.setCoordinate(
        profileId: world.profileId,
        owner: MapCoordinateOwner.savedPlace,
        recordId: _placeIdA,
        coordinate: _far,
      );
      await tester.pumpAndSettle();
      native = _map(tester).markers;
      expect(native, hasLength(2));
      final a = native.singleWhere(
        (marker) =>
            marker.markerId.value ==
            MapCoordinate.ownerKey(
              MapCoordinateOwner.savedPlace.kind,
              _placeIdA,
            ),
      );
      final b = native.singleWhere(
        (marker) =>
            marker.markerId.value ==
            MapCoordinate.ownerKey(
              MapCoordinateOwner.savedPlace.kind,
              _placeIdB,
            ),
      );
      expect(a.position, LatLng(_far.latitude, _far.longitude));
      expect(b.position, LatLng(_pin.latitude, _pin.longitude));
      expect(a.clusterManagerId, isNull);
      expect(b.clusterManagerId, isNull);
      expect(container.read(mapTransientFocusProvider).pending, isNull);

      // DELETE one: exactly one individual remains.
      await world.savedPlaces.delete(profileId: world.profileId, id: _placeIdB);
      await tester.pumpAndSettle();
      expect(_dataMarkers(tester), hasLength(1));
      native = _map(tester).markers;
      expect(native, hasLength(1));
      expect(
        native.single.markerId.value,
        MapCoordinate.ownerKey(MapCoordinateOwner.savedPlace.kind, _placeIdA),
      );
      expect(native.single.clusterManagerId, isNull);

      // DELETE the last one: no marker, no cluster manager remains.
      await world.savedPlaces.delete(profileId: world.profileId, id: _placeIdA);
      await tester.pumpAndSettle();
      expect(_dataMarkers(tester), isEmpty);
      expect(_map(tester).markers, isEmpty);
      expect(_map(tester).clusterManagers, isEmpty);

      // ADD a new record: it appears as one individual again.
      await world.create('Gamma', point: _pin);
      await tester.pumpAndSettle();
      expect(_dataMarkers(tester), hasLength(1));
      expect(_map(tester).markers, hasLength(1));
      expect(_map(tester).markers.single.clusterManagerId, isNull);
    });
  });
}

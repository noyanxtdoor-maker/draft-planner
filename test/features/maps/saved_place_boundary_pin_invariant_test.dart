// VS-15 M6.1 PASS 3 — Edit Pin Location preserves the boundary invariant.
//
// A Saved Place WITH a boundary may only move to a coordinate inside, on an
// edge, or on a vertex of that boundary (shared domain law). An outside
// candidate shows the canonical containment dialog, performs ZERO coordinate
// writes, keeps the inline editor active with the candidate camera, and
// leaves the persisted coordinate untouched. Contacts/Events and Saved Places
// without a boundary are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/map_marker_preview_sheet.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

const _placeMarker = MapMarker(
  owner: MapCoordinateOwner.savedPlace,
  recordId: 'place-1',
  displayName: 'Offline home',
  coordinate: MapCoordinate(latitude: 14.6, longitude: 121),
);
const _contactMarker = MapMarker(
  owner: MapCoordinateOwner.contact,
  recordId: 'contact-1',
  displayName: 'Mom',
  coordinate: MapCoordinate(latitude: 14.6, longitude: 121),
);
const _eventMarker = MapMarker(
  owner: MapCoordinateOwner.event,
  recordId: 'event-1',
  displayName: 'Party',
  coordinate: MapCoordinate(latitude: 14.6, longitude: 121),
);
const _outside = MapCoordinate(latitude: 16.25, longitude: 120.75);

/// Square boundary around (14.6, 121.0): lat 14.5..14.7, lng 120.9..121.1.
final _boundary = SavedPlaceBoundary(
  colorHex: '#C62828',
  vertices: const <MapCoordinate>[
    MapCoordinate(latitude: 14.5, longitude: 120.9),
    MapCoordinate(latitude: 14.5, longitude: 121.1),
    MapCoordinate(latitude: 14.7, longitude: 121.1),
    MapCoordinate(latitude: 14.7, longitude: 120.9),
  ],
);

class _RecordingCoordinates implements MapCoordinateRepository {
  @override
  Stream<int> watchChanges(String profileId) => const Stream.empty();
  @override
  Future<List<MapMarker>> readMarkers(String profileId) async => const [];
  @override
  Future<MapCoordinate?> readCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async => _placeMarker.coordinate;
  @override
  Future<void> clearCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async {}

  final writes =
      <({MapCoordinateOwner owner, String id, MapCoordinate point})>[];

  @override
  Future<void> setCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
    required MapCoordinate coordinate,
  }) async {
    writes.add((owner: owner, id: recordId, point: coordinate));
  }
}

class _FakeSavedPlaces implements SavedPlaceRepository {
  _FakeSavedPlaces({this.place});

  SavedPlace? place;
  int readCalls = 0;

  @override
  Future<SavedPlace?> readById({
    required String profileId,
    required String id,
  }) async {
    readCalls += 1;
    return place;
  }

  @override
  Stream<List<SavedPlace>> watch(String profileId) => const Stream.empty();

  @override
  Future<List<SavedPlace>> list(String profileId) async =>
      place == null ? const <SavedPlace>[] : <SavedPlace>[place!];

  @override
  Future<SavedPlace> create({
    required String profileId,
    required SavedPlaceDraft draft,
  }) => throw UnimplementedError();

  @override
  Future<SavedPlace> update({
    required String profileId,
    required String id,
    required SavedPlaceDraft draft,
  }) => throw UnimplementedError();

  @override
  Future<void> delete({required String profileId, required String id}) async {}
}

SavedPlace _placeWith({SavedPlaceBoundary? boundary}) => SavedPlace(
  id: 'place-1',
  profileId: 'profile-1',
  label: 'Offline home',
  coordinate: _placeMarker.coordinate,
  markerMode: SavedPlaceMarkerMode.standard,
  standardCategory: SavedPlaceStandardCategory.information,
  customEmoji: null,
  markerColorHex: '#175A8F',
  createdAtUtc: DateTime.utc(2026, 9, 4),
  updatedAtUtc: DateTime.utc(2026, 9, 4),
  boundary: boundary,
);

Future<
  ({
    ProviderContainer container,
    _RecordingCoordinates coordinates,
    _FakeSavedPlaces places,
  })
>
_mount(
  WidgetTester tester, {
  required List<MapMarker> markers,
  SavedPlace? place,
}) async {
  tester.view.physicalSize = const Size(431, 912);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final coordinates = _RecordingCoordinates();
  final places = _FakeSavedPlaces(place: place);
  final container = ProviderContainer(
    overrides: <Override>[
      mapProfileIdProvider.overrideWithValue('profile-1'),
      savedPlaceProfileIdProvider.overrideWithValue('profile-1'),
      mapProjectedMarkersProvider.overrideWith((ref) async => markers),
      mapPassiveLocationProvider.overrideWith((ref) async => null),
      mapCoordinateRepositoryProvider.overrideWithValue(coordinates),
      savedPlaceRepositoryProvider.overrideWithValue(places),
      diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MapsScreen(
          mapBuilder: (_, _) => const ColoredBox(
            key: Key('stable-map-canvas'),
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, coordinates: coordinates, places: places);
}

GoogleMapsSurface _surface(WidgetTester tester) =>
    tester.widget<GoogleMapsSurface>(find.byType(GoogleMapsSurface));

Future<void> _openInlineEdit(
  WidgetTester tester, [
  MapMarker marker = _placeMarker,
]) async {
  _surface(tester).onMarkerTap(marker);
  await tester.pumpAndSettle();
  tester
      .widget<MapMarkerPreviewSheet>(find.byType(MapMarkerPreviewSheet))
      .onEditLocation();
  await tester.pumpAndSettle();
}

Future<void> _moveCameraTo(
  WidgetTester tester,
  MapCoordinate coordinate,
) async {
  _surface(tester).onCameraCenterChanged!(coordinate);
  await tester.pump();
}

void main() {
  testWidgets('Saved Place with boundary: inside candidate persists', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      markers: const [_placeMarker],
      place: _placeWith(boundary: _boundary),
    );
    await _openInlineEdit(tester);
    await _moveCameraTo(
      tester,
      const MapCoordinate(latitude: 14.6, longitude: 121.05),
    );
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    expect(harness.coordinates.writes, hasLength(1));
    expect(
      harness.coordinates.writes.single.point,
      const MapCoordinate(latitude: 14.6, longitude: 121.05),
    );
    expect(harness.places.readCalls, 1);
    expect(find.byKey(const Key('boundary-exclusion-dialog')), findsNothing);
    expect(find.byKey(const Key('maps-centering-confirm')), findsNothing);
  });

  testWidgets('Saved Place with boundary: on-edge candidate persists', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      markers: const [_placeMarker],
      place: _placeWith(boundary: _boundary),
    );
    await _openInlineEdit(tester);
    await _moveCameraTo(
      tester,
      const MapCoordinate(latitude: 14.6, longitude: 120.9),
    );
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    expect(harness.coordinates.writes, hasLength(1));
    expect(
      harness.coordinates.writes.single.point,
      const MapCoordinate(latitude: 14.6, longitude: 120.9),
    );
  });

  testWidgets('Saved Place with boundary: on-vertex candidate persists', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      markers: const [_placeMarker],
      place: _placeWith(boundary: _boundary),
    );
    await _openInlineEdit(tester);
    await _moveCameraTo(
      tester,
      const MapCoordinate(latitude: 14.5, longitude: 120.9),
    );
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    expect(harness.coordinates.writes, hasLength(1));
    expect(
      harness.coordinates.writes.single.point,
      const MapCoordinate(latitude: 14.5, longitude: 120.9),
    );
  });

  testWidgets('Saved Place with boundary: outside candidate shows the '
      'canonical dialog, performs ZERO writes, keeps inline edit active and '
      'the old persisted coordinate unchanged', (tester) async {
    final harness = await _mount(
      tester,
      markers: const [_placeMarker],
      place: _placeWith(boundary: _boundary),
    );
    await _openInlineEdit(tester);
    await _moveCameraTo(tester, _outside);
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    // Exact owner-approved copy.
    expect(find.text("Boundary doesn't include this place"), findsOneWidget);
    expect(
      find.text(
        'The place icon must be inside the boundary. '
        'Adjust the outline and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('boundary-exclusion-ok')), findsOneWidget);
    // Zero coordinate writes; inline edit still active; pin visible.
    expect(harness.coordinates.writes, isEmpty);
    expect(find.byKey(const Key('maps-centering-pin')), findsOneWidget);
    expect(find.byKey(const Key('maps-centering-confirm')), findsOneWidget);
    // Dismiss, then correct the candidate: Confirm now succeeds.
    await tester.tap(find.byKey(const Key('boundary-exclusion-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('maps-centering-confirm')), findsOneWidget);
    await _moveCameraTo(
      tester,
      const MapCoordinate(latitude: 14.6, longitude: 121.05),
    );
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    expect(harness.coordinates.writes, hasLength(1));
    expect(
      harness.coordinates.writes.single.point,
      const MapCoordinate(latitude: 14.6, longitude: 121.05),
    );
  });

  testWidgets('Saved Place with NO boundary: existing behavior unchanged '
      '(outside candidate persists)', (tester) async {
    final harness = await _mount(
      tester,
      markers: const [_placeMarker],
      place: _placeWith(boundary: null),
    );
    await _openInlineEdit(tester);
    await _moveCameraTo(tester, _outside);
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    expect(harness.coordinates.writes, hasLength(1));
    expect(harness.coordinates.writes.single.point, _outside);
    expect(find.byKey(const Key('boundary-exclusion-dialog')), findsNothing);
  });

  testWidgets('Contact Edit Pin is unchanged and never reads the Saved Place '
      'repository', (tester) async {
    final harness = await _mount(tester, markers: const [_contactMarker]);
    await _openInlineEdit(tester, _contactMarker);
    await _moveCameraTo(tester, _outside);
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    expect(harness.coordinates.writes, hasLength(1));
    expect(harness.coordinates.writes.single.owner, MapCoordinateOwner.contact);
    expect(harness.coordinates.writes.single.point, _outside);
    expect(harness.places.readCalls, 0);
  });

  testWidgets('Event Edit Pin is unchanged and never reads the Saved Place '
      'repository', (tester) async {
    final harness = await _mount(tester, markers: const [_eventMarker]);
    await _openInlineEdit(tester, _eventMarker);
    await _moveCameraTo(tester, _outside);
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pumpAndSettle();
    expect(harness.coordinates.writes, hasLength(1));
    expect(harness.coordinates.writes.single.owner, MapCoordinateOwner.event);
    expect(harness.coordinates.writes.single.point, _outside);
    expect(harness.places.readCalls, 0);
  });
}

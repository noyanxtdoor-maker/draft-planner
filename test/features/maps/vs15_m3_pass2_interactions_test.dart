import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/map_marker_preview_sheet.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';

const _place = MapMarker(
  owner: MapCoordinateOwner.savedPlace,
  recordId: 'place-1',
  displayName: 'Offline home',
  coordinate: MapCoordinate(latitude: 14.6, longitude: 121),
);
const _otherPlace = MapMarker(
  owner: MapCoordinateOwner.savedPlace,
  recordId: 'place-2',
  displayName: 'Second place',
  coordinate: MapCoordinate(latitude: 10.3, longitude: 123.8),
);
const _changed = MapCoordinate(latitude: 16.25, longitude: 120.75);

class _RecordingCoordinates implements MapCoordinateRepository {
  @override
  Stream<int> watchChanges(String profileId) => const Stream.empty();
  @override
  Future<List<MapMarker>> readMarkers(String profileId) async => [
    _place,
    _otherPlace,
  ];
  @override
  Future<MapCoordinate?> readCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async => _place.coordinate;
  @override
  Future<void> clearCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async {}
  final writes =
      <({MapCoordinateOwner owner, String id, MapCoordinate point})>[];
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> setCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
    required MapCoordinate coordinate,
  }) async {
    if (fail) throw StateError('Offline storage failure');
    writes.add((owner: owner, id: recordId, point: coordinate));
    if (pending != null) await pending!.future;
  }
}

/// Pass 3: inline confirm reads the CURRENT Saved Place (boundary invariant).
/// These interaction tests exercise the no-boundary path, so the fake returns
/// null — exactly the pre-Pass-3 behavior.
class _NoBoundarySavedPlaces implements SavedPlaceRepository {
  @override
  Stream<List<SavedPlace>> watch(String profileId) => const Stream.empty();
  @override
  Future<List<SavedPlace>> list(String profileId) async => const [];
  @override
  Future<SavedPlace?> readById({
    required String profileId,
    required String id,
  }) async => null;
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

Future<void> _mount(
  WidgetTester tester, {
  _RecordingCoordinates? repository,
  VoidCallback? onCanvasBuild,
}) async {
  tester.view.physicalSize = const Size(431, 912);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProfileIdProvider.overrideWithValue('test-profile'),
        savedPlaceProfileIdProvider.overrideWithValue('test-profile'),
        mapProjectedMarkersProvider.overrideWith(
          (ref) async => [_place, _otherPlace],
        ),
        mapPassiveLocationProvider.overrideWith((ref) async => null),
        mapCoordinateRepositoryProvider.overrideWithValue(
          repository ?? _RecordingCoordinates(),
        ),
        savedPlaceRepositoryProvider.overrideWithValue(
          _NoBoundarySavedPlaces(),
        ),
      ],
      child: MaterialApp(
        home: MapsScreen(
          mapBuilder: (_, _) {
            onCanvasBuild?.call();
            return const ColoredBox(
              key: Key('stable-map-canvas'),
              color: Colors.white,
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GoogleMapsSurface _surface(WidgetTester tester) =>
    tester.widget<GoogleMapsSurface>(find.byType(GoogleMapsSurface));

Future<void> _select(WidgetTester tester, [MapMarker marker = _place]) async {
  _surface(tester).onMarkerTap(marker);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'real preview callbacks restore all three controls through ten cycles',
    (tester) async {
      await _mount(tester);
      final keys = [
        'maps-type-button',
        'maps-locate-button',
        'maps-drop-pin-button',
      ];
      final resting = [
        for (final key in keys) tester.getRect(find.byKey(Key(key))),
      ];
      for (var cycle = 0; cycle < 10; cycle++) {
        await _select(tester);
        expect(find.byType(MapMarkerPreviewSheet), findsOneWidget);
        for (var index = 0; index < keys.length; index++) {
          expect(
            tester.getRect(find.byKey(Key(keys[index]))).top,
            lessThan(resting[index].top),
          );
        }
        if (cycle % 3 == 0) {
          _surface(tester).onMapTap!();
        } else if (cycle % 3 == 1) {
          await tester.drag(
            find.byKey(const Key('maps-marker-preview-handle')),
            const Offset(0, 600),
          );
        } else {
          tester
              .widget<MapMarkerPreviewSheet>(find.byType(MapMarkerPreviewSheet))
              .onDismiss();
        }
        await tester.pumpAndSettle();
        expect(find.byType(MapMarkerPreviewSheet), findsNothing);
        for (var index = 0; index < keys.length; index++) {
          expect(
            tester.getRect(find.byKey(Key(keys[index]))),
            resting[index],
            reason: 'control ${keys[index]}, cycle $cycle',
          );
        }
      }
      await _select(tester);
      _surface(tester).onMapTap!();
      await tester.pump(const Duration(milliseconds: 80));
      _surface(tester).onMarkerTap(_otherPlace);
      await tester.pumpAndSettle();
      expect(find.text('Second place'), findsOneWidget);
      expect(find.text('10.30000, 123.80000'), findsNothing);
    },
  );

  testWidgets(
    'camera motion costs zero parent rebuilds, including inline Edit',
    (tester) async {
      var builds = 0;
      await _mount(tester, onCanvasBuild: () => builds++);
      final idleBuilds = builds;
      for (var move = 0; move < 500; move++) {
        _surface(tester).onCameraCenterChanged!(_changed);
      }
      await tester.pump();
      expect(builds, idleBuilds);
      final mapState = tester.state(find.byType(GoogleMapsSurface));
      await _select(tester);
      tester
          .widget<MapMarkerPreviewSheet>(find.byType(MapMarkerPreviewSheet))
          .onEditLocation();
      await tester.pumpAndSettle();
      final editingBuilds = builds;
      for (var move = 0; move < 500; move++) {
        _surface(tester).onCameraCenterChanged!(_changed);
      }
      await tester.pump();
      expect(builds, editingBuilds);
      expect(
        identical(tester.state(find.byType(GoogleMapsSurface)), mapState),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('maps-centering-cancel')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('inline confirm writes the Saved Place exact coordinate once', (
    tester,
  ) async {
    final repository = _RecordingCoordinates()..pending = Completer<void>();
    await _mount(tester, repository: repository);
    // Enter through the real preview action with an exact typed record owner.
    await _select(tester);
    tester
        .widget<MapMarkerPreviewSheet>(find.byType(MapMarkerPreviewSheet))
        .onEditLocation();
    await tester.pumpAndSettle();
    _surface(tester).onCameraCenterChanged!(_changed);
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('maps-centering-confirm')));
    expect(repository.writes, hasLength(1));
    expect(repository.writes.single.point, _changed);
    expect(repository.writes.single.id, 'place-1');
    expect(repository.writes.single.owner, MapCoordinateOwner.savedPlace);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('maps-centering-confirm')), findsNothing);
    expect(find.byType(MapsScreen), findsOneWidget);
  });

  testWidgets(
    'inline X and Android Back write nothing; failed save stays truthful',
    (tester) async {
      final repository = _RecordingCoordinates();
      await _mount(tester, repository: repository);
      for (final useBack in [false, true]) {
        await _select(tester);
        tester
            .widget<MapMarkerPreviewSheet>(find.byType(MapMarkerPreviewSheet))
            .onEditLocation();
        await tester.pumpAndSettle();
        _surface(tester).onCameraCenterChanged!(_changed);
        if (useBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byKey(const Key('maps-centering-cancel')));
        }
        await tester.pumpAndSettle();
        expect(repository.writes, isEmpty);
        expect(find.byKey(const Key('maps-centering-pin')), findsNothing);
      }
      repository.fail = true;
      await _select(tester);
      tester
          .widget<MapMarkerPreviewSheet>(find.byType(MapMarkerPreviewSheet))
          .onEditLocation();
      await tester.pumpAndSettle();
      _surface(tester).onCameraCenterChanged!(_changed);
      await tester.tap(find.byKey(const Key('maps-centering-confirm')));
      await tester.pump();
      expect(repository.writes, isEmpty);
      expect(
        find.text('Location could not be saved. Your pin is unchanged.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('maps-centering-pin')), findsOneWidget);
    },
  );

  testWidgets(
    'long press opens dismissible chooser then full-screen editor and Back cancels',
    (tester) async {
      final repository = _RecordingCoordinates();
      await _mount(tester, repository: repository);
      final stateBefore = tester.state(find.byType(GoogleMapsSurface));
      _surface(tester).onMapLongPress!(_changed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-action-handle')), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('location-action-handle')),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-action-handle')), findsNothing);
      expect(repository.writes, isEmpty);
      _surface(tester).onMapLongPress!(_changed);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-action-place')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('saved-place-form-screen')), findsOneWidget);
      expect(find.text('16.25000, 120.75000'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('saved-place-form-screen')), findsNothing);
      expect(
        identical(tester.state(find.byType(GoogleMapsSurface)), stateBefore),
        isTrue,
      );
      expect(repository.writes, isEmpty);
    },
  );
}

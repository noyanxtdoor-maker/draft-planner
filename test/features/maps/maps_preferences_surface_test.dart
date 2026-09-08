// VS-15 M6.2 — GoogleMapsSurface grouping ON/OFF, durable layer
// visibility, and quick-sheet synchronization.
//
// Uses the accepted fake-platform harness (same pattern as the session
// motion controls suite): GoogleMapsSurface mounts a real GoogleMap widget
// against a stubbed platform so markers/clusterManagers are inspectable.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_provider.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';

import 'maps_preferences_test_support.dart';

const _a = MapCoordinate(latitude: 14.6, longitude: 121.0);
const _b = MapCoordinate(latitude: 14.61, longitude: 121.01);

const _contactA = MapMarker(
  owner: MapCoordinateOwner.contact,
  recordId: 'contact-a',
  coordinate: _a,
  displayName: 'Ana Reyes',
  isFavorite: true,
  colorValue: 0xFF175A8F,
);

const _contactB = MapMarker(
  owner: MapCoordinateOwner.contact,
  recordId: 'contact-b',
  coordinate: _a, // Exact-coordinate twin of _contactA.
  displayName: 'Ben Cruz',
  isFavorite: true,
  colorValue: 0xFF175A8F,
);

const _event = MapMarker(
  owner: MapCoordinateOwner.event,
  recordId: 'event-1',
  occurrenceId: 'event-1@2026-09-07',
  coordinate: _b,
  displayName: 'Temple Visit',
);

const _place = MapMarker(
  owner: MapCoordinateOwner.savedPlace,
  recordId: 'place-1',
  coordinate: MapCoordinate(latitude: 10.3157, longitude: 123.8854),
  displayName: 'My Farm',
);

class _FakePlatform extends GoogleMapsFlutterPlatform {
  final Set<int> createdIds = <int>{};

  @override
  Widget buildViewWithConfiguration(
    int id,
    PlatformViewCreatedCallback created, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    if (!createdIds.contains(id)) {
      createdIds.add(id);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('nexttransfer/maps_interaction/$id'),
            (_) async => null,
          );
      scheduleMicrotask(() => created(id));
    }
    return ColoredBox(key: Key('native-canvas-$id'), color: Colors.grey);
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

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
  Future<void> updatePolylines(
    PolylineUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> moveCamera(CameraUpdate update, {required int mapId}) async {}

  @override
  Future<void> animateCameraWithConfiguration(
    CameraUpdate update,
    CameraUpdateAnimationConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      const Stream.empty();

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakePlatform platform;
  setUp(() {
    platform = _FakePlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });

  Future<ProviderContainer> mount(
    WidgetTester tester,
    List<MapMarker> markers, {
    List<MapMarker> Function(List<MapMarker> visible)? projection,
    MapCoordinate? provisionalPlaceCoordinate,
    bool interactionPaused = false,
    MapsPreferencesRepository? preferencesRepository,
    MapsPreferencesModel? preferencesSeed,
  }) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: mapsPreferencesOverrides(
        repository: preferencesRepository,
        seed: preferencesSeed,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(ThemeColorMode.blue),
          home: Scaffold(
            body: GoogleMapsSurface(
              markers: markers,
              initialCoordinate: null,
              provisionalPlaceCoordinate: provisionalPlaceCoordinate,
              interactionPaused: interactionPaused,
              onMarkerTap: (_) {},
              onDropPin: () {},
              mapBuilder: projection == null
                  ? null
                  : (context, visible) => SizedBox.expand(
                      child: Text('markers=${visible.length}'),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  GoogleMap mapOf(WidgetTester tester) =>
      tester.widget<GoogleMap>(find.byType(GoogleMap));

  Future<void> setGrouping(ProviderContainer container, bool value) async {
    await container
        .read(mapsPreferencesProvider.notifier)
        .setGroupNearbyMarkers(value);
  }

  group('grouping', () {
    testWidgets(
      '24. ON (default) uses the exact-coordinate aggregate pipeline with '
      'cluster managers active',
      (tester) async {
        await mount(tester, const [_contactA, _contactB]);
        final map = mapOf(tester);
        // Exact-coordinate twins collapse into ONE aggregate marker.
        expect(map.markers, hasLength(1));
        expect(map.markers.single.markerId.value, startsWith('maps-location:'));
        expect(map.markers.single.clusterManagerId, isNotNull);
        expect(map.clusterManagers, hasLength(3));
      },
    );

    testWidgets('25/26/27. OFF keeps exact-coordinate records separate with NO '
        'aggregate targets and null clusterManagerId', (tester) async {
      final container = await mount(tester, const [_contactA, _contactB]);
      await setGrouping(container, false);
      await tester.pumpAndSettle();
      final map = mapOf(tester);
      expect(map.markers, hasLength(2));
      for (final marker in map.markers) {
        expect(marker.markerId.value, isNot(startsWith('maps-location:')));
        expect(marker.clusterManagerId, isNull);
      }
    });

    testWidgets('28. OFF removes every active cluster manager', (tester) async {
      final container = await mount(tester, const [_contactA, _contactB]);
      await setGrouping(container, false);
      await tester.pumpAndSettle();
      expect(mapOf(tester).clusterManagers, isEmpty);
    });

    testWidgets('29/30/31. OFF keeps stable marker identity and visuals; the '
        'underlying record set is untouched', (tester) async {
      final container = await mount(tester, const [_contactA, _contactB]);
      await setGrouping(container, false);
      await tester.pumpAndSettle();
      final markers = mapOf(tester).markers.toList();
      expect(
        markers.map((m) => m.markerId.value),
        containsAll(<String>['contact:contact-a', 'contact:contact-b']),
      );
      for (final marker in markers) {
        expect(marker.position.latitude, closeTo(14.6, 0.001));
        expect(marker.consumeTapEvents, isTrue);
        expect(marker.onTap, isNotNull);
      }
    });

    testWidgets('32. ON after OFF returns the exact clustering', (
      tester,
    ) async {
      final container = await mount(tester, const [_contactA, _contactB]);
      await setGrouping(container, false);
      await tester.pumpAndSettle();
      expect(mapOf(tester).markers, hasLength(2));
      await setGrouping(container, true);
      await tester.pumpAndSettle();
      final map = mapOf(tester);
      expect(map.markers, hasLength(1));
      expect(map.markers.single.markerId.value, startsWith('maps-location:'));
      expect(map.markers.single.clusterManagerId, isNotNull);
      expect(map.clusterManagers, hasLength(3));
    });

    testWidgets(
      '33/34. cache transitions never reuse a stale clusterManagerId in '
      'either direction',
      (tester) async {
        final container = await mount(tester, const [_contactA, _contactB]);
        // OFF after ON: every marker must carry null membership (an OFF
        // marker must never reuse an ON Marker with a stale manager id).
        await setGrouping(container, false);
        await tester.pumpAndSettle();
        for (final marker in mapOf(tester).markers) {
          expect(marker.clusterManagerId, isNull);
        }
        // ON after OFF: the aggregate must re-join the manager set (an ON
        // marker must never keep null membership).
        await setGrouping(container, true);
        await tester.pumpAndSettle();
        expect(mapOf(tester).markers.single.clusterManagerId, isNotNull);
        expect(mapOf(tester).clusterManagers, hasLength(3));
      },
    );

    testWidgets('35. turning OFF while a GROUP is selected clears that group '
        'selection; an individual selection may remain', (tester) async {
      final container = await mount(tester, const [_contactA, _contactB]);
      container.read(mapSelectedMarkerProvider.notifier).selectGroup(const [
        _contactA,
        _contactB,
      ], MapMarkerGrouping.exactCoordinate);
      expect(container.read(mapSelectedMarkerProvider)?.isGroup, isTrue);
      await setGrouping(container, false);
      await tester.pumpAndSettle();
      expect(container.read(mapSelectedMarkerProvider), isNull);

      // Individual selection survives the OFF transition.
      container.read(mapSelectedMarkerProvider.notifier).select(_event);
      expect(container.read(mapSelectedMarkerProvider)?.isGroup, isFalse);
      await setGrouping(container, true);
      await tester.pumpAndSettle();
      expect(
        container.read(mapSelectedMarkerProvider)?.markerKey,
        _event.ownerKey,
      );
    });

    testWidgets('37. ON keeps the [4] → selected + [3] → [4] family intact', (
      tester,
    ) async {
      final four = <MapMarker>[
        for (var i = 0; i < 4; i++)
          MapMarker(
            owner: MapCoordinateOwner.contact,
            recordId: 'contact-$i',
            coordinate: _a,
            displayName: 'Member $i',
            isFavorite: true,
            colorValue: 0xFF175A8F,
          ),
      ];
      await mount(tester, four);
      final map = mapOf(tester);
      expect(map.markers, hasLength(1));
      expect(map.markers.single.markerId.value, startsWith('maps-location:'));
      // Selecting the group must not duplicate the pin (one marker stays).
      map.markers.single.onTap!();
      await tester.pumpAndSettle();
      expect(mapOf(tester).markers, hasLength(1));
    });
  });

  group('layer visibility (durable)', () {
    testWidgets(
      '40/41. Contacts OFF hides Contacts; ON restores the exact identities',
      (tester) async {
        final container = await mount(tester, const [_contactA, _event]);
        expect(mapOf(tester).markers, hasLength(2));
        await container
            .read(mapsPreferencesProvider.notifier)
            .setShowContacts(false);
        await tester.pumpAndSettle();
        expect(mapOf(tester).markers, hasLength(1));
        expect(mapOf(tester).markers.single.markerId.value, _event.ownerKey);
        await container
            .read(mapsPreferencesProvider.notifier)
            .setShowContacts(true);
        await tester.pumpAndSettle();
        final markers = mapOf(tester).markers.map((m) => m.markerId.value);
        expect(
          markers,
          containsAll(<String>[_contactA.ownerKey, _event.ownerKey]),
        );
      },
    );

    testWidgets('42. Events OFF/ON', (tester) async {
      final container = await mount(tester, const [_contactA, _event]);
      await container
          .read(mapsPreferencesProvider.notifier)
          .setShowEvents(false);
      await tester.pumpAndSettle();
      expect(mapOf(tester).markers.map((m) => m.markerId.value), <String>[
        _contactA.ownerKey,
      ]);
      await container
          .read(mapsPreferencesProvider.notifier)
          .setShowEvents(true);
      await tester.pumpAndSettle();
      expect(mapOf(tester).markers, hasLength(2));
    });

    testWidgets('43. Saved Places OFF/ON', (tester) async {
      final container = await mount(tester, const [_place]);
      await container
          .read(mapsPreferencesProvider.notifier)
          .setShowSavedPlaces(false);
      await tester.pumpAndSettle();
      expect(mapOf(tester).markers, isEmpty);
      await container
          .read(mapsPreferencesProvider.notifier)
          .setShowSavedPlaces(true);
      await tester.pumpAndSettle();
      expect(mapOf(tester).markers, hasLength(1));
    });

    testWidgets(
      '47. preferences survive surface recreation (one durable truth)',
      (tester) async {
        final container = await mount(tester, const [_contactA, _event]);
        await container
            .read(mapsPreferencesProvider.notifier)
            .setShowContacts(false);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(ThemeColorMode.blue),
              home: Scaffold(
                body: GoogleMapsSurface(
                  markers: const [_contactA, _event],
                  initialCoordinate: null,
                  onMarkerTap: (_) {},
                  onDropPin: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(mapOf(tester).markers, hasLength(1));
        expect(mapOf(tester).markers.single.markerId.value, _event.ownerKey);
      },
    );

    testWidgets(
      '49. a focused hidden record keeps the visibilityLease exception',
      (tester) async {
        final container = await mount(tester, const [_contactA, _event]);
        await container
            .read(mapsPreferencesProvider.notifier)
            .setShowContacts(false);
        await tester.pumpAndSettle();
        expect(mapOf(tester).markers, hasLength(1));
        container
            .read(mapTransientFocusProvider.notifier)
            .focusContact(contactId: 'contact-a', coordinate: _a);
        // In production the focused marker re-enters the surface through the
        // marker providers watching the visibility lease; re-pump so the
        // surface rebuilds against the lease, exactly as a parent rebuild
        // does when mapProjectedMarkersProvider re-emits.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(ThemeColorMode.blue),
              home: Scaffold(
                body: GoogleMapsSurface(
                  markers: const [_contactA, _event],
                  initialCoordinate: null,
                  onMarkerTap: (_) {},
                  onDropPin: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          mapOf(tester).markers.map((m) => m.markerId.value),
          contains(_contactA.ownerKey),
        );
      },
    );
  });

  group('quick sheet syncs with the durable provider', () {
    testWidgets(
      '62-67. quick controls read/write the durable preference; toggles '
      'persist and the provider is the single truth',
      (tester) async {
        final container = await mount(tester, const [_contactA, _event]);
        await tester.tap(find.byKey(const Key('maps-type-button')));
        await tester.pumpAndSettle();
        // Existing quick sheet shows the durable Contacts state (ON).
        expect(
          tester
              .widget<Switch>(
                find.descendant(
                  of: find.byKey(const Key('maps-layer-people')),
                  matching: find.byType(Switch),
                ),
              )
              .value,
          isTrue,
        );
        await tester.tap(find.byKey(const Key('maps-layer-people')));
        await tester.pumpAndSettle();
        final fake = container.read(mapsPreferencesRepositoryProvider);
        expect((await fake.readPreferences()).showContacts, isFalse);
        expect(container.read(mapsPreferencesProvider).showContacts, isFalse);
        // The Map Type quick control mirrors the durable map type.
        expect(
          container.read(mapsPreferencesProvider).mapType,
          NextTransferMapType.satellite,
        );
      },
    );

    Future<void> openMarkerGrouping(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('maps-type-button')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('maps-group-nearby')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }

    Switch groupingSwitch(WidgetTester tester) => tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('maps-group-nearby')),
        matching: find.byType(Switch),
      ),
    );

    testWidgets(
      '68-72. quick sheet adds only MARKER GROUPING with the durable ON '
      'default and preserves existing sections',
      (tester) async {
        await mount(tester, const [_contactA, _contactB]);
        await openMarkerGrouping(tester);

        expect(find.text('MARKER GROUPING'), findsOneWidget);
        expect(find.text('Group nearby markers'), findsOneWidget);
        expect(groupingSwitch(tester).value, isTrue);
        expect(find.text('Map Type'), findsWidgets);
        expect(find.text('Markers'), findsOneWidget);
        expect(find.text('Contacts'), findsOneWidget);
        expect(find.text("Today's Events"), findsOneWidget);
        expect(find.text('Places'), findsOneWidget);
        expect(find.text('Boundaries'), findsNothing);
        expect(find.text('Map Tiles'), findsNothing);
        expect(find.text('Icons'), findsNothing);
      },
    );

    testWidgets('73. persisted OFF is already OFF when the quick sheet opens', (
      tester,
    ) async {
      const seed = MapsPreferencesModel(groupNearbyMarkers: false);
      final fake = FakeMapsPreferencesRepository(seed);
      await mount(
        tester,
        const [_contactA, _contactB],
        preferencesRepository: fake,
        preferencesSeed: seed,
      );
      await openMarkerGrouping(tester);

      expect(groupingSwitch(tester).value, isFalse);
      expect(mapOf(tester).markers, hasLength(2));
      expect(mapOf(tester).clusterManagers, isEmpty);
    });

    testWidgets(
      '74-77. quick toggle persists ON to OFF, updates the live map and '
      'provider, then OFF to ON restores clustering',
      (tester) async {
        final fake = FakeMapsPreferencesRepository();
        final container = await mount(tester, const [
          _contactA,
          _contactB,
        ], preferencesRepository: fake);
        await openMarkerGrouping(tester);

        await tester.tap(find.byKey(const Key('maps-group-nearby')));
        await tester.pumpAndSettle();
        expect(groupingSwitch(tester).value, isFalse);
        expect(fake.stored?.groupNearbyMarkers, isFalse);
        expect(
          container.read(mapsPreferencesProvider).groupNearbyMarkers,
          isFalse,
        );
        expect(mapOf(tester).markers, hasLength(2));
        expect(mapOf(tester).clusterManagers, isEmpty);

        await tester.tap(find.byKey(const Key('maps-group-nearby')));
        await tester.pumpAndSettle();
        expect(groupingSwitch(tester).value, isTrue);
        expect(fake.stored?.groupNearbyMarkers, isTrue);
        expect(
          container.read(mapsPreferencesProvider).groupNearbyMarkers,
          isTrue,
        );
        expect(mapOf(tester).markers, hasLength(1));
        expect(mapOf(tester).clusterManagers, hasLength(3));
      },
    );

    testWidgets(
      '78. quick-toggle write failure retains confirmed ON state and reports '
      'the canonical concise failure',
      (tester) async {
        final fake = FakeMapsPreferencesRepository()..failWrites = true;
        final container = await mount(tester, const [
          _contactA,
          _contactB,
        ], preferencesRepository: fake);
        await openMarkerGrouping(tester);

        await tester.tap(find.byKey(const Key('maps-group-nearby')));
        await tester.pumpAndSettle();

        expect(fake.writeCount, 1);
        expect(groupingSwitch(tester).value, isTrue);
        expect(
          container.read(mapsPreferencesProvider).groupNearbyMarkers,
          isTrue,
        );
        expect(mapOf(tester).markers, hasLength(1));
        expect(mapOf(tester).clusterManagers, hasLength(3));
        expect(
          find.text("Couldn't save this setting. Please try again."),
          findsOneWidget,
        );
      },
    );
  });
}

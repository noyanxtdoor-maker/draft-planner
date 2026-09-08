import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/application/contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_interaction_trace.dart';
import 'package:rmplanner/features/maps/application/map_marker_target.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

const _point = MapCoordinate(latitude: 14.6, longitude: 121);
MapMarker _place(String id, {MapCoordinate point = _point}) => MapMarker(
  owner: MapCoordinateOwner.savedPlace,
  recordId: id,
  displayName: id,
  coordinate: point,
  colorValue: 0xFF175A8F,
  placeMarkerMode: SavedPlaceMarkerMode.standard,
  placeStandardCategory: SavedPlaceStandardCategory.food,
);

class _DelayedContacts implements ContactRepository {
  @override
  Future<List<EventParticipantPresentation>> readEventParticipantPresentation({
    required String profileId,
    required String eventId,
    required String occurrenceId,
    required bool historical,
  }) async => [];
  final requests = <String, Completer<ContactDetail>>{};
  @override
  Future<ContactDetail> readContactDetail({
    required String profileId,
    required String contactId,
  }) => requests.putIfAbsent(contactId, Completer<ContactDetail>.new).future;
  @override
  Future<Map<String, ContactSummary>> readContactsByIds({
    required String profileId,
    required List<String> contactIds,
    required PlannerDate today,
  }) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ContactDetail _detail(String id) => ContactDetail(
  contact: Contact(
    id: id,
    profileId: 'test-profile',
    firstName: id,
    lastName: null,
    displayName: id,
    preferredContactMethod: ContactPreferredMethod.message,
    isFavorite: false,
    lifecycleState: ContactLifecycleState.active,
    source: ContactSource.manual,
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
  ),
);

class _PendingCalendar implements CalendarEventRepository {
  final pending = Completer<CalendarEventOccurrence?>();
  @override
  Future<CalendarEventOccurrence?> readOccurrence({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
  }) => pending.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MovingDateSource implements PlannerDateSource {
  _MovingDateSource(this.value);
  PlannerDate value;
  @override
  PlannerDate today() => value;
}

class _CanvasPlatform extends GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int id,
    PlatformViewCreatedCallback created, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) => const ColoredBox(color: Colors.white);
}

GoogleMap _map(WidgetTester tester) =>
    tester.widget<GoogleMap>(find.byType(GoogleMap));
Future<ProviderContainer> _mount(
  WidgetTester tester,
  List<MapMarker> markers, {
  ContactRepository? contacts,
  PlannerDateSource? dates,
  CalendarEventRepository? calendar,
}) async {
  tester.view.physicalSize = const Size(431, 912);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (calendar != null)
          calendarEventRepositoryProvider.overrideWithValue(calendar),
        if (dates != null) plannerDateSourceProvider.overrideWithValue(dates),
        if (contacts != null)
          contactRepositoryProvider.overrideWithValue(contacts),
        contactProfileIdProvider.overrideWithValue('test-profile'),
        mapProfileIdProvider.overrideWithValue('test-profile'),
        mapProjectedMarkersProvider.overrideWith((ref) async => markers),
        mapPassiveLocationProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: MapsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MapsScreen)));
}

void _clusterTap(WidgetTester tester, Iterable<Marker> members) {
  final ids = members.map((m) => m.markerId).toList();
  final manager = _map(tester).clusterManagers.firstWhere(
    (c) => c.clusterManagerId == members.first.clusterManagerId,
  );
  expect(manager.onClusterTap, isNotNull);
  manager.onClusterTap!(
    Cluster(
      manager.clusterManagerId,
      ids,
      position: const LatLng(14.6, 121),
      bounds: LatLngBounds(
        southwest: const LatLng(14, 120),
        northeast: const LatLng(15, 122),
      ),
    ),
  );
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
  testWidgets(
    'exact location is one target; all unique members open and select',
    (tester) async {
      final a = _place('A'), b = _place('B');
      final container = await _mount(tester, [a, b, a]);
      expect(_map(tester).markers, hasLength(1));
      _map(tester).markers.single.onTap!();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('maps-group-row-place:A')), findsOneWidget);
      expect(find.byKey(const Key('maps-group-row-place:B')), findsOneWidget);
      expect(container.read(mapTransientFocusProvider).pending, isNull);
      await tester.tap(find.byKey(const Key('maps-group-row-place:B')));
      await tester.pumpAndSettle();
      expect(container.read(mapSelectedMarkerProvider)?.markerKey, b.ownerKey);
      expect(find.byKey(const Key('maps-place-preview-label')), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    },
  );
  testWidgets('zoom cluster opens all members without a focus command', (
    tester,
  ) async {
    final container = await _mount(tester, [
      _place('A'),
      _place(
        'B',
        point: const MapCoordinate(latitude: 14.60001, longitude: 121),
      ),
    ]);
    expect(_map(tester).markers, hasLength(2));
    _clusterTap(tester, _map(tester).markers);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('maps-group-row-place:A')), findsOneWidget);
    expect(find.byKey(const Key('maps-group-row-place:B')), findsOneWidget);
    expect(container.read(mapTransientFocusProvider).pending, isNull);
  });
  testWidgets('rapid native A B C taps and interrupted close keep C', (
    tester,
  ) async {
    final markers = [
      for (var i = 0; i < 3; i++)
        _place(
          'ABC'[i],
          point: MapCoordinate(latitude: 14.6 + i * .001, longitude: 121),
        ),
    ];
    final container = await _mount(tester, markers);
    final native = _map(tester).markers.toList();
    native[0].onTap!();
    await tester.pump(const Duration(milliseconds: 40));
    native[1].onTap!();
    _map(tester).onTap!(const LatLng(0, 0));
    await tester.pump(const Duration(milliseconds: 40));
    native[2].onTap!();
    await tester.pump();
    expect(find.text('C'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      container.read(mapSelectedMarkerProvider)?.markerKey,
      markers.last.ownerKey,
    );
    expect(find.text('C'), findsOneWidget);
    expect(container.read(mapTransientFocusProvider).pending, isNull);
    expect(
      _map(tester).markers.singleWhere((m) => m.zIndexInt == 20).position,
      native.last.position,
    );
  });
  testWidgets(
    'mixed exact members use canonical unselected bitmap identities',
    (tester) async {
      final markers = [
        const MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'contact',
          displayName: 'Contact',
          coordinate: _point,
          colorValue: 0xFF805AB8,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'favorite',
          displayName: 'Favorite',
          coordinate: _point,
          colorValue: 0xFFE7BA53,
          isFavorite: true,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.event,
          recordId: 'event',
          displayName: 'Event',
          coordinate: _point,
          colorValue: 0xFF397642,
        ),
        _place('standard'),
        const MapMarker(
          owner: MapCoordinateOwner.savedPlace,
          recordId: 'avoid',
          displayName: 'Avoid',
          coordinate: _point,
          colorValue: 0xFFD32F2F,
          placeMarkerMode: SavedPlaceMarkerMode.standard,
          placeStandardCategory: SavedPlaceStandardCategory.avoid,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.savedPlace,
          recordId: 'emoji',
          displayName: 'Emoji',
          coordinate: _point,
          placeMarkerMode: SavedPlaceMarkerMode.custom,
          placeEmoji: '☕',
        ),
      ];
      await _mount(tester, markers);
      expect(_map(tester).markers, hasLength(1));
      _map(tester).markers.single.onTap!();
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future.wait([
          for (final marker in markers)
            renderMapMarkerForTesting(marker, selected: false),
        ]),
      );
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('maps-group-row-contact:contact'));
      await tester.drag(sheet, const Offset(0, -420));
      await tester.pumpAndSettle();
      for (final marker in markers) {
        final row = find.byKey(Key('maps-group-row-${marker.ownerKey}'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(row, findsOneWidget);
        final image = tester.widget<Image>(
          find.descendant(of: row, matching: find.byType(Image)),
        );
        final expected =
            await tester.runAsync(
                  () => renderMapMarkerForTesting(marker, selected: false),
                )
                as BytesMapBitmap;
        expect(
          (image.image as MemoryImage).bytes,
          expected.byteData,
          reason: marker.ownerKey,
        );
        expect(
          image.color,
          isNull,
          reason: 'native emoji and stored colors must not be tinted',
        );
      }
    },
  );
  testWidgets('group sheet clears and controls return on map tap', (
    tester,
  ) async {
    final container = await _mount(tester, [_place('A'), _place('B')]);
    final control = find.byKey(const Key('maps-type-button'));
    final resting = tester.getRect(control);
    _map(tester).markers.first.onTap!();
    await tester.pumpAndSettle();
    expect(tester.getRect(control).bottom, lessThan(resting.bottom));
    _map(tester).onTap!(const LatLng(0, 0));
    await tester.pumpAndSettle();
    expect(container.read(mapSelectedMarkerProvider), isNull);
    expect(find.byKey(const Key('maps-marker-preview-sheet')), findsNothing);
    expect(tester.getRect(control), resting);
  });
  testWidgets('zoom cluster expands exact-location members exactly once', (
    tester,
  ) async {
    await _mount(tester, [
      _place('A'),
      _place('B'),
      _place('C', point: const MapCoordinate(latitude: 14.601, longitude: 121)),
    ]);
    expect(_map(tester).markers, hasLength(2));
    _clusterTap(tester, _map(tester).markers);
    await tester.pumpAndSettle();
    for (final name in ['A', 'B', 'C']) {
      expect(find.byKey(Key('maps-group-row-place:$name')), findsOneWidget);
    }
  });
  testWidgets('single-member cluster keeps individual preview and no focus', (
    tester,
  ) async {
    final container = await _mount(tester, [_place('A')]);
    _clusterTap(tester, _map(tester).markers);
    await tester.pumpAndSettle();
    expect(container.read(mapSelectedMarkerProvider)?.isGroup, isFalse);
    expect(find.byKey(const Key('maps-place-preview-label')), findsOneWidget);
    expect(container.read(mapTransientFocusProvider).pending, isNull);
  });
  testWidgets(
    'close distinct markers stay independent; only selected native entries change',
    (tester) async {
      final records = [
        for (var i = 0; i < 3; i++)
          _place(
            'ABC'[i],
            point: MapCoordinate(latitude: 14.6 + i * .00001, longitude: 121),
          ),
      ];
      final container = await _mount(tester, records);
      await tester.runAsync(
        () => renderMapMarkerForTesting(records.first, selected: true),
      );
      await tester.pumpAndSettle();
      final before = _map(tester).markers;
      expect(before.map((m) => m.position).toSet(), hasLength(3));
      final untouched = before.singleWhere(
        (m) => m.markerId.value == records[2].ownerKey,
      );
      var notifications = 0;
      final sub = container.listen(
        mapSelectedMarkerProvider,
        (_, _) => notifications++,
      );
      addTearDown(sub.close);
      before.first.onTap!();
      await tester.pumpAndSettle();
      final a = _map(tester).markers;
      expect(MarkerUpdates.from(before, a).markersToChange, hasLength(1));
      before.elementAt(1).onTap!();
      await tester.pumpAndSettle();
      final b = _map(tester).markers;
      expect(MarkerUpdates.from(a, b).markersToChange, hasLength(2));
      expect(
        identical(
          untouched,
          b.singleWhere((m) => m.markerId == untouched.markerId),
        ),
        isTrue,
      );
      expect(notifications, 2, reason: 'one state write per native tap');
      expect(b.singleWhere((m) => m.zIndexInt == 20).clusterManagerId, isNull);
      expect(
        b
            .where((m) => m.zIndexInt == 0)
            .every((m) => m.clusterManagerId != null),
        isTrue,
      );
      for (final marker in b) {
        expect((marker.icon as BytesMapBitmap).width, 34);
        expect(marker.consumeTapEvents, isTrue);
      }
    },
  );
  testWidgets('same visual event occurrences share one bitmap object', (
    tester,
  ) async {
    final records = [
      for (var i = 0; i < 2; i++)
        MapMarker(
          owner: MapCoordinateOwner.event,
          recordId: 'event',
          occurrenceId: 'occurrence-$i',
          displayName: 'Event',
          coordinate: MapCoordinate(latitude: 14.6 + i * .001, longitude: 121),
          colorValue: 0xFF397642,
        ),
    ];
    await _mount(tester, records);
    await tester.runAsync(
      () => renderMapMarkerForTesting(records.first, selected: false),
    );
    await tester.pumpAndSettle();
    final icons = _map(tester).markers.map((m) => m.icon).toList();
    expect(icons.first, isA<BytesMapBitmap>());
    expect(identical(icons.first, icons.last), isTrue);
  });
  test(
    'group reconciliation refreshes, reduces to single, clears, and ignores old group state',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(mapSelectedMarkerProvider.notifier);
      final a = _place('A'), b = _place('B');
      controller.selectGroup([a, b, a], MapMarkerGrouping.exactCoordinate);
      expect(container.read(mapSelectedMarkerProvider)!.members, hasLength(2));
      final updated = b.copyWith(displayName: 'Updated');
      controller.retainVisibleGroupMembers([a, updated]);
      expect(
        container.read(mapSelectedMarkerProvider)!.members.last.displayName,
        'Updated',
      );
      controller.retainVisibleGroupMembers([updated]);
      expect(container.read(mapSelectedMarkerProvider)!.isGroup, isFalse);
      expect(container.read(mapSelectedMarkerProvider)!.markerKey, b.ownerKey);
      controller.selectGroup([a, b], MapMarkerGrouping.zoomCluster);
      controller.retainVisibleGroupMembers([]);
      expect(container.read(mapSelectedMarkerProvider), isNull);
      controller.select(a);
      controller.retainVisibleGroupMembers([b]);
      expect(container.read(mapSelectedMarkerProvider)!.markerKey, a.ownerKey);
    },
  );

  testWidgets(
    'contact header switches immediately while delayed A and B cannot replace C',
    (tester) async {
      final repository = _DelayedContacts();
      final records = [
        for (var i = 0; i < 3; i++)
          MapMarker(
            owner: MapCoordinateOwner.contact,
            recordId: 'ABC'[i],
            displayName: 'ABC'[i],
            coordinate: MapCoordinate(
              latitude: 14.6 + i * .001,
              longitude: 121,
            ),
          ),
      ];
      final container = await _mount(tester, records, contacts: repository);
      final native = _map(tester).markers.toList();
      for (var i = 0; i < 3; i++) {
        native[i].onTap!();
        await tester.pump();
        expect(
          find.text('ABC'[i]),
          findsOneWidget,
          reason: 'selected identity must not wait for repository details',
        );
      }
      expect(repository.requests.keys, containsAll(['A', 'B', 'C']));
      repository.requests['C']!.complete(_detail('C'));
      await tester.pumpAndSettle();
      repository.requests['B']!.complete(_detail('B'));
      repository.requests['A']!.complete(_detail('A'));
      await tester.pumpAndSettle();
      expect(find.text('C'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
      expect(container.read(mapSelectedMarkerProvider)!.markerKey, 'contact:C');
      expect(container.read(mapTransientFocusProvider).pending, isNull);
    },
  );
  testWidgets(
    'Pass2 exact four exclude B and selected remainder then clear restores four',
    (tester) async {
      final records = [
        for (final id in ['A', 'B', 'C', 'D']) _place(id),
      ];
      final container = await _mount(tester, records);
      _map(tester).markers.single.onTap!();
      await tester.pumpAndSettle();
      container.read(mapSelectedMarkerProvider.notifier).select(records[1]);
      await tester.pumpAndSettle();
      final targets = exactCoordinateTargets(
        records,
        excludedOwnerKey: container
            .read(mapSelectedMarkerProvider)!
            .excludedOwnerKey,
      );
      expect(targets.single.members.map((m) => m.recordId), ['A', 'C', 'D']);
      expect(_map(tester).markers, hasLength(2));
      expect(
        _map(
          tester,
        ).markers.singleWhere((m) => m.zIndexInt == 20).markerId.value,
        'place:B',
      );
      _map(tester).markers
          .singleWhere((m) => m.markerId.value.startsWith('maps-location:'))
          .onTap!();
      await tester.pumpAndSettle();
      final selected = container.read(mapSelectedMarkerProvider)!;
      expect(selected.members.map((m) => m.recordId), ['A', 'C', 'D']);
      expect(selected.excludedOwnerKey, 'place:B');
      expect(_map(tester).markers, hasLength(2));
      container.read(mapSelectedMarkerProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(_map(tester).markers, hasLength(1));
      _map(tester).markers.single.onTap!();
      await tester.pumpAndSettle();
      expect(container.read(mapSelectedMarkerProvider)!.members, hasLength(4));
      expect(container.read(mapTransientFocusProvider).pending, isNull);
    },
  );
  testWidgets(
    'Pass2 zoom selection retains reported position and parent IDs for remainder',
    (tester) async {
      final records = [
        for (var i = 0; i < 4; i++)
          _place(
            'ABCD'[i],
            point: MapCoordinate(latitude: 14.6 + i * .001, longitude: 121),
          ),
      ];
      final container = await _mount(tester, records);
      _clusterTap(tester, _map(tester).markers);
      await tester.pumpAndSettle();
      final grouped = container.read(mapSelectedMarkerProvider)!;
      expect(grouped.origin!.position, _point);
      expect(
        grouped.origin!.nativeMarkerIds,
        containsAll(records.map((m) => m.ownerKey)),
      );
      container.read(mapSelectedMarkerProvider.notifier).select(records[1]);
      await tester.pumpAndSettle();
      expect(
        container.read(mapSelectedMarkerProvider)!.origin!.nativeMarkerIds,
        hasLength(4),
      );
      expect(
        _map(tester).markers.where((m) => m.clusterManagerId != null),
        hasLength(3),
      );
      expect(
        _map(
          tester,
        ).markers.singleWhere((m) => m.clusterManagerId == null).position,
        LatLng(records[1].coordinate.latitude, records[1].coordinate.longitude),
      );
      container.read(mapSelectedMarkerProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(
        _map(tester).markers.every((m) => m.clusterManagerId != null),
        isTrue,
      );
    },
  );
  test(
    'Pass2 selected group reuses pin and preserves lower count pixels',
    () async {
      final base =
          await renderMapMarkerForTesting(_place('shape'), selected: false)
              as BytesMapBitmap;
      final selected =
          await renderSelectedGroupForTesting(base.byteData) as BytesMapBitmap;
      final bc = await ui.instantiateImageCodec(base.byteData),
          sc = await ui.instantiateImageCodec(selected.byteData);
      final bi = (await bc.getNextFrame()).image,
          si = (await sc.getNextFrame()).image;
      expect(si.width, 96);
      expect(si.height, 176);
      final bp = (await bi.toByteData())!.buffer.asUint8List(),
          sp = (await si.toByteData())!.buffer.asUint8List();
      expect(sp.sublist(128 * 96 * 4), bp.sublist(48 * 96 * 4));
      var red = 0;
      for (var i = 0; i < sp.length; i += 4) {
        if (sp[i] > 150 &&
            sp[i + 1] < 90 &&
            sp[i + 2] < 90 &&
            sp[i + 3] > 150) {
          red++;
        }
      }
      expect(red, greaterThan(300));
      bi.dispose();
      si.dispose();
      bc.dispose();
      sc.dispose();
    },
  );
  testWidgets(
    'Pass2 single pending and loaded Contact and Favorite retain canonical identity',
    (tester) async {
      for (final favorite in [false, true]) {
        final repository = _DelayedContacts();
        final marker = MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'one',
          displayName: 'One',
          coordinate: _point,
          colorValue: 0xFF805AB8,
          isFavorite: favorite,
        );
        await _mount(tester, [marker], contacts: repository);
        _map(tester).markers.single.onTap!();
        await tester.pump();
        expect(
          tester
              .widget<MapMarkerIdentityIcon>(find.byType(MapMarkerIdentityIcon))
              .marker,
          marker,
        );
        expect(find.text('One'), findsOneWidget);
        repository.requests['one']!.complete(_detail('one'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MapMarkerIdentityIcon>(find.byType(MapMarkerIdentityIcon))
              .marker,
          marker,
        );
        expect(
          find.byKey(const Key('maps-contact-preview-name')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('Pass2 all Saved Place single identities use original renderer', (
    tester,
  ) async {
    final markers = [
      _place('standard'),
      const MapMarker(
        owner: MapCoordinateOwner.savedPlace,
        recordId: 'avoid',
        coordinate: _point,
        displayName: 'Avoid',
        colorValue: 0xFFD32F2F,
        placeMarkerMode: SavedPlaceMarkerMode.standard,
        placeStandardCategory: SavedPlaceStandardCategory.avoid,
      ),
      const MapMarker(
        owner: MapCoordinateOwner.savedPlace,
        recordId: 'emoji',
        coordinate: _point,
        displayName: 'Emoji',
        placeMarkerMode: SavedPlaceMarkerMode.custom,
        placeEmoji: '☕',
      ),
    ];
    final container = await _mount(tester, markers);
    for (final marker in markers) {
      container.read(mapSelectedMarkerProvider.notifier).select(marker);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MapMarkerIdentityIcon>(find.byType(MapMarkerIdentityIcon))
            .marker,
        marker,
      );
    }
  });
  testWidgets('Pass2 midnight and resume advance map-local day', (
    tester,
  ) async {
    final dates = _MovingDateSource(
      const PlannerDate(year: 2026, month: 9, day: 3),
    );
    final container = await _mount(tester, [_place('A')], dates: dates);
    expect(container.read(mapLocalDayProvider), dates.value);
    dates.value = dates.value.addDays(1);
    await tester.pump(const Duration(days: 1));
    expect(container.read(mapLocalDayProvider), dates.value);
    dates.value = dates.value.addDays(1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(container.read(mapLocalDayProvider), dates.value);
  });
  testWidgets(
    'Pass2 trace records committed selection and first frame without names',
    (tester) async {
      final container = await _mount(tester, [_place('A'), _place('B')]);
      container.read(mapSelectedMarkerProvider.notifier).select(_place('B'));
      final token = MapInteractionTrace.token;
      await tester.pump();
      final phases = MapInteractionTrace.events
          .where((e) => e['token'] == token)
          .map((e) => e['phase'])
          .toList();
      expect(phases, containsAll(['T1', 'T2', 'T3', 'T4']));
      expect(container.read(mapSelectedMarkerProvider)!.markerKey, 'place:B');
    },
  );

  testWidgets(
    'Pass2 Event heading identity survives pending and loaded states',
    (tester) async {
      const day = PlannerDate(year: 2026, month: 9, day: 3);
      const marker = MapMarker(
        owner: MapCoordinateOwner.event,
        recordId: 'event-one',
        displayName: 'Event',
        coordinate: _point,
        colorValue: 0xFF397642,
        eventOriginalDate: day,
        occurrenceId: 'occ-one',
      );
      final calendar = _PendingCalendar();
      await _mount(
        tester,
        [marker],
        calendar: calendar,
        contacts: _DelayedContacts(),
      );
      _map(tester).markers.single.onTap!();
      await tester.pump();
      expect(
        tester
            .widget<MapMarkerIdentityIcon>(find.byType(MapMarkerIdentityIcon))
            .marker,
        marker,
      );
      calendar.pending.complete(
        const CalendarEventOccurrence(
          id: 'occ-one',
          eventId: 'event-one',
          profileId: 'test-profile',
          title: 'Event',
          timing: CalendarEventTiming.allDay,
          originalDate: day,
          displayDate: day,
          status: CalendarEventStatus.scheduled,
          requiresReport: false,
          recurrence: CalendarRecurrenceRule(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('maps-event-preview-title')), findsOneWidget);
      expect(
        tester
            .widget<MapMarkerIdentityIcon>(find.byType(MapMarkerIdentityIcon))
            .marker,
        marker,
      );
    },
  );
}

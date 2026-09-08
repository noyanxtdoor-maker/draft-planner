// VS-15 M7.2 — Maps Search -> Saved Place -> Maps stale-result safety.
//
// Owner-approved M7 correction (Search Option A): Maps Search results are
// generated from a repository snapshot. If the Saved Place is edited or
// moved AFTER the result was produced but BEFORE the user taps the result,
// MapsScreen must re-resolve the CURRENT Saved Place row and focus its LIVE
// coordinate — never the stale search-time snapshot. If the place was
// deleted before the tap, no camera command may be issued, nothing may be
// selected or previewed, and the app must stay safely on the Maps context.
//
// These tests drive the real seam: MapsScreen._openSearch is opened through
// the maps search button, the pushed Search route returns a
// MapSearchSelection carrying the OLD/stale coordinate (exactly as a result
// row generated before the mutation would), and the resulting
// mapTransientFocusProvider state is asserted. The repositories are quiet
// in-memory fakes because every mutation happens BEFORE the maps screen is
// mounted; the full Drift reactive chain is exercised by the sibling
// vs15_m7_reactive_places_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/maps/application/current_location_service.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';
import 'package:rmplanner/features/maps/presentation/maps_search_screen.dart';

const _profileId = 'profile-1';
const _original = MapCoordinate(latitude: 14.6, longitude: 121.0);
const _moved = MapCoordinate(latitude: 14.62, longitude: 121.02);

final class _FakeLocation implements CurrentLocationService {
  const _FakeLocation();

  @override
  Future<CurrentLocationResult> locate() async => CurrentLocationResult.located(
    MapCoordinate(latitude: 14.6, longitude: 121),
  );
}

/// Quiet SavedPlace repository: one optional record, static watches.
///
/// Every read/write lands on a 1 ms timer instead of completing in a raw
/// microtask. A provider future that resolves while a route-removal frame is
/// mid-build cascades an inline refresh into the UncontrolledProviderScope
/// (setState during build); timer-delayed completion always lands at a clean
/// pump boundary.
final class _FakeSavedPlaces implements SavedPlaceRepository {
  SavedPlace? _place;
  int _nextId = 1;

  SavedPlace? get place => _place;

  Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 1));

  SavedPlace _materialize(SavedPlaceDraft draft, {String? id}) {
    final created = DateTime.utc(2026, 9, 4, 12);
    return SavedPlace(
      id: id ?? 'place-${_nextId++}',
      profileId: _profileId,
      label: draft.label,
      coordinate: draft.coordinate,
      markerMode: draft.markerMode,
      standardCategory: draft.standardCategory,
      customEmoji: draft.customEmoji,
      markerColorHex: draft.markerColorHex,
      createdAtUtc: created,
      updatedAtUtc: created,
      boundary: draft.boundary,
    );
  }

  SavedPlace? byId(String id) =>
      _place != null && _place!.id == id ? _place : null;

  @override
  Stream<List<SavedPlace>> watch(String profileId) async* {
    yield _place == null ? const <SavedPlace>[] : <SavedPlace>[_place!];
  }

  @override
  Future<List<SavedPlace>> list(String profileId) async {
    await _tick();
    return _place == null ? const <SavedPlace>[] : <SavedPlace>[_place!];
  }

  @override
  Future<SavedPlace?> readById({
    required String profileId,
    required String id,
  }) async {
    await _tick();
    return byId(id);
  }

  @override
  Future<SavedPlace> create({
    required String profileId,
    required SavedPlaceDraft draft,
  }) async {
    await _tick();
    _place = _materialize(draft.normalized());
    return _place!;
  }

  @override
  Future<SavedPlace> update({
    required String profileId,
    required String id,
    required SavedPlaceDraft draft,
  }) async {
    await _tick();
    final current = byId(id);
    if (current == null) {
      throw StateError('no place $id to update');
    }
    final normalized = draft.normalized();
    _place = SavedPlace(
      id: current.id,
      profileId: current.profileId,
      label: normalized.label,
      coordinate: normalized.coordinate,
      markerMode: normalized.markerMode,
      standardCategory: normalized.standardCategory,
      customEmoji: normalized.customEmoji,
      markerColorHex: normalized.markerColorHex,
      createdAtUtc: current.createdAtUtc,
      updatedAtUtc: DateTime.utc(2026, 9, 4, 13),
      boundary: normalized.boundary,
    );
    return _place!;
  }

  @override
  Future<void> delete({required String profileId, required String id}) async {
    await _tick();
    if (_place?.id == id) _place = null;
  }
}

/// Quiet coordinate repository bound to the same fake place store.
final class _FakeCoordinates implements MapCoordinateRepository {
  _FakeCoordinates(this.places);

  final _FakeSavedPlaces places;

  @override
  Stream<int> watchChanges(String profileId) => const Stream<int>.empty();

  @override
  Future<List<MapMarker>> readMarkers(String profileId) async {
    await places._tick();
    final place = places.place;
    if (place == null) return const <MapMarker>[];
    return <MapMarker>[
      MapMarker(
        owner: MapCoordinateOwner.savedPlace,
        recordId: place.id,
        coordinate: place.coordinate,
        displayName: place.label,
        colorValue: place.markerColorArgb,
        placeMarkerMode: place.markerMode,
        placeStandardCategory: place.standardCategory,
        placeEmoji: place.customEmoji,
      ),
    ];
  }

  @override
  Future<MapCoordinate?> readCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async {
    await places._tick();
    return places.byId(recordId)?.coordinate;
  }

  @override
  Future<void> setCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
    required MapCoordinate coordinate,
  }) async {
    await places._tick();
    final place = places.byId(recordId);
    if (place == null) return;
    await places.update(
      profileId: profileId,
      id: place.id,
      draft: SavedPlaceDraft(
        label: place.label,
        coordinate: coordinate,
        markerMode: place.markerMode,
        standardCategory: place.standardCategory,
        customEmoji: place.customEmoji,
        markerColorHex: place.markerColorHex,
      ),
    );
  }

  @override
  Future<void> clearCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async {}
}

/// Zero-duration page: the pop transition completes in a single frame so the
/// focus re-resolution that runs on result delivery can never land inside an
/// animated overlay build phase.
final class _InstantPage<T> extends Page<T> {
  const _InstantPage({required this.child, super.key});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => PageRouteBuilder<T>(
    settings: this,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );
}

/// Stand-in for the accepted Maps Search results page. It renders the result
/// row exactly as Search would have produced it at result-generation time —
/// including the stale [selection] — and pops that selection when tapped.
final class _FakeSearchResultsPage extends StatelessWidget {
  const _FakeSearchResultsPage({required this.selection, required this.title});

  final MapSearchSelection selection;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maps Search')),
      body: ListView(
        children: <Widget>[
          ListTile(
            key: const Key('fake-search-result-row'),
            leading: const Icon(Icons.place),
            title: Text(title),
            subtitle: const Text('Saved Place'),
            onTap: () => context.pop<MapSearchSelection>(selection),
          ),
        ],
      ),
    );
  }
}

Future<ProviderContainer> _pumpMaps({
  required WidgetTester tester,
  required _FakeSavedPlaces savedPlaces,
  required _FakeCoordinates coordinates,
  required MapSearchSelection selection,
  required String rowTitle,
  required List<MapMarker> probe,
}) async {
  tester.view.physicalSize = const Size(431, 912);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: <Override>[
      mapProfileIdProvider.overrideWithValue(_profileId),
      savedPlaceProfileIdProvider.overrideWithValue(_profileId),
      savedPlaceRepositoryProvider.overrideWithValue(savedPlaces),
      mapCoordinateRepositoryProvider.overrideWithValue(coordinates),
      currentLocationServiceProvider.overrideWithValue(const _FakeLocation()),
    ],
  );
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => MapsScreen(
          mapBuilder: (context, markers) {
            probe
              ..clear()
              ..addAll(markers);
            return SizedBox(
              key: const Key('maps-test-surface'),
              child: Text('markers=${markers.length}'),
            );
          },
        ),
      ),
      GoRoute(
        path: RoutePaths.mapSearch,
        pageBuilder: (context, state) => _InstantPage<MapSearchSelection>(
          child: _FakeSearchResultsPage(selection: selection, title: rowTitle),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Fires every Riverpod zero-duration refresh timer: pumpAndSettle stops as
/// soon as no frame is scheduled, which can leave a scheduled refresh timer
/// pending. Each fired refresh can schedule one more, so drain in a loop.
Future<void> _drainRiverpodTimers(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
  }
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> _openSearchAndTapResult(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('maps-search-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('fake-search-result-row')));
  // Zero-duration pop: the route is removed in a single frame, then settle.
  await tester.pump();
  await tester.pumpAndSettle();
  await _drainRiverpodTimers(tester);
}

/// Unmounts the tree and disposes the container INSIDE the test body.
/// MapsScreen.dispose defers its ephemeral-state clear to a microtask whose
/// provider-refresh cascade would otherwise land after the tree teardown but
/// before the container's own dispose, leaving a pending timer at the
/// invariant check.
Future<void> _unmountAndDispose(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _drainRiverpodTimers(tester);
  container.dispose();
}

SavedPlaceDraft _draftAt(MapCoordinate point) =>
    SavedPlaceDraft(label: 'Test Place', coordinate: point);

/// Runs [future] to completion in the widget-test zone by advancing the fake
/// clock past the fakes' 1 ms completion tick.
Future<T> _settle<T>(WidgetTester tester, Future<T> future) async {
  await tester.pump(const Duration(milliseconds: 5));
  return future;
}

void main() {
  testWidgets('moved before tap: Search focuses the CURRENT live coordinate, '
      'never the stale snapshot', (tester) async {
    final savedPlaces = _FakeSavedPlaces();
    final coordinates = _FakeCoordinates(savedPlaces);
    final created = await _settle(
      tester,
      savedPlaces.create(profileId: _profileId, draft: _draftAt(_original)),
    );
    // The place moves AFTER any Search result was generated.
    await _settle(
      tester,
      coordinates.setCoordinate(
        profileId: _profileId,
        owner: MapCoordinateOwner.savedPlace,
        recordId: created.id,
        coordinate: _moved,
      ),
    );
    final probe = <MapMarker>[];
    final container = await _pumpMaps(
      tester: tester,
      savedPlaces: savedPlaces,
      coordinates: coordinates,
      // The stale result row still carries the ORIGINAL coordinate.
      selection: MapSearchSelection.savedPlace(
        placeId: created.id,
        coordinate: _original,
      ),
      rowTitle: created.label,
      probe: probe,
    );

    await _openSearchAndTapResult(tester);

    final focus = container.read(mapTransientFocusProvider);
    final request = focus.pending;
    expect(request, isNotNull, reason: 'a live place must still be focused');
    expect(request!.recordId, created.id);
    expect(request.coordinate, _moved);
    expect(request.coordinate, isNot(_original));
    expect(
      request.markerKey,
      MapCoordinate.ownerKey(MapCoordinateOwner.savedPlace.kind, created.id),
    );
    expect(focus.visibilityLease?.markerKey, request.markerKey);
    // The live marker is on the canvas; the Maps context was not recreated.
    expect(probe, hasLength(1));
    expect(find.byKey(const Key('maps-test-surface')), findsOneWidget);
    expect(find.byKey(const Key('maps-search-button')), findsOneWidget);
    await _unmountAndDispose(tester, container);
  });

  testWidgets('deleted before tap: zero camera command, zero selection, zero '
      'preview, safe stay on Maps', (tester) async {
    final savedPlaces = _FakeSavedPlaces();
    final coordinates = _FakeCoordinates(savedPlaces);
    final created = await _settle(
      tester,
      savedPlaces.create(profileId: _profileId, draft: _draftAt(_original)),
    );
    // The place is deleted AFTER any Search result was generated.
    await _settle(
      tester,
      savedPlaces.delete(profileId: _profileId, id: created.id),
    );
    final probe = <MapMarker>[];
    final container = await _pumpMaps(
      tester: tester,
      savedPlaces: savedPlaces,
      coordinates: coordinates,
      selection: MapSearchSelection.savedPlace(
        placeId: created.id,
        coordinate: _original,
      ),
      rowTitle: created.label,
      probe: probe,
    );

    await _openSearchAndTapResult(tester);

    final focus = container.read(mapTransientFocusProvider);
    expect(
      focus.pending,
      isNull,
      reason: 'no camera animation may be issued for a deleted place',
    );
    expect(focus.visibilityLease, isNull);
    expect(container.read(mapSelectedMarkerProvider), isNull);
    expect(await _settle(tester, savedPlaces.list(_profileId)), isEmpty);
    // Still safely on the Maps context: no crash, no route churn.
    expect(find.byKey(const Key('maps-test-surface')), findsOneWidget);
    expect(find.byKey(const Key('maps-search-button')), findsOneWidget);
    expect(probe, isEmpty);
    await _unmountAndDispose(tester, container);
  });

  testWidgets('unchanged place: Search still focuses normally with the '
      'recorded coordinate', (tester) async {
    final savedPlaces = _FakeSavedPlaces();
    final coordinates = _FakeCoordinates(savedPlaces);
    final created = await _settle(
      tester,
      savedPlaces.create(profileId: _profileId, draft: _draftAt(_original)),
    );
    final probe = <MapMarker>[];
    final container = await _pumpMaps(
      tester: tester,
      savedPlaces: savedPlaces,
      coordinates: coordinates,
      selection: MapSearchSelection.savedPlace(
        placeId: created.id,
        coordinate: _original,
      ),
      rowTitle: created.label,
      probe: probe,
    );

    await _openSearchAndTapResult(tester);

    final request = container.read(mapTransientFocusProvider).pending;
    expect(request, isNotNull);
    expect(request!.coordinate, _original);
    expect(
      request.markerKey,
      MapCoordinate.ownerKey(MapCoordinateOwner.savedPlace.kind, created.id),
    );
    expect(probe, hasLength(1));
    await _unmountAndDispose(tester, container);
  });
}

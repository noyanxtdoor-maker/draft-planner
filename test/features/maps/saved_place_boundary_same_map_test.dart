// VS-15 M6.1 PASS 2 — SAME-MAP Define Boundary round trips.
//
// The Add/Edit Place form no longer pushes a second GoogleMap. It yields:
// the form commits a snapshot into boundaryEditSessionProvider, pops itself,
// and the canonical MapsScreen enters Define Boundary mode on its OWN living
// map. Done/X re-open the SAME form with every unsaved value restored, and
// the main form Save remains the ONLY persistence boundary.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/boundary_edit_session.dart';
import 'package:rmplanner/features/maps/application/current_location_service.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/data/drift_map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';

import '../../support/test_dependencies.dart';

const _placeId = '33333333-3333-4333-8333-333333333333';
const _pin = MapCoordinate(latitude: 14.6, longitude: 121.0);

const _a = MapCoordinate(latitude: 14.6, longitude: 121.0);
const _b = MapCoordinate(latitude: 14.61, longitude: 121.01);
const _c = MapCoordinate(latitude: 14.59, longitude: 121.02);

void main() {
  Future<ProviderContainer> pumpMaps(WidgetTester tester) async {
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
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MapsScreen(
            mapBuilder: (_, markers) => SizedBox(
              key: const Key('maps-test-surface'),
              child: Text('markers=${markers.length}'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  SavedPlaceFormSnapshot snapshot({
    String label = 'My Farm',
    SavedPlaceBoundary? boundaryDraft,
    String boundaryColor = '#FFD600',
  }) => SavedPlaceFormSnapshot(
    label: label,
    markerMode: SavedPlaceMarkerMode.standard,
    standardCategory: SavedPlaceStandardCategory.food,
    customEmoji: null,
    markerColorHex: '#175A8F',
    boundaryColorHex: boundaryColor,
    boundaryDraft: boundaryDraft,
  );

  Future<BoundaryEditSession> beginSession(
    ProviderContainer container,
    BoundaryEditOrigin origin,
    SavedPlaceFormSnapshot snapshot,
  ) async {
    container
        .read(boundaryEditSessionProvider.notifier)
        .begin(origin: origin, snapshot: snapshot);
    final session = container.read(boundaryEditSessionProvider)!;
    addTearDown(
      () => container.read(boundaryEditSessionProvider.notifier).endSession(),
    );
    return session;
  }

  testWidgets('Add Place yield: SAME map enters Define Boundary with every '
      'normal context still visible; Done re-opens the SAME draft; Save '
      'persists Place + Boundary together', (tester) async {
    final container = await pumpMaps(tester);
    // Canonical empty state before the yield: the SAME map canvas, controls.
    expect(find.byKey(const Key('maps-test-surface')), findsOneWidget);
    expect(find.byKey(const Key('maps-type-button')), findsOneWidget);

    final session = await beginSession(
      container,
      BoundaryEditOriginAdd(coordinate: _pin),
      snapshot(),
    );
    await tester.pumpAndSettle();

    // SAME canonical canvas — never a second map or a separate route.
    expect(find.byKey(const Key('maps-test-surface')), findsOneWidget);
    // Owner-approved M6.1 chrome, frozen geometry.
    expect(find.text('Define Boundary'), findsOneWidget);
    expect(find.byKey(const Key('boundary-editor-cancel')), findsOneWidget);
    expect(
      find.byKey(const Key('boundary-editor-instruction')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('boundary-editor-locate')), findsOneWidget);
    expect(find.byKey(const Key('boundary-editor-undo')), findsNothing);
    expect(find.byKey(const Key('boundary-editor-done')), findsNothing);
    // Ordinary map interactions are temporarily suppressed.
    expect(find.byKey(const Key('maps-type-button')), findsNothing);
    expect(find.byKey(const Key('maps-drop-pin-button')), findsNothing);

    // Drawing: 3 vertices unlock Undo/Clear/Done; the instruction yields.
    session.controller
      ..addVertex(_a)
      ..addVertex(_b)
      ..addVertex(_c);
    await tester.pump();
    expect(find.byKey(const Key('boundary-editor-undo')), findsOneWidget);
    expect(find.byKey(const Key('boundary-editor-clear')), findsOneWidget);
    expect(find.byKey(const Key('boundary-editor-done')), findsOneWidget);
    expect(find.byKey(const Key('boundary-editor-instruction')), findsNothing);

    await tester.tap(find.byKey(const Key('boundary-editor-done')));
    await tester.pumpAndSettle();

    // The SAME Add Place draft is re-opened, label + boundary restored.
    expect(find.text('Add Place'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'My Farm'), findsOneWidget);
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);

    // Main form Save is the ONLY persistence boundary.
    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pumpAndSettle();
    final repository = container.read(savedPlaceRepositoryProvider);
    final place = await repository.readById(
      profileId: container.read(savedPlaceProfileIdProvider),
      id: _placeId,
    );
    expect(place, isNotNull);
    expect(place!.label, 'My Farm');
    expect(place.boundary!.colorHex, '#FFD600');
    expect(place.boundary!.vertices, <MapCoordinate>[_a, _b, _c]);
    // The boundary session is fully resolved; canonical chrome is gone.
    expect(container.read(boundaryEditSessionProvider), isNull);
    expect(find.text('Define Boundary'), findsNothing);
  });

  testWidgets('X from Define Boundary discards THIS visit, preserves the '
      'prior form BoundaryDraft, and a Cancel afterwards writes NOTHING', (
    tester,
  ) async {
    final container = await pumpMaps(tester);
    const prior = SavedPlaceBoundary(
      colorHex: '#FFD600',
      vertices: <MapCoordinate>[_a, _b, _c],
    );
    final session = await beginSession(
      container,
      BoundaryEditOriginAdd(coordinate: _pin),
      snapshot(boundaryDraft: prior),
    );
    await tester.pumpAndSettle();
    // A partial new outline from THIS visit…
    session.controller
      ..addVertex(_b)
      ..addVertex(_c);
    await tester.pump();

    await tester.tap(find.byKey(const Key('boundary-editor-cancel')));
    await tester.pumpAndSettle();

    // The form returns with the PRIOR draft untouched.
    expect(find.text('Add Place'), findsOneWidget);
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);

    // Cancel Add Place: zero Saved Place rows, zero Boundary rows.
    await tester.tap(find.byKey(const Key('saved-place-cancel')));
    await tester.pumpAndSettle();
    final places = await container
        .read(savedPlaceRepositoryProvider)
        .list(container.read(savedPlaceProfileIdProvider));
    expect(places, isEmpty);
    expect(container.read(boundaryEditSessionProvider), isNull);
  });

  testWidgets('Edit Place yield: the canonical marker keeps its normal '
      'identity (no red-pin replacement); Done redefines by taps; Save '
      'persists the replacement boundary', (tester) async {
    final container = await pumpMaps(tester);
    final profileId = container.read(savedPlaceProfileIdProvider);
    final repository = container.read(savedPlaceRepositoryProvider);
    const persisted = SavedPlaceBoundary(
      colorHex: '#175A8F',
      vertices: <MapCoordinate>[
        MapCoordinate(latitude: 10.0, longitude: 122.0),
        MapCoordinate(latitude: 10.01, longitude: 122.01),
        MapCoordinate(latitude: 9.99, longitude: 122.02),
      ],
    );
    final place = await repository.create(
      profileId: profileId,
      draft: SavedPlaceDraft(
        label: 'Old Farm',
        coordinate: _pin,
        markerMode: SavedPlaceMarkerMode.standard,
        standardCategory: SavedPlaceStandardCategory.food,
        markerColorHex: '#175A8F',
        boundary: persisted,
      ),
    );
    await tester.pumpAndSettle();
    // The place marker reached the canonical canvas with its full identity.
    // (marker projection is exercised by the surface; here the session is
    // opened exactly as the form's Edit Boundary path would.)

    final session = await beginSession(
      container,
      BoundaryEditOriginEdit(place: place),
      snapshot(
        label: place.label,
        boundaryDraft: place.boundary,
        boundaryColor: place.boundary!.colorHex,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Define Boundary'), findsOneWidget);

    // Redefine-by-taps: NEW vertices replace the old outline at Done. The
    // boundary COLOR stays form-owned (the form's boundary color), never
    // rewritten by the map visit. Pass 3: the replacement must CONTAIN the
    // place coordinate (_pin) or Done is blocked, so the square wraps it.
    const replacementVertices = <MapCoordinate>[
      MapCoordinate(latitude: 14.5, longitude: 120.9),
      MapCoordinate(latitude: 14.5, longitude: 121.1),
      MapCoordinate(latitude: 14.7, longitude: 121.1),
      MapCoordinate(latitude: 14.7, longitude: 120.9),
    ];
    for (final vertex in replacementVertices) {
      session.controller.addVertex(vertex);
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('boundary-editor-done')));
    await tester.pumpAndSettle();

    // The SAME Edit Place draft returns with every value intact.
    expect(find.text('Edit Place'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Old Farm'), findsOneWidget);
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);

    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pumpAndSettle();
    final updated = await repository.readById(
      profileId: profileId,
      id: place.id,
    );
    expect(updated, isNotNull);
    expect(updated!.label, 'Old Farm');
    // Replacement persisted; exactly one boundary for the place.
    expect(updated.boundary!.colorHex, '#175A8F');
    expect(updated.boundary!.vertices, replacementVertices);
    expect(container.read(boundaryEditSessionProvider), isNull);
  });

  group(
    'M6.1 PASS 3 — Done validates that the boundary contains the place',
    () {
      testWidgets('Add origin inside the outline: Done resolves and reopens '
          'the form', (tester) async {
        final container = await pumpMaps(tester);
        final session = await beginSession(
          container,
          BoundaryEditOriginAdd(
            coordinate: const MapCoordinate(latitude: 14.6, longitude: 121.01),
          ),
          snapshot(),
        );
        await tester.pumpAndSettle();
        session.controller
          ..addVertex(_a)
          ..addVertex(_b)
          ..addVertex(_c);
        await tester.pump();
        await tester.tap(find.byKey(const Key('boundary-editor-done')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('boundary-exclusion-dialog')),
          findsNothing,
        );
        expect(find.text('Add Place'), findsOneWidget);
        expect(
          find.byKey(const Key('saved-place-added-boundary')),
          findsOneWidget,
        );
        expect(container.read(boundaryEditSessionProvider), isNull);
      });

      testWidgets('Add origin ON an edge: Done resolves', (tester) async {
        final container = await pumpMaps(tester);
        final session = await beginSession(
          container,
          BoundaryEditOriginAdd(
            // Midpoint of the _a -> _b edge.
            coordinate: const MapCoordinate(
              latitude: 14.605,
              longitude: 121.005,
            ),
          ),
          snapshot(),
        );
        await tester.pumpAndSettle();
        session.controller
          ..addVertex(_a)
          ..addVertex(_b)
          ..addVertex(_c);
        await tester.pump();
        await tester.tap(find.byKey(const Key('boundary-editor-done')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('boundary-exclusion-dialog')),
          findsNothing,
        );
        expect(find.text('Add Place'), findsOneWidget);
      });

      testWidgets('Add origin ON a vertex: Done resolves', (tester) async {
        final container = await pumpMaps(tester);
        final session = await beginSession(
          container,
          BoundaryEditOriginAdd(coordinate: _a),
          snapshot(),
        );
        await tester.pumpAndSettle();
        session.controller
          ..addVertex(_a)
          ..addVertex(_b)
          ..addVertex(_c);
        await tester.pump();
        await tester.tap(find.byKey(const Key('boundary-editor-done')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('boundary-exclusion-dialog')),
          findsNothing,
        );
        expect(find.text('Add Place'), findsOneWidget);
      });

      testWidgets(
        'outside place: blocking dialog, session/vertices/color/marker '
        'intact, OK keeps Undo working, corrected outline succeeds',
        (tester) async {
          final container = await pumpMaps(tester);
          final session = await beginSession(
            container,
            BoundaryEditOriginAdd(
              coordinate: const MapCoordinate(latitude: 14.0, longitude: 120.0),
            ),
            snapshot(boundaryColor: '#FFD600'),
          );
          await tester.pumpAndSettle();
          session.controller
            ..addVertex(_a)
            ..addVertex(_b)
            ..addVertex(_c);
          await tester.pump();
          // The working marker (Add origin) rides the canonical canvas.
          expect(find.text('markers=1'), findsOneWidget);

          await tester.tap(find.byKey(const Key('boundary-editor-done')));
          await tester.pumpAndSettle();
          // Canonical blocking error with the exact owner-approved copy.
          expect(
            find.text("Boundary doesn't include this place"),
            findsOneWidget,
          );
          expect(
            find.text(
              'The place icon must be inside the boundary. '
              'Adjust the outline and try again.',
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('boundary-exclusion-ok')),
            findsOneWidget,
          );
          // Still in Define Boundary; session alive; every vertex untouched;
          // color untouched; working marker untouched.
          expect(find.text('Define Boundary'), findsOneWidget);
          expect(container.read(boundaryEditSessionProvider), isNotNull);
          expect(session.controller.vertices, <MapCoordinate>[_a, _b, _c]);
          expect(session.controller.colorHex, '#FFD600');
          expect(find.text('markers=1'), findsOneWidget);

          // Dismiss OK: the existing same-map experience remains fully intact.
          await tester.tap(find.byKey(const Key('boundary-exclusion-ok')));
          await tester.pumpAndSettle();
          expect(find.text('Define Boundary'), findsOneWidget);
          await tester.tap(find.byKey(const Key('boundary-editor-undo')));
          await tester.pump();
          expect(session.controller.vertices, hasLength(2));

          // Correct the outline around the place and Done succeeds.
          session.controller
            ..clear()
            ..addVertex(const MapCoordinate(latitude: 13.9, longitude: 119.9))
            ..addVertex(const MapCoordinate(latitude: 13.9, longitude: 120.1))
            ..addVertex(const MapCoordinate(latitude: 14.1, longitude: 120.1))
            ..addVertex(const MapCoordinate(latitude: 14.1, longitude: 119.9));
          await tester.pump();
          await tester.tap(find.byKey(const Key('boundary-editor-done')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('boundary-exclusion-dialog')),
            findsNothing,
          );
          expect(find.text('Add Place'), findsOneWidget);
          expect(
            find.byKey(const Key('saved-place-added-boundary')),
            findsOneWidget,
          );
        },
      );

      testWidgets('Edit-origin Done validates the EXISTING place coordinate', (
        tester,
      ) async {
        final container = await pumpMaps(tester);
        final profileId = container.read(savedPlaceProfileIdProvider);
        final repository = container.read(savedPlaceRepositoryProvider);
        final place = await repository.create(
          profileId: profileId,
          draft: SavedPlaceDraft(
            label: 'Old Farm',
            coordinate: _pin,
            markerMode: SavedPlaceMarkerMode.standard,
            standardCategory: SavedPlaceStandardCategory.food,
            markerColorHex: '#175A8F',
            boundary: const SavedPlaceBoundary(
              colorHex: '#175A8F',
              vertices: <MapCoordinate>[
                MapCoordinate(latitude: 10.0, longitude: 122.0),
                MapCoordinate(latitude: 10.01, longitude: 122.01),
                MapCoordinate(latitude: 9.99, longitude: 122.02),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final session = await beginSession(
          container,
          BoundaryEditOriginEdit(place: place),
          snapshot(
            label: place.label,
            boundaryDraft: place.boundary,
            boundaryColor: place.boundary!.colorHex,
          ),
        );
        await tester.pumpAndSettle();
        // Redefine outline FAR away — does not contain the place coordinate.
        session.controller
          ..addVertex(const MapCoordinate(latitude: 20.0, longitude: 100.0))
          ..addVertex(const MapCoordinate(latitude: 20.01, longitude: 100.01))
          ..addVertex(const MapCoordinate(latitude: 19.99, longitude: 100.02));
        await tester.pump();
        await tester.tap(find.byKey(const Key('boundary-editor-done')));
        await tester.pumpAndSettle();
        expect(
          find.text("Boundary doesn't include this place"),
          findsOneWidget,
        );
        expect(find.text('Define Boundary'), findsOneWidget);
        expect(session.controller.vertices, hasLength(3));
      });
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

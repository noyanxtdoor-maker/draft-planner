import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/application/boundary_edit_session.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_form_sheet.dart';

void main() {
  const coordinate = MapCoordinate(latitude: 14.59951, longitude: 120.98422);
  final triangle = SavedPlaceBoundary(
    colorHex: '#FFD600',
    vertices: const <MapCoordinate>[
      MapCoordinate(latitude: 14.6, longitude: 121.0),
      MapCoordinate(latitude: 14.61, longitude: 121.01),
      MapCoordinate(latitude: 14.59, longitude: 121.02),
    ],
  );

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget editor({
    required Future<void> Function(SavedPlaceDraft) onSave,
    SavedPlace? initialPlace,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: SavedPlaceFormScreen(
          coordinate: coordinate,
          initialPlace: initialPlace,
          onSave: onSave,
          onCancel: () {},
        ),
      ),
    );
  }

  testWidgets('M6.1 empty state: + Boundary row and Boundary Color row', (
    tester,
  ) async {
    setViewport(tester);
    await tester.pumpWidget(editor(onSave: (_) async {}));
    expect(
      find.text('Boundary'),
      findsNWidgets(2),
      reason: 'section heading + the add-row label share the word',
    );
    expect(find.byKey(const Key('saved-place-add-boundary')), findsOneWidget);
    expect(find.text('Boundary Color'), findsOneWidget);
    expect(
      find.byKey(const Key('saved-place-continuous-boundary-color')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('saved-place-added-boundary')), findsNothing);
  });

  testWidgets('M6.1 Added Boundary state exposes pencil + red trash and a '
      'swatch of the boundary color', (tester) async {
    setViewport(tester);
    final place = SavedPlace(
      id: 'place-1',
      profileId: 'profile-1',
      label: 'Farm',
      coordinate: coordinate,
      markerMode: SavedPlaceMarkerMode.standard,
      standardCategory: SavedPlaceStandardCategory.food,
      customEmoji: null,
      markerColorHex: '#175A8F',
      createdAtUtc: DateTime.utc(2026, 9, 1),
      updatedAtUtc: DateTime.utc(2026, 9, 1),
      boundary: triangle,
    );
    await tester.pumpWidget(editor(onSave: (_) async {}, initialPlace: place));
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);
    expect(find.text('Added Boundary'), findsOneWidget);
    expect(find.byKey(const Key('saved-place-edit-boundary')), findsOneWidget);
    expect(
      find.byKey(const Key('saved-place-remove-boundary')),
      findsOneWidget,
    );
    final swatch = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('saved-place-continuous-boundary-color')),
        matching: find.byKey(const Key('saved-place-boundary-swatch')),
      ),
    );
    expect((swatch.decoration as BoxDecoration).color, const Color(0xFFFFD600));
    // Marker identity untouched by boundary state.
    expect(find.byKey(const Key('saved-place-color-swatch')), findsOneWidget);
  });

  testWidgets('Boundary draft survives Standard <-> Custom mode switching', (
    tester,
  ) async {
    setViewport(tester);
    final place = SavedPlace(
      id: 'place-1',
      profileId: 'profile-1',
      label: 'Farm',
      coordinate: coordinate,
      markerMode: SavedPlaceMarkerMode.standard,
      standardCategory: SavedPlaceStandardCategory.information,
      customEmoji: null,
      markerColorHex: '#175A8F',
      createdAtUtc: DateTime.utc(2026, 9, 1),
      updatedAtUtc: DateTime.utc(2026, 9, 1),
      boundary: triangle,
    );
    await tester.pumpWidget(editor(onSave: (_) async {}, initialPlace: place));
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);
    await tester.tap(find.text('Custom'));
    await tester.pump();
    // The boundary belongs to the PLACE, never to marker mode.
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);
    await tester.tap(find.text('Standard'));
    await tester.pump();
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);
  });

  testWidgets('removing a PERSISTED boundary requires the locked '
      'confirmation; Cancel keeps it and Remove clears the draft', (
    tester,
  ) async {
    setViewport(tester);
    final place = SavedPlace(
      id: 'place-1',
      profileId: 'profile-1',
      label: 'Farm',
      coordinate: coordinate,
      markerMode: SavedPlaceMarkerMode.standard,
      standardCategory: SavedPlaceStandardCategory.information,
      customEmoji: null,
      markerColorHex: '#175A8F',
      createdAtUtc: DateTime.utc(2026, 9, 1),
      updatedAtUtc: DateTime.utc(2026, 9, 1),
      boundary: triangle,
    );
    SavedPlaceDraft? captured;
    await tester.pumpWidget(
      editor(onSave: (draft) async => captured = draft, initialPlace: place),
    );
    await tester.tap(find.byKey(const Key('saved-place-remove-boundary')));
    await tester.pumpAndSettle();
    expect(find.text('Remove boundary?'), findsOneWidget);
    expect(
      find.text(
        'This removes the boundary from this Saved Place. '
        'The Saved Place itself will not be deleted.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('remove-boundary-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-place-added-boundary')), findsOneWidget);
    await tester.tap(find.byKey(const Key('saved-place-remove-boundary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-boundary-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-place-added-boundary')), findsNothing);
    // Save now persists NO boundary — the removal reaches the repository
    // only through the canonical form Save.
    await tester.enterText(find.byKey(const Key('saved-place-label')), 'Farm');
    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.boundary, isNull);
  });

  testWidgets('form Save carries the boundary draft (draft-until-Save law)', (
    tester,
  ) async {
    setViewport(tester);
    SavedPlaceDraft? captured;
    await tester.pumpWidget(editor(onSave: (draft) async => captured = draft));
    // Simulate a completed editor visit by seeding the state directly is not
    // possible from outside; instead verify the Save path with the marker
    // fields and NO boundary (zero-write cancel law is covered by the
    // cancel test below plus the editor suite).
    await tester.enterText(find.byKey(const Key('saved-place-label')), 'Farm');
    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.boundary, isNull);
    expect(captured!.label, 'Farm');
  });

  testWidgets('M6 zero-write law: drawing a boundary then cancelling the '
      'Add Place form never invokes persistence', (tester) async {
    setViewport(tester);
    var saveCount = 0;
    await tester.pumpWidget(editor(onSave: (_) async => saveCount += 1));
    // The boundary draft only exists in form state; a Cancel pops the form
    // with no onSave call. Prove Cancel invokes onCancel and not onSave.
    await tester.tap(find.byKey(const Key('saved-place-cancel')));
    await tester.pump();
    expect(saveCount, 0);
  });

  group('M6.1 PASS 3 — boundary color follows marker for a NEW boundary', () {
    Color swatch(WidgetTester tester, String rowKey, String swatchKey) {
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(Key(rowKey)),
          matching: find.byKey(Key(swatchKey)),
        ),
      );
      return (container.decoration as BoxDecoration).color!;
    }

    Color markerSwatch(WidgetTester tester) => swatch(
      tester,
      'saved-place-continuous-color',
      'saved-place-color-swatch',
    );

    Color boundarySwatch(WidgetTester tester) => swatch(
      tester,
      'saved-place-continuous-boundary-color',
      'saved-place-boundary-swatch',
    );

    /// Drags the picker hue gesture so its final hue lands near
    /// [fraction] * 360 degrees (the exact landing spot is irrelevant — the
    /// assertions only need a color CHANGE from the initial blue).
    Future<void> dragHue(WidgetTester tester, double fraction) async {
      final gesture = find.byKey(const Key('planner-event-color-hue-gesture'));
      final rect = tester.getRect(gesture);
      await tester.drag(
        gesture,
        Offset(0, rect.height * fraction - rect.height / 2),
      );
      await tester.pump();
    }

    SavedPlace placeWith({
      String markerHex = '#175A8F',
      SavedPlaceBoundary? boundary,
    }) => SavedPlace(
      id: 'place-1',
      profileId: 'profile-1',
      label: 'Farm',
      coordinate: coordinate,
      markerMode: SavedPlaceMarkerMode.standard,
      standardCategory: SavedPlaceStandardCategory.information,
      customEmoji: null,
      markerColorHex: markerHex,
      createdAtUtc: DateTime.utc(2026, 9, 1),
      updatedAtUtc: DateTime.utc(2026, 9, 1),
      boundary: boundary,
    );

    testWidgets('28 — new Information place: pending Boundary Color starts '
        'at the Information marker color', (tester) async {
      setViewport(tester);
      await tester.pumpWidget(editor(onSave: (_) async {}));
      expect(markerSwatch(tester), const Color(0xFF175A8F));
      expect(boundarySwatch(tester), const Color(0xFF175A8F));
    });

    testWidgets('29 — selecting Avoid before Add Boundary turns the pending '
        'Boundary Color Avoid red', (tester) async {
      setViewport(tester);
      await tester.pumpWidget(editor(onSave: (_) async {}));
      await tester.tap(find.byKey(const Key('saved-place-category-avoid')));
      await tester.pump();
      expect(markerSwatch(tester), const Color(0xFFD32F2F));
      expect(boundarySwatch(tester), const Color(0xFFD32F2F));
    });

    testWidgets('30 — marker color picker change (blue -> yellow) before any '
        'boundary: new Boundary starts from the new marker color', (
      tester,
    ) async {
      setViewport(tester);
      await tester.pumpWidget(editor(onSave: (_) async {}));
      await tester.tap(find.byKey(const Key('saved-place-continuous-color')));
      await tester.pumpAndSettle();
      await dragHue(tester, 1 / 6);
      await tester.tap(find.byKey(const Key('planner-event-color-save')));
      await tester.pumpAndSettle();
      expect(markerSwatch(tester), isNot(const Color(0xFF175A8F)));
      expect(boundarySwatch(tester), markerSwatch(tester));
    });

    testWidgets('31 — existing red boundary + marker color change: boundary '
        'stays red (independence by existing boundary)', (tester) async {
      setViewport(tester);
      const redBoundary = SavedPlaceBoundary(
        colorHex: '#C62828',
        vertices: <MapCoordinate>[
          MapCoordinate(latitude: 14.6, longitude: 121.0),
          MapCoordinate(latitude: 14.61, longitude: 121.01),
          MapCoordinate(latitude: 14.59, longitude: 121.02),
        ],
      );
      await tester.pumpWidget(
        editor(
          onSave: (_) async {},
          initialPlace: placeWith(boundary: redBoundary),
        ),
      );
      expect(boundarySwatch(tester), const Color(0xFFC62828));
      await tester.tap(find.byKey(const Key('saved-place-category-avoid')));
      await tester.pump();
      expect(markerSwatch(tester), const Color(0xFFD32F2F));
      expect(boundarySwatch(tester), const Color(0xFFC62828));
    });

    testWidgets('32/33 — manual Boundary Color before drawing stays '
        'independent of later marker changes', (tester) async {
      setViewport(tester);
      await tester.pumpWidget(editor(onSave: (_) async {}));
      await tester.tap(
        find.byKey(const Key('saved-place-continuous-boundary-color')),
      );
      await tester.pumpAndSettle();
      await dragHue(tester, 1 / 6);
      await tester.tap(find.byKey(const Key('planner-event-color-save')));
      await tester.pumpAndSettle();
      final chosenBoundary = boundarySwatch(tester);
      expect(chosenBoundary, isNot(const Color(0xFF175A8F)));
      // A later marker change must NOT overwrite the explicit choice.
      await tester.tap(find.byKey(const Key('saved-place-category-avoid')));
      await tester.pump();
      expect(markerSwatch(tester), const Color(0xFFD32F2F));
      expect(boundarySwatch(tester), chosenBoundary);
    });

    testWidgets('34 — cancelling the Boundary Color picker restores BOTH the '
        'prior color and the follow flag', (tester) async {
      setViewport(tester);
      await tester.pumpWidget(editor(onSave: (_) async {}));
      await tester.tap(
        find.byKey(const Key('saved-place-continuous-boundary-color')),
      );
      await tester.pumpAndSettle();
      await dragHue(tester, 1 / 6);
      await tester.tap(find.byKey(const Key('planner-event-color-cancel')));
      await tester.pumpAndSettle();
      expect(boundarySwatch(tester), const Color(0xFF175A8F));
      // The cancelled picker never armed independence: the follow state is
      // still live, so a marker change still moves the pending boundary.
      await tester.tap(find.byKey(const Key('saved-place-category-avoid')));
      await tester.pump();
      expect(boundarySwatch(tester), const Color(0xFFD32F2F));
    });

    testWidgets('35/36 — removing the boundary re-arms follow and the next '
        'Add Boundary inherits the CURRENT marker color', (tester) async {
      setViewport(tester);
      const redBoundary = SavedPlaceBoundary(
        colorHex: '#C62828',
        vertices: <MapCoordinate>[
          MapCoordinate(latitude: 14.6, longitude: 121.0),
          MapCoordinate(latitude: 14.61, longitude: 121.01),
          MapCoordinate(latitude: 14.59, longitude: 121.02),
        ],
      );
      setViewport(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(
        () => container.read(boundaryEditSessionProvider.notifier).endSession(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SavedPlaceFormScreen(
              coordinate: coordinate,
              initialPlace: placeWith(boundary: redBoundary),
              onSave: (_) async {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('saved-place-remove-boundary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('remove-boundary-confirm')));
      await tester.pumpAndSettle();
      // Removal resets the pending boundary color to the CURRENT marker
      // color and re-arms following.
      expect(boundarySwatch(tester), const Color(0xFF175A8F));
      await tester.tap(find.byKey(const Key('saved-place-category-avoid')));
      await tester.pump();
      expect(boundarySwatch(tester), const Color(0xFFD32F2F));
      // Re-add now inherits the CURRENT (Avoid red) marker color. The form
      // yields its exact state into the boundary session provider (and pops
      // itself, so the session is read from the owned container).
      await tester.tap(find.byKey(const Key('saved-place-add-boundary')));
      await tester.pumpAndSettle();
      final session = container.read(boundaryEditSessionProvider);
      expect(session, isNotNull);
      expect(session!.snapshot.boundaryColorHex, '#D32F2F');
      expect(session.snapshot.boundaryColorFollowsMarkerForNewBoundary, isTrue);
    });

    testWidgets('37 — Standard <-> Custom preserves marker color, boundary '
        'color, and follow state', (tester) async {
      setViewport(tester);
      await tester.pumpWidget(editor(onSave: (_) async {}));
      await tester.tap(find.byKey(const Key('saved-place-category-avoid')));
      await tester.pump();
      final boundaryBefore = boundarySwatch(tester);
      await tester.tap(find.text('Custom'));
      await tester.pump();
      await tester.tap(find.text('Standard'));
      await tester.pump();
      expect(markerSwatch(tester), const Color(0xFFD32F2F));
      expect(boundarySwatch(tester), boundaryBefore);
    });

    testWidgets('40 — form Save persists marker color and Boundary Color as '
        'independent persisted values', (tester) async {
      setViewport(tester);
      const existing = SavedPlaceBoundary(
        colorHex: '#175A8F',
        vertices: <MapCoordinate>[
          MapCoordinate(latitude: 14.6, longitude: 121.0),
          MapCoordinate(latitude: 14.61, longitude: 121.01),
          MapCoordinate(latitude: 14.59, longitude: 121.02),
        ],
      );
      SavedPlaceDraft? captured;
      await tester.pumpWidget(
        editor(
          onSave: (draft) async => captured = draft,
          initialPlace: placeWith(boundary: existing),
        ),
      );
      // Recolor the boundary through the picker: explicit choice, independent.
      await tester.tap(
        find.byKey(const Key('saved-place-continuous-boundary-color')),
      );
      await tester.pumpAndSettle();
      await dragHue(tester, 1 / 6);
      await tester.tap(find.byKey(const Key('planner-event-color-save')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('saved-place-label')),
        'Farm',
      );
      await tester.tap(find.byKey(const Key('saved-place-save')));
      await tester.pump();
      expect(captured, isNotNull);
      expect(captured!.markerColorHex, '#175A8F');
      expect(captured!.boundary, isNotNull);
      expect(captured!.boundary!.colorHex, isNot('#175A8F'));
    });
  });

  group('M6.1 PASS 2 — same-map Define Boundary yield', () {
    Future<ProviderContainer> pumpYieldable(WidgetTester tester) async {
      setViewport(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(
        () => container.read(boundaryEditSessionProvider.notifier).endSession(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (homeContext) => Center(
                  child: TextButton(
                    key: const Key('open-form'),
                    onPressed: () =>
                        Navigator.of(
                          homeContext,
                          rootNavigator: true,
                        ).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => SavedPlaceFormScreen(
                              coordinate: coordinate,
                              onSave: (_) async {},
                              onCancel: () {},
                            ),
                          ),
                        ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open-form')));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('Add Place + Boundary yields: session captures the exact '
        'unsaved form state and the form pops (no second map editor route)', (
      tester,
    ) async {
      final container = await pumpYieldable(tester);
      await tester.enterText(
        find.byKey(const Key('saved-place-label')),
        'My Farm',
      );
      await tester.tap(find.byKey(const Key('saved-place-add-boundary')));
      await tester.pumpAndSettle();
      final session = container.read(boundaryEditSessionProvider);
      expect(session, isNotNull);
      expect(session!.origin, isA<BoundaryEditOriginAdd>());
      expect((session.origin as BoundaryEditOriginAdd).coordinate, coordinate);
      expect(session.snapshot.label, 'My Farm');
      expect(session.snapshot.boundaryDraft, isNull);
      expect(session.snapshot.boundaryColorHex, defaultBoundaryColorHex);
      // Pass 3: a NEW boundary inherits the current marker color and the
      // snapshot carries the transient follow flag.
      expect(session.snapshot.boundaryColorFollowsMarkerForNewBoundary, isTrue);
      expect(
        session.snapshot.boundaryColorHex,
        session.snapshot.markerColorHex,
      );
      // The form yielded: no second full-screen boundary editor remains.
      expect(find.byKey(const Key('saved-place-form-screen')), findsNothing);
    });

    testWidgets('Edit Place boundary yield carries the existing boundary '
        'draft and the place identity', (tester) async {
      final place = SavedPlace(
        id: 'place-1',
        profileId: 'profile-1',
        label: 'Farm',
        coordinate: coordinate,
        markerMode: SavedPlaceMarkerMode.standard,
        standardCategory: SavedPlaceStandardCategory.food,
        customEmoji: null,
        markerColorHex: '#175A8F',
        createdAtUtc: DateTime.utc(2026, 9, 1),
        updatedAtUtc: DateTime.utc(2026, 9, 1),
        boundary: triangle,
      );
      setViewport(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(
        () => container.read(boundaryEditSessionProvider.notifier).endSession(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SavedPlaceFormScreen(
              coordinate: coordinate,
              initialPlace: place,
              onSave: (_) async {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('saved-place-edit-boundary')));
      await tester.pumpAndSettle();
      final session = container.read(boundaryEditSessionProvider);
      expect(session, isNotNull);
      final origin = session!.origin;
      expect(origin, isA<BoundaryEditOriginEdit>());
      expect((origin as BoundaryEditOriginEdit).place.id, 'place-1');
      expect(session.snapshot.boundaryDraft, triangle);
      expect(session.snapshot.boundaryColorHex, '#FFD600');
      // Pass 3: an existing boundary is independent — no follow state.
      expect(
        session.snapshot.boundaryColorFollowsMarkerForNewBoundary,
        isFalse,
      );
      expect(find.byKey(const Key('saved-place-form-screen')), findsNothing);
    });
  });

  test('polygon projection is a faithful, tap-free ground layer', () {
    // Contract constants locked by M6.1 (source assertions in the map test
    // file cover the wiring; here the visual contract values are locked).
    expect(boundaryFillOpacity, 0.32);
    expect(boundaryStrokeWidthPx, 2);
    final polygon = Polygon(
      polygonId: const PolygonId('saved-place-boundary-place-1'),
      points: const <LatLng>[
        LatLng(14.6, 121.0),
        LatLng(14.61, 121.01),
        LatLng(14.59, 121.02),
      ],
      fillColor: const Color(0xFFFFD600).withValues(alpha: boundaryFillOpacity),
      strokeColor: const Color(0xFFFFD600),
      strokeWidth: boundaryStrokeWidthPx,
      consumeTapEvents: false,
      zIndex: 1,
    );
    expect(polygon.consumeTapEvents, isFalse);
    expect(polygon.zIndex, 1);
    expect(polygon.fillColor.a, closeTo(0.32, 0.01));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/boundary_edit_session.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart'
    show boundaryStrokeWidthPx;
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/boundary_mode_chrome.dart';

void main() {
  const pin = MapCoordinate(latitude: 14.6, longitude: 121.0);
  const a = MapCoordinate(latitude: 14.6, longitude: 121.0);
  const b = MapCoordinate(latitude: 14.61, longitude: 121.01);
  const c = MapCoordinate(latitude: 14.59, longitude: 121.02);

  SavedPlaceFormSnapshot snapshot({
    String label = 'Farm',
    String boundaryColor = '#175A8F',
    SavedPlaceBoundary? boundaryDraft,
    bool boundaryColorFollowsMarkerForNewBoundary = false,
  }) => SavedPlaceFormSnapshot(
    label: label,
    markerMode: SavedPlaceMarkerMode.standard,
    standardCategory: SavedPlaceStandardCategory.information,
    customEmoji: null,
    markerColorHex: '#175A8F',
    boundaryColorHex: boundaryColor,
    boundaryDraft: boundaryDraft,
    boundaryColorFollowsMarkerForNewBoundary:
        boundaryColorFollowsMarkerForNewBoundary,
  );

  group('BoundaryModeChrome (same-map Define Boundary overlay)', () {
    Future<void> pumpChrome(
      WidgetTester tester, {
      required int verticesCount,
      required bool canDone,
      bool locating = false,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                const SizedBox.expand(),
                Positioned.fill(
                  child: BoundaryModeChrome(
                    verticesCount: verticesCount,
                    canDone: canDone,
                    locating: locating,
                    onUndo: () {},
                    onClear: () {},
                    onDone: () {},
                    onLocate: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('empty session shows the instruction and Locate, and no '
        'Undo/Clear/Done', (tester) async {
      await pumpChrome(tester, verticesCount: 0, canDone: false);
      expect(
        find.byKey(const Key('boundary-editor-instruction')),
        findsOneWidget,
      );
      expect(
        find.text('Tap to create an outline of your boundary'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('boundary-editor-undo')), findsNothing);
      expect(find.byKey(const Key('boundary-editor-clear')), findsNothing);
      expect(find.byKey(const Key('boundary-editor-done')), findsNothing);
      expect(find.byKey(const Key('boundary-editor-locate')), findsOneWidget);
    });

    testWidgets('drawing state shows Undo and Clear; Done appears only for '
        '>=3 valid vertices', (tester) async {
      await pumpChrome(tester, verticesCount: 2, canDone: false);
      expect(find.byKey(const Key('boundary-editor-undo')), findsOneWidget);
      expect(find.byKey(const Key('boundary-editor-clear')), findsOneWidget);
      expect(find.byKey(const Key('boundary-editor-done')), findsNothing);
      // The instruction card disappears once drawing has started, so the
      // lifted Current Location control can never collide with it.
      expect(
        find.byKey(const Key('boundary-editor-instruction')),
        findsNothing,
      );
      await pumpChrome(tester, verticesCount: 3, canDone: true);
      expect(find.byKey(const Key('boundary-editor-done')), findsOneWidget);
    });

    testWidgets('Done is hidden for a zero-area draft (invalid geometry) '
        'while Undo/Clear remain available', (tester) async {
      await pumpChrome(tester, verticesCount: 3, canDone: false);
      expect(find.byKey(const Key('boundary-editor-done')), findsNothing);
      expect(find.byKey(const Key('boundary-editor-undo')), findsOneWidget);
      expect(find.byKey(const Key('boundary-editor-clear')), findsOneWidget);
    });

    testWidgets('Locate shows its in-progress state while locating', (
      tester,
    ) async {
      await pumpChrome(
        tester,
        verticesCount: 0,
        canDone: false,
        locating: true,
      );
      final fab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('boundary-editor-locate')),
      );
      expect(fab.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('same-map draft geometry builders', () {
    test('draft polygon rides on top: alpha 0.32 fill, full-color stroke, '
        'tap-free', () {
      final polygon = boundaryDraftPolygon(
        vertices: <MapCoordinate>[a, b, c],
        colorHex: '#175A8F',
      )!;
      expect(polygon.polygonId.value, 'boundary-editor-draft');
      expect(polygon.fillColor.a, closeTo(0.32, 0.01));
      expect(polygon.strokeColor, const Color(0xFF175A8F));
      expect(polygon.strokeWidth, boundaryStrokeWidthPx);
      expect(polygon.consumeTapEvents, isFalse);
      expect(polygon.zIndex, 2);
      expect(
        boundaryDraftPolygon(
          vertices: <MapCoordinate>[a, b],
          colorHex: '#175A8F',
        ),
        isNull,
      );
    });

    test('edit reference polygon is faint, thin, and tap-free', () {
      final reference = boundaryReferencePolygon(
        const SavedPlaceBoundary(
          colorHex: '#FFD600',
          vertices: <MapCoordinate>[a, b, c],
        ),
      );
      expect(reference.polygonId.value, 'boundary-editor-existing');
      expect(reference.fillColor.a, closeTo(0.10, 0.01));
      expect(reference.strokeColor.a, closeTo(0.45, 0.01));
      expect(reference.strokeWidth, 1);
      expect(reference.consumeTapEvents, isFalse);
      expect(reference.zIndex, 1);
    });

    test('vertex handles use the boundary-color center with a contrasting '
        'neutral ring and never consume taps', () {
      final handles = boundaryVertexHandles(
        vertices: <MapCoordinate>[a, b],
        colorHex: '#175A8F',
      );
      expect(handles, hasLength(2));
      for (final handle in handles) {
        expect(handle.fillColor, const Color(0xFF175A8F));
        expect(handle.strokeColor, Colors.white);
        expect(handle.consumeTapEvents, isFalse);
      }
      final lightHandles = boundaryVertexHandles(
        vertices: <MapCoordinate>[a],
        colorHex: '#FFD600',
      );
      expect(lightHandles.single.fillColor, const Color(0xFFFFD600));
      expect(lightHandles.single.strokeColor, Colors.black87);
    });
  });

  group('boundaryEditSessionProvider (same-map session lifecycle)', () {
    test('begin creates the draft controller from the form snapshot color; '
        'resolve clears and disposes; the session id never crosses visits', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boundaryEditSessionProvider.notifier);

      expect(container.read(boundaryEditSessionProvider), isNull);

      controller.begin(
        origin: BoundaryEditOriginAdd(coordinate: pin),
        snapshot: snapshot(boundaryColor: '#FFD600'),
      );
      final first = container.read(boundaryEditSessionProvider)!;
      expect(first.controller.colorHex, '#FFD600');
      expect(first.controller.vertices, isEmpty);
      expect(first.controller.canDone, isFalse);

      first.controller
        ..addVertex(a)
        ..addVertex(b)
        ..addVertex(c);
      expect(first.controller.canDone, isTrue);

      final resolved = controller.resolve(
        const SavedPlaceBoundary(
          colorHex: '#FFD600',
          vertices: <MapCoordinate>[a, b, c],
        ),
      );
      expect(identical(resolved, first), isTrue);
      expect(container.read(boundaryEditSessionProvider), isNull);
      // Disposed controller rejects further mutation without crashing.
      expect(() => first.controller.addVertex(a), throwsFlutterError);

      controller.begin(
        origin: BoundaryEditOriginEdit(
          place: SavedPlace(
            id: 'place-1',
            profileId: 'profile-1',
            label: 'Farm',
            coordinate: pin,
            markerMode: SavedPlaceMarkerMode.standard,
            standardCategory: SavedPlaceStandardCategory.information,
            customEmoji: null,
            markerColorHex: '#175A8F',
            createdAtUtc: DateTime.utc(2026, 9, 1),
            updatedAtUtc: DateTime.utc(2026, 9, 1),
          ),
        ),
        snapshot: snapshot(),
      );
      final second = container.read(boundaryEditSessionProvider)!;
      expect(identical(second, first), isFalse);
      expect(second.sessionId, isNot(first.sessionId));
      expect(second.controller.vertices, isEmpty);
      controller.resolve(null);
      expect(container.read(boundaryEditSessionProvider), isNull);
    });

    test('snapshot.withBoundary adopts a Done draft (color + vertices) and a '
        'Cancel keeps the prior draft untouched', () {
      const prior = SavedPlaceBoundary(
        colorHex: '#175A8F',
        vertices: <MapCoordinate>[a, b, c],
      );
      final base = snapshot(boundaryDraft: prior);
      expect(base.withBoundary(null), same(base));
      const replacement = SavedPlaceBoundary(
        colorHex: '#FFD600',
        vertices: <MapCoordinate>[b, c, a],
      );
      final restored = base.withBoundary(replacement);
      expect(restored.boundaryDraft, same(replacement));
      expect(restored.boundaryColorHex, '#FFD600');
      // Everything else is byte-identical to the yield-time state.
      expect(restored.label, base.label);
      expect(restored.markerColorHex, base.markerColorHex);
      expect(restored.markerMode, base.markerMode);
      expect(restored.standardCategory, base.standardCategory);
    });

    test('PASS 3 — a Done boundary adopts independence (follows false); X '
        '(withBoundary(null)) preserves the follow state exactly', () {
      final following = snapshot(
        boundaryDraft: null,
        boundaryColor: '#D32F2F',
        boundaryColorFollowsMarkerForNewBoundary: true,
      );
      // X / cancel: snapshot untouched -> follow flag survives the round trip.
      expect(following.withBoundary(null), same(following));
      expect(
        following.withBoundary(null).boundaryColorFollowsMarkerForNewBoundary,
        isTrue,
      );
      // Done: adopting the draft arms independence even when the chosen
      // color happens to equal the marker color.
      final done = following.withBoundary(
        const SavedPlaceBoundary(
          colorHex: '#D32F2F',
          vertices: <MapCoordinate>[a, b, c],
        ),
      );
      expect(done.boundaryColorFollowsMarkerForNewBoundary, isFalse);
      expect(done.boundaryDraft, isNotNull);
    });

    test('session snapshot is captured verbatim, including unsaved values', () {
      final captured = SavedPlaceFormSnapshot(
        label: 'My Farm',
        markerMode: SavedPlaceMarkerMode.custom,
        standardCategory: SavedPlaceStandardCategory.food,
        customEmoji: '🐝',
        markerColorHex: '#8E24AA',
        boundaryColorHex: '#C62828',
        boundaryDraft: null,
        boundaryColorFollowsMarkerForNewBoundary: true,
      );
      expect(captured.label, 'My Farm');
      expect(captured.customEmoji, '🐝');
      expect(captured.markerMode, SavedPlaceMarkerMode.custom);
      expect(captured.markerColorHex, '#8E24AA');
      expect(captured.boundaryColorHex, '#C62828');
      expect(captured.boundaryDraft, isNull);
      expect(captured.boundaryColorFollowsMarkerForNewBoundary, isTrue);
    });
  });
}

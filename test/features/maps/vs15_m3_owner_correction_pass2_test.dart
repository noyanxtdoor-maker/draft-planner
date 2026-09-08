import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/location_action_sheet.dart';

void main() {
  final surface = File(
    'lib/features/maps/presentation/google_maps_surface.dart',
  ).readAsStringSync();
  final screen = File(
    'lib/features/maps/presentation/maps_screen.dart',
  ).readAsStringSync();
  final actionSheet = File(
    'lib/features/maps/presentation/location_action_sheet.dart',
  ).readAsStringSync();
  final placeEditor = File(
    'lib/features/maps/presentation/saved_place_form_sheet.dart',
  ).readAsStringSync();

  test('selected marker uses the real centered location-pin glyph', () {
    expect(surface, contains('Icons.location_pin'));
    expect(surface, contains('_paintSelectedLocationPinGlyph'));
    expect(surface, isNot(contains('_paintCenteredLocationPin')));
  });

  test('controls have one reversible resting-position calculation', () {
    expect(surface, contains('mapControlColumnBottom'));
    expect(surface, isNot(contains('previewOpen\n                ? 300.0')));
  });

  testWidgets('controls return exactly after 10 preview open/dismiss cycles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lift = ValueNotifier<double>(0);
    addTearDown(lift.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GoogleMapsSurface(
              markers: const <MapMarker>[
                MapMarker(
                  owner: MapCoordinateOwner.contact,
                  recordId: 'contact-1',
                  coordinate: MapCoordinate(latitude: 14.6, longitude: 121),
                  displayName: 'Stable Marker',
                ),
              ],
              initialCoordinate: null,
              onMarkerTap: (_) {},
              controlsLift: lift,
              mapBuilder: (_, _) => const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double controlBottom() {
      final positioned = find.ancestor(
        of: find.byKey(const Key('maps-drop-pin-button')),
        matching: find.byType(AnimatedPositioned),
      );
      return tester.widget<AnimatedPositioned>(positioned.first).bottom!;
    }

    for (var cycle = 0; cycle < 10; cycle += 1) {
      lift.value = 276;
      await tester.pump();
      expect(controlBottom(), 300, reason: 'open cycle ${cycle + 1}');
      lift.value = 0;
      await tester.pump();
      expect(controlBottom(), 24, reason: 'dismiss cycle ${cycle + 1}');
    }
  });

  test(
    'location action sheet has one handle and is explicitly dismissible',
    () {
      expect(actionSheet, contains('isDismissible: true'));
      expect(actionSheet, contains('enableDrag: true'));
      expect(actionSheet, contains('showDragHandle: false'));
      expect(
        RegExp('location-action-handle').allMatches(actionSheet),
        hasLength(1),
      );
    },
  );

  testWidgets('location action sheet barrier dismisses with no action', (
    tester,
  ) async {
    Future<MapLocationAction?>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => result = showMapLocationActionSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-action-handle')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  test('Add Place is a full-screen editor with no raw coordinates', () {
    expect(placeEditor, contains('final class SavedPlaceFormScreen'));
    expect(placeEditor, contains("key: const Key('saved-place-form-screen')"));
    expect(placeEditor, contains('Scaffold('));
    expect(placeEditor, isNot(contains('DraggableScrollableSheet')));
    expect(placeEditor, isNot(contains('coordinate.description')));
    expect(screen, contains('SavedPlaceFormScreen('));
    expect(screen, contains('MaterialPageRoute<void>'));
  });

  test('Standard and Custom editor laws are explicit', () {
    expect(placeEditor, contains('savedPlaceCategoryIcon'));
    expect(placeEditor, contains('showPlannerEventColorPicker'));
    expect(placeEditor, isNot(contains('_presetEmojis')));
    expect(placeEditor, isNot(contains('saved-place-swatch-')));
    expect(
      placeEditor,
      contains('if (_mode == SavedPlaceMarkerMode.standard)'),
    );
    // VS-15 M6.1: the editor now owns the Boundary section (previously a
    // deferred control); the boundary is place-owned, never marker-owned.
    expect(placeEditor, contains("Text('Boundary'"));
    expect(placeEditor, contains("Text('Boundary Color'"));
  });

  test('same-map camera updates do not rebuild the Maps screen', () {
    expect(
      screen,
      contains('onCameraCenterChanged: (value) => _cameraCenter = value'),
    );
    expect(screen, isNot(contains('setState(() => _cameraCenter = value)')));
  });

  test('Custom requires exactly one emoji grapheme', () {
    const coordinate = MapCoordinate(latitude: 14.6, longitude: 121);
    expect(
      () => const SavedPlaceDraft(
        label: 'Invalid text',
        coordinate: coordinate,
        markerMode: SavedPlaceMarkerMode.custom,
        customEmoji: 'A',
      ).normalized(),
      throwsA(isA<SavedPlaceValidationException>()),
    );
    expect(
      () => const SavedPlaceDraft(
        label: 'Two emoji',
        coordinate: coordinate,
        markerMode: SavedPlaceMarkerMode.custom,
        customEmoji: '😀😁',
      ).normalized(),
      throwsA(isA<SavedPlaceValidationException>()),
    );
    expect(
      const SavedPlaceDraft(
        label: 'Family',
        coordinate: coordinate,
        markerMode: SavedPlaceMarkerMode.custom,
        customEmoji: '👨‍👩‍👧‍👦',
      ).normalized().customEmoji,
      '👨‍👩‍👧‍👦',
    );
  });
}

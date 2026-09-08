import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_form_sheet.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_marker_visuals.dart';

const _render = bool.fromEnvironment('VS15_RENDER_QA');
const _coordinate = MapCoordinate(latitude: 14.6, longitude: 121);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
  });
  test('nine categories use nine distinct correct glyph concepts', () {
    final icons = SavedPlaceStandardCategory.values
        .map(savedPlaceCategoryIcon)
        .toSet();
    expect(icons, hasLength(9));
    expect(
      savedPlaceCategoryIcon(SavedPlaceStandardCategory.avoid),
      Icons.warning_amber_rounded,
    );
    expect(
      savedPlaceCategoryIcon(SavedPlaceStandardCategory.shopping),
      Icons.shopping_cart,
    );
    expect(
      savedPlaceCategoryIcon(SavedPlaceStandardCategory.laundry),
      Icons.checkroom,
    );
  });

  test(
    'selected bitmap pins the red pin above the pixel-stable base identity',
    () async {
      final markers = [
        const MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'dot',
          displayName: 'Contact',
          coordinate: _coordinate,
          colorValue: 0xFF407AC2,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'star',
          displayName: 'Favorite',
          coordinate: _coordinate,
          colorValue: 0xFF805AB8,
          isFavorite: true,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.event,
          recordId: 'calendar',
          displayName: 'Event',
          coordinate: _coordinate,
          colorValue: 0xFF397642,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.savedPlace,
          recordId: 'place',
          displayName: 'Place',
          coordinate: _coordinate,
          colorValue: 0xFF175A8F,
          placeStandardCategory: SavedPlaceStandardCategory.information,
        ),
      ];
      for (final marker in markers) {
        final normal =
            await renderMapMarkerForTesting(marker, selected: false)
                as BytesMapBitmap;
        final selected =
            await renderMapMarkerForTesting(marker, selected: true)
                as BytesMapBitmap;
        final normalCodec = await ui.instantiateImageCodec(normal.byteData);
        final selectedCodec = await ui.instantiateImageCodec(selected.byteData);
        final normalImage = (await normalCodec.getNextFrame()).image;
        final selectedImage = (await selectedCodec.getNextFrame()).image;
        expect(normalImage.width, 96);
        expect(normalImage.height, 96);
        expect(selectedImage.width, 96);
        // Pass 4 + M3.1 final alignment: selection only extends the bitmap
        // ABOVE the identity zone (96 + 80); the identity keeps its exact
        // unselected canvas position.
        expect(selectedImage.height, 176);
        final normalPixels = (await normalImage.toByteData())!.buffer
            .asUint8List();
        final selectedPixels = (await selectedImage.toByteData())!.buffer
            .asUint8List();
        final markerColor = Color(marker.colorValue);

        // Owner law: selection must not move/recreate the base record. Every
        // opaque pixel of the normal identity bitmap must reappear at the
        // exact same position in the selected bitmap; new pixels may only
        // appear where the normal bitmap is transparent (the pin above).
        var movedIdentityPixels = 0;
        final unexpected = <String>[];
        for (var index = 0; index < normalPixels.length; index += 4) {
          // The selected bitmap is the 80-row pin extension stacked ABOVE the
          // unchanged 96-row identity zone.
          final selectedZIndex = index + 80 * 96 * 4;
          final x = (index ~/ 4) % 96;
          final y = (index ~/ 4) ~/ 96;
          // The M3.1 final composition lets the larger pin tip reach deeper
          // into the upper identity zone (rows < 40). Its antialiased white
          // edge can blend with the unchanged base color here; the head and
          // lower core are checked separately by the M3.1 pixel regression.
          if (y < 40 && x >= 32 && x <= 64 && normalPixels[index + 3] >= 200) {
            continue;
          }
          final sameColor =
              (selectedPixels[selectedZIndex] - normalPixels[index]).abs() <=
                  2 &&
              (selectedPixels[selectedZIndex + 1] - normalPixels[index + 1])
                      .abs() <=
                  2 &&
              (selectedPixels[selectedZIndex + 2] - normalPixels[index + 2])
                      .abs() <=
                  2 &&
              (selectedPixels[selectedZIndex + 3] - normalPixels[index + 3])
                      .abs() <=
                  2;
          // M3.1 explicitly allows the pin tip to overlap the top of the
          // identity. Its core/lower pixels must remain at the same anchor.
          if (normalPixels[index + 3] >= 200 && index ~/ (96 * 4) >= 32) {
            // Strongly-opaque identity pixels (fill/outline) are the record
            // itself and must be byte-stable. Faint shadow anti-aliasing may
            // legitimately composite over the pin tip in the selected bitmap.
            if (!sameColor) movedIdentityPixels++;
          } else if (!sameColor) {
            // New pixels may only be pin artwork: red, the white separation
            // edge, or any anti-aliased red/white blend — i.e. red-dominant
            // or a near-white neutral. A blue/teal dot would fail this.
            final r = selectedPixels[selectedZIndex];
            final g = selectedPixels[selectedZIndex + 1];
            final b = selectedPixels[selectedZIndex + 2];
            final a = selectedPixels[selectedZIndex + 3];
            final isPinArtwork =
                a > 0 &&
                ((r >= g && r >= b && r > 100) ||
                    (r > 230 && g > 230 && b > 230) ||
                    // Faint neutral anti-aliasing on the pin's outer edge.
                    (a < 130 &&
                        (r - g).abs() <= 6 &&
                        (g - b).abs() <= 6 &&
                        (r - b).abs() <= 6));
            if (!isPinArtwork) {
              final pixel = index ~/ 4;
              unexpected.add(
                '(${pixel % 96},${pixel ~/ 96})'
                'rgba($r,$g,$b,$a)',
              );
            }
          }
        }
        expect(
          movedIdentityPixels,
          0,
          reason:
              'Selection displaced the base identity for ${marker.recordId}: '
              '$movedIdentityPixels identity pixels changed',
        );
        expect(
          unexpected,
          isEmpty,
          reason:
              'Selection painted unexpected non-pin artwork for '
              '${marker.recordId}: ${unexpected.take(6).join(', ')}',
        );

        var identityPixels = 0;
        var redPixels = 0;
        for (var index = 0; index < selectedPixels.length; index += 4) {
          final pixel = index ~/ 4;
          final y = pixel ~/ 96;
          if (y >= 96 &&
              (selectedPixels[index] - markerColor.r * 255).abs() < 16 &&
              (selectedPixels[index + 1] - markerColor.g * 255).abs() < 16 &&
              (selectedPixels[index + 2] - markerColor.b * 255).abs() < 16 &&
              selectedPixels[index + 3] > 150) {
            identityPixels++;
          }
          if (selectedPixels[index] > 150 &&
              selectedPixels[index + 1] < 90 &&
              selectedPixels[index + 2] < 90 &&
              selectedPixels[index + 3] > 150 &&
              y < 96) {
            redPixels++;
          }
        }
        expect(
          identityPixels,
          greaterThan(100),
          reason:
              'Readable identity beneath the pin tip for ${marker.recordId}',
        );
        expect(
          redPixels,
          greaterThan(100),
          reason: 'Red pin directly above the marker for ${marker.recordId}',
        );
        if (_render) {
          await Directory('build/pass2-qa').create(recursive: true);
          await File(
            'build/pass2-qa/${marker.recordId}-normal.png',
          ).writeAsBytes(normal.byteData);
          await File(
            'build/pass2-qa/${marker.recordId}-selected.png',
          ).writeAsBytes(selected.byteData);
        }
        normalImage.dispose();
        selectedImage.dispose();
        normalCodec.dispose();
        selectedCodec.dispose();
      }
    },
  );

  testWidgets('editor renders compact Standard and isolated Custom modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (Platform.environment['VS15_QA_TEXT_FONT'] case final path?
        when _render) {
      await tester.runAsync(() async {
        final font = FontLoader('Roboto')
          ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
        await font.load();
      });
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(ThemeColorMode.blue),
          home: RepaintBoundary(
            key: key,
            child: SavedPlaceFormScreen(
              coordinate: _coordinate,
              onSave: (_) async {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final first = tester.getRect(
      find.byKey(const Key('saved-place-category-information')),
    );
    final last = tester.getRect(
      find.byKey(const Key('saved-place-category-laundry')),
    );
    expect(last.bottom - first.top, lessThan(270));
    if (_render) await _capture(tester, key, 'editor-standard');
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-place-hex')), findsNothing);
    expect(tester.takeException(), isNull);
    if (_render) await _capture(tester, key, 'editor-custom');
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/pass2-qa').create(recursive: true);
    await File(
      'build/pass2-qa/$name.png',
    ).writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

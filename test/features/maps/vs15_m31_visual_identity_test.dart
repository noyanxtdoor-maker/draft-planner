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
import 'package:rmplanner/features/contacts/presentation/contact_search_screen.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/maps_search_screen.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_form_sheet.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_marker_visuals.dart';

const _qa = bool.fromEnvironment('M31_RENDER');
const _point = MapCoordinate(latitude: 14.6, longitude: 121);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    if (Platform.environment['VS15_QA_TEXT_FONT'] case final path? when _qa) {
      await (FontLoader(
        'Roboto',
      )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  test(
    'M3.1 all nine persisted colors/icons resolve with contrast; emoji untinted',
    () {
      for (final category in SavedPlaceStandardCategory.values) {
        final identity = SavedPlaceVisualIdentity.resolve(
          mode: SavedPlaceMarkerMode.standard,
          category: category,
          color: const Color(0xFFF5EF22),
        );
        expect(identity.icon, savedPlaceCategoryIcon(category));
        expect(identity.color, const Color(0xFFF5EF22));
        if (category == SavedPlaceStandardCategory.avoid) {
          expect(
            SavedPlaceVisualIdentity.resolve(
              mode: SavedPlaceMarkerMode.standard,
              category: category,
            ).color,
            SavedPlaceVisualIdentity.warningRed,
          );
        }
        final a = identity.color.computeLuminance(),
            b = identity.foreground.computeLuminance();
        expect(
          (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
      final emoji = SavedPlaceVisualIdentity.resolve(
        mode: SavedPlaceMarkerMode.custom,
        category: SavedPlaceStandardCategory.avoid,
        color: Colors.green,
        emoji: '👨‍👩‍👧‍👦',
      );
      expect(emoji.emoji, '👨‍👩‍👧‍👦');
      expect(emoji.icon, isNull);
      expect(emoji.color, Colors.green);
    },
  );
  test(
    'M3.1 native marker glyphs remain readable; pin head/tip and anchor stable',
    () async {
      final markers = <MapMarker>[
        for (final owner in [
          MapCoordinateOwner.contact,
          MapCoordinateOwner.event,
        ])
          MapMarker(
            owner: owner,
            recordId: owner.name,
            coordinate: _point,
            displayName: owner.name,
            colorValue: 0xFF327ABA,
          ),
        const MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'favorite',
          coordinate: _point,
          displayName: 'Favorite',
          colorValue: 0xFF327ABA,
          isFavorite: true,
        ),
        for (final category in SavedPlaceStandardCategory.values)
          MapMarker(
            owner: MapCoordinateOwner.savedPlace,
            recordId: category.name,
            coordinate: _point,
            displayName: category.label,
            colorValue: 0xFF175A8F,
            placeMarkerMode: SavedPlaceMarkerMode.standard,
            placeStandardCategory: category,
          ),
        const MapMarker(
          owner: MapCoordinateOwner.savedPlace,
          recordId: 'emoji',
          coordinate: _point,
          displayName: 'Emoji',
          placeMarkerMode: SavedPlaceMarkerMode.custom,
          placeEmoji: '👨‍👩‍👧‍👦',
        ),
      ];
      for (final marker in markers) {
        final normal =
            await renderMapMarkerForTesting(marker, selected: false)
                as BytesMapBitmap;
        final selected =
            await renderMapMarkerForTesting(marker, selected: true)
                as BytesMapBitmap;
        final nc = await ui.instantiateImageCodec(normal.byteData),
            sc = await ui.instantiateImageCodec(selected.byteData);
        final ni = (await nc.getNextFrame()).image,
            si = (await sc.getNextFrame()).image;
        final np = (await ni.toByteData())!.buffer.asUint8List(),
            sp = (await si.toByteData())!.buffer.asUint8List();
        expect(ni.height, 96);
        expect(si.height, 176);
        expect(
          sp.sublist(128 * 96 * 4),
          np.sublist(48 * 96 * 4),
          reason: 'lower half stays anchored for ${marker.recordId}',
        );
        var headRed = 0, foreignHead = 0, tipRed = 0;
        for (var y = 25; y < 120; y++) {
          for (var x = 20; x < 76; x++) {
            final i = (y * 96 + x) * 4;
            if (sp[i + 3] < 180) continue;
            if (y < 70) {
              if (sp[i] > sp[i + 1] * 1.3 && sp[i] > sp[i + 2] * 1.3) headRed++;
              if (sp[i + 2] > sp[i] * 1.2 || sp[i + 1] > sp[i] * 1.2) {
                foreignHead++;
              }
            }
            if (y >= 80 &&
                x >= 40 &&
                x <= 56 &&
                sp[i] > sp[i + 1] * 1.3 &&
                sp[i] > sp[i + 2] * 1.3) {
              tipRed++;
            }
          }
        }
        expect(headRed, greaterThan(100));
        expect(foreignHead, 0);
        expect(
          tipRed,
          greaterThan(0),
          reason: 'tip meets identity top, not empty gap',
        );
        if (marker.owner == MapCoordinateOwner.savedPlace &&
            marker.placeMarkerMode != SavedPlaceMarkerMode.custom) {
          var foreground = 0;
          for (var y = 27; y < 69; y++) {
            for (var x = 27; x < 69; x++) {
              final i = (y * 96 + x) * 4;
              if (np[i] > 220 &&
                  np[i + 1] > 220 &&
                  np[i + 2] > 220 &&
                  np[i + 3] > 200) {
                foreground++;
              }
            }
          }
          expect(
            foreground,
            greaterThan(20),
            reason: 'foreground ${marker.recordId} glyph not covered',
          );
        }
        if (_qa) {
          await Directory('build/m31-qa').create(recursive: true);
          await File(
            'build/m31-qa/${marker.recordId}-normal.png',
          ).writeAsBytes(normal.byteData);
          await File(
            'build/m31-qa/${marker.recordId}-selected.png',
          ).writeAsBytes(selected.byteData);
        }
        ni.dispose();
        si.dispose();
        nc.dispose();
        sc.dispose();
      }
    },
  );
  testWidgets(
    'M3.1 actual Search result builder uses persisted visual identity',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MapsSearchScreen())),
      );
      final picker = tester.widget<ContactSearchPickerScreen<MapSearchResult>>(
        find.byType(ContactSearchPickerScreen<MapSearchResult>),
      );
      for (final custom in [false, true]) {
        final place = SavedPlace(
          id: 'p',
          profileId: 'profile',
          label: 'Example',
          coordinate: _point,
          markerMode: custom
              ? SavedPlaceMarkerMode.custom
              : SavedPlaceMarkerMode.standard,
          standardCategory: SavedPlaceStandardCategory.food,
          customEmoji: custom ? '☕' : null,
          markerColorHex: '#327ABA',
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => picker.resultBuilder(
                  context,
                  MapSearchResult.savedPlace(place),
                  () {},
                ),
              ),
            ),
          ),
        );
        expect(find.byType(SavedPlaceIdentityIcon), findsOneWidget);
        if (custom) {
          expect(find.text('☕'), findsOneWidget);
          expect(tester.widget<Text>(find.text('☕')).style!.color, isNull);
        } else {
          expect(find.byIcon(Icons.restaurant), findsOneWidget);
        }
      }
    },
  );
  for (final mode in ThemeColorMode.values) {
    for (final dark in [false, true]) {
      testWidgets('M3.1 render $mode dark=$dark at Infinix and scale 1.3', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(431, 912);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark(mode) : AppTheme.light(mode),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: key,
                  child: ProviderScope(
                    child: SavedPlaceFormScreen(
                      coordinate: _point,
                      onSave: (_) async {},
                      onCancel: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final category in SavedPlaceStandardCategory.values) {
            expect(find.text(category.label), findsOneWidget);
          }
          if (_qa && scale == 1) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final img = await boundary.toImage(pixelRatio: 2);
              final png = await img.toByteData(format: ui.ImageByteFormat.png);
              await Directory('build/m31-qa').create(recursive: true);
              await File(
                'build/m31-qa/editor-${mode.name}-$dark.png',
              ).writeAsBytes(png!.buffer.asUint8List());
              img.dispose();
            });
          }
        }
      });
    }
  }
}

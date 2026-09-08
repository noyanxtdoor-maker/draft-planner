import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';

/// VS-15 M3.1 final alignment regression lock: the selected red pin is
/// moderately larger and sits lower so its tip overlaps the upper half of the
/// original marker (Contact / Favorite / Event / Saved Place Standard /
/// Saved Place Custom emoji read as one selected-state composition), while
/// the base record identity stays pixel-stable at its exact LatLng anchor.
const _coordinate = MapCoordinate(latitude: 14.6, longitude: 121);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'selected pin is larger, lower, and meets the marker upper half',
    () async {
      final markers = <MapMarker>[
        const MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'contact',
          displayName: 'Contact',
          coordinate: _coordinate,
          colorValue: 0xFF407AC2,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.contact,
          recordId: 'favorite',
          displayName: 'Favorite',
          coordinate: _coordinate,
          colorValue: 0xFF805AB8,
          isFavorite: true,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.event,
          recordId: 'event',
          displayName: 'Event',
          coordinate: _coordinate,
          colorValue: 0xFF397642,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.savedPlace,
          recordId: 'place-standard',
          displayName: 'Saved Place',
          coordinate: _coordinate,
          colorValue: 0xFF175A8F,
          placeMarkerMode: SavedPlaceMarkerMode.standard,
          placeStandardCategory: SavedPlaceStandardCategory.information,
        ),
        const MapMarker(
          owner: MapCoordinateOwner.savedPlace,
          recordId: 'place-emoji',
          displayName: 'Saved Place',
          coordinate: _coordinate,
          colorValue: 0xFF175A8F,
          placeMarkerMode: SavedPlaceMarkerMode.custom,
          placeEmoji: '☕',
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
        expect(ni.width, 96);
        expect(ni.height, 96);
        expect(si.width, 96);
        expect(si.height, 176, reason: '${marker.recordId} canvas');
        // Base record law: the identity's lower half is byte-identical.
        expect(
          sp.sublist(128 * 96 * 4),
          np.sublist(48 * 96 * 4),
          reason: '${marker.recordId} identity must stay anchored',
        );

        // Measure the painted red pin bounding box.
        var redTop = 1 << 30;
        var redBottom = -1;
        var redCount = 0;
        for (var y = 0; y < 176; y++) {
          for (var x = 0; x < 96; x++) {
            final i = (y * 96 + x) * 4;
            if (sp[i + 3] > 150 &&
                sp[i] > 150 &&
                sp[i + 1] < 90 &&
                sp[i + 2] < 90) {
              redCount++;
              if (y < redTop) redTop = y;
              if (y > redBottom) redBottom = y;
            }
          }
        }
        // Moderately larger: the visible red extent grows from ~59 rows
        // (74px glyph) to well over 70 rows (96px glyph).
        expect(
          redBottom - redTop + 1,
          greaterThan(70),
          reason: '${marker.recordId} pin must be moderately larger',
        );
        // Lower + centered: the tip must reach into the identity upper zone
        // (identity top row = 80) without passing its center row (128).
        expect(redTop, lessThan(80), reason: '${marker.recordId} pin head');
        expect(
          redBottom,
          inInclusiveRange(88, 118),
          reason:
              '${marker.recordId} tip must overlap the marker upper half, '
              'not float above it or cover its center',
        );
        expect(redCount, greaterThan(300), reason: '${marker.recordId} pin');

        // The identity must remain readable: plenty of its own pixels survive
        // beside the narrow tip overlap. Custom-emoji places are untinted and
        // no emoji font exists in the test renderer, so for them the lock only
        // requires the identity zone not be covered by the pin artwork.
        final isEmoji =
            marker.owner == MapCoordinateOwner.savedPlace &&
            marker.placeMarkerMode == SavedPlaceMarkerMode.custom;
        var identityVisible = 0;
        for (var y = 80; y < 176; y++) {
          for (var x = 0; x < 96; x++) {
            final i = (y * 96 + x) * 4;
            if (sp[i + 3] <= 150) continue;
            if (isEmoji) {
              final isRedPin = sp[i] > 150 && sp[i + 1] < 90 && sp[i + 2] < 90;
              final isWhiteEdge =
                  sp[i] > 230 && sp[i + 1] > 230 && sp[i + 2] > 230;
              if (!isRedPin && !isWhiteEdge) identityVisible++;
            } else {
              final color = marker.colorValue;
              if ((sp[i] - ((color >> 16) & 0xFF)).abs() < 16 &&
                  (sp[i + 1] - ((color >> 8) & 0xFF)).abs() < 16 &&
                  (sp[i + 2] - (color & 0xFF)).abs() < 16) {
                identityVisible++;
              }
            }
          }
        }
        expect(
          identityVisible,
          isEmoji ? greaterThan(40) : greaterThan(400),
          reason: '${marker.recordId} identity must stay readable',
        );
        ni.dispose();
        si.dispose();
        nc.dispose();
        sc.dispose();
      }
    },
  );
}

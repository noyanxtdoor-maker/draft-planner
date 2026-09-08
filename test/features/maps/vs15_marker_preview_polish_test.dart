import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';

void main() {
  const marker = MapMarker(
    owner: MapCoordinateOwner.contact,
    recordId: 'contact-1',
    coordinate: MapCoordinate(latitude: 14.6, longitude: 121.0),
    displayName: 'Ada Gomez',
  );

  test('direct marker selection is not a future MapFocus command', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(mapSelectedMarkerProvider.notifier).select(marker);

    expect(
      container.read(mapSelectedMarkerProvider)?.marker.ownerKey,
      marker.ownerKey,
    );
    expect(container.read(mapTransientFocusProvider).pending, isNull);

    container.read(mapSelectedMarkerProvider.notifier).clear();
    expect(container.read(mapSelectedMarkerProvider), isNull);
  });

  test(
    'Satellite retains its label and uses labeled satellite SDK imagery',
    () {
      expect(NextTransferMapType.road.googleType, MapType.normal);
      expect(NextTransferMapType.satellite.googleType, MapType.hybrid);
      expect(NextTransferMapType.terrain.googleType, MapType.terrain);
      expect(NextTransferMapType.hybrid.googleType, MapType.hybrid);
    },
  );

  test(
    'the map is the stable canvas: direct marker tap issues no camera move',
    () {
      final surface = File(
        'lib/features/maps/presentation/google_maps_surface.dart',
      ).readAsStringSync();

      expect(
        surface,
        isNot(contains('CameraUpdate.scrollBy(0, 180)')),
        reason:
            'selection must not offset the camera to make room for the sheet',
      );
      expect(
        surface.indexOf('onTap: () => _selectMarker(marker)'),
        greaterThan(-1),
      );
      // Marker selection is exactly selection + preview, never a camera
      // command. (The optional same-map boundary-mode guard suppresses
      // selection entirely and adds no camera behavior of any kind.)
      final markerTap = RegExp(
        r'void _selectMarker\(MapMarker marker\) \{\s*'
        r'(//[^\n]*\n\s*)*'
        r'(if \(widget\.interactionPaused\) return;\s*)?'
        r'ref\.read\(mapSelectedMarkerProvider\.notifier\)\.select\(marker\);\s*'
        r'widget\.onMarkerTap\(marker\);\s*\}',
      );
      expect(markerTap.hasMatch(surface), isTrue);
    },
  );

  test(
    'source enforces preview-first behavior, thin edge, and centered pin',
    () {
      final surface = File(
        'lib/features/maps/presentation/google_maps_surface.dart',
      ).readAsStringSync();
      final mapsScreen = File(
        'lib/features/maps/presentation/maps_screen.dart',
      ).readAsStringSync();
      final preview = File(
        'lib/features/maps/presentation/map_marker_preview_sheet.dart',
      ).readAsStringSync();

      expect(surface, contains('static const double _markerEdgeWidth = 2'));
      expect(surface, contains('static const double _markerLogicalSize = 34'));
      expect(surface, contains('_paintSelectedLocationPinGlyph'));
      expect(
        surface,
        isNot(contains('_paintSelectedLocationBadge')),
        reason: 'the upper-right badge is owner-rejected',
      );
      expect(surface, isNot(contains('defaultMarkerWithHue')));
      expect(surface, isNot(contains('_selectedMarkerHaloWidth')));
      expect(surface, contains('PmgStyleSortField('));
      expect(surface, contains("key: const Key('maps-drop-pin-button')"));
      expect(
        surface,
        isNot(contains("key: const Key('maps-drop-pin')")),
        reason: 'Drop Pin is a dedicated control now, not a map-type sheet row',
      );
      expect(
        surface,
        isNot(contains('DropdownButtonFormField<NextTransferMapType>')),
      );
      expect(mapsScreen, contains('MapMarkerPreviewSheet('));
      expect(mapsScreen, isNot(contains('void _openRecord(MapMarker marker)')));
      expect(mapsScreen, contains('_PlacementChrome('));
      expect(preview, contains('MapExternalNavigation.launchWithFallback'));
      expect(preview, contains("'maps-contact-preview-view'"));
      expect(preview, contains("'maps-event-preview-view'"));
      expect(preview, contains("'Edit Pin Location'"));
      expect(preview, isNot(contains('RoutePaths.mapPicker')));
    },
  );
}

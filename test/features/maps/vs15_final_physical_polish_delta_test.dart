import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final physical marker and camera laws are explicit', () {
    final source = File(
      'lib/features/maps/presentation/google_maps_surface.dart',
    ).readAsStringSync();

    expect(source, contains('static const double _markerLogicalSize = 34'));
    expect(source, contains('static const double _markerEdgeWidth = 2'));
    expect(source, contains('canvas.drawPath(star, outline)'));
    expect(source, contains('_paintSelectedLocationPinGlyph'));
    expect(source, contains('Icons.location_pin'));
    expect(source, isNot(contains('_paintSelectedLocationBadge')));
    expect(source, isNot(contains('defaultMarkerWithHue')));
    expect(source, isNot(contains('_selectedMarkerHaloWidth')));
    expect(source, contains('if (!selected) return normal;'));
    expect(source, isNot(contains('CameraUpdate.scrollBy(0, 180)')));
    expect(source, isNot(contains('_centerSelectedMarker')));
  });

  test('shared center-pin picker keeps confirm-only persistence boundary', () {
    final picker = File(
      'lib/features/maps/presentation/map_location_picker_screen.dart',
    ).readAsStringSync();

    expect(picker, contains("title: const Text('Edit Pin Location')"));
    expect(picker, contains("'Move map to find location'"));
    expect(picker, contains("key: Key('map-picker-fixed-pin')"));
    expect(picker, contains('color: Colors.red'));
    expect(picker, contains('onCameraMove: _onCameraMove'));
    expect(picker, contains("key: const Key('map-picker-locate')"));
    expect(picker, contains('Navigator.of(context).pop(_cameraCenter)'));
    expect(picker, isNot(contains('onTap: _onMapTap')));
    expect(picker, isNot(contains("MarkerId('map-picker-candidate')")));
  });

  test('inline edit stays on the same map and never pushes a picker route', () {
    final surface = File(
      'lib/features/maps/presentation/google_maps_surface.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/maps/presentation/maps_screen.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/maps/presentation/map_marker_preview_sheet.dart',
    ).readAsStringSync();

    expect(surface, contains('onCameraCenterChanged'));
    expect(surface, contains('controlsLift'));
    expect(screen, contains('_InlineEditSession'));
    expect(screen, contains('maps-centering-pin'));
    expect(screen, contains('maps-centering-confirm'));
    expect(screen, contains('maps-centering-cancel'));
    expect(screen, contains("'Move map to find location'"));
    expect(screen, contains('setCoordinate('));
    expect(screen, isNot(contains('MapLocationPickerScreen')));
    expect(preview, contains('required this.onEditLocation'));
    expect(preview, isNot(contains('RoutePaths.mapPicker')));
    expect(preview, isNot(contains('AddressMapEditor(')));
    expect(preview, isNot(contains('RoutePaths.calendarEventEdit(')));
  });

  test('shared Location Action Sheet and dedicated Drop Pin converge', () {
    final screen = File(
      'lib/features/maps/presentation/maps_screen.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/features/maps/presentation/location_action_sheet.dart',
    ).readAsStringSync();

    expect(screen, contains('showMapLocationActionSheet'));
    expect(screen, contains('_beginPlacementCoordinate'));
    expect(screen, contains('_confirmDropPin'));
    expect(sheet, contains('MapLocationAction.place'));
    expect(sheet, contains('MapLocationAction.contact'));
    expect(sheet, contains('MapLocationAction.event'));
    expect(sheet, contains("'Add at this location'"));
    expect(sheet, contains("key: const Key('location-action-place')"));
    expect(sheet, contains("key: const Key('location-action-contact')"));
    expect(sheet, contains("key: const Key('location-action-event')"));
    expect(sheet, isNot(contains('Add Information')));
    expect(sheet, isNot(contains('Add Marker')));
    expect(sheet, isNot(contains('Add Person')));
  });

  test('preview uses shared coordinate seam and accepted typography', () {
    final preview = File(
      'lib/features/maps/presentation/map_marker_preview_sheet.dart',
    ).readAsStringSync();

    expect(preview, contains('maps-contact-preview-edit-location'));
    expect(preview, contains('maps-event-preview-edit-location'));
    expect(preview, contains('maps-place-preview-edit-location'));
    expect(preview, isNot(contains("child: const Text('Edit location')")));
    expect(preview, contains('AppTypography.sectionTitle'));
    expect(preview, contains('AppTypography.secondary'));
    expect(preview, contains('AppTypography.micro'));
    expect(preview, contains('AppTypography.body'));
    expect(preview, contains('onEditLocation'));
  });

  test('toggle visuals shrink without shrinking the interaction target', () {
    final source = File(
      'lib/features/maps/presentation/google_maps_surface.dart',
    ).readAsStringSync();

    expect(source, contains('final class _CompactMarkerToggle'));
    expect(source, contains('dimension: 48'));
    expect(source, contains('scale: .84'));
    expect(source, contains('PmgStyleSortField('));
  });
}

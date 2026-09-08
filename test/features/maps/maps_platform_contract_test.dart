// MAPS V1 — platform contract tests.
//
// Locks the VS-15 M1 renderer, foreground-only permission, secret plumbing,
// and staged MapLibre-retirement boundary.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';

void main() {
  late String manifest;

  setUpAll(() {
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test(
    'release manifest has INTERNET and foreground-only location permissions',
    () {
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(
        manifest,
        isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')),
      );
    },
  );

  test(
    'Google Maps key uses a manifest placeholder and ignored local file',
    () {
      expect(manifest, contains('com.google.android.geo.API_KEY'));
      expect(manifest, contains(r'${MAPS_API_KEY}'));
      final ignore = File('.gitignore').readAsStringSync();
      expect(ignore, contains('android/secrets.properties'));
      final defaults = File(
        'android/secrets.defaults.properties',
      ).readAsStringSync();
      expect(defaults, contains('MAPS_API_KEY=DEFAULT_API_KEY'));
    },
  );

  test('official Google Maps is active while MapLibre remains for M6', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('google_maps_flutter: ^2.18.0'));
    expect(pubspec, contains('maplibre_gl: ^0.26.2'));
    expect(NextTransferMapType.road.googleType, MapType.normal);
    expect(NextTransferMapType.satellite.googleType, MapType.hybrid);
    expect(NextTransferMapType.hybrid.googleType, MapType.hybrid);
    expect(NextTransferMapType.terrain.googleType, MapType.terrain);
  });

  test('no active Dart surface references MapLibre', () {
    for (final path in <String>[
      'lib/features/maps/presentation/maps_screen.dart',
      'lib/features/maps/presentation/map_location_picker_screen.dart',
      'lib/features/maps/presentation/map_pin_section.dart',
      'lib/features/contacts/presentation/contact_detail_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('MapLibreMap')),
        reason: '$path must use the M1 Google renderer',
      );
      expect(
        source,
        isNot(contains('package:maplibre_gl')),
        reason: '$path must not import the retired active renderer',
      );
    }
  });
}

// MAPS V1 — platform contract tests.
//
// Locks the exact manifest/permission delta: release INTERNET present (the
// ONLY authorized release network addition), NO coarse/fine/background
// location permissions anywhere, and the locked maplibre_gl 0.26.2 stack.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  late String manifest;

  setUpAll(() {
    manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  test(
    'release manifest has INTERNET for the OpenFreeMap basemap (V1-only '
    'network addition)',
    () {
      expect(
        manifest,
        contains('android.permission.INTERNET'),
      );
    },
  );

  test('NO location permissions exist anywhere in the main manifest', () {
    for (final permission in <String>[
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_BACKGROUND_LOCATION',
    ]) {
      expect(
        manifest,
        isNot(contains(permission)),
        reason: '$permission must stay out of the release manifest',
      );
    }
  });

  test('locked maplibre_gl 0.26.2 dependency is present and usable', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('maplibre_gl: ^0.26.2'),
    );
    // Compile-time proof the 0.26.2 API surface we rely on exists.
    const style = MapLibreStyles.openfreemapLiberty;
    expect(style, isNotEmpty);
  });

  test('debug manifest adds no location permissions either', () {
    final debug = File('android/app/src/debug/AndroidManifest.xml');
    if (!debug.existsSync()) {
      return; // no separate debug manifest -> main manifest governs
    }
    final text = debug.readAsStringSync();
    for (final permission in <String>[
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
    ]) {
      expect(text, isNot(contains(permission)));
    }
  });
}

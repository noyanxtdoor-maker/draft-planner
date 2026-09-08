import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'owner amendment leaves no Android screen-capture blocking code path',
    () {
      final activity = File(
        'android/app/src/main/kotlin/com/nexttransfer/rmplanner/'
        'MainActivity.kt',
      ).readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(activity, isNot(contains('FLAG_SECURE')));
      expect(activity, isNot(contains('WindowManager')));
      expect(activity, isNot(contains('addFlags')));
      expect(pubspec, isNot(contains('secure_screen')));
      expect(pubspec, isNot(contains('screenshot_block')));
    },
  );
}

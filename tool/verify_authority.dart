import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _organization = 'com.nexttransfer';
const _applicationId = 'com.nexttransfer.rmplanner';
const _flutterVersion = '3.44.7';

const _approvedSources = <String, String>{
  'Next_Transfer_Phase_3_Approved_Baseline_and_Vertical_Slices.xlsx':
      '8c457c5c605fc714d6733061f5c010fa7d1f02190e1706ed0ee5ffc0edbc83e1',
  'Next_Transfer_Phase_3_Vertical_Slice_Specifications_Draft.docx':
      '1cecc97a29ccf789f957b210fda8add5f2145a65a651dd5a6d3d609c072f644b',
};

Future<void> main() async {
  final failures = <String>[];

  for (final source in _approvedSources.entries) {
    await _verifyHash(File('docs/${source.key}'), source.value, failures);
    await _verifyHash(
      File('docs/baseline/phase-3/${source.key}'),
      source.value,
      failures,
    );
  }

  _expectFileText(
    File('.flutter-version'),
    (text) => text.trim() == _flutterVersion,
    'Flutter version is not pinned to $_flutterVersion',
    failures,
  );
  _expectFileText(
    File('android/app/build.gradle.kts'),
    (text) =>
        text.contains('namespace = "$_applicationId"') &&
        text.contains('applicationId = "$_applicationId"') &&
        text.contains('minSdk = 24') &&
        text.contains('targetSdk = 36') &&
        text.contains('compileSdk = 36'),
    'Android Gradle identity or SDK baseline differs from the lock',
    failures,
  );
  _expectFileText(
    File(
      'android/app/src/main/kotlin/'
      'com/nexttransfer/rmplanner/MainActivity.kt',
    ),
    (text) => text.contains('package $_applicationId'),
    'MainActivity does not use the permanent Android package',
    failures,
  );
  _expectFileText(
    File('android/app/src/main/AndroidManifest.xml'),
    (text) =>
        text.contains('android:label="Next Transfer"') &&
        text.contains('android:allowBackup="false"') &&
        !text.contains('<uses-permission'),
    'Production manifest identity, backup policy, or permission scope changed',
    failures,
  );
  _expectFileText(
    File('pubspec.yaml'),
    (text) {
      const forbidden = <String>[
        'supabase_flutter:',
        'local_auth:',
        'file_picker:',
        'workmanager:',
        'device_calendar:',
        '@insforge',
      ];
      return forbidden.every((package) => !text.contains(package));
    },
    'A VS-02+ or remote package entered the VS-01 dependency set',
    failures,
  );
  _expectFileText(
    File('tool/toolchain.json'),
    (text) {
      final value = jsonDecode(text) as Map<String, Object?>;
      return value['flutter'] == _flutterVersion &&
          value['android_organization'] == _organization &&
          value['android_application_id'] == _applicationId &&
          value['android_min_sdk'] == 24 &&
          value['android_target_sdk'] == 36;
    },
    'tool/toolchain.json differs from the locked baseline',
    failures,
  );

  if (!File('pubspec.lock').existsSync()) {
    failures.add('pubspec.lock is missing');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Authority verification failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Authority verification passed: approved hashes, Flutter pin, '
    'Android identity, permission scope, and VS-01 dependency boundary.',
  );
}

Future<void> _verifyHash(
  File file,
  String expected,
  List<String> failures,
) async {
  if (!file.existsSync()) {
    failures.add('Required approved source is missing: ${file.path}');
    return;
  }
  final actual = (await sha256.bind(file.openRead()).first).toString();
  if (actual != expected) {
    failures.add(
      'Hash mismatch for ${file.path}: expected $expected, found $actual',
    );
  }
}

void _expectFileText(
  File file,
  bool Function(String text) predicate,
  String failure,
  List<String> failures,
) {
  if (!file.existsSync()) {
    failures.add('Required file is missing: ${file.path}');
    return;
  }
  try {
    if (!predicate(file.readAsStringSync())) {
      failures.add(failure);
    }
  } on Object catch (error) {
    failures.add('$failure (${error.runtimeType})');
  }
}

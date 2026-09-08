import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/platform/app_environment.dart';

void main() {
  test('Q1: locked environment names parse deterministically', () {
    for (final value in AppEnvironmentName.values) {
      expect(AppEnvironmentName.parse(value.name), value);
    }
    expect(AppEnvironmentName.parse('unknown'), AppEnvironmentName.local);
  });
}

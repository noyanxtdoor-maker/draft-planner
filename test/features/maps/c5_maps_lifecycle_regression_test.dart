import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('C5 Maps marker subscription is safe outside the build phase', () {
    final source = File('lib/features/maps/presentation/maps_screen.dart')
        .readAsStringSync();

    expect(source, contains('ref.listenManual(mapMarkersProvider'));
    expect(source, isNot(contains('ref.listen(mapMarkersProvider')));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'VS16 M1 minimal Notifications settings keeps controls but removes teaching copy',
    () {
      final source = File(
        'lib/features/settings/presentation/notifications_settings_screen.dart',
      ).readAsStringSync();

      expect(source, contains("key: const Key('notifications-system-toggle')"));
      expect(
        source,
        contains("key: const Key('notifications-reminder-custom')"),
      );
      expect(source, contains('enabled: systemEnabled'));
      expect(source, isNot(contains('Preference only.')));
      expect(source, isNot(contains('Foundation ready.')));
      expect(source, isNot(contains('Allowed by Android')));
      expect(source, isNot(contains('Blocked by Android')));
    },
  );

  test(
    'VS16 owner decision: Snooze Duration row, presets, and Custom path are absent',
    () {
      final source = File(
        'lib/features/settings/presentation/notifications_settings_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        isNot(contains("key: const Key('notifications-snooze-duration')")),
      );
      expect(source, isNot(contains('Snooze duration')));
      expect(source, isNot(contains('Snooze')));
      expect(source, isNot(contains('snooze')));
      expect(source, isNot(contains("_SectionLabel('SNOOZE')")));
    },
  );
}

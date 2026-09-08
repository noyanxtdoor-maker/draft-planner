import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/notifications/application/reconcile_reminders.dart';
import 'package:rmplanner/features/notifications/application/reminder_quiet_hours.dart';
import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(data.initializeTimeZones);
  test('off preserves target', () {
    final target = DateTime.utc(2026, 9, 7, 22);
    expect(
      ReminderQuietHours.delayUntilEnd(
        targetUtc: target,
        settings: const QuietHoursSettings.disabled(),
        location: tz.UTC,
      ),
      target,
    );
  });
  for (final hour in [22, 23, 0, 6]) {
    test('overnight hour $hour delays to next local 07:00', () {
      final target = DateTime.utc(2026, 9, 7, hour);
      expect(
        ReminderQuietHours.delayUntilEnd(
          targetUtc: target,
          settings: const QuietHoursSettings(
            enabled: true,
            startMinute: 1320,
            endMinute: 420,
          ),
          location: tz.UTC,
        ),
        DateTime.utc(2026, 9, hour >= 22 ? 8 : 7, 7),
      );
    });
  }
  test('end boundary is exclusive', () {
    final target = DateTime.utc(2026, 9, 7, 7);
    expect(
      ReminderQuietHours.delayUntilEnd(
        targetUtc: target,
        settings: const QuietHoursSettings(
          enabled: true,
          startMinute: 1320,
          endMinute: 420,
        ),
        location: tz.UTC,
      ),
      target,
    );
  });
  test('normal interval delays within same day', () {
    expect(
      ReminderQuietHours.delayUntilEnd(
        targetUtc: DateTime.utc(2026, 9, 7, 12),
        settings: const QuietHoursSettings(
          enabled: true,
          startMinute: 720,
          endMinute: 780,
        ),
        location: tz.UTC,
      ),
      DateTime.utc(2026, 9, 7, 13),
    );
  });
  test('zone change recomputes end from canonical wall time', () {
    final target = DateTime.utc(2026, 9, 7, 16);
    const settings = QuietHoursSettings(
      enabled: true,
      startMinute: 1320,
      endMinute: 420,
    );
    expect(
      ReminderQuietHours.delayUntilEnd(
        targetUtc: target,
        settings: settings,
        location: tz.getLocation('Asia/Singapore'),
      ),
      DateTime.utc(2026, 9, 7, 23),
    );
    expect(
      ReminderQuietHours.delayUntilEnd(
        targetUtc: target,
        settings: settings,
        location: tz.UTC,
      ),
      target,
    );
  });
  test('DST transition uses local end instead of fixed duration', () {
    expect(
      ReminderQuietHours.delayUntilEnd(
        targetUtc: DateTime.utc(2026, 3, 8, 4),
        settings: const QuietHoursSettings(
          enabled: true,
          startMinute: 1320,
          endMinute: 420,
        ),
        location: tz.getLocation('America/New_York'),
      ),
      DateTime.utc(2026, 3, 8, 11),
    );
  });
  test('overlapping triggers coalesce with one trailing pass', () async {
    final release = Completer<void>();
    var events = 0;
    var tasks = 0;
    final recovery = ReconcileReminders(
      reconcileEvents: () async {
        events++;
        if (events == 1) await release.future;
      },
      reconcileTasks: () async {
        tasks++;
      },
    );
    final first = recovery();
    await Future<void>.delayed(Duration.zero);
    final second = recovery();
    final third = recovery();
    release.complete();
    await Future.wait([first, second, third]);
    expect(events, 2);
    expect(tasks, 2);
  });
  test('failed recovery permits a later retry', () async {
    var calls = 0;
    final recovery = ReconcileReminders(
      reconcileEvents: () async {
        if (++calls == 1) throw StateError('temporary failure');
      },
      reconcileTasks: () async {},
    );
    await expectLater(recovery(), throwsStateError);
    await recovery();
    expect(calls, 2);
  });
}

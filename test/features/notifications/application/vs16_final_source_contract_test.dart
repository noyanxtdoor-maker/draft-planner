import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Event edit hydration resolves occurrence or series policy exactly', () {
    final value = source(
      'lib/features/planner/presentation/calendar_event_form_screen.dart',
    );
    expect(value, contains('.readPolicies('));
    expect(value, contains('ReminderSourceKind.calendarEvent'));
    expect(
      value,
      contains('widget.scope == CalendarEventEditScope.occurrence'),
    );
    expect(value, contains('CalendarEventOccurrenceIdentity.forDate('));
    expect(value, contains('ReminderPolicy.seriesOccurrenceId'));
    expect(
      value,
      contains(
        '_reminderMode = reminderPolicy?.mode ?? ReminderPolicyMode.inherit;',
      ),
    );
    expect(
      value,
      contains('_reminderOffsetMinutes = reminderPolicy?.offsetMinutes;'),
    );
  });

  test('Task edit hydration restores its exact dated policy', () {
    final value = source(
      'lib/features/planner/presentation/task_form_screen.dart',
    );
    expect(value, contains("'task:\${task.id}:\${task.dueDate!.iso8601}'"));
    expect(value, contains('.readPolicies('));
    expect(value, contains('ReminderSourceKind.task'));
    expect(
      value,
      contains(
        '_reminderMode = reminderPolicy?.mode ?? ReminderPolicyMode.inherit;',
      ),
    );
    expect(
      value,
      contains('_reminderOffsetMinutes = reminderPolicy?.offsetMinutes;'),
    );
  });

  test(
    'Task scheduling converts local wall time to UTC and never invents time',
    () {
      final value = source(
        'lib/features/planner/application/planner_providers.dart',
      );
      expect(
        value,
        contains('final startsAtUtc = due == null || minute == null'),
      );
      expect(value, contains('DateTime('));
      expect(value, contains(').toUtc();'));
      expect(value, isNot(contains('DateTime.utc(\n              due.year')));
    },
  );

  test('typed notification taps route only canonical Event and Task IDs', () {
    final value = source('lib/app/next_transfer_app.dart');
    expect(value, contains('NotificationSourceKind.calendarEvent'));
    expect(value, contains('readOccurrenceById('));
    expect(value, contains('occurrenceId: occurrenceId'));
    expect(value, contains('NotificationSourceKind.task'));
    // M3/M4 owner-review correction: planner-first OPEN. Both kinds land on
    // the Planner tab and then present the canonical shared preview over the
    // shell; the exact canonical IDs are still re-read from the repository.
    expect(value, contains('router.go(RoutePaths.planner)'));
    expect(value, contains('showNotificationEventPreview('));
    expect(value, contains('showNotificationTaskPreview('));
    expect(value, contains('eventId: occurrence.eventId'));
    expect(value, contains('taskId: task.id'));
    expect(value, isNot(contains("'\${RoutePaths.tasks}/\${intent.sourceId}'")));
  });
}

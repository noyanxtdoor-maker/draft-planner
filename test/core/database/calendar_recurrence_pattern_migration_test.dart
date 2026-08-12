import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/test_dependencies.dart';

void main() {
  test(
    'Delta 4.2F: v22 to v23 adds only nullable recurrence pattern JSON',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();
      try {
        final version22 = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 22,
        );
        final profile = await buildTestRepository(
          database: version22,
        ).completeOnboarding();
        final now = DateTime.utc(2026, 8, 9, 12);
        await version22
            .into(version22.calendarEvents)
            .insert(
              CalendarEventsCompanion.insert(
                id: '11111111-1111-4111-8111-111111111111',
                profileId: profile.id,
                title: 'Legacy weekly Event',
                timing: 'timed',
                startDate: '2026-08-09',
                startMinute: const Value<int?>(9 * 60),
                endMinute: const Value<int?>(10 * 60),
                timeZoneId: const Value<String?>('Asia/Manila'),
                recurrenceFrequency: const Value<String>('weekly'),
                recurrenceEndMode: const Value<String>('afterCount'),
                recurrenceCount: const Value<int?>(8),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );

        // The current table declaration necessarily contains the newest
        // nullable column even when a test database is created with a schema
        // override. Removing it recreates the exact v22 boundary before the
        // production v23 migration is opened below.
        await version22.customStatement(
          'ALTER TABLE calendar_events DROP COLUMN recurrence_pattern_json',
        );
        await version22.close();

        final version23 = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 23,
        );
        final columns = await version23
            .customSelect('PRAGMA table_info(calendar_events)')
            .get();
        expect(
          columns.map((row) => row.read<String>('name')),
          contains('recurrence_pattern_json'),
        );
        final row = await version23
            .select(version23.calendarEvents)
            .getSingle();
        expect(row.title, 'Legacy weekly Event');
        expect(row.recurrenceFrequency, 'weekly');
        expect(row.recurrenceEndMode, 'afterCount');
        expect(row.recurrenceCount, 8);
        expect(row.recurrencePatternJson, equals(null));
        await version23.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );
}

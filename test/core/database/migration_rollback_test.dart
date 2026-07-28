import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/test_dependencies.dart';

void main() {
  test(
    'AC-A-020 / Q0: failed migration rolls back and preserves prior data',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();

      try {
        final versionOne = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 1,
        );
        final repository = buildTestRepository(database: versionOne);
        final original = await repository.completeOnboarding();
        await versionOne.close();

        final failingVersionTwo = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 2,
          injectMigrationFailure: true,
        );
        await expectLater(
          failingVersionTwo.select(failingVersionTwo.localProfiles).get(),
          throwsA(isA<StateError>()),
        );
        await failingVersionTwo.close();

        final reopenedVersionOne = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 1,
        );
        final profiles = await reopenedVersionOne
            .select(reopenedVersionOne.localProfiles)
            .get();
        final userVersion = await reopenedVersionOne
            .customSelect('PRAGMA user_version')
            .getSingle();
        final privacyTable = await reopenedVersionOne
            .customSelect(
              "SELECT COUNT(*) AS count FROM sqlite_master "
              "WHERE type = 'table' AND name = 'privacy_preferences'",
            )
            .getSingle();

        expect(profiles, hasLength(1));
        expect(profiles.single.id, original.id);
        expect(userVersion.read<int>('user_version'), 1);
        expect(privacyTable.read<int>('count'), 0);
        await reopenedVersionOne.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test(
    'AC-C-011,019 / Q2: v2 upgrades to schema v3 without profile loss',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();

      try {
        final versionTwo = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 2,
        );
        final original = await buildTestRepository(
          database: versionTwo,
        ).completeOnboarding();
        await versionTwo.close();

        final versionThree = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 3,
        );
        final profiles = await versionThree
            .select(versionThree.localProfiles)
            .get();
        final taskRows = await versionThree
            .select(versionThree.plannerTasks)
            .get();
        final userVersion = await versionThree
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(profiles.single.id, original.id);
        expect(taskRows, isEmpty);
        expect(userVersion.read<int>('user_version'), 3);
        await versionThree.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test(
    'AC-C-019 / Q2: failed v3 migration preserves the valid v2 database',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();

      try {
        final versionTwo = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 2,
        );
        final original = await buildTestRepository(
          database: versionTwo,
        ).completeOnboarding();
        await versionTwo.close();

        final failingVersionThree = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 3,
          injectTaskMigrationFailure: true,
        );
        await expectLater(
          failingVersionThree.select(failingVersionThree.localProfiles).get(),
          throwsA(isA<StateError>()),
        );
        await failingVersionThree.close();

        final reopenedVersionTwo = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 2,
        );
        final profiles = await reopenedVersionTwo
            .select(reopenedVersionTwo.localProfiles)
            .get();
        final userVersion = await reopenedVersionTwo
            .customSelect('PRAGMA user_version')
            .getSingle();
        final taskTable = await reopenedVersionTwo
            .customSelect(
              "SELECT COUNT(*) AS count FROM sqlite_master "
              "WHERE type='table' AND name='planner_tasks'",
            )
            .getSingle();

        expect(profiles.single.id, original.id);
        expect(userVersion.read<int>('user_version'), 2);
        expect(taskTable.read<int>('count'), 0);
        await reopenedVersionTwo.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test(
    'AC-E-019,024 / Q2: v3 upgrades to schema v4 without profile or Task loss',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();

      try {
        final versionThree = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 3,
        );
        final original = await buildTestRepository(
          database: versionThree,
        ).completeOnboarding();
        await versionThree.close();

        final versionFour = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 4,
        );
        final profiles = await versionFour
            .select(versionFour.localProfiles)
            .get();
        final eventRows = await versionFour
            .select(versionFour.calendarEvents)
            .get();
        final userVersion = await versionFour
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(profiles.single.id, original.id);
        expect(eventRows, isEmpty);
        expect(userVersion.read<int>('user_version'), 4);
        await versionFour.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test(
    'AC-E-024 / Q2: failed v4 migration preserves the valid v3 database',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();

      try {
        final versionThree = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 3,
        );
        final original = await buildTestRepository(
          database: versionThree,
        ).completeOnboarding();
        await versionThree.close();

        final failingVersionFour = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 4,
          injectCalendarEventMigrationFailure: true,
        );
        await expectLater(
          failingVersionFour.select(failingVersionFour.localProfiles).get(),
          throwsA(isA<StateError>()),
        );
        await failingVersionFour.close();

        final reopenedVersionThree = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 3,
        );
        final profiles = await reopenedVersionThree
            .select(reopenedVersionThree.localProfiles)
            .get();
        final userVersion = await reopenedVersionThree
            .customSelect('PRAGMA user_version')
            .getSingle();
        final eventTable = await reopenedVersionThree
            .customSelect(
              "SELECT COUNT(*) AS count FROM sqlite_master "
              "WHERE type='table' AND name='calendar_events'",
            )
            .getSingle();

        expect(profiles.single.id, original.id);
        expect(userVersion.read<int>('user_version'), 3);
        expect(eventTable.read<int>('count'), 0);
        await reopenedVersionThree.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test(
    'AC-F-018 / Q2: v4 upgrades to schema v5 without prior-data loss',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();
      try {
        final versionFour = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 4,
        );
        final original = await buildTestRepository(
          database: versionFour,
        ).completeOnboarding();
        await versionFour.close();

        final versionFive = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 5,
        );
        expect(
          (await versionFive.select(versionFive.localProfiles).get()).single.id,
          original.id,
        );
        expect(
          await versionFive.select(versionFive.taskEventLinks).get(),
          isEmpty,
        );
        expect(
          (await versionFive.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          5,
        );
        await versionFive.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test(
    'AC-F-018 / Q2: failed v5 migration preserves the valid v4 database',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();
      try {
        final versionFour = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 4,
        );
        final original = await buildTestRepository(
          database: versionFour,
        ).completeOnboarding();
        await versionFour.close();

        final failingVersionFive = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 5,
          injectTaskEventLinkMigrationFailure: true,
        );
        await expectLater(
          failingVersionFive.select(failingVersionFive.localProfiles).get(),
          throwsA(isA<StateError>()),
        );
        await failingVersionFive.close();

        final reopenedVersionFour = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 4,
        );
        expect(
          (await reopenedVersionFour
                  .select(reopenedVersionFour.localProfiles)
                  .get())
              .single
              .id,
          original.id,
        );
        expect(
          (await reopenedVersionFour
                  .customSelect('PRAGMA user_version')
                  .getSingle())
              .read<int>('user_version'),
          4,
        );
        final linkTable = await reopenedVersionFour
            .customSelect(
              "SELECT COUNT(*) AS count FROM sqlite_master "
              "WHERE type='table' AND name='task_event_links'",
            )
            .getSingle();
        expect(linkTable.read<int>('count'), 0);
        await reopenedVersionFour.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test('AC-G-016 / AC-H-020 / Q2: v5 upgrades to schema v6 without prior-data '
      'loss', () async {
    final sqliteDatabase = sqlite3.openInMemory();
    try {
      final versionFive = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 5,
      );
      final original = await buildTestRepository(
        database: versionFive,
      ).completeOnboarding();
      await versionFive.close();

      final versionSix = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 6,
      );
      expect(
        (await versionSix.select(versionSix.localProfiles).get()).single.id,
        original.id,
      );
      expect(await versionSix.select(versionSix.outcomeReports).get(), isEmpty);
      expect(
        await versionSix.select(versionSix.activityLedgerEntries).get(),
        isEmpty,
      );
      expect(
        (await versionSix.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        6,
      );
      await versionSix.close();
    } finally {
      sqliteDatabase.close();
    }
  });

  test('AC-G-016 / AC-H-020 / Q2: failed v6 migration preserves the valid v5 '
      'database', () async {
    final sqliteDatabase = sqlite3.openInMemory();
    try {
      final versionFive = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 5,
      );
      final original = await buildTestRepository(
        database: versionFive,
      ).completeOnboarding();
      await versionFive.close();

      final failingVersionSix = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 6,
        injectOutcomeReportingMigrationFailure: true,
      );
      await expectLater(
        failingVersionSix.select(failingVersionSix.localProfiles).get(),
        throwsA(isA<StateError>()),
      );
      await failingVersionSix.close();

      final reopenedVersionFive = AppDatabase.forTesting(
        NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
        schemaVersionOverride: 5,
      );
      expect(
        (await reopenedVersionFive
                .select(reopenedVersionFive.localProfiles)
                .get())
            .single
            .id,
        original.id,
      );
      expect(
        (await reopenedVersionFive
                .customSelect('PRAGMA user_version')
                .getSingle())
            .read<int>('user_version'),
        5,
      );
      final reportTable = await reopenedVersionFive
          .customSelect(
            "SELECT COUNT(*) AS count FROM sqlite_master "
            "WHERE type='table' AND name='outcome_reports'",
          )
          .getSingle();
      final ledgerTable = await reopenedVersionFive
          .customSelect(
            "SELECT COUNT(*) AS count FROM sqlite_master "
            "WHERE type='table' AND name='activity_ledger_entries'",
          )
          .getSingle();
      expect(reportTable.read<int>('count'), 0);
      expect(ledgerTable.read<int>('count'), 0);
      await reopenedVersionFive.close();
    } finally {
      sqliteDatabase.close();
    }
  });

  test(
    'AC-B-004 / Q2: v6 upgrades to schema v7 without prior-data loss',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();
      try {
        final versionSix = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 6,
        );
        final original = await buildTestRepository(
          database: versionSix,
        ).completeOnboarding();
        await versionSix.close();

        final versionSeven = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 7,
        );
        expect(
          (await versionSeven.select(versionSeven.localProfiles).get())
              .single
              .id,
          original.id,
        );
        expect(
          await versionSeven
              .select(versionSeven.weeklyIndicatorTargetRevisions)
              .get(),
          isEmpty,
        );
        expect(
          (await versionSeven.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          7,
        );
        await versionSeven.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );

  test(
    'AC-B-004 / Q2: failed v7 migration preserves the valid v6 database',
    () async {
      final sqliteDatabase = sqlite3.openInMemory();
      try {
        final versionSix = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 6,
        );
        final original = await buildTestRepository(
          database: versionSix,
        ).completeOnboarding();
        await versionSix.close();

        final failingVersionSeven = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 7,
          injectIndicatorMigrationFailure: true,
        );
        await expectLater(
          failingVersionSeven.select(failingVersionSeven.localProfiles).get(),
          throwsA(isA<StateError>()),
        );
        await failingVersionSeven.close();

        final reopenedVersionSix = AppDatabase.forTesting(
          NativeDatabase.opened(sqliteDatabase, closeUnderlyingOnClose: false),
          schemaVersionOverride: 6,
        );
        expect(
          (await reopenedVersionSix
                  .select(reopenedVersionSix.localProfiles)
                  .get())
              .single
              .id,
          original.id,
        );
        expect(
          (await reopenedVersionSix
                  .customSelect('PRAGMA user_version')
                  .getSingle())
              .read<int>('user_version'),
          6,
        );
        final targetTable = await reopenedVersionSix
            .customSelect(
              "SELECT COUNT(*) AS count FROM sqlite_master "
              "WHERE type='table' AND "
              "name='weekly_indicator_target_revisions'",
            )
            .getSingle();
        expect(targetTable.read<int>('count'), 0);
        await reopenedVersionSix.close();
      } finally {
        sqliteDatabase.close();
      }
    },
  );
}

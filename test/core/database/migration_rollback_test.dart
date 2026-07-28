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
}

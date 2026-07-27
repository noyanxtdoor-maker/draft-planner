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
}

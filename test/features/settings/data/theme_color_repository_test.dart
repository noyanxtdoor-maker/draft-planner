import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';
import 'package:rmplanner/features/settings/data/drift_appearance_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../../support/test_dependencies.dart';

void main() {
  group('B2-FINAL-POLISH ThemeColorMode / schema v26 / DARK+BLUE default', () {
    test('ThemeColorMode exists with rose and blue and BLUE default', () {
      expect(ThemeColorMode.values, containsAll(<ThemeColorMode>[
        ThemeColorMode.rose,
        ThemeColorMode.blue,
      ]));
      expect(ThemeColorMode.fromStorage('rose'), ThemeColorMode.rose);
      expect(ThemeColorMode.fromStorage('blue'), ThemeColorMode.blue);
      // Locked: invalid/unknown/null Theme Color falls back to BLUE.
      expect(ThemeColorMode.fromStorage('neon'), ThemeColorMode.blue);
      expect(ThemeColorMode.fromStorage(null), ThemeColorMode.blue);
      expect(ThemeColorMode.rose.storageName, 'rose');
      expect(ThemeColorMode.blue.storageName, 'blue');
    });

    test('AppearanceMode invalid/unknown/null falls back to DARK', () {
      expect(AppearanceMode.fromStorage('dark'), AppearanceMode.dark);
      expect(AppearanceMode.fromStorage('light'), AppearanceMode.light);
      expect(AppearanceMode.fromStorage('system'), AppearanceMode.system);
      // Locked: invalid/unknown/null Appearance falls back to DARK.
      expect(AppearanceMode.fromStorage('neon'), AppearanceMode.dark);
      expect(AppearanceMode.fromStorage(null), AppearanceMode.dark);
    });

    test('fresh v26 database has schema 26, no appearance row (reads DARK+BLUE)',
        () async {
      final sqliteDatabase = sqlite.sqlite3.openInMemory();
      try {
        final database = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
          schemaVersionOverride: 26,
        );
        addTearDown(database.close);

        final userVersion = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(userVersion.read<int>('user_version'), 26);

        final repository = DriftAppearanceRepository(
          database: database,
          clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
        );
        expect(await repository.readAppearance(), AppearanceMode.dark);
        expect(await repository.readThemeColor(), ThemeColorMode.blue);
      } finally {
        sqliteDatabase.close();
      }
    });

    test('v25 database migrates to v26 adding theme_color defaulting to BLUE '
        'and preserving the valid appearance', () async {
      final sqliteDatabase = sqlite.sqlite3.openInMemory();
      try {
        // Build a GENUINE v25 database: drop the drift-created table (which
        // already carries theme_color from the current generated schema) and
        // recreate it with the exact pre-correction v25 definition so the
        // ALTER TABLE migration step is actually exercised.
        final version25 = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
          schemaVersionOverride: 25,
        );
        await version25.customStatement(
          'DROP TABLE appearance_preferences',
        );
        await version25.customStatement(
          "CREATE TABLE appearance_preferences ("
          "key TEXT NOT NULL PRIMARY KEY DEFAULT 'primary', "
          "appearance_mode TEXT NOT NULL DEFAULT 'system', "
          "updated_at_utc INTEGER NOT NULL)",
        );
        await version25.customStatement(
          "INSERT INTO appearance_preferences "
          "(key, appearance_mode, updated_at_utc) "
          "VALUES ('primary', 'light', 1786708800)",
        );
        await version25.close();

        final version26 = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
          schemaVersionOverride: 26,
        );
        addTearDown(version26.close);

        final userVersion = await version26
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(userVersion.read<int>('user_version'), 26);

        final row = await (version26.select(version26.appearancePreferences))
            .getSingle();
        expect(row.key, 'primary');
        expect(row.appearanceMode, 'light');
        expect(row.themeColor, 'blue');

        final repository = DriftAppearanceRepository(
          database: version26,
          clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
        );
        // Appearance Mode survived; Theme Color defaulted to BLUE.
        expect(await repository.readAppearance(), AppearanceMode.light);
        expect(await repository.readThemeColor(), ThemeColorMode.blue);
      } finally {
        sqliteDatabase.close();
      }
    });

    test('existing v26 light|rose and system|blue rows stay untouched', () async {
      final sqliteDatabase = sqlite.sqlite3.openInMemory();
      try {
        final database = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
          schemaVersionOverride: 26,
        );
        addTearDown(database.close);
        final repository = DriftAppearanceRepository(
          database: database,
          clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
        );
        // Write a valid light|rose and prove it round-trips.
        await repository.saveAppearance(AppearanceMode.light);
        await repository.saveThemeColor(ThemeColorMode.rose);
        expect(await repository.readAppearance(), AppearanceMode.light);
        expect(await repository.readThemeColor(), ThemeColorMode.rose);
        // Then system|blue.
        await repository.saveAppearance(AppearanceMode.system);
        await repository.saveThemeColor(ThemeColorMode.blue);
        expect(await repository.readAppearance(), AppearanceMode.system);
        expect(await repository.readThemeColor(), ThemeColorMode.blue);
      } finally {
        sqliteDatabase.close();
      }
    });

    test('blue -> rose -> blue persistence and invalid fails safe', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
      );
      expect(await repository.readThemeColor(), ThemeColorMode.blue);
      await repository.saveThemeColor(ThemeColorMode.rose);
      expect(await repository.readThemeColor(), ThemeColorMode.rose);
      await repository.saveThemeColor(ThemeColorMode.blue);
      expect(await repository.readThemeColor(), ThemeColorMode.blue);

      // Invalid stored string fails safely to BLUE.
      await database.into(database.appearancePreferences).insertOnConflictUpdate(
            AppearancePreferencesCompanion.insert(
              key: const Value<String>('primary'),
              appearanceMode: const Value<String>('dark'),
              themeColor: const Value<String>('neon'),
              updatedAtUtc: DateTime.utc(2026, 8, 14, 12),
            ),
          );
      expect(await repository.readThemeColor(), ThemeColorMode.blue);
    });

    test('persisted blue survives database reopen (relaunch)', () async {
      final sqliteDatabase = sqlite.sqlite3.openInMemory();
      try {
        final first = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
        );
        final firstRepository = DriftAppearanceRepository(
          database: first,
          clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
        );
        await firstRepository.saveAppearance(AppearanceMode.light);
        await firstRepository.saveThemeColor(ThemeColorMode.blue);
        await first.close();

        final second = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
        );
        addTearDown(second.close);
        final secondRepository = DriftAppearanceRepository(
          database: second,
          clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
        );
        expect(await secondRepository.readAppearance(), AppearanceMode.light);
        expect(await secondRepository.readThemeColor(), ThemeColorMode.blue);
      } finally {
        sqliteDatabase.close();
      }
    });

    test('theme color is independent of appearance mode', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
      );
      // Fresh defaults: DARK + BLUE.
      expect(await repository.readAppearance(), AppearanceMode.dark);
      expect(await repository.readThemeColor(), ThemeColorMode.blue);
      // Changing Appearance never touches Theme Color and vice versa.
      await repository.saveAppearance(AppearanceMode.light);
      expect(await repository.readThemeColor(), ThemeColorMode.blue);
      await repository.saveThemeColor(ThemeColorMode.rose);
      expect(await repository.readAppearance(), AppearanceMode.light);
      await repository.saveAppearance(AppearanceMode.dark);
      expect(await repository.readThemeColor(), ThemeColorMode.rose);
    });

    test('missing-row insert yields DARK+BLUE (never clobbers the other '
        'dimension)', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 14, 12)),
      );
      // First-ever write of one dimension must carry the locked default of
      // the other dimension (not reset it).
      await repository.saveAppearance(AppearanceMode.light);
      final row = await (database.select(database.appearancePreferences))
          .getSingle();
      expect(row.appearanceMode, 'light');
      expect(row.themeColor, 'blue');
      expect(await repository.readThemeColor(), ThemeColorMode.blue);

      await database
          .delete(database.appearancePreferences)
          .go();
      await repository.saveThemeColor(ThemeColorMode.rose);
      final row2 = await (database.select(database.appearancePreferences))
          .getSingle();
      expect(row2.themeColor, 'rose');
      expect(row2.appearanceMode, 'dark');
      expect(await repository.readAppearance(), AppearanceMode.dark);
    });
  });
}

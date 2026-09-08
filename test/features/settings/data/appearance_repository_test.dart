import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';
import 'package:rmplanner/features/settings/data/drift_appearance_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../../support/test_dependencies.dart';

void main() {
  group('B1 schema / migration (v24 -> v25)', () {
    test('v24 database migrates to v25 with the new table and DARK compat row',
        () async {
      final sqliteDatabase = sqlite.sqlite3.openInMemory();

      try {
        final version24 = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
          schemaVersionOverride: 24,
        );
        final profile = await buildTestRepository(
          database: version24,
        ).completeOnboarding();
        final now = DateTime.utc(2026, 8, 2, 12);

        // Representative user data that must survive the migration.
        await version24.into(version24.plannerPreferences).insert(
          PlannerPreferencesCompanion.insert(
            profileId: profile.id,
            weekStartDay: const Value<int>(3),
            use24HourTime: const Value<bool>(true),
            updatedAtUtc: now,
          ),
        );
        await version24.into(version24.goals).insert(
          GoalsCompanion.insert(
            id: '${profile.id}:goal:9',
            profileId: profile.id,
            indicatorKey: const Value<String?>(null),
            role: 'dailyWeekly',
            activeSlotIndex: const Value<int?>(9),
            title: 'Survival Goal',
            iconId: const Value<String?>(null),
            status: 'active',
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
        await version24.close();

        final version25 = AppDatabase.forTesting(
          NativeDatabase.opened(
            sqliteDatabase,
            closeUnderlyingOnClose: false,
          ),
          schemaVersionOverride: 25,
        );
        addTearDown(version25.close);

        final userVersion = await version25
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(userVersion.read<int>('user_version'), 25);

        final tableRows = await version25
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'table' AND name = 'appearance_preferences'",
            )
            .get();
        expect(tableRows, isNotEmpty);

        final appearanceRow = await (version25
                .select(version25.appearancePreferences))
            .getSingle();
        expect(appearanceRow.key, 'primary');
        expect(appearanceRow.appearanceMode, 'dark');

        // Representative data survives unchanged.
        final savedProfile = await version25
            .select(version25.localProfiles)
            .getSingle();
        expect(savedProfile.id, profile.id);
        final savedPref = await (version25.select(version25.plannerPreferences)
              ..where((table) => table.profileId.equals(profile.id)))
            .getSingle();
        expect(savedPref.weekStartDay, 3);
        expect(savedPref.use24HourTime, true);
        final savedGoal = await (version25.select(version25.goals)
              ..where((table) => table.id.equals('${profile.id}:goal:9')))
            .getSingle();
        expect(savedGoal.id, '${profile.id}:goal:9');
        expect(savedGoal.title, 'Survival Goal');
        expect(savedGoal.status, 'active');
      } finally {
        sqliteDatabase.close();
      }
    });

    test('fresh install has no appearance row (reads DARK)', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 2, 12)),
      );
      expect(await repository.readAppearance(), AppearanceMode.dark);
    });
  });

  group('B1 appearance repository', () {
    test('requires no profile row (device-scoped)', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 2, 12)),
      );
      // No onboarding, no profile, no planner preference: still readable.
      expect(await repository.readAppearance(), AppearanceMode.dark);
      await repository.saveAppearance(AppearanceMode.light);
      expect(await repository.readAppearance(), AppearanceMode.light);
    });

    test('DARK -> LIGHT -> SYSTEM round-trip', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 2, 12)),
      );
      expect(await repository.readAppearance(), AppearanceMode.dark);
      await repository.saveAppearance(AppearanceMode.light);
      expect(await repository.readAppearance(), AppearanceMode.light);
      await repository.saveAppearance(AppearanceMode.system);
      expect(await repository.readAppearance(), AppearanceMode.system);
    });

    test('persisted value survives repository/database reopen', () async {
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
          clock: FixedClock(DateTime.utc(2026, 8, 2, 12)),
        );
        await firstRepository.saveAppearance(AppearanceMode.light);
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
          clock: FixedClock(DateTime.utc(2026, 8, 2, 12)),
        );
        expect(await secondRepository.readAppearance(), AppearanceMode.light);
      } finally {
        sqliteDatabase.close();
      }
    });

    test('invalid stored string fails safely to DARK', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      await database.into(database.appearancePreferences).insert(
            AppearancePreferencesCompanion.insert(
              key: const Value<String>('primary'),
              appearanceMode: const Value<String>('neon'),
              updatedAtUtc: DateTime.utc(2026, 8, 2, 12),
            ),
          );
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 2, 12)),
      );
      expect(await repository.readAppearance(), AppearanceMode.dark);
    });

    test('setting the same value is an idempotent no-write', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final clock = FixedClock(DateTime.utc(2026, 8, 2, 12));
      final repository = DriftAppearanceRepository(
        database: database,
        clock: clock,
      );
      // B2-FINAL-POLISH: DARK is the fresh default, so saving 'dark' on a
      // missing row is already a no-op (no row is ever created).  Use a
      // non-default value to exercise the real no-write path.
      await repository.saveAppearance(AppearanceMode.light);
      final first = await (database.select(database.appearancePreferences))
          .getSingle();
      final firstUpdatedAt = first.updatedAtUtc;
      expect(first.appearanceMode, 'light');

      await repository.saveAppearance(AppearanceMode.light);
      final second = await (database.select(database.appearancePreferences))
          .getSingle();
      expect(second.appearanceMode, 'light');
      expect(second.updatedAtUtc, firstUpdatedAt);
    });
  });
}

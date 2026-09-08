import 'package:drift/drift.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';

/// Drift-backed, device-scoped Appearance repository (Pack B1 + B2-CORRECTION).
///
/// Reads and writes the single-row `AppearancePreferences` table keyed by
/// the constant 'primary'.  A missing row (fresh v26 install) reads as
/// [AppearanceMode.dark] / [ThemeColorMode.blue] (B2-FINAL-POLISH owner
/// lock); an invalid persisted string fails safely to the same defaults;
/// setting the current value again is an idempotent no-write.
final class DriftAppearanceRepository implements AppearanceRepository {
  const DriftAppearanceRepository({
    required this.database,
    required this.clock,
  });

  final AppDatabase database;
  final AppClock clock;

  @override
  Future<AppearanceMode> readAppearance() async {
    final row = await (database.select(database.appearancePreferences))
        .getSingleOrNull();
    if (row == null) {
      return AppearanceMode.dark;
    }
    return AppearanceMode.fromStorage(row.appearanceMode);
  }

  @override
  Future<void> saveAppearance(AppearanceMode mode) async {
    if (await readAppearance() == mode) {
      // Idempotent: persisting the same value is a no-write, so
      // updated_at_utc only moves on a real change.
      return;
    }
    // Preserve the independent Theme Color: a fresh row must not reset it to
    // its column default, and an existing row must keep its value.
    final row = await (database.select(database.appearancePreferences))
        .getSingleOrNull();
    await database
        .into(database.appearancePreferences)
        .insertOnConflictUpdate(
          AppearancePreferencesCompanion.insert(
            key: const Value<String>('primary'),
            appearanceMode: Value<String>(mode.storageName),
            themeColor: Value<String>(
              row?.themeColor ?? ThemeColorMode.blue.storageName,
            ),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
  }

  @override
  Future<ThemeColorMode> readThemeColor() async {
    final row = await (database.select(database.appearancePreferences))
        .getSingleOrNull();
    if (row == null) {
      return ThemeColorMode.blue;
    }
    return ThemeColorMode.fromStorage(row.themeColor);
  }

  @override
  Future<void> saveThemeColor(ThemeColorMode color) async {
    if (await readThemeColor() == color) {
      // Idempotent: persisting the same value is a no-write, so
      // updated_at_utc only moves on a real change.
      return;
    }
    // Preserve the independent Appearance Mode: a fresh row must not reset
    // it to its column default, and an existing row must keep its value.
    final row = await (database.select(database.appearancePreferences))
        .getSingleOrNull();
    await database
        .into(database.appearancePreferences)
        .insertOnConflictUpdate(
          AppearancePreferencesCompanion.insert(
            key: const Value<String>('primary'),
            appearanceMode: Value<String>(
              row?.appearanceMode ?? AppearanceMode.dark.storageName,
            ),
            themeColor: Value<String>(color.storageName),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
  }
}

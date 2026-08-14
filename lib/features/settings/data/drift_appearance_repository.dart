import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';

/// Drift-backed, device-scoped Appearance repository (Pack B1).
///
/// Reads and writes the single-row `AppearancePreferences` table keyed by
/// the constant 'primary'.  A missing row (fresh v25 install) reads as
/// [AppearanceMode.system]; an invalid persisted string fails safely to
/// system; setting the current value again is an idempotent no-write.
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
      return AppearanceMode.system;
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
    await database
        .into(database.appearancePreferences)
        .insertOnConflictUpdate(
          AppearancePreferencesCompanion.insert(
            key: const Value<String>('primary'),
            appearanceMode: Value<String>(mode.storageName),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
  }
}

import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/settings/application/start_of_week_repository.dart';

final class DriftStartOfWeekRepository implements StartOfWeekRepository {
  const DriftStartOfWeekRepository({required this.database, required this.clock});

  final AppDatabase database;
  final AppClock clock;

  @override
  Future<int> readStartOfWeek({required String profileId}) async {
    final row = await (database.select(database.plannerPreferences)
          ..where((table) => table.profileId.equals(profileId)))
        .getSingleOrNull();
    final value = row?.weekStartDay;
    if (value == null) {
      return DateTime.monday;
    }
    if (value < DateTime.monday || value > DateTime.sunday) {
      return DateTime.monday;
    }
    return value;
  }

  @override
  Future<void> saveStartOfWeek({
    required String profileId,
    required int startDay,
  }) async {
    if (startDay < DateTime.monday || startDay > DateTime.sunday) {
      throw ArgumentError.value(startDay, 'startDay', 'Must be 1..7');
    }
    await database
        .into(database.plannerPreferences)
        .insertOnConflictUpdate(
          PlannerPreferencesCompanion.insert(
            profileId: profileId,
            weekStartDay: Value<int>(startDay),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
  }
}

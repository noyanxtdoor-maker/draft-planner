import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/settings/data/drift_start_of_week_repository.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test('defaults to Monday when no preference row exists', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final repository = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    expect(
      await repository.readStartOfWeek(profileId: profile.id),
      DateTime.monday,
    );
  });

  test('persists a non-Monday value and reads it back', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final repository = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    await repository.saveStartOfWeek(
      profileId: profile.id,
      startDay: DateTime.sunday,
    );
    expect(
      await repository.readStartOfWeek(profileId: profile.id),
      DateTime.sunday,
    );
  });

  test('is scoped per Local Profile', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profileA = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final now = DateTime.utc(2026, 7, 27, 12);
    // A second Local Profile with a distinct slot (the primary slot is unique).
    await database.into(database.localProfiles).insert(
      LocalProfilesCompanion.insert(
        id: 'profile-b',
        slot: const Value<String>('secondary'),
        localName: 'Profile B',
        timeZoneId: const Value<String?>(null),
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    final repository = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(now),
    );
    await repository.saveStartOfWeek(
      profileId: profileA.id,
      startDay: DateTime.wednesday,
    );
    expect(
      await repository.readStartOfWeek(profileId: profileA.id),
      DateTime.wednesday,
    );
    // The other profile has no row -> Monday.
    expect(
      await repository.readStartOfWeek(profileId: 'profile-b'),
      DateTime.monday,
    );
  });

  test('rejects an invalid day', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final repository = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    expect(
      () => repository.saveStartOfWeek(profileId: profile.id, startDay: 0),
      throwsArgumentError,
    );
    expect(
      () => repository.saveStartOfWeek(profileId: profile.id, startDay: 8),
      throwsArgumentError,
    );
  });

  test('survives database recreation (persistence across restart)', () async {
    final database = openMemoryDatabase();
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final repository = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    await repository.saveStartOfWeek(
      profileId: profile.id,
      startDay: DateTime.saturday,
    );
    // Re-open the same database through a fresh repository instance.
    final reopened = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 12)),
    );
    expect(
      await reopened.readStartOfWeek(profileId: profile.id),
      DateTime.saturday,
    );
    addTearDown(database.close);
  });
}

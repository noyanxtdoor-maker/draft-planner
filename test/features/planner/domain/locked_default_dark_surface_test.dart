import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

import '../../../support/test_dependencies.dart';

/// Final locked-default correction contract (final correction pack 02):
/// - Budget Review  accent #BFA384 unchanged, surface -> #575048
/// - Ministering Visit accent #B0A971 unchanged, surface -> #565448
/// - fresh/fallback/restore resolve the dark pairs
/// - exact OLD locked light pairs upgrade on repository read (existing
///   recommended repair)
/// - arbitrary manual same-accent surfaces survive
/// - new dark pairs survive
/// - unrelated locked defaults and Job stay unchanged
/// - schema/user_version stays 24
void main() {
  late AppDatabase database;
  late DriftEventTypeRepository repository;
  late String profileId;

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    repository = DriftEventTypeRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 13, 12)),
    );
  });

  tearDown(() => database.close());

  Future<EventType> typeOf(String stableKey) async {
    final types = await repository.readEventTypes(profileId: profileId);
    return types.singleWhere((type) => type.stableKey == stableKey);
  }

  test('Budget Review default pair joins the dark family', () async {
    final budget = await typeOf(SystemEventTypeKeys.budgetReview);
    expect(budget.colorValue, 0xFFBFA384);
    expect(
      PlannerEventColorDefaults.budgetReview.accentArgb,
      0xFFBFA384,
      reason: 'the Budget Review accent must not change',
    );
    expect(
      PlannerEventColorDefaults.budgetReview.surfaceArgb,
      0xFF575048,
      reason: 'Budget Review must resolve its dark partner as the default',
    );
    expect(
      PlannerEventColorDefaults.forEventType(budget).surfaceArgb,
      0xFF575048,
      reason: 'the type fallback must use the dark pair',
    );
  });

  test('Ministering Visit default pair joins the dark family', () async {
    final ministering = await typeOf(
      SystemEventTypeKeys.meaningfulConnection,
    );
    expect(ministering.colorValue, 0xFFB0A971);
    expect(
      PlannerEventColorDefaults.ministeringVisit.accentArgb,
      0xFFB0A971,
      reason: 'the Ministering Visit accent must not change',
    );
    expect(
      PlannerEventColorDefaults.ministeringVisit.surfaceArgb,
      0xFF565448,
      reason: 'Ministering Visit must resolve its dark partner as the default',
    );
    expect(
      PlannerEventColorDefaults.forEventType(ministering).surfaceArgb,
      0xFF565448,
      reason: 'the type fallback must use the dark pair',
    );
  });

  test('restore-default path resolves the dark pairs', () async {
    // A user had customized colors; Restore Event Color Defaults clears the
    // document, so the renderer falls back to the defaults (dark pairs).
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.budgetReview,
      preference: const EventColorPreference(
        accentArgb: 0xFF123456,
        surfaceArgb: 0xFFABCDEF,
      ),
    );
    await repository.restoreEventColorDefaults(profileId: profileId);

    final restored = await repository.readEventColorPreferences(
      profileId: profileId,
    );
    expect(restored, isEmpty);
    final budget = await typeOf(SystemEventTypeKeys.budgetReview);
    final ministering = await typeOf(
      SystemEventTypeKeys.meaningfulConnection,
    );
    expect(
      PlannerEventColorDefaults.forEventType(budget).surfaceArgb,
      0xFF575048,
    );
    expect(
      PlannerEventColorDefaults.forEventType(ministering).surfaceArgb,
      0xFF565448,
    );
  });

  test('exact OLD locked light pairs upgrade to the dark partners on read',
      () async {
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.budgetReview,
      preference: const EventColorPreference(
        accentArgb: 0xFFBFA384,
        surfaceArgb: 0xFF8A7E72,
      ),
    );
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.meaningfulConnection,
      preference: const EventColorPreference(
        accentArgb: 0xFFB0A971,
        surfaceArgb: 0xFF7D7B6A,
      ),
    );

    final healed = await repository.readEventColorPreferences(
      profileId: profileId,
    );
    expect(
      healed[SystemEventTypeKeys.budgetReview]?.surfaceArgb,
      0xFF575048,
      reason: 'the exact old locked light Budget Review pair must upgrade',
    );
    expect(
      healed[SystemEventTypeKeys.meaningfulConnection]?.surfaceArgb,
      0xFF565448,
      reason: 'the exact old locked light Ministering Visit pair must upgrade',
    );
    // Upgraded pairs are persisted and idempotent.
    final again = await repository.readEventColorPreferences(
      profileId: profileId,
    );
    expect(
      again[SystemEventTypeKeys.budgetReview],
      healed[SystemEventTypeKeys.budgetReview],
    );
    expect(
      again[SystemEventTypeKeys.meaningfulConnection],
      healed[SystemEventTypeKeys.meaningfulConnection],
    );
  });

  test('arbitrary manual surfaces for the same accents survive read', () async {
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.budgetReview,
      preference: const EventColorPreference(
        accentArgb: 0xFFBFA384,
        surfaceArgb: 0xFF112233,
      ),
    );
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.meaningfulConnection,
      preference: const EventColorPreference(
        accentArgb: 0xFFB0A971,
        surfaceArgb: 0xFF445566,
      ),
    );

    final read = await repository.readEventColorPreferences(
      profileId: profileId,
    );
    expect(
      read[SystemEventTypeKeys.budgetReview]?.surfaceArgb,
      0xFF112233,
      reason: 'a manual Budget Review surface must never be overwritten',
    );
    expect(
      read[SystemEventTypeKeys.meaningfulConnection]?.surfaceArgb,
      0xFF445566,
      reason: 'a manual Ministering Visit surface must never be overwritten',
    );
  });

  test('new dark pairs survive repository reads', () async {
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.budgetReview,
      preference: const EventColorPreference(
        accentArgb: 0xFFBFA384,
        surfaceArgb: 0xFF575048,
      ),
    );
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.meaningfulConnection,
      preference: const EventColorPreference(
        accentArgb: 0xFFB0A971,
        surfaceArgb: 0xFF565448,
      ),
    );

    final read = await repository.readEventColorPreferences(
      profileId: profileId,
    );
    expect(
      read[SystemEventTypeKeys.budgetReview],
      const EventColorPreference(accentArgb: 0xFFBFA384, surfaceArgb: 0xFF575048),
    );
    expect(
      read[SystemEventTypeKeys.meaningfulConnection],
      const EventColorPreference(accentArgb: 0xFFB0A971, surfaceArgb: 0xFF565448),
    );
  });

  test('unrelated locked defaults remain unchanged', () async {
    expect(
      PlannerEventColorDefaults.lockedJobApplication.surfaceArgb,
      0xFF4C4942,
    );
    expect(
      PlannerEventColorDefaults.lockedScriptureStudy.surfaceArgb,
      0xFF4C464A,
    );
    expect(
      PlannerEventColorDefaults.lockedExercise.surfaceArgb,
      0xFF474141,
    );
    expect(
      PlannerEventColorDefaults.lockedTempleVisit.surfaceArgb,
      0xFF454B4B,
    );
  });

  test('Job remains exactly #EBC766/#4C4942', () async {
    final job = await typeOf(SystemEventTypeKeys.jobApplication);
    expect(job.colorValue, 0xFFEBC766);
    expect(
      PlannerEventColorDefaults.forEventType(job),
      const EventColorPreference(accentArgb: 0xFFEBC766, surfaceArgb: 0xFF4C4942),
      reason: 'Job color fidelity is locked — the pair must stay exact',
    );
  });

  test('schema user_version stays 28 (v28 = MAPS V1 coordinate columns)',
      () async {
    // Pack B1 added the AppearancePreferences table (v24 -> v25);
    // B2-CORRECTION added the themeColor column (v25 -> v26);
    // B3.2 added the direct Task Goal + contact-link columns (v26 -> v27);
    // MAPS V1 added additive Contact/Event coordinate columns (v27 -> v28).
    final version = await database.customSelect(
      'PRAGMA user_version',
    ).getSingle();
    expect(version.read<int>('user_version'), 28);
  });
}

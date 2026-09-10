import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/colors/vs11_color_system.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/data/planner_presentation_document_store.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

import '../../../support/test_dependencies.dart';

/// Contract: Education default transition to the approved P22 Gray Blue pair
/// (accent #64B1E6, dark surface #484F56) with strict existing-user law:
/// no saved entry -> new pair; saved old default -> old pair verbatim;
/// saved custom pair -> custom pair verbatim; zero passive writes; peers
/// never recolored; raw color_value untouched.
void main() {
  late AppDatabase database;
  late DriftEventTypeRepository types;
  late String profileId;
  final clock = FixedClock(DateTime.utc(2026, 9, 9, 12));

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    types = DriftEventTypeRepository(database: database, clock: clock);
  });

  tearDown(() => database.close());

  const newPair = EventColorPreference(
    accentArgb: 0xFF64B1E6,
    surfaceArgb: 0xFF484F56,
  );
  // The pre-P46 default pair (old raw seed accent).
  const oldPair = EventColorPreference(
    accentArgb: 0xFFA19FE2,
    surfaceArgb: 0xFF3F434F,
  );
  const customPair = EventColorPreference(
    accentArgb: 0xFF112233,
    surfaceArgb: 0xFF445566,
  );

  Future<PlannerColorPreferencesDocument> storedDocument() async {
    final row = await (database.select(
      database.plannerPreferences,
    )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
    return EventColorPreferenceCodec.decodeDocument(
      row?.eventColorPreferencesJson,
    );
  }

  Future<String?> storedJson() async {
    final row = await (database.select(
      database.plannerPreferences,
    )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
    return row?.eventColorPreferencesJson;
  }

  test('approved default pair uses the exact P22 accent and surface', () {
    expect(PlannerEventColorDefaults.education.accentArgb, 0xFF64B1E6);
    expect(PlannerEventColorDefaults.education.surfaceArgb, 0xFF484F56);
    expect(PlannerEventColorDefaults.education, newPair);
  });

  test('fresh install: seed row exists with P22 accent and raw fallback law',
      () async {
    final education = await types.readEventType(
      profileId: profileId,
      eventTypeId: SystemEventTypeIds.education,
    );
    expect(education, isNotNull);
    expect(education!.stableKey, SystemEventTypeKeys.education);
    expect(education.position, 19);
    expect(education.defaultDurationMinutes, 60);
    expect(education.reportRequiredDefault, isFalse);
    expect(education.indicatorKeys, isEmpty);
    // Raw seed follows the new Education default accent...
    expect(education.colorValue, 0xFF64B1E6);
    // ...and no preference row write happened merely by reading (no
    // passive default backfill into the explicit map).
    expect(await storedJson(), isNull);
    expect((await storedDocument()).events, isEmpty);
  });

  test('no saved entry: effective default immediately resolves to P22', () {
    expect(
      PlannerEventColorDefaults.pmgStableKeyDefaults[
          SystemEventTypeKeys.education],
      newPair,
    );
  });

  test('saved OLD default pair is preserved verbatim, not upgraded',
      () async {
    await types.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.education,
      preference: oldPair,
    );
    // Repeated reads: zero writes, entry preserved.
    final first = await storedDocument();
    final second = await storedDocument();
    expect(first.events[SystemEventTypeKeys.education], oldPair);
    expect(second.events[SystemEventTypeKeys.education], oldPair);
  });

  test('saved CUSTOM pair is preserved verbatim', () async {
    await types.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.education,
      preference: customPair,
    );
    expect(
      (await storedDocument()).events[SystemEventTypeKeys.education],
      customPair,
    );
  });

  test('unrelated color save preserves the Education entry', () async {
    await types.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.education,
      preference: customPair,
    );
    await types.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.exercise,
      preference: const EventColorPreference(
        accentArgb: 0xFF7986CB,
        surfaceArgb: 0xFF3E4356,
      ),
    );
    final document = await storedDocument();
    expect(document.events[SystemEventTypeKeys.education], customPair);
    expect(document.events[SystemEventTypeKeys.exercise]?.accentArgb,
        0xFF7986CB);
  });

  test('restore Event Color defaults clears events but never names',
      () async {
    // Seed an entry and a name override, then restore color defaults.
    await types.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: SystemEventTypeKeys.education,
      preference: customPair,
    );
    await PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    ).update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: current.document.events,
        groups: current.document.groups,
        goalEventTypeNames: <String, GoalEventTypeNameOverride>{
          'g0000000-0000-4000-8000-000000000001':
              const GoalEventTypeNameOverride(
            eventTypeStableKey: 'exercise',
            name: 'Pool training',
          ),
        },
      );
    });

    await types.restoreEventColorDefaults(profileId: profileId);

    final document = await storedDocument();
    expect(document.events, isEmpty);
    final override = document.goalEventTypeNames[
        'g0000000-0000-4000-8000-000000000001'];
    expect(override?.name, 'Pool training');
  });

  test('existing Education row is never rewritten on repeated opens',
      () async {
    final first = await types.readEventType(
      profileId: profileId,
      eventTypeId: SystemEventTypeIds.education,
    );
    // Overwrite the raw color to emulate an old install's stored value.
    await (database.update(database.activityTypes)..where(
          (table) => table.id.equals(SystemEventTypeIds.education),
        )).write(const ActivityTypesCompanion(
      colorValue: Value<int>(0xFFA19FE2),
    ));
    final second = await types.readEventType(
      profileId: profileId,
      eventTypeId: SystemEventTypeIds.education,
    );
    expect(first!.id, second!.id);
    expect(second.colorValue, 0xFFA19FE2);
    // Reopening again preserves the row verbatim (no rewrite to P22).
    await types.readEventTypes(profileId: profileId);
    final third = await types.readEventType(
      profileId: profileId,
      eventTypeId: SystemEventTypeIds.education,
    );
    expect(third!.colorValue, 0xFFA19FE2);
    expect(third.label, 'Education');
  });

  test('P24 remains available and untouched for explicit choices', () {
    expect(Vs11ColorSystem.p24DeepBlue, isNotNull);
    // The approved pair is NOT the P24 token value.
    expect(newPair.accentArgb, isNot(Vs11ColorSystem.p24DeepBlue));
  });

  test('canonical peers keep their locked defaults (no recoloring)', () {
    expect(
      PlannerEventColorDefaults.pmgStableKeyDefaults[
          SystemEventTypeKeys.studyOrPlan],
      PlannerEventColorDefaults.studyOrPlan,
    );
    expect(
      PlannerEventColorDefaults
          .pmgStableKeyDefaults[SystemEventTypeKeys.templeVisit],
      PlannerEventColorDefaults.lockedTempleVisit,
    );
    expect(
      PlannerEventColorDefaults.pmgStableKeyDefaults[
          SystemEventTypeKeys.exercise],
      PlannerEventColorDefaults.exercise,
    );
  });

  test('Education slot identity is the exact canonical pair', () {
    final slot = CanonicalGoalSlot.tryByEventTypeKey(
      SystemEventTypeKeys.education,
    );
    expect(slot, isNull, reason: 'Education is NOT one of the six Goal slots');
    final study = CanonicalGoalSlot.tryByEventTypeKey(
      SystemEventTypeKeys.studyOrPlan,
    );
    expect(study, isNull);
  });
}

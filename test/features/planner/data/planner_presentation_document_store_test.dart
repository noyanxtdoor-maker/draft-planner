import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/planner_presentation_document_store.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;
  late String profileId;
  final clock = FixedClock(DateTime.utc(2026, 9, 9, 12));

  setUp(() async {
    database = openMemoryDatabase();
    profileId = '11111111-1111-4111-8111-111111111111';
    await buildTestRepository(database: database).completeOnboarding();
  });

  tearDown(() => database.close());

  const exercisePair = EventColorPreference(
    accentArgb: 0xFF7986CB,
    surfaceArgb: 0xFF3E4356,
  );
  const studyPair = EventColorPreference(
    accentArgb: 0xFF8E6FC8,
    surfaceArgb: 0xFF473E55,
  );

  Future<void> writeRawJson(String? json) async {
    final existing = await (database.select(
      database.plannerPreferences,
    )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
    if (existing == null) {
      await database.into(database.plannerPreferences).insert(
            PlannerPreferencesCompanion.insert(
              profileId: profileId,
              eventColorPreferencesJson: Value<String?>(json),
              updatedAtUtc: clock.nowUtc(),
            ),
          );
    } else {
      await (database.update(
        database.plannerPreferences,
      )..where((table) => table.profileId.equals(profileId))).write(
        PlannerPreferencesCompanion(
          eventColorPreferencesJson: Value<String?>(json),
        ),
      );
    }
  }

  Future<String?> storedJson() async {
    final row = await (database.select(
      database.plannerPreferences,
    )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
    return row?.eventColorPreferencesJson;
  }

  Future<PlannerColorPreferencesDocument> stored() async {
    return EventColorPreferenceCodec.decodeDocument(await storedJson());
  }

  test('read on a missing row returns the empty document with zero writes', () async {
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    expect((await store.read(profileId)).events, isEmpty);
    expect((await store.read(profileId)).goalEventTypeNames, isEmpty);
    expect(await storedJson(), isNull);
  });

  test('update creates the row with events, groups, and names in one document',
      () async {
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: <String, EventColorPreference>{'exercise': exercisePair},
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

    final document = await stored();
    expect(document.events['exercise'], exercisePair);
    expect(
      document.goalEventTypeNames['g0000000-0000-4000-8000-000000000001']
          ?.name,
      'Pool training',
    );
    final raw = await storedJson();
    expect(raw, isNotNull);
    expect(raw, contains('"goalEventTypeNames"'));
  });

  test('a mutation returning null writes nothing (idempotent no-op)', () async {
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: <String, EventColorPreference>{'exercise': exercisePair},
        groups: current.document.groups,
      );
    });
    final before = await storedJson();
    final after = await store.update(profileId, (current) async => null);
    expect(after.events['exercise'], exercisePair);
    expect(await storedJson(), before);
  });

  test('unrelated writes carry name metadata forward', () async {
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    const goalId = 'g0000000-0000-4000-8000-000000000001';
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: current.document.events,
        groups: current.document.groups,
        goalEventTypeNames: <String, GoalEventTypeNameOverride>{
          goalId: const GoalEventTypeNameOverride(
            eventTypeStableKey: 'exercise',
            name: 'Pool training',
          ),
        },
      );
    });

    // A color-only write must NOT drop the name override.
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: <String, EventColorPreference>{
          ...current.document.events,
          'budget_review': studyPair,
        },
        groups: current.document.groups,
        goalEventTypeNames: current.document.goalEventTypeNames,
      );
    });

    final document = await stored();
    expect(document.events['budget_review'], studyPair);
    expect(document.goalEventTypeNames[goalId]?.name, 'Pool training');
  });

  test('group colors and event colors persist independently', () async {
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: current.document.events,
        groups: <String, int>{'family': 0xFF112233},
        goalEventTypeNames: current.document.goalEventTypeNames,
      );
    });
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: <String, EventColorPreference>{'exercise': exercisePair},
        groups: current.document.groups,
        goalEventTypeNames: current.document.goalEventTypeNames,
      );
    });
    final document = await stored();
    expect(document.groups['family'], 0xFF112233);
    expect(document.events['exercise'], exercisePair);
  });

  test('invalid metadata entry is preserved verbatim on unrelated writes',
      () async {
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    const goalId = 'g0000000-0000-4000-8000-000000000001';
    // Seed a document whose metadata contains an invalid entry shape via a
    // direct row write (the store never produces invalid entries itself).
    final seed = EventColorPreferenceCodec.encodeDocument(
      events: <String, EventColorPreference>{'exercise': exercisePair},
      groups: const <String, int>{},
    );
    final seedMap = jsonDecode(seed) as Map<String, Object?>;
    seedMap['goalEventTypeNames'] = <String, Object?>{
      goalId: <String, Object?>{
        'eventTypeStableKey': 'exercise',
        'name': '   ',
      },
    };
    final injected = jsonEncode(seedMap);
    await writeRawJson(injected);

    // A color write must preserve the invalid raw entry untouched.
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: <String, EventColorPreference>{
          ...current.document.events,
          'study_or_plan': studyPair,
        },
        groups: current.document.groups,
        goalEventTypeNames: current.document.goalEventTypeNames,
      );
    });

    final raw = (await storedJson())!;
    expect(raw, contains('"name":"   "'));
    final document = await stored();
    expect(document.events['study_or_plan'], studyPair);
    // The invalid entry never becomes a validated override.
    expect(document.goalEventTypeNames.containsKey(goalId), isFalse);
  });

  test('completely malformed JSON fails the mutation closed', () async {
    await writeRawJson('{not json');

    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    await expectLater(
      store.update(profileId, (current) async => current.document),
      throwsA(isA<PresentationMutationRejectedException>()),
    );
    // The malformed owner content is never replaced.
    expect(await storedJson(), '{not json');
  });

  test('non-object JSON fails the mutation closed', () async {
    await writeRawJson('[1,2,3]');
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    await expectLater(
      store.update(profileId, (current) async => current.document),
      throwsA(isA<PresentationMutationRejectedException>()),
    );
    expect(await storedJson(), '[1,2,3]');
  });

  test('encodedCurrentDocument re-encodes losslessly without writing',
      () async {
    final store = PlannerPresentationDocumentStore(
      database: database,
      clock: clock,
    );
    const goalId = 'g0000000-0000-4000-8000-000000000001';
    await store.update(profileId, (current) async {
      return PlannerColorPreferencesDocument(
        events: <String, EventColorPreference>{'exercise': exercisePair},
        groups: current.document.groups,
        goalEventTypeNames: <String, GoalEventTypeNameOverride>{
          goalId: const GoalEventTypeNameOverride(
            eventTypeStableKey: 'exercise',
            name: 'Pool training',
          ),
        },
      );
    });
    final before = await storedJson();
    final encoded = await store.encodedCurrentDocument(profileId);
    expect(encoded, before);
    expect(await storedJson(), before);
  });
}

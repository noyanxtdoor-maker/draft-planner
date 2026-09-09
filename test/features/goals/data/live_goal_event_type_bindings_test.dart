import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/goals/data/live_goal_event_type_bindings.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;
  late String profileId;
  final clock = FixedClock(DateTime.utc(2026, 9, 9, 12));

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    // completeOnboarding seeds the six canonical bootstrap Goals. Archive
    // them ALL here (raw status change, mirroring repository archive law)
    // so each test's inserted rows are the only raw-active candidates.
    await (database.update(database.goals)
            ..where((table) => table.status.equals('active')))
        .write(const GoalsCompanion(status: Value<String>('archived')));
    final types = DriftEventTypeRepository(database: database, clock: clock);
    await types.readEventTypes(profileId: profileId);
  });

  tearDown(() => database.close());

  Future<String> insertGoal({
    required int? slotIndex,
    String status = 'active',
    String? role,
    String? assignedKey,
    String? indicatorKey,
    String title = 'Sample1',
    String? id,
  }) async {
    final slot = slotIndex == null
        ? null
        : (slotIndex >= 1 && slotIndex <= CanonicalGoalSlot.all.length
              ? CanonicalGoalSlot.bySlot(slotIndex)
              : null);
    final goalId = id ?? 'goal-$slotIndex-$status-${assignedKey ?? ''}';
    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            id: goalId,
            profileId: profileId,
            role: role ?? slot?.role.storageName ?? 'weekly',
            title: title,
            status: status,
            activeSlotIndex: Value<int?>(slotIndex),
            indicatorKey: Value<String?>(indicatorKey ?? slot?.indicatorKey),
            assignedEventTypeStableKey: Value<String?>(
              assignedKey ?? slot?.eventTypeStableKey,
            ),
            iconId: const Value<String?>(null),
            createdAtUtc: clock.value,
            updatedAtUtc: clock.value,
            archivedAtUtc: const Value<DateTime?>(null),
          ),
        );
    return goalId;
  }

  test('three consecutive reads produce identical maps with zero writes', () async {
    await insertGoal(slotIndex: 1, title: 'Sample1');
    await insertGoal(slotIndex: 6, title: 'Temple Visit');
    Future<Map<String, List<Map<String, Object?>>>> snapshot() async {
      final result = <String, List<Map<String, Object?>>>{};
      for (final table in [
        'goals',
        'activity_types',
        'calendar_events',
        'goal_activities',
      ]) {
        result[table] = (await database
                .customSelect('SELECT * FROM $table ORDER BY rowid')
                .get())
            .map((r) => r.data)
            .toList();
      }
      return result;
    }

    final before = await snapshot();
    final first = await readLiveGoalEventTypeBindings(database, profileId);
    final second = await readLiveGoalEventTypeBindings(database, profileId);
    final third = await readLiveGoalEventTypeBindings(database, profileId);
    final after = await snapshot();

    expect(first, second);
    expect(second, third);
    expect(first.keys.toSet(), <int>{1, 6});
    expect(first[1]!.title, 'Sample1');
    expect(first[6]!.title, 'Temple Visit');
    expect(after, before, reason: 'the bindings reader must never write');
  });

  test('raw completed legacy status never becomes a binding', () async {
    await insertGoal(slotIndex: 2, status: 'completed', title: 'Legacy Done');
    final bindings = await readLiveGoalEventTypeBindings(database, profileId);
    expect(bindings, isEmpty);
  });

  test('raw archived status and unslotted active rows never bind', () async {
    await insertGoal(slotIndex: 3, status: 'archived');
    await insertGoal(slotIndex: null, title: 'Unslotted Active');
    final bindings = await readLiveGoalEventTypeBindings(database, profileId);
    expect(bindings, isEmpty);
  });

  test('wrong identity fields fail closed even with an active status', () async {
    await insertGoal(slotIndex: 4, assignedKey: 'exercise');
    await insertGoal(slotIndex: 5, indicatorKey: 'exercise');
    final bindings = await readLiveGoalEventTypeBindings(database, profileId);
    expect(bindings, isEmpty);
  });

  test('queries by deterministic IDs, never by titles', () async {
    final id = await insertGoal(slotIndex: 1, title: 'Any Display Title');
    final bindings = await readLiveGoalEventTypeBindings(database, profileId);
    expect(bindings[1]!.goalId, id);
  });
}

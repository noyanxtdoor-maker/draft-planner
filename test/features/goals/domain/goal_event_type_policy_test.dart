import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/domain/goal_event_type_policy.dart';

void main() {
  LiveGoalCandidateRow candidate({
    String id = 'g1',
    String profileId = 'p1',
    String status = 'active',
    String? role,
    int? slotIndex,
    String? assignedKey,
    String? indicatorKey,
    String title = 'Sample1',
  }) {
    final slot = slotIndex == null
        ? null
        : (slotIndex >= 1 && slotIndex <= CanonicalGoalSlot.all.length
              ? CanonicalGoalSlot.bySlot(slotIndex)
              : null);
    return LiveGoalCandidateRow(
      id: id,
      profileId: profileId,
      status: status,
      role: role ?? slot?.role.storageName ?? GoalRole.weekly.storageName,
      activeSlotIndex: slotIndex,
      assignedEventTypeStableKey: assignedKey ?? slot?.eventTypeStableKey,
      indicatorKey: indicatorKey ?? slot?.indicatorKey,
      title: title,
    );
  }

  group('T01 table-driven slot identity', () {
    test('every canonical slot maps role/key/indicator/ID exactly', () {
      for (final slot in CanonicalGoalSlot.all) {
        final binding = GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: slot.slotIndex),
          profileId: 'p1',
        );
        expect(binding, isNotNull, reason: 'slot ${slot.slotIndex}');
        expect(binding!.slotIndex, slot.slotIndex);
        expect(binding.title, 'Sample1');
        final canonical = CanonicalGoalSlot.bySlot(binding.slotIndex);
        expect(canonical.eventTypeStableKey, slot.eventTypeStableKey);
        expect(canonical.eventTypeId, slot.eventTypeId);
        expect(canonical.indicatorKey, slot.indicatorKey);
        expect(canonical.role, slot.role);
      }
    });

    test('rejects non-active raw statuses before model fallback', () {
      for (final status in <String>[
        'archived',
        'deleted',
        'completed',
        'paused',
        'unknown-legacy',
        'Active',
        '',
      ]) {
        final binding = GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: 1, status: status),
          profileId: 'p1',
        );
        expect(
          binding,
          isNull,
          reason: "raw status '$status' must never become live",
        );
      }
    });

    test('rejects null, zero, and out-of-range slots', () {
      expect(
        GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: null),
          profileId: 'p1',
        ),
        isNull,
      );
      for (final bad in const <int>[0, -1, 7, 99]) {
        expect(
          GoalEventTypePolicy.bindingForCandidate(
            candidate: candidate(slotIndex: bad),
            profileId: 'p1',
          ),
          isNull,
          reason: 'slot $bad is not canonical',
        );
      }
    });

    test('rejects wrong role, profile, key, indicator, and blank titles', () {
      expect(
        GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: 1, role: GoalRole.weekly.storageName),
          profileId: 'p1',
        ),
        isNull,
        reason: 'slot 1 is dailyWeekly',
      );
      expect(
        GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: 1),
          profileId: 'other',
        ),
        isNull,
      );
      expect(
        GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: 1, assignedKey: 'exercise'),
          profileId: 'p1',
        ),
        isNull,
      );
      expect(
        GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: 1, indicatorKey: 'exercise'),
          profileId: 'p1',
        ),
        isNull,
      );
      expect(
        GoalEventTypePolicy.bindingForCandidate(
          candidate: candidate(slotIndex: 1, title: '   '),
          profileId: 'p1',
        ),
        isNull,
      );
    });

    test('duplicate raw-active occupants fail closed with no winner', () {
      final bindings = GoalEventTypePolicy.bindingsForCandidates(
        candidates: <LiveGoalCandidateRow>[
          candidate(id: 'dup-a', slotIndex: 2),
          candidate(id: 'dup-b', slotIndex: 2),
        ],
        profileId: 'p1',
      );
      expect(bindings.containsKey(2), isFalse);
      expect(bindings, isEmpty);
    });

    test('bindings map keeps valid slots while excluding invalid ones', () {
      final bindings = GoalEventTypePolicy.bindingsForCandidates(
        candidates: <LiveGoalCandidateRow>[
          candidate(id: 'ok1', slotIndex: 1),
          candidate(id: 'bad-status', slotIndex: 6, status: 'archived'),
          candidate(id: 'unslotted', slotIndex: null),
        ],
        profileId: 'p1',
      );
      expect(bindings.keys, <int>[1]);
      expect(bindings[1]!.goalId, 'ok1');
    });
  });
}

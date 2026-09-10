import 'package:rmplanner/features/goals/domain/assigned_event_type_draft.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';

/// The Goal-title creation alias for one live canonical slot (D.1).
///
/// Identity is the slot itself: the same slot keeps one canonical Event Type
/// ID/key/mapping forever and only this alias title changes. The title is
/// never compared to decide identity, and the legacy deterministic Goal ID is
/// never used as identity — [goalId] is carried as read-only data so new
/// Event snapshots can capture the live alias.
final class LiveGoalEventTypeBinding {
  const LiveGoalEventTypeBinding({
    required this.profileId,
    required this.goalId,
    required this.slotIndex,
    required this.title,
    this.eventTypeNameOverride,
  });

  final String profileId;
  final String goalId;
  final int slotIndex;
  final String title;

  /// Presentation-name override for this exact Goal, when one is stored.
  /// Null means AUTO (display name follows the Goal title). The Goal title
  /// is NEVER overloaded to mean an Event Type override.
  final AssignedEventTypeNameOverrideRef? eventTypeNameOverride;

  /// Effective prospective display name: MANUAL override, otherwise the
  /// trimmed Goal title. A raw canonical label is never a fallback.
  String get displayLabel =>
      eventTypeNameOverride?.name.trim() ?? title.trim();

  LiveGoalEventTypeBinding withNameOverride(
    AssignedEventTypeNameOverrideRef? override,
  ) {
    return LiveGoalEventTypeBinding(
      profileId: profileId,
      goalId: goalId,
      slotIndex: slotIndex,
      title: title,
      eventTypeNameOverride: override,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiveGoalEventTypeBinding &&
      other.profileId == profileId &&
      other.goalId == goalId &&
      other.slotIndex == slotIndex &&
      other.title == title &&
      other.eventTypeNameOverride == eventTypeNameOverride;

  @override
  int get hashCode => Object.hash(
    profileId,
    goalId,
    slotIndex,
    title,
    eventTypeNameOverride,
  );

  @override
  String toString() =>
      'LiveGoalEventTypeBinding(slot: $slotIndex, goal: $goalId, title: $title)';
}

/// Read-only reference to a stored manual presentation-name override. Kept
/// separate from [AssignedEventTypeNameMode] so the domain binding stays a
/// plain data carrier; equals by value for easy provider diffing.
final class AssignedEventTypeNameOverrideRef {
  const AssignedEventTypeNameOverrideRef({
    required this.eventTypeStableKey,
    required this.name,
  });

  final String eventTypeStableKey;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AssignedEventTypeNameOverrideRef &&
      other.eventTypeStableKey == eventTypeStableKey &&
      other.name == name;

  @override
  int get hashCode => Object.hash(eventTypeStableKey, name);
}

/// Raw, storage-shaped Goal fields offered to the policy.
///
/// Status and role remain the exact raw database strings so the policy can
/// validate them BEFORE any model conversion: unknown legacy statuses (for
/// example `completed`) and unknown roles must fail closed instead of
/// flowing through the model-layer fallback that maps unknown raw statuses
/// to active.
final class LiveGoalCandidateRow {
  const LiveGoalCandidateRow({
    required this.id,
    required this.profileId,
    required this.status,
    required this.role,
    required this.activeSlotIndex,
    required this.assignedEventTypeStableKey,
    required this.indicatorKey,
    required this.title,
  });

  final String id;
  final String profileId;
  final String status;
  final String role;
  final int? activeSlotIndex;
  final String? assignedEventTypeStableKey;
  final String? indicatorKey;
  final String title;
}

/// Pure live-slot eligibility law (contract C).
///
/// A Goal occupies its canonical slot live only when every raw identity
/// field matches the fixed slot exactly:
/// raw status exactly 'active', same profile, non-null slot 1..6, exact raw
/// role for that slot, assigned Event Type stable key equal to the slot key,
/// indicator key equal to the slot indicator, and a non-empty trimmed title.
/// Data corruption (two raw-active occupants of one slot) fails closed: the
/// slot is excluded entirely, never resolved by picking a winner. No UI, no
/// SQL, no writes, and no Goal lifecycle semantics live here.
abstract final class GoalEventTypePolicy {
  /// Validates one raw candidate row for [profileId].
  ///
  /// Returns the immutable binding for the candidate's canonical slot, or
  /// null when the row is not a live valid occupant (wrong profile, any raw
  /// status other than exactly 'active', unknown role, missing or
  /// out-of-range slot, wrong role/key/indicator identity, or blank title).
  static LiveGoalEventTypeBinding? bindingForCandidate({
    required LiveGoalCandidateRow candidate,
    required String profileId,
  }) {
    if (candidate.profileId != profileId) {
      return null;
    }
    // Raw status must be exactly 'active' BEFORE any model conversion. The
    // model fallback maps unknown statuses (completed/paused/...) to active;
    // this law must not inherit that fallback.
    if (candidate.status != 'active') {
      return null;
    }
    final slotIndex = candidate.activeSlotIndex;
    if (slotIndex == null) {
      return null;
    }
    final CanonicalGoalSlot slot;
    try {
      slot = CanonicalGoalSlot.bySlot(slotIndex);
    } on StateError {
      return null;
    }
    // Raw role string validated against the slot's storage name before any
    // enum conversion; unknown roles can never match a storage name.
    if (candidate.role != slot.role.storageName) {
      return null;
    }
    if (candidate.assignedEventTypeStableKey != slot.eventTypeStableKey) {
      return null;
    }
    if (candidate.indicatorKey != slot.indicatorKey) {
      return null;
    }
    final trimmedTitle = candidate.title.trim();
    if (trimmedTitle.isEmpty) {
      return null;
    }
    return LiveGoalEventTypeBinding(
      profileId: candidate.profileId,
      goalId: candidate.id,
      slotIndex: slot.slotIndex,
      title: trimmedTitle,
    );
  }

  /// Builds the immutable slot -> binding map for raw candidates.
  ///
  /// Occupants are grouped and counted BEFORE validation results are used:
  /// a slot with more than one raw-active occupant is corrupt and fails
  /// closed (excluded, no winner is picked). Invalid single occupants are
  /// excluded; all other slots keep their valid binding. The returned map is
  /// unmodifiable.
  static Map<int, LiveGoalEventTypeBinding> bindingsForCandidates({
    required List<LiveGoalCandidateRow> candidates,
    required String profileId,
  }) {
    final bySlot = <int, List<LiveGoalCandidateRow>>{};
    for (final candidate in candidates) {
      bySlot.putIfAbsent(candidate.activeSlotIndex ?? -1, () => []).add(
            candidate,
          );
    }
    final bindings = <int, LiveGoalEventTypeBinding>{};
    bySlot.forEach((slotIndex, occupants) {
      if (slotIndex <= 0 || occupants.length != 1) {
        // Corrupt duplicate (or out-of-range) occupants: fail closed.
        return;
      }
      final binding = bindingForCandidate(
        candidate: occupants.single,
        profileId: profileId,
      );
      if (binding != null) {
        bindings[slotIndex] = binding;
      }
    });
    return Map<int, LiveGoalEventTypeBinding>.unmodifiable(bindings);
  }
}

import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

/// The six non-reassignable Goal/Event Type relationships.
///
/// A slot is the identity boundary.  Display titles, Event Type labels, and
/// icons may change, but a Goal must never be moved to another slot or linked
/// to another Event Type.
final class CanonicalGoalSlot {
  const CanonicalGoalSlot({
    required this.slotIndex,
    required this.eventTypeStableKey,
    required this.indicatorKey,
    required this.role,
    required this.defaultTitle,
  });

  final int slotIndex;
  final String eventTypeStableKey;
  final String indicatorKey;
  final GoalRole role;
  final String defaultTitle;

  String get eventTypeId => switch (eventTypeStableKey) {
    SystemEventTypeKeys.jobApplication => SystemEventTypeIds.jobApplication,
    SystemEventTypeKeys.scriptureStudy => SystemEventTypeIds.scriptureStudy,
    SystemEventTypeKeys.exercise => SystemEventTypeIds.exercise,
    SystemEventTypeKeys.budgetReview => SystemEventTypeIds.budgetReview,
    SystemEventTypeKeys.meaningfulConnection =>
      SystemEventTypeIds.meaningfulConnection,
    SystemEventTypeKeys.templeVisit => SystemEventTypeIds.templeVisit,
    _ => throw StateError('Unknown canonical Event Type key.'),
  };

  static const List<CanonicalGoalSlot> all = <CanonicalGoalSlot>[
    CanonicalGoalSlot(
      slotIndex: 1,
      eventTypeStableKey: SystemEventTypeKeys.jobApplication,
      indicatorKey: 'job_applications',
      role: GoalRole.dailyWeekly,
      defaultTitle: 'Job Applications',
    ),
    CanonicalGoalSlot(
      slotIndex: 2,
      eventTypeStableKey: SystemEventTypeKeys.scriptureStudy,
      indicatorKey: 'scripture_study',
      role: GoalRole.weekly,
      defaultTitle: 'Scripture Study',
    ),
    CanonicalGoalSlot(
      slotIndex: 3,
      eventTypeStableKey: SystemEventTypeKeys.exercise,
      indicatorKey: 'exercise',
      role: GoalRole.weekly,
      defaultTitle: 'Exercise',
    ),
    CanonicalGoalSlot(
      slotIndex: 4,
      eventTypeStableKey: SystemEventTypeKeys.budgetReview,
      indicatorKey: 'budget_review',
      role: GoalRole.weekly,
      defaultTitle: 'Budget Review',
    ),
    CanonicalGoalSlot(
      slotIndex: 5,
      eventTypeStableKey: SystemEventTypeKeys.meaningfulConnection,
      indicatorKey: 'meaningful_connections',
      role: GoalRole.weekly,
      defaultTitle: 'Ministering Visit',
    ),
    CanonicalGoalSlot(
      slotIndex: 6,
      eventTypeStableKey: SystemEventTypeKeys.templeVisit,
      indicatorKey: 'temple_visit',
      role: GoalRole.weeklyMonthly,
      defaultTitle: 'Temple Visit',
    ),
  ];

  static CanonicalGoalSlot bySlot(int slotIndex) {
    return all.firstWhere(
      (slot) => slot.slotIndex == slotIndex,
      orElse: () => throw StateError('Unknown canonical Goal slot.'),
    );
  }

  static CanonicalGoalSlot byEventTypeKey(String key) {
    return all.firstWhere(
      (slot) => slot.eventTypeStableKey == key,
      orElse: () => throw StateError('Unknown canonical Event Type key.'),
    );
  }

  static CanonicalGoalSlot? tryByEventTypeKey(String? key) {
    if (key == null) return null;
    for (final slot in all) {
      if (slot.eventTypeStableKey == key) return slot;
    }
    return null;
  }

  static CanonicalGoalSlot? tryByIndicatorKey(String? key) {
    if (key == null) return null;
    for (final slot in all) {
      if (slot.indicatorKey == key) return slot;
    }
    return null;
  }
}

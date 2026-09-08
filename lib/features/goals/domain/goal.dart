import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

enum GoalRole { dailyWeekly, weekly, weeklyMonthly }

extension GoalRolePresentation on GoalRole {
  String get storageName => name;

  String get title => switch (this) {
    GoalRole.dailyWeekly => 'Daily Progress Goal',
    GoalRole.weekly => 'Weekly Goal',
    GoalRole.weeklyMonthly => 'Monthly Progress Goal',
  };

  String get description => switch (this) {
    GoalRole.dailyWeekly =>
      'Plan something every day to reach a weekly target.',
    GoalRole.weekly => 'Complete a target during the current week.',
    GoalRole.weeklyMonthly =>
      'Use weekly progress to work toward a monthly target.',
  };

  String get metricLabel => switch (this) {
    GoalRole.dailyWeekly => 'Today Goal',
    GoalRole.weekly => 'Weekly Goal',
    GoalRole.weeklyMonthly => 'Month Goal',
  };

  int get slotIndex => switch (this) {
    GoalRole.dailyWeekly => 1,
    GoalRole.weekly => -1,
    GoalRole.weeklyMonthly => 6,
  };

  int get capacity => switch (this) {
    GoalRole.dailyWeekly => 1,
    GoalRole.weekly => 4,
    GoalRole.weeklyMonthly => 1,
  };
}

/// `deleted` is deliberately an internal tombstone.  It is not a user-facing
/// lifecycle alternative to the four canonical states below.
enum GoalStatus { active, paused, completed, archived, deleted }

enum GoalCompletionMethod { userConfirmation, targetReached }

enum GoalActivityAction {
  created,
  renamed,
  paused,
  resumed,
  completed,
  reopened,
  archived,
  restored,
  deleted,
}

enum GoalAchievementType { goalCompleted }

/// Deliberately not implemented: the current domain has no truthful,
/// canonical cohort from which an "all goals completed" event could be
/// derived. Individual Goal completion receipts remain fully canonical.
const String combinedAllGoalsEventDeferredReason =
    'COMBINED ALL-GOALS EVENT DEFERRED — NO CANONICAL COHORT';

final class GoalAchievement {
  const GoalAchievement({
    required this.id,
    required this.profileId,
    required this.goalId,
    required this.type,
    required this.completionGeneration,
    required this.occurredAtUtc,
    required this.createdAtUtc,
    required this.sourceOperationId,
    required this.systemNotificationEligible,
    required this.inAppCelebrationEligible,
    this.systemNotificationDeliveredAtUtc,
    this.inAppCelebrationConsumedAtUtc,
  });

  final String id;
  final String profileId;
  final String goalId;
  final GoalAchievementType type;
  final int completionGeneration;
  final DateTime occurredAtUtc;
  final DateTime createdAtUtc;
  final String sourceOperationId;
  final bool systemNotificationEligible;
  final bool inAppCelebrationEligible;
  final DateTime? systemNotificationDeliveredAtUtc;
  final DateTime? inAppCelebrationConsumedAtUtc;
}

final class Goal {
  const Goal({
    required this.id,
    required this.profileId,
    required this.indicatorKey,
    required this.assignedEventTypeStableKey,
    required this.role,
    required this.activeSlotIndex,
    required this.title,
    required this.iconId,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.archivedAtUtc,
    required this.deletedAtUtc,
    this.completedAtUtc,
    this.completionMethod,
    this.completionGeneration = 0,
    this.completionArmed = true,
  });

  final String id;
  final String profileId;
  final String? indicatorKey;
  final String? assignedEventTypeStableKey;
  final GoalRole role;
  final int? activeSlotIndex;
  final String title;
  final String? iconId;
  final GoalStatus status;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? archivedAtUtc;
  final DateTime? deletedAtUtc;
  final DateTime? completedAtUtc;
  final GoalCompletionMethod? completionMethod;
  final int completionGeneration;
  final bool completionArmed;

  bool get isActive => status == GoalStatus.active;
  bool get isPaused => status == GoalStatus.paused;
  bool get isCompleted => status == GoalStatus.completed;

  bool get isDeleted => status == GoalStatus.deleted;
}

final class GoalActivity {
  const GoalActivity({
    required this.id,
    required this.profileId,
    required this.goalId,
    required this.operationId,
    required this.action,
    required this.previousValue,
    required this.newValue,
    required this.occurredAtUtc,
  });

  final String id;
  final String profileId;
  final String goalId;
  final String operationId;
  final GoalActivityAction action;
  final String? previousValue;
  final String? newValue;
  final DateTime occurredAtUtc;
}

final class GoalCapacity {
  const GoalCapacity({required this.activeByRole});

  final Map<GoalRole, int> activeByRole;

  int get usedDaily => activeByRole[GoalRole.dailyWeekly] ?? 0;
  int get usedWeekly => activeByRole[GoalRole.weekly] ?? 0;
  int get usedMonthly => activeByRole[GoalRole.weeklyMonthly] ?? 0;

  int get availableDaily => GoalRole.dailyWeekly.capacity - usedDaily;
  int get availableWeekly => GoalRole.weekly.capacity - usedWeekly;
  int get availableMonthly => GoalRole.weeklyMonthly.capacity - usedMonthly;

  bool isAvailable(GoalRole role) => switch (role) {
    GoalRole.dailyWeekly => availableDaily > 0,
    GoalRole.weekly => availableWeekly > 0,
    GoalRole.weeklyMonthly => availableMonthly > 0,
  };

  String availabilityLabel(GoalRole role) {
    final available = switch (role) {
      GoalRole.dailyWeekly => availableDaily,
      GoalRole.weekly => availableWeekly,
      GoalRole.weeklyMonthly => availableMonthly,
    };
    return available == 0
        ? 'Full'
        : role == GoalRole.weekly
        ? '$available of 4 available'
        : 'Available';
  }
}

final class GoalTargets {
  const GoalTargets({this.daily, this.weekly, this.monthly});

  final IndicatorAmount? daily;
  final IndicatorAmount? weekly;
  final IndicatorAmount? monthly;

  GoalTargets copyWith({
    IndicatorAmount? daily,
    IndicatorAmount? weekly,
    IndicatorAmount? monthly,
  }) {
    return GoalTargets(
      daily: daily ?? this.daily,
      weekly: weekly ?? this.weekly,
      monthly: monthly ?? this.monthly,
    );
  }
}

final class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.dailyActual,
    required this.dailyTarget,
    required this.weeklyActual,
    required this.weeklyTarget,
    required this.monthlyActual,
    required this.monthlyTarget,
  });

  final Goal goal;
  final IndicatorAmount dailyActual;
  final IndicatorTarget dailyTarget;
  final IndicatorAmount weeklyActual;
  final IndicatorTarget weeklyTarget;
  final IndicatorAmount monthlyActual;
  final IndicatorTarget monthlyTarget;

  IndicatorTarget get primaryTarget => switch (goal.role) {
    GoalRole.dailyWeekly => weeklyTarget,
    GoalRole.weekly => weeklyTarget,
    GoalRole.weeklyMonthly => weeklyTarget,
  };

  IndicatorAmount get primaryActual => weeklyActual;
}

final class GoalPlanningSnapshot {
  const GoalPlanningSnapshot({
    required this.periodStart,
    required this.periodEnd,
    required this.daily,
    required this.weekly,
    required this.monthly,
  });

  final PlannerDate periodStart;
  final PlannerDate periodEnd;
  final GoalProgress? daily;
  final List<GoalProgress> weekly;
  final GoalProgress? monthly;
}

final class GoalActivityHistoryItem {
  const GoalActivityHistoryItem({
    required this.activity,
    required this.goalTitle,
    required this.role,
  });

  final GoalActivity activity;
  final String goalTitle;
  final GoalRole role;
}

final class GoalValidationException implements Exception {
  const GoalValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class GoalCapacityException implements Exception {
  const GoalCapacityException(this.role);

  final GoalRole role;

  @override
  String toString() => '${role.title} capacity is full.';
}

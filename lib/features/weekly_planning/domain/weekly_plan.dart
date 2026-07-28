import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

enum WeeklyPlanState { draft, active, reviewDue, reviewed, historical }

enum WeeklyCommitmentType { task, event }

enum TaskCarryoverDecision { carry, doNotCarry }

final class WeeklyPeriod {
  WeeklyPeriod({required this.start, required this.end}) {
    if (start.weekday != DateTime.monday || end != start.addDays(6)) {
      throw const WeeklyPlanningValidationException(
        'A Weekly Plan must cover exactly Monday through Sunday.',
      );
    }
  }

  factory WeeklyPeriod.containing(PlannerDate date) {
    final start = date.addDays(-(date.weekday - DateTime.monday));
    return WeeklyPeriod(start: start, end: start.addDays(6));
  }

  final PlannerDate start;
  final PlannerDate end;

  IndicatorPeriod get indicatorPeriod =>
      IndicatorPeriod(start: start, end: end);

  bool contains(PlannerDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
}

final class WeeklyPlanCommitment {
  const WeeklyPlanCommitment({
    required this.id,
    required this.type,
    required this.sourceId,
    required this.label,
    required this.requiresReport,
    required this.reportResolved,
    this.occurrenceId,
    this.taskStatus,
  });

  final String id;
  final WeeklyCommitmentType type;
  final String sourceId;
  final String? occurrenceId;
  final String label;
  final bool requiresReport;
  final bool reportResolved;
  final PlannerTaskStatus? taskStatus;

  bool get hasUnresolvedReport => requiresReport && !reportResolved;
  bool get isIncompleteTask =>
      type == WeeklyCommitmentType.task &&
      taskStatus == PlannerTaskStatus.incomplete;
}

final class WeeklyIndicatorReview {
  const WeeklyIndicatorReview({
    required this.indicatorKey,
    required this.label,
    required this.actual,
    required this.target,
    required this.scheduled,
  });

  final String indicatorKey;
  final String label;
  final IndicatorAmount actual;
  final IndicatorTarget target;
  final IndicatorAmount scheduled;
}

final class WeeklyReview {
  const WeeklyReview({
    required this.id,
    required this.completedAtUtc,
    required this.unresolvedReportsAcknowledged,
    required this.indicators,
    this.privateReflection,
  });

  final String id;
  final DateTime completedAtUtc;
  final bool unresolvedReportsAcknowledged;
  final String? privateReflection;
  final List<WeeklyIndicatorReview> indicators;
}

final class PostReviewChange {
  const PostReviewChange({
    required this.indicatorKey,
    required this.recordedAtUtc,
  });

  final String indicatorKey;
  final DateTime recordedAtUtc;
}

final class WeeklyPlan {
  const WeeklyPlan({
    required this.id,
    required this.profileId,
    required this.period,
    required this.timeZoneId,
    required this.storedState,
    required this.commitments,
    required this.indicators,
    required this.postReviewChanges,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.review,
  });

  final String id;
  final String profileId;
  final WeeklyPeriod period;
  final String timeZoneId;
  final WeeklyPlanState storedState;
  final List<WeeklyPlanCommitment> commitments;
  final List<WeeklyIndicatorReview> indicators;
  final WeeklyReview? review;
  final List<PostReviewChange> postReviewChanges;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  WeeklyPlanState effectiveState(PlannerDate today) {
    if ((storedState == WeeklyPlanState.draft ||
            storedState == WeeklyPlanState.active) &&
        today.compareTo(period.end) > 0) {
      return WeeklyPlanState.reviewDue;
    }
    return storedState;
  }

  List<WeeklyPlanCommitment> get unresolvedReports => commitments
      .where((commitment) => commitment.hasUnresolvedReport)
      .toList(growable: false);

  bool get isReadOnly =>
      storedState == WeeklyPlanState.reviewed ||
      storedState == WeeklyPlanState.historical;
}

final class WeeklyPlanningValidationException implements Exception {
  const WeeklyPlanningValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

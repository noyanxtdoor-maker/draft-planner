import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

abstract interface class PlannerCalendarSource {
  Future<List<PlannerCalendarItem>> readDay({
    required String profileId,
    required PlannerDate date,
  });
}

final class EmptyPlannerCalendarSource implements PlannerCalendarSource {
  const EmptyPlannerCalendarSource();

  @override
  Future<List<PlannerCalendarItem>> readDay({
    required String profileId,
    required PlannerDate date,
  }) async {
    return const <PlannerCalendarItem>[];
  }
}

abstract interface class PlannerTaskContextSource {
  Future<PlannerTaskContext> readContext(String taskId);
}

final class EmptyPlannerTaskContextSource implements PlannerTaskContextSource {
  const EmptyPlannerTaskContextSource();

  @override
  Future<PlannerTaskContext> readContext(String taskId) async {
    return const PlannerTaskContext();
  }
}

abstract interface class TaskHistoricalEffectReader {
  Future<bool> hasReportOrLedgerEffect(String taskId);
}

final class NoTaskHistoricalEffects implements TaskHistoricalEffectReader {
  const NoTaskHistoricalEffects();

  @override
  Future<bool> hasReportOrLedgerEffect(String taskId) async => false;
}

abstract interface class PlannerRepository {
  Future<PlannerDay> readDay({
    required String profileId,
    required PlannerDate selectedDate,
    required PlannerDate today,
  });

  Future<PlannerTask?> readTask({
    required String profileId,
    required String taskId,
  });

  Future<PlannerTask> saveTask({
    required String profileId,
    required PlannerTaskDraft draft,
  });

  Future<TaskStatusChangeOutcome> changeTaskStatus({
    required String profileId,
    required String taskId,
    required PlannerTaskStatus target,
    required String operationId,
    String? reason,
  });
}

import 'package:rmplanner/features/planner/domain/planner_date.dart';

enum PlannerTaskStatus { incomplete, completed, skipped, cancelled }

final class PlannerTaskContext {
  const PlannerTaskContext({
    this.linkedEventIds = const <String>[],
    this.pathwayContextLabels = const <String>[],
  });

  final List<String> linkedEventIds;
  final List<String> pathwayContextLabels;
}

final class PlannerTaskDraft {
  const PlannerTaskDraft({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.requiresReport,
    this.notes,
    this.contributionRuleKey,
  });

  final String id;
  final String title;
  final String? notes;
  final PlannerDate? dueDate;
  final bool requiresReport;
  final String? contributionRuleKey;

  PlannerTaskDraft normalized() {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const PlannerTaskValidationException(
        'A Task title cannot be blank.',
      );
    }
    return PlannerTaskDraft(
      id: id,
      title: normalizedTitle,
      notes: _normalizeOptional(notes),
      dueDate: dueDate,
      requiresReport: requiresReport,
      contributionRuleKey: _normalizeOptional(contributionRuleKey),
    );
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

final class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.profileId,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.requiresReport,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.notes,
    this.contributionRuleKey,
    this.linkedEventIds = const <String>[],
    this.pathwayContextLabels = const <String>[],
  });

  final String id;
  final String profileId;
  final String title;
  final String? notes;
  final PlannerDate? dueDate;
  final PlannerTaskStatus status;
  final bool requiresReport;
  final String? contributionRuleKey;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final List<String> linkedEventIds;
  final List<String> pathwayContextLabels;

  bool isOverdueOn(PlannerDate date) {
    final due = dueDate;
    return status == PlannerTaskStatus.incomplete &&
        due != null &&
        due.compareTo(date) < 0;
  }

  bool get isHistorical => status != PlannerTaskStatus.incomplete;
}

final class TaskStatusChange {
  const TaskStatusChange({
    required this.id,
    required this.taskId,
    required this.operationId,
    required this.fromStatus,
    required this.toStatus,
    required this.changedAtUtc,
    this.reason,
  });

  final String id;
  final String taskId;
  final String operationId;
  final PlannerTaskStatus fromStatus;
  final PlannerTaskStatus toStatus;
  final String? reason;
  final DateTime changedAtUtc;
}

enum TaskStatusChangeOutcome {
  changed,
  unchanged,
  reportRequired,
  correctionRequired,
}

abstract final class TaskStatusPolicy {
  static TaskStatusChangeOutcome evaluate({
    required PlannerTask task,
    required PlannerTaskStatus target,
    required bool hasReportOrLedgerEffect,
  }) {
    if (task.status == target) {
      return TaskStatusChangeOutcome.unchanged;
    }
    if (target == PlannerTaskStatus.completed &&
        task.status == PlannerTaskStatus.incomplete &&
        task.requiresReport) {
      return TaskStatusChangeOutcome.reportRequired;
    }
    if (target == PlannerTaskStatus.incomplete &&
        task.status != PlannerTaskStatus.incomplete &&
        hasReportOrLedgerEffect) {
      return TaskStatusChangeOutcome.correctionRequired;
    }
    if (task.status == PlannerTaskStatus.incomplete ||
        target == PlannerTaskStatus.incomplete) {
      return TaskStatusChangeOutcome.changed;
    }
    return TaskStatusChangeOutcome.correctionRequired;
  }
}

final class PlannerTaskValidationException implements Exception {
  const PlannerTaskValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

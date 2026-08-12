import 'package:rmplanner/features/planner/domain/planner_date.dart';

enum PlannerTaskStatus { incomplete, completed, skipped, cancelled }

enum PlannerTaskRecurrence { none, daily, weekly, monthly, yearly }

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
    this.dueMinute,
    this.recurrence = PlannerTaskRecurrence.none,
    this.people = const <String>[],
    this.linkedActivityTypeId,
    this.linkedActivityTypeStableKey,
    this.linkedActivityTypeLabelSnapshot,
  });

  final String id;
  final String title;
  final String? notes;
  final PlannerDate? dueDate;
  final bool requiresReport;
  final String? contributionRuleKey;
  final int? dueMinute;
  final PlannerTaskRecurrence recurrence;
  final List<String> people;
  final String? linkedActivityTypeId;
  final String? linkedActivityTypeStableKey;
  final String? linkedActivityTypeLabelSnapshot;

  PlannerTaskDraft normalized() {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const PlannerTaskValidationException(
        'A Task title cannot be blank.',
      );
    }
    if (dueMinute != null && (dueMinute! < 0 || dueMinute! > 1439)) {
      throw const PlannerTaskValidationException(
        'A Task due time must be a valid time of day.',
      );
    }
    final normalizedDueMinute = dueDate == null ? null : dueMinute;
    final normalizedRecurrence = dueDate == null
        ? PlannerTaskRecurrence.none
        : recurrence;
    final normalizedPeople = <String>[];
    for (final person in people) {
      final normalizedPerson = person.trim();
      if (normalizedPerson.isNotEmpty &&
          !normalizedPeople.contains(normalizedPerson)) {
        normalizedPeople.add(normalizedPerson);
      }
    }
    return PlannerTaskDraft(
      id: id,
      title: normalizedTitle,
      notes: _normalizeOptional(notes),
      dueDate: dueDate,
      requiresReport: requiresReport,
      contributionRuleKey: _normalizeOptional(contributionRuleKey),
      dueMinute: normalizedDueMinute,
      recurrence: normalizedRecurrence,
      people: List<String>.unmodifiable(normalizedPeople),
      linkedActivityTypeId: _normalizeOptional(linkedActivityTypeId),
      linkedActivityTypeStableKey: _normalizeOptional(
        linkedActivityTypeStableKey,
      ),
      linkedActivityTypeLabelSnapshot: _normalizeOptional(
        linkedActivityTypeLabelSnapshot,
      ),
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
    this.dueMinute,
    this.recurrence = PlannerTaskRecurrence.none,
    this.people = const <String>[],
    this.linkedEventIds = const <String>[],
    this.pathwayContextLabels = const <String>[],
    this.linkedActivityTypeId,
    this.linkedActivityTypeStableKey,
    this.linkedActivityTypeLabelSnapshot,
  });

  final String id;
  final String profileId;
  final String title;
  final String? notes;
  final PlannerDate? dueDate;
  final PlannerTaskStatus status;
  final bool requiresReport;
  final String? contributionRuleKey;
  final int? dueMinute;
  final PlannerTaskRecurrence recurrence;
  final List<String> people;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final List<String> linkedEventIds;
  final List<String> pathwayContextLabels;
  final String? linkedActivityTypeId;
  final String? linkedActivityTypeStableKey;
  final String? linkedActivityTypeLabelSnapshot;

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
    this.activityTypeId,
    this.activityTypeStableKeySnapshot,
    this.activityTypeLabelSnapshot,
  });

  final String id;
  final String taskId;
  final String operationId;
  final PlannerTaskStatus fromStatus;
  final PlannerTaskStatus toStatus;
  final String? reason;
  final String? activityTypeId;
  final String? activityTypeStableKeySnapshot;
  final String? activityTypeLabelSnapshot;
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
    bool hasReversibleGoalContribution = false,
  }) {
    if (task.status == target) {
      return TaskStatusChangeOutcome.unchanged;
    }
    if (target == PlannerTaskStatus.incomplete &&
        task.status != PlannerTaskStatus.incomplete &&
        hasReportOrLedgerEffect &&
        !hasReversibleGoalContribution) {
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

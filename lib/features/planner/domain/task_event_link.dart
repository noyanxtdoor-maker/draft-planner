import 'package:rmplanner/features/planner/domain/planner_date.dart';

enum TaskEventLinkScope { series, occurrence }

enum TaskEventLinkStatus { active, removed, brokenReference, historical }

enum TaskEventCanonicalSource { task, event }

enum TaskEventLinkAction {
  created,
  removed,
  repaired,
  markedBroken,
  transferred,
}

enum TaskEventLinkMutationOutcome { changed, unchanged }

final class TaskEventLinkDraft {
  const TaskEventLinkDraft({
    required this.id,
    required this.taskId,
    required this.eventId,
    required this.scope,
    required this.canonicalSource,
    this.occurrenceId,
    this.originalDate,
    this.transferredFromLinkId,
  });

  final String id;
  final String taskId;
  final String eventId;
  final TaskEventLinkScope scope;
  final String? occurrenceId;
  final PlannerDate? originalDate;
  final TaskEventCanonicalSource canonicalSource;
  final String? transferredFromLinkId;

  String get targetKey => switch (scope) {
    TaskEventLinkScope.series => 'series',
    TaskEventLinkScope.occurrence => 'occurrence:$occurrenceId',
  };

  String get canonicalRecordId => switch (canonicalSource) {
    TaskEventCanonicalSource.task => taskId,
    TaskEventCanonicalSource.event => occurrenceId ?? eventId,
  };
}

final class TaskEventLink {
  const TaskEventLink({
    required this.id,
    required this.profileId,
    required this.taskId,
    required this.eventId,
    required this.scope,
    required this.status,
    required this.canonicalSource,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.occurrenceId,
    this.originalDate,
    this.transferredFromLinkId,
  });

  final String id;
  final String profileId;
  final String taskId;
  final String eventId;
  final TaskEventLinkScope scope;
  final String? occurrenceId;
  final PlannerDate? originalDate;
  final TaskEventLinkStatus status;
  final TaskEventCanonicalSource canonicalSource;
  final String? transferredFromLinkId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  String get canonicalRecordId => switch (canonicalSource) {
    TaskEventCanonicalSource.task => taskId,
    TaskEventCanonicalSource.event => occurrenceId ?? eventId,
  };

  String get scheduledPotentialExplanation {
    if (status != TaskEventLinkStatus.active) {
      return 'This link contributes no Scheduled Potential because it is '
          '${taskEventLinkStatusLabel(status).toLowerCase()}.';
    }
    final source = canonicalSource == TaskEventCanonicalSource.task
        ? 'the Task'
        : scope == TaskEventLinkScope.occurrence
        ? 'this Calendar Event occurrence'
        : 'the Calendar Event series';
    return 'The link itself contributes nothing. Future Scheduled Potential '
        'may count once through $source when an explicit contribution rule '
        'qualifies it.';
  }
}

final class TaskEventLinkView {
  const TaskEventLinkView({
    required this.link,
    required this.taskTitle,
    required this.eventTitle,
    required this.taskExists,
    required this.eventExists,
    this.eventStartDate,
  });

  final TaskEventLink link;
  final String taskTitle;
  final String eventTitle;
  final bool taskExists;
  final bool eventExists;
  final PlannerDate? eventStartDate;

  bool get isBroken => !taskExists || !eventExists;
}

final class TaskEventTaskCandidate {
  const TaskEventTaskCandidate({
    required this.id,
    required this.title,
    required this.statusLabel,
  });

  final String id;
  final String title;
  final String statusLabel;
}

final class TaskEventEventCandidate {
  const TaskEventEventCandidate({
    required this.id,
    required this.title,
    required this.startDate,
    required this.isRecurring,
    required this.statusLabel,
  });

  final String id;
  final String title;
  final PlannerDate startDate;
  final bool isRecurring;
  final String statusLabel;
}

final class TaskEventLinkValidationException implements Exception {
  const TaskEventLinkValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String taskEventLinkScopeLabel(TaskEventLinkScope scope) {
  return switch (scope) {
    TaskEventLinkScope.series => 'Series',
    TaskEventLinkScope.occurrence => 'Occurrence',
  };
}

String taskEventLinkStatusLabel(TaskEventLinkStatus status) {
  return switch (status) {
    TaskEventLinkStatus.active => 'Active',
    TaskEventLinkStatus.removed => 'Removed',
    TaskEventLinkStatus.brokenReference => 'Broken reference',
    TaskEventLinkStatus.historical => 'Historical',
  };
}

String taskEventCanonicalSourceLabel(TaskEventCanonicalSource source) {
  return switch (source) {
    TaskEventCanonicalSource.task => 'Task',
    TaskEventCanonicalSource.event => 'Calendar Event',
  };
}

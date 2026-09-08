import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';

abstract interface class TaskEventLinkRepository
    implements
        PlannerTaskContextSource,
        CalendarEventTaskContextSource,
        CalendarEventLinkContextTransfer {
  Future<List<TaskEventLinkView>> readForTask({
    required String profileId,
    required String taskId,
  });

  Future<List<TaskEventLinkView>> readForEvent({
    required String profileId,
    required String eventId,
    required String occurrenceId,
  });

  Future<List<TaskEventTaskCandidate>> readTaskCandidates({
    required String profileId,
  });

  Future<List<TaskEventEventCandidate>> readEventCandidates({
    required String profileId,
  });

  Future<TaskEventLinkMutationOutcome> createLink({
    required String profileId,
    required TaskEventLinkDraft draft,
    required String operationId,
  });

  Future<TaskEventLinkMutationOutcome> removeLink({
    required String profileId,
    required String linkId,
    required String operationId,
    String? occurrenceOverrideId,
    PlannerDate? occurrenceOverrideDate,
  });

  Future<TaskEventLinkMutationOutcome> repairLink({
    required String profileId,
    required String linkId,
    required String taskId,
    required String eventId,
    required String operationId,
  });
}

abstract interface class TaskEventLinkCoordinator {
  Future<TaskEventLinkMutationOutcome> createEventFromTask({
    required String profileId,
    required String taskId,
    required CalendarEventDraft event,
    required String linkId,
    required String operationId,
    required TaskEventCanonicalSource canonicalSource,
  });
}

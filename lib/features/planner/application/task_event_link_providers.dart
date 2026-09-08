import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final taskEventLinkRepositoryProvider = Provider<TaskEventLinkRepository>((
  ref,
) {
  throw StateError(
    'TaskEventLinkRepository must be overridden at the app root',
  );
});

final taskEventLinkCoordinatorProvider = Provider<TaskEventLinkCoordinator>((
  ref,
) {
  throw StateError(
    'TaskEventLinkCoordinator must be overridden at the app root',
  );
});

final taskEventLinkControllerProvider =
    NotifierProvider<TaskEventLinkController, String?>(
      TaskEventLinkController.new,
    );

final class TaskEventLinkController extends Notifier<String?> {
  TaskEventLinkRepository get _repository =>
      ref.read(taskEventLinkRepositoryProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Task-Event linking requires a ready Local Profile');
    }
    return startup.profile.id;
  }

  @override
  String? build() => null;

  Future<List<TaskEventLinkView>> readForTask(String taskId) {
    return _repository.readForTask(profileId: _profileId, taskId: taskId);
  }

  Future<List<TaskEventLinkView>> readForEvent({
    required String eventId,
    required String occurrenceId,
  }) {
    return _repository.readForEvent(
      profileId: _profileId,
      eventId: eventId,
      occurrenceId: occurrenceId,
    );
  }

  Future<List<TaskEventTaskCandidate>> readTaskCandidates() {
    return _repository.readTaskCandidates(profileId: _profileId);
  }

  Future<List<TaskEventEventCandidate>> readEventCandidates() {
    return _repository.readEventCandidates(profileId: _profileId);
  }

  Future<bool> createLink({
    required TaskEventLinkDraft draft,
    required String operationId,
  }) {
    return _run(
      () => _repository.createLink(
        profileId: _profileId,
        draft: draft,
        operationId: operationId,
      ),
    );
  }

  Future<bool> createEventFromTask({
    required String taskId,
    required CalendarEventDraft event,
    required String linkId,
    required String operationId,
    required TaskEventCanonicalSource canonicalSource,
  }) {
    return _run(
      () => ref
          .read(taskEventLinkCoordinatorProvider)
          .createEventFromTask(
            profileId: _profileId,
            taskId: taskId,
            event: event,
            linkId: linkId,
            operationId: operationId,
            canonicalSource: canonicalSource,
          ),
    );
  }

  Future<bool> removeLink({
    required String linkId,
    required String operationId,
    String? occurrenceOverrideId,
    PlannerDate? occurrenceOverrideDate,
  }) {
    return _run(
      () => _repository.removeLink(
        profileId: _profileId,
        linkId: linkId,
        operationId: operationId,
        occurrenceOverrideId: occurrenceOverrideId,
        occurrenceOverrideDate: occurrenceOverrideDate,
      ),
    );
  }

  Future<bool> repairLink({
    required String linkId,
    required String taskId,
    required String eventId,
    required String operationId,
  }) {
    return _run(
      () => _repository.repairLink(
        profileId: _profileId,
        linkId: linkId,
        taskId: taskId,
        eventId: eventId,
        operationId: operationId,
      ),
    );
  }

  void clearMessage() {
    state = null;
  }

  Future<bool> _run(
    Future<TaskEventLinkMutationOutcome> Function() command,
  ) async {
    try {
      await command();
      await ref
          .read(plannerControllerProvider.notifier)
          .selectDate(ref.read(plannerControllerProvider).selectedDate);
      state = null;
      return true;
    } on TaskEventLinkValidationException catch (error) {
      state = error.message;
      return false;
    } on Object {
      state =
          'The link was not changed. Your selections remain available '
          'and you can safely retry.';
      return false;
    }
  }
}

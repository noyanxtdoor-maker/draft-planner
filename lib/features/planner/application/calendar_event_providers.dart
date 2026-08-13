import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final calendarEventRepositoryProvider = Provider<CalendarEventRepository>((
  ref,
) {
  throw StateError(
    'CalendarEventRepository must be overridden at the app root',
  );
});

final calendarEventControllerProvider =
    NotifierProvider<CalendarEventController, String?>(
      CalendarEventController.new,
    );

final class CalendarEventController extends Notifier<String?> {
  CalendarEventRepository get _repository =>
      ref.read(calendarEventRepositoryProvider);

  String get displayTimeZoneId => _repository.displayTimeZoneId;

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Calendar Events require a ready Local Profile');
    }
    return startup.profile.id;
  }

  @override
  String? build() => null;

  bool isValidTimeZone(String value) => _repository.isValidTimeZone(value);

  Future<CalendarEventDraft?> readEventDraft(String eventId) {
    return _repository.readEventDraft(profileId: _profileId, eventId: eventId);
  }

  Future<CalendarEventOccurrence?> readOccurrence({
    required String eventId,
    required PlannerDate originalDate,
  }) {
    return _repository.readOccurrence(
      profileId: _profileId,
      eventId: eventId,
      originalDate: originalDate,
    );
  }

  Future<bool> saveEvent(CalendarEventDraft draft) async {
    try {
      await _repository.saveEvent(profileId: _profileId, draft: draft);
      await _refreshPlanner();
      state = null;
      return true;
    } on CalendarEventValidationException catch (error) {
      state = error.message;
      return false;
    } on Object {
      state =
          'Calendar Event could not be saved. Your input remains available '
          'to retry.';
      return false;
    }
  }

  Future<bool> editEvent({
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft draft,
    required String operationId,
    bool refreshPlanner = true,
    bool awaitPlannerRefresh = true,
  }) async {
    return _runMutation(
      () => _repository.editEvent(
        profileId: _profileId,
        eventId: eventId,
        originalDate: originalDate,
        scope: scope,
        draft: draft,
        operationId: operationId,
      ),
      refreshPlanner: refreshPlanner,
      awaitPlannerRefresh: awaitPlannerRefresh,
    );
  }

  Future<bool> cancelEvent({
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required String operationId,
    bool refreshPlanner = true,
    bool managePendingDeletion = true,
  }) async {
    final targets = switch (scope) {
      CalendarEventEditScope.series => PlannerEventDeletionTargetSet.series(
        eventId,
      ),
      CalendarEventEditScope.occurrence =>
        PlannerEventDeletionTargetSet.occurrence(
          eventId: eventId,
          originalDate: originalDate,
        ),
      // ThisAndFuture hides the clicked occurrence (same transient identity
      // as an occurrence delete) but its durable mutation affects future
      // dates too, so its confirmation must stay BROAD.
      CalendarEventEditScope.thisAndFuture =>
        PlannerEventDeletionTargetSet.thisAndFuture(
          eventId: eventId,
          originalDate: originalDate,
        ),
    };
    final planner = ref.read(plannerControllerProvider.notifier);
    if (managePendingDeletion) {
      planner.beginPendingEventDeletion(targets);
    }
    try {
      await _repository.cancelEvent(
        profileId: _profileId,
        eventId: eventId,
        originalDate: originalDate,
        scope: scope,
        operationId: operationId,
      );
      if (managePendingDeletion) {
        final confirmed = await planner.confirmPendingEventDeletion(targets);
        if (!confirmed) {
          state = 'Calendar Event was not changed. You can safely retry.';
          return false;
        }
      } else if (refreshPlanner) {
        await _refreshPlanner();
      }
      state = null;
      return true;
    } on CalendarEventValidationException catch (error) {
      if (managePendingDeletion) {
        planner.rollbackPendingEventDeletion(targets);
      }
      state = error.message;
      return false;
    } on Object {
      if (managePendingDeletion) {
        planner.rollbackPendingEventDeletion(targets);
      }
      state = 'Calendar Event was not changed. You can safely retry.';
      return false;
    }
  }

  Future<bool> rescheduleEvent({
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft replacement,
    required String operationId,
    bool refreshPlanner = true,
  }) async {
    return _runMutation(
      () => _repository.rescheduleEvent(
        profileId: _profileId,
        eventId: eventId,
        originalDate: originalDate,
        scope: scope,
        replacement: replacement,
        operationId: operationId,
      ),
      refreshPlanner: refreshPlanner,
    );
  }

  Future<bool> duplicateEvent({
    required String eventId,
    required PlannerDate originalDate,
    required String duplicateId,
    required String operationId,
  }) async {
    return _runMutation(
      () => _repository.duplicateEvent(
        profileId: _profileId,
        eventId: eventId,
        originalDate: originalDate,
        duplicateId: duplicateId,
        operationId: operationId,
      ),
    );
  }

  void clearMessage() {
    state = null;
  }

  Future<bool> _runMutation(
    Future<CalendarEventMutationOutcome> Function() command, {
    bool refreshPlanner = true,
    bool awaitPlannerRefresh = true,
  }) async {
    try {
      await command();
      if (refreshPlanner) {
        if (awaitPlannerRefresh) {
          await _refreshPlanner();
        } else {
          // Background refresh for the normal Edit form: the durable Event
          // write is the truth gate, so dismissal must not wait on the
          // selected-day reload. Failures are surfaced through PlannerState;
          // an unexpected error must never escape as an unhandled async
          // error, hence the explicit swallow on the unawaited future.
          unawaited(_refreshPlanner().catchError((Object _) {}));
        }
      }
      state = null;
      return true;
    } on CalendarEventValidationException catch (error) {
      state = error.message;
      return false;
    } on Object {
      state = 'Calendar Event was not changed. You can safely retry.';
      return false;
    }
  }

  Future<void> _refreshPlanner() {
    final planner = ref.read(plannerControllerProvider.notifier);
    return planner.selectDate(ref.read(plannerControllerProvider).selectedDate);
  }
}

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
    );
  }

  Future<bool> cancelEvent({
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required String operationId,
  }) async {
    return _runMutation(
      () => _repository.cancelEvent(
        profileId: _profileId,
        eventId: eventId,
        originalDate: originalDate,
        scope: scope,
        operationId: operationId,
      ),
    );
  }

  Future<bool> rescheduleEvent({
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft replacement,
    required String operationId,
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
    Future<CalendarEventMutationOutcome> Function() command,
  ) async {
    try {
      await command();
      await _refreshPlanner();
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

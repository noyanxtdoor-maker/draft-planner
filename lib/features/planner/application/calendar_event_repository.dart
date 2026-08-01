import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

abstract interface class CalendarEventReportSource {
  Future<List<CalendarEventReportSnapshot>> readSeriesReports(String eventId);
}

final class EmptyCalendarEventReportSource
    implements CalendarEventReportSource {
  const EmptyCalendarEventReportSource();

  @override
  Future<List<CalendarEventReportSnapshot>> readSeriesReports(
    String eventId,
  ) async {
    return const <CalendarEventReportSnapshot>[];
  }
}

abstract interface class CalendarEventTaskContextSource {
  Future<List<String>> readLinkedTaskIds({
    required String eventId,
    required String occurrenceId,
  });
}

final class EmptyCalendarEventTaskContextSource
    implements CalendarEventTaskContextSource {
  const EmptyCalendarEventTaskContextSource();

  @override
  Future<List<String>> readLinkedTaskIds({
    required String eventId,
    required String occurrenceId,
  }) async {
    return const <String>[];
  }
}

abstract interface class CalendarEventLinkContextTransfer {
  Future<void> transferOnReschedule({
    required String profileId,
    required String sourceEventId,
    required String sourceOccurrenceId,
    required PlannerDate sourceOriginalDate,
    required CalendarEventEditScope scope,
    required String replacementEventId,
    required PlannerDate replacementOriginalDate,
    required String operationId,
  });
}

final class EmptyCalendarEventLinkContextTransfer
    implements CalendarEventLinkContextTransfer {
  const EmptyCalendarEventLinkContextTransfer();

  @override
  Future<void> transferOnReschedule({
    required String profileId,
    required String sourceEventId,
    required String sourceOccurrenceId,
    required PlannerDate sourceOriginalDate,
    required CalendarEventEditScope scope,
    required String replacementEventId,
    required PlannerDate replacementOriginalDate,
    required String operationId,
  }) async {}
}

abstract interface class CalendarEventRepository
    implements PlannerCalendarSource {
  String get displayTimeZoneId;

  bool isValidTimeZone(String timeZoneId);

  Future<CalendarEventDraft?> readEventDraft({
    required String profileId,
    required String eventId,
  });

  Future<CalendarEventOccurrence?> readOccurrence({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
  });

  Future<CalendarEventDraft> saveEvent({
    required String profileId,
    required CalendarEventDraft draft,
  });

  Future<CalendarEventMutationOutcome> editEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft draft,
    required String operationId,
  });

  Future<CalendarEventMutationOutcome> cancelEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required String operationId,
  });

  Future<CalendarEventMutationOutcome> rescheduleEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft replacement,
    required String operationId,
  });

  Future<CalendarEventMutationOutcome> duplicateEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required String duplicateId,
    required String operationId,
  });
}

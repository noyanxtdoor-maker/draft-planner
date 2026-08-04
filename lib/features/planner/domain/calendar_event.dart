import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:uuid/uuid.dart';

enum CalendarEventTiming { allDay, timed }

enum CalendarEventStatus {
  scheduled,
  completedHappened,
  partiallyCompleted,
  didNotHappen,
  cancelled,
  rescheduled,
}

enum CalendarRecurrenceFrequency { none, daily, weekly, monthly, yearly }

enum CalendarRecurrenceEndMode { never, onDate, afterCount }

enum CalendarEventEditScope { occurrence, thisAndFuture, series }

enum CalendarEventMutationOutcome { changed, unchanged }

final class CalendarEventValidationException implements Exception {
  const CalendarEventValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CalendarRecurrenceRule {
  const CalendarRecurrenceRule({
    this.frequency = CalendarRecurrenceFrequency.none,
    this.endMode = CalendarRecurrenceEndMode.never,
    this.endDate,
    this.occurrenceCount,
  });

  final CalendarRecurrenceFrequency frequency;
  final CalendarRecurrenceEndMode endMode;
  final PlannerDate? endDate;
  final int? occurrenceCount;

  bool get isRecurring => frequency != CalendarRecurrenceFrequency.none;

  CalendarRecurrenceRule normalizedFor(PlannerDate startDate) {
    if (!isRecurring) {
      return const CalendarRecurrenceRule();
    }
    switch (endMode) {
      case CalendarRecurrenceEndMode.never:
        return CalendarRecurrenceRule(frequency: frequency);
      case CalendarRecurrenceEndMode.onDate:
        final value = endDate;
        if (value == null || value.compareTo(startDate) < 0) {
          throw const CalendarEventValidationException(
            'Recurrence end date cannot be before the first occurrence.',
          );
        }
        return CalendarRecurrenceRule(
          frequency: frequency,
          endMode: endMode,
          endDate: value,
        );
      case CalendarRecurrenceEndMode.afterCount:
        final value = occurrenceCount;
        if (value == null || value < 1) {
          throw const CalendarEventValidationException(
            'Recurrence count must be at least 1.',
          );
        }
        return CalendarRecurrenceRule(
          frequency: frequency,
          endMode: endMode,
          occurrenceCount: value,
        );
    }
  }

  int? occurrenceIndexOn({
    required PlannerDate startDate,
    required PlannerDate targetDate,
  }) {
    if (targetDate.compareTo(startDate) < 0) {
      return null;
    }
    final index = switch (frequency) {
      CalendarRecurrenceFrequency.none => targetDate == startDate ? 0 : null,
      CalendarRecurrenceFrequency.daily => _dayDifference(
        startDate,
        targetDate,
      ),
      CalendarRecurrenceFrequency.weekly => _weeklyIndex(startDate, targetDate),
      CalendarRecurrenceFrequency.monthly => _monthlyIndex(
        startDate,
        targetDate,
      ),
      CalendarRecurrenceFrequency.yearly => _yearlyIndex(startDate, targetDate),
    };
    if (index == null) {
      return null;
    }
    if (endMode == CalendarRecurrenceEndMode.onDate &&
        targetDate.compareTo(endDate!) > 0) {
      return null;
    }
    if (endMode == CalendarRecurrenceEndMode.afterCount &&
        index >= occurrenceCount!) {
      return null;
    }
    return index;
  }

  PlannerDate occurrenceAt({
    required PlannerDate startDate,
    required int index,
  }) {
    if (index < 0) {
      throw RangeError.range(index, 0, null, 'index');
    }
    return switch (frequency) {
      CalendarRecurrenceFrequency.none when index == 0 => startDate,
      CalendarRecurrenceFrequency.none => throw RangeError.range(
        index,
        0,
        0,
        'index',
      ),
      CalendarRecurrenceFrequency.daily => startDate.addDays(index),
      CalendarRecurrenceFrequency.weekly => startDate.addDays(index * 7),
      CalendarRecurrenceFrequency.monthly => _addMonths(startDate, index),
      CalendarRecurrenceFrequency.yearly => _addYears(startDate, index),
    };
  }

  static int _dayDifference(PlannerDate start, PlannerDate target) {
    return target.asLocalDate.difference(start.asLocalDate).inDays;
  }

  static int? _weeklyIndex(PlannerDate start, PlannerDate target) {
    final days = _dayDifference(start, target);
    return days % 7 == 0 ? days ~/ 7 : null;
  }

  static int? _monthlyIndex(PlannerDate start, PlannerDate target) {
    final months = (target.year - start.year) * 12 + target.month - start.month;
    return _addMonths(start, months) == target ? months : null;
  }

  static int? _yearlyIndex(PlannerDate start, PlannerDate target) {
    final years = target.year - start.year;
    return _addYears(start, years) == target ? years : null;
  }

  static PlannerDate _addMonths(PlannerDate start, int months) {
    final absoluteMonth = start.year * 12 + start.month - 1 + months;
    final year = absoluteMonth ~/ 12;
    final month = absoluteMonth % 12 + 1;
    final day = start.day.clamp(1, _daysInMonth(year, month));
    return PlannerDate(year: year, month: month, day: day);
  }

  static PlannerDate _addYears(PlannerDate start, int years) {
    final year = start.year + years;
    final day = start.day.clamp(1, _daysInMonth(year, start.month));
    return PlannerDate(year: year, month: start.month, day: day);
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}

final class CalendarEventDraft {
  const CalendarEventDraft({
    required this.id,
    required this.title,
    required this.timing,
    required this.startDate,
    required this.requiresReport,
    this.status = CalendarEventStatus.scheduled,
    this.notes,
    this.startMinute,
    this.endMinute,
    this.timeZoneId,
    this.locationText,
    this.activityTypeId,
    this.activityTypeMappingVersion,
    this.activityTypeStableKeySnapshot,
    this.activityTypeLabelSnapshot,
    this.activityTypeColorValueSnapshot,
    this.contributionRuleKey,
    this.isBackupAppointment = false,
    this.backupForEventId,
    this.backupRelationshipProvenance,
    this.recurrence = const CalendarRecurrenceRule(),
  });

  final String id;
  final String title;
  final String? notes;
  final CalendarEventTiming timing;
  final PlannerDate startDate;
  final CalendarEventStatus status;
  final int? startMinute;
  final int? endMinute;
  final String? timeZoneId;
  final String? locationText;
  final String? activityTypeId;
  final int? activityTypeMappingVersion;
  final String? activityTypeStableKeySnapshot;
  final String? activityTypeLabelSnapshot;
  final int? activityTypeColorValueSnapshot;
  final bool requiresReport;
  final String? contributionRuleKey;
  final bool isBackupAppointment;
  final String? backupForEventId;
  final String? backupRelationshipProvenance;
  final CalendarRecurrenceRule recurrence;

  CalendarEventDraft normalized() {
    if (!Uuid.isValidUUID(fromString: id)) {
      throw const CalendarEventValidationException(
        'Calendar Events require stable UUID identifiers.',
      );
    }
    final normalizedTitle = _normalizeOptional(title);
    final normalizedNotes = _normalizeOptional(notes);
    final normalizedLocation = _normalizeOptional(locationText);
    final normalizedActivityTypeStableKey = _normalizeOptional(
      activityTypeStableKeySnapshot,
    );
    final normalizedActivityTypeLabel = _normalizeOptional(
      activityTypeLabelSnapshot,
    );
    final normalizedContribution = _normalizeOptional(contributionRuleKey);
    final normalizedRecurrence = recurrence.normalizedFor(startDate);
    if (timing == CalendarEventTiming.allDay) {
      return CalendarEventDraft(
        id: id,
        title: normalizedTitle ?? '',
        notes: normalizedNotes,
        timing: timing,
        startDate: startDate,
        requiresReport: requiresReport,
        status: status,
        locationText: normalizedLocation,
        activityTypeId: activityTypeId,
        activityTypeMappingVersion: activityTypeMappingVersion,
        activityTypeStableKeySnapshot: normalizedActivityTypeStableKey,
        activityTypeLabelSnapshot: normalizedActivityTypeLabel,
        activityTypeColorValueSnapshot: activityTypeColorValueSnapshot,
        contributionRuleKey: normalizedContribution,
        isBackupAppointment: isBackupAppointment,
        backupForEventId: isBackupAppointment
            ? _normalizeOptional(backupForEventId)
            : null,
        backupRelationshipProvenance: isBackupAppointment
            ? _normalizeOptional(backupRelationshipProvenance)
            : null,
        recurrence: normalizedRecurrence,
      );
    }
    final start = startMinute;
    final end = endMinute;
    if (start == null ||
        end == null ||
        start < 0 ||
        start > 1439 ||
        end < 1 ||
        end > 1440 ||
        end <= start) {
      throw const CalendarEventValidationException(
        'Timed events need a valid end time after the start time.',
      );
    }
    final zone = _normalizeOptional(timeZoneId);
    if (zone == null) {
      throw const CalendarEventValidationException(
        'Timed events require an IANA time-zone identity.',
      );
    }
    return CalendarEventDraft(
      id: id,
      title: normalizedTitle ?? '',
      notes: normalizedNotes,
      timing: timing,
      startDate: startDate,
      startMinute: start,
      endMinute: end,
      timeZoneId: zone,
      locationText: normalizedLocation,
      activityTypeId: activityTypeId,
      activityTypeMappingVersion: activityTypeMappingVersion,
      activityTypeStableKeySnapshot: normalizedActivityTypeStableKey,
      activityTypeLabelSnapshot: normalizedActivityTypeLabel,
      activityTypeColorValueSnapshot: activityTypeColorValueSnapshot,
      requiresReport: requiresReport,
      status: status,
      contributionRuleKey: normalizedContribution,
      isBackupAppointment: isBackupAppointment,
      backupForEventId: isBackupAppointment
          ? _normalizeOptional(backupForEventId)
          : null,
      backupRelationshipProvenance: isBackupAppointment
          ? _normalizeOptional(backupRelationshipProvenance)
          : null,
      recurrence: normalizedRecurrence,
    );
  }

  CalendarEventDraft copyWith({
    String? id,
    String? title,
    String? notes,
    CalendarEventTiming? timing,
    PlannerDate? startDate,
    CalendarEventStatus? status,
    int? startMinute,
    int? endMinute,
    String? timeZoneId,
    String? locationText,
    String? activityTypeId,
    int? activityTypeMappingVersion,
    String? activityTypeStableKeySnapshot,
    String? activityTypeLabelSnapshot,
    int? activityTypeColorValueSnapshot,
    bool? requiresReport,
    String? contributionRuleKey,
    bool? isBackupAppointment,
    String? backupForEventId,
    String? backupRelationshipProvenance,
    CalendarRecurrenceRule? recurrence,
  }) {
    return CalendarEventDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      timing: timing ?? this.timing,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      locationText: locationText ?? this.locationText,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      activityTypeMappingVersion:
          activityTypeMappingVersion ?? this.activityTypeMappingVersion,
      activityTypeStableKeySnapshot:
          activityTypeStableKeySnapshot ?? this.activityTypeStableKeySnapshot,
      activityTypeLabelSnapshot:
          activityTypeLabelSnapshot ?? this.activityTypeLabelSnapshot,
      activityTypeColorValueSnapshot:
          activityTypeColorValueSnapshot ?? this.activityTypeColorValueSnapshot,
      requiresReport: requiresReport ?? this.requiresReport,
      contributionRuleKey: contributionRuleKey ?? this.contributionRuleKey,
      isBackupAppointment: isBackupAppointment ?? this.isBackupAppointment,
      backupForEventId: backupForEventId ?? this.backupForEventId,
      backupRelationshipProvenance:
          backupRelationshipProvenance ?? this.backupRelationshipProvenance,
      recurrence: recurrence ?? this.recurrence,
    );
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

/// Returns the human-visible title for a stored Calendar Event.
///
/// Prefers the user-entered title; falls back to the Event Type label
/// when the user left the title blank. Callers should never substitute
/// a generic placeholder string here.
String calendarEventDisplayTitle({
  required String? storedTitle,
  required String? eventTypeLabel,
}) {
  final trimmed = storedTitle?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  final label = eventTypeLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return '';
}

/// Returns the human-visible title for a Planner display item.
String plannerItemDisplayTitle({
  required String storedTitle,
  required String? eventTypeLabel,
}) {
  final resolved = calendarEventDisplayTitle(
    storedTitle: storedTitle,
    eventTypeLabel: eventTypeLabel,
  );
  return resolved.isEmpty ? 'Calendar Event' : resolved;
}

final class CalendarEventOccurrence {
  const CalendarEventOccurrence({
    required this.id,
    required this.eventId,
    required this.profileId,
    required this.title,
    required this.timing,
    required this.originalDate,
    required this.displayDate,
    required this.status,
    required this.requiresReport,
    required this.recurrence,
    this.notes,
    this.startUtc,
    this.endUtc,
    this.startDisplay,
    this.endDisplay,
    this.timeZoneId,
    this.displayTimeZoneId,
    this.locationText,
    this.activityTypeId,
    this.activityTypeMappingVersion,
    this.activityTypeStableKey,
    this.activityTypeLabel,
    this.activityTypeColorValue,
    this.contributionRuleKey,
    this.isBackupAppointment = false,
    this.backupForEventId,
    this.backupRelationshipProvenance,
    this.replacementEventId,
    this.linkedTaskIds = const <String>[],
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  final String id;
  final String eventId;
  final String profileId;
  final String title;
  final String? notes;
  final CalendarEventTiming timing;
  final PlannerDate originalDate;
  final PlannerDate displayDate;
  final DateTime? startUtc;
  final DateTime? endUtc;
  final DateTime? startDisplay;
  final DateTime? endDisplay;
  final String? timeZoneId;
  final String? displayTimeZoneId;
  final String? locationText;
  final String? activityTypeId;
  final int? activityTypeMappingVersion;
  final String? activityTypeStableKey;
  final String? activityTypeLabel;
  final int? activityTypeColorValue;
  final CalendarEventStatus status;
  final bool requiresReport;
  final String? contributionRuleKey;
  final bool isBackupAppointment;
  final String? backupForEventId;
  final String? backupRelationshipProvenance;
  final CalendarRecurrenceRule recurrence;
  final String? replacementEventId;
  final List<String> linkedTaskIds;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  bool get isRecurring => recurrence.isRecurring;

  /// Human-visible title with the Event Type label fallback.
  String get displayTitle => calendarEventDisplayTitle(
    storedTitle: title,
    eventTypeLabel: activityTypeLabel,
  );

  bool get isChange =>
      status == CalendarEventStatus.cancelled ||
      status == CalendarEventStatus.rescheduled;

  bool isAwaitingReport({
    required DateTime nowUtc,
    required PlannerDate displayToday,
  }) {
    if (status != CalendarEventStatus.scheduled || !requiresReport) {
      return false;
    }
    if (timing == CalendarEventTiming.allDay) {
      return displayDate.compareTo(displayToday) < 0;
    }
    final end = endUtc;
    return end != null && end.isBefore(nowUtc);
  }
}

final class CalendarEventReportSnapshot {
  const CalendarEventReportSnapshot({
    required this.occurrenceId,
    required this.originalDate,
    required this.status,
  }) : assert(
         status == CalendarEventStatus.completedHappened ||
             status == CalendarEventStatus.partiallyCompleted ||
             status == CalendarEventStatus.didNotHappen,
       );

  final String occurrenceId;
  final PlannerDate originalDate;
  final CalendarEventStatus status;
}

abstract final class CalendarEventOccurrenceIdentity {
  static const Uuid _uuid = Uuid();

  static String forDate({
    required String eventId,
    required PlannerDate originalDate,
  }) {
    return _uuid.v5(
      Namespace.url.value,
      'com.nexttransfer.rmplanner:event:$eventId:${originalDate.iso8601}',
    );
  }
}

abstract final class CalendarEventExceptionIdentity {
  static const Uuid _uuid = Uuid();

  static String forOperation({
    required String operationId,
    required String occurrenceId,
  }) {
    return _uuid.v5(
      Namespace.url.value,
      'com.nexttransfer.rmplanner:event-exception:'
      '$operationId:$occurrenceId',
    );
  }
}

String calendarEventStatusLabel(CalendarEventStatus status) {
  return switch (status) {
    CalendarEventStatus.scheduled => 'Unreported',
    CalendarEventStatus.completedHappened => 'Completed',
    CalendarEventStatus.partiallyCompleted => 'Missed - Attempted',
    CalendarEventStatus.didNotHappen => 'Did Not Attempt',
    CalendarEventStatus.cancelled => 'Cancelled',
    CalendarEventStatus.rescheduled => 'Rescheduled',
  };
}

String calendarEventOutcomeLabel({
  required CalendarEventStatus status,
  required bool isContactEvent,
}) {
  return switch (status) {
    CalendarEventStatus.scheduled => 'Unreported',
    CalendarEventStatus.completedHappened =>
      isContactEvent ? 'Contacted' : 'Completed',
    CalendarEventStatus.partiallyCompleted => 'Missed - Attempted',
    CalendarEventStatus.didNotHappen => 'Did Not Attempt',
    CalendarEventStatus.cancelled => 'Cancelled',
    CalendarEventStatus.rescheduled => 'Rescheduled',
  };
}

String calendarEventScopeLabel(CalendarEventEditScope scope) {
  return switch (scope) {
    CalendarEventEditScope.occurrence => 'This occurrence',
    CalendarEventEditScope.thisAndFuture => 'This and future',
    CalendarEventEditScope.series => 'Entire series',
  };
}

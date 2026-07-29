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
    this.notes,
    this.startMinute,
    this.endMinute,
    this.timeZoneId,
    this.locationText,
    this.activityTypeId,
    this.activityTypeMappingVersion,
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
  final int? startMinute;
  final int? endMinute;
  final String? timeZoneId;
  final String? locationText;
  final String? activityTypeId;
  final int? activityTypeMappingVersion;
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
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const CalendarEventValidationException(
        'Calendar Event title is required.',
      );
    }
    final normalizedNotes = _normalizeOptional(notes);
    final normalizedLocation = _normalizeOptional(locationText);
    final normalizedContribution = _normalizeOptional(contributionRuleKey);
    final normalizedRecurrence = recurrence.normalizedFor(startDate);
    if (timing == CalendarEventTiming.allDay) {
      return CalendarEventDraft(
        id: id,
        title: normalizedTitle,
        notes: normalizedNotes,
        timing: timing,
        startDate: startDate,
        requiresReport: requiresReport,
        locationText: normalizedLocation,
        activityTypeId: activityTypeId,
        activityTypeMappingVersion: activityTypeMappingVersion,
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
      title: normalizedTitle,
      notes: normalizedNotes,
      timing: timing,
      startDate: startDate,
      startMinute: start,
      endMinute: end,
      timeZoneId: zone,
      locationText: normalizedLocation,
      activityTypeId: activityTypeId,
      activityTypeMappingVersion: activityTypeMappingVersion,
      requiresReport: requiresReport,
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
    int? startMinute,
    int? endMinute,
    String? timeZoneId,
    String? locationText,
    String? activityTypeId,
    int? activityTypeMappingVersion,
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
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      locationText: locationText ?? this.locationText,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      activityTypeMappingVersion:
          activityTypeMappingVersion ?? this.activityTypeMappingVersion,
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
    this.activityTypeLabel,
    this.activityTypeColorValue,
    this.contributionRuleKey,
    this.isBackupAppointment = false,
    this.backupForEventId,
    this.backupRelationshipProvenance,
    this.replacementEventId,
    this.linkedTaskIds = const <String>[],
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

  bool get isRecurring => recurrence.isRecurring;

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
    CalendarEventStatus.scheduled => 'Scheduled',
    CalendarEventStatus.completedHappened => 'Completed / Happened',
    CalendarEventStatus.partiallyCompleted => 'Partially Completed',
    CalendarEventStatus.didNotHappen => 'Did Not Happen',
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

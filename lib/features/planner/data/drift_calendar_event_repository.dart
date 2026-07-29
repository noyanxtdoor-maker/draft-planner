import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:uuid/uuid.dart';

abstract interface class CalendarEventWriteGuard {
  Future<void> beforeCommit();
}

final class AllowCalendarEventWrites implements CalendarEventWriteGuard {
  const AllowCalendarEventWrites();

  @override
  Future<void> beforeCommit() async {}
}

final class DriftCalendarEventRepository implements CalendarEventRepository {
  const DriftCalendarEventRepository({
    required this.database,
    required this.clock,
    required this.timeZones,
    this.reportSource = const EmptyCalendarEventReportSource(),
    this.taskContextSource = const EmptyCalendarEventTaskContextSource(),
    this.linkContextTransfer = const EmptyCalendarEventLinkContextTransfer(),
    this.writeGuard = const AllowCalendarEventWrites(),
  });

  final AppDatabase database;
  final AppClock clock;
  final IanaCalendarEventTimeZones timeZones;
  final CalendarEventReportSource reportSource;
  final CalendarEventTaskContextSource taskContextSource;
  final CalendarEventLinkContextTransfer linkContextTransfer;
  final CalendarEventWriteGuard writeGuard;

  @override
  String get displayTimeZoneId => timeZones.displayTimeZoneId;

  @override
  bool isValidTimeZone(String timeZoneId) => timeZones.isValid(timeZoneId);

  @override
  Future<List<PlannerCalendarItem>> readDay({
    required String profileId,
    required PlannerDate date,
  }) async {
    final rows =
        await (database.select(database.calendarEvents)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(CalendarEvents)>[
                (table) => OrderingTerm.asc(table.createdAtUtc),
              ]))
            .get();
    final items = <PlannerCalendarItem>[];
    for (final row in rows) {
      final reports = await reportSource.readSeriesReports(row.id);
      final reportById = <String, CalendarEventReportSnapshot>{
        for (final report in reports) report.occurrenceId: report,
      };
      final exceptions = await _latestExceptions(row.id);
      final candidates = row.timing == CalendarEventTiming.allDay.name
          ? <PlannerDate>[date]
          : <PlannerDate>[date.addDays(-1), date, date.addDays(1)];
      final included = <String>{};
      for (final originalDate in candidates) {
        final occurrence = await _buildOccurrence(
          row: row,
          originalDate: originalDate,
          exception:
              exceptions[CalendarEventOccurrenceIdentity.forDate(
                eventId: row.id,
                originalDate: originalDate,
              )],
          reportById: reportById,
        );
        if (occurrence == null ||
            (occurrence.displayDate != date &&
                !(occurrence.isChange && occurrence.originalDate == date))) {
          continue;
        }
        included.add(occurrence.id);
        items.add(_toPlannerItem(occurrence));
      }
      for (final exception in exceptions.values) {
        if (included.contains(exception.occurrenceId)) {
          continue;
        }
        final originalDate = PlannerDate.parse(exception.originalDate);
        final effectiveDate = PlannerDate.parse(exception.effectiveDate);
        if (originalDate != date && effectiveDate != date) {
          continue;
        }
        final occurrence = await _buildOccurrence(
          row: row,
          originalDate: originalDate,
          exception: exception,
          reportById: reportById,
        );
        if (occurrence != null) {
          items.add(_toPlannerItem(occurrence));
        }
      }
    }
    items.sort((left, right) {
      final leftTime = left.startLocal;
      final rightTime = right.startLocal;
      if (leftTime == null && rightTime != null) {
        return -1;
      }
      if (leftTime != null && rightTime == null) {
        return 1;
      }
      return (leftTime?.compareTo(rightTime!) ?? 0);
    });
    return items;
  }

  @override
  Future<CalendarEventDraft?> readEventDraft({
    required String profileId,
    required String eventId,
  }) async {
    final row = await _readRow(profileId: profileId, eventId: eventId);
    return row == null ? null : _draftFromRow(row);
  }

  @override
  Future<CalendarEventOccurrence?> readOccurrence({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
  }) async {
    final row = await _readRow(profileId: profileId, eventId: eventId);
    if (row == null) {
      return null;
    }
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: originalDate,
    );
    final reports = await reportSource.readSeriesReports(eventId);
    return _buildOccurrence(
      row: row,
      originalDate: originalDate,
      exception: (await _latestExceptions(eventId))[occurrenceId],
      reportById: <String, CalendarEventReportSnapshot>{
        for (final report in reports) report.occurrenceId: report,
      },
    );
  }

  @override
  Future<CalendarEventDraft> saveEvent({
    required String profileId,
    required CalendarEventDraft draft,
  }) async {
    final normalized = _validateDraft(draft);
    await database.transaction(() async {
      final existing = await _readRow(
        profileId: profileId,
        eventId: normalized.id,
      );
      await _writeEvent(
        profileId: profileId,
        eventId: normalized.id,
        draft: normalized,
        existing: existing,
      );
      await writeGuard.beforeCommit();
    });
    return normalized;
  }

  @override
  Future<CalendarEventMutationOutcome> editEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft draft,
    required String operationId,
  }) async {
    _validateOperationId(operationId);
    final normalized = _validateDraft(draft);
    final reports = await reportSource.readSeriesReports(eventId);
    _ensureOccurrenceIsEditable(
      eventId: eventId,
      originalDate: originalDate,
      reports: reports,
    );
    return database.transaction(() async {
      if (await _operationExists(operationId)) {
        return CalendarEventMutationOutcome.unchanged;
      }
      final row = await _requireRow(profileId: profileId, eventId: eventId);
      final current = await _requireOccurrence(
        row: row,
        originalDate: originalDate,
        reports: reports,
      );
      if (scope != CalendarEventEditScope.occurrence) {
        await _preserveReports(
          profileId: profileId,
          row: row,
          reports: reports,
          operationId: operationId,
        );
      }
      switch (scope) {
        case CalendarEventEditScope.occurrence:
          await _insertException(
            profileId: profileId,
            eventId: eventId,
            originalDate: originalDate,
            occurrenceId: current.id,
            draft: normalized.copyWith(
              id: eventId,
              startDate: originalDate,
              recurrence: const CalendarRecurrenceRule(),
            ),
            status: CalendarEventStatus.scheduled,
            operationId: operationId,
          );
        case CalendarEventEditScope.thisAndFuture:
          if (originalDate == PlannerDate.parse(row.startDate)) {
            await _writeEvent(
              profileId: profileId,
              eventId: eventId,
              draft: normalized.copyWith(id: eventId),
              existing: row,
            );
          } else {
            if (normalized.id == eventId) {
              throw const CalendarEventValidationException(
                'This-and-future edits require a new stable series identity.',
              );
            }
            await _truncateBefore(row, originalDate);
            await _writeEvent(
              profileId: profileId,
              eventId: normalized.id,
              draft: _draftForSplit(
                source: row,
                targetDate: originalDate,
                replacement: normalized,
              ),
              parentEventId: eventId,
            );
          }
        case CalendarEventEditScope.series:
          await _writeEvent(
            profileId: profileId,
            eventId: eventId,
            draft: normalized.copyWith(id: eventId),
            existing: row,
          );
      }
      await _insertOperation(
        operationId: operationId,
        profileId: profileId,
        eventId: eventId,
        occurrenceId: current.id,
        command: 'edit:${scope.name}',
      );
      await writeGuard.beforeCommit();
      return CalendarEventMutationOutcome.changed;
    });
  }

  @override
  Future<CalendarEventMutationOutcome> cancelEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required String operationId,
  }) async {
    _validateOperationId(operationId);
    final reports = await reportSource.readSeriesReports(eventId);
    _ensureOccurrenceIsEditable(
      eventId: eventId,
      originalDate: originalDate,
      reports: reports,
    );
    return database.transaction(() async {
      if (await _operationExists(operationId)) {
        return CalendarEventMutationOutcome.unchanged;
      }
      final row = await _requireRow(profileId: profileId, eventId: eventId);
      final current = await _requireOccurrence(
        row: row,
        originalDate: originalDate,
        reports: reports,
      );
      if (scope != CalendarEventEditScope.occurrence) {
        await _preserveReports(
          profileId: profileId,
          row: row,
          reports: reports,
          operationId: operationId,
        );
      }
      switch (scope) {
        case CalendarEventEditScope.occurrence:
          await _insertExceptionFromOccurrence(
            profileId: profileId,
            occurrence: current,
            status: CalendarEventStatus.cancelled,
            operationId: operationId,
          );
        case CalendarEventEditScope.thisAndFuture:
          if (originalDate == PlannerDate.parse(row.startDate)) {
            await _setSeriesStatus(
              row: row,
              status: CalendarEventStatus.cancelled,
            );
          } else {
            await _truncateBefore(row, originalDate);
            await _insertExceptionFromOccurrence(
              profileId: profileId,
              occurrence: current,
              status: CalendarEventStatus.cancelled,
              operationId: operationId,
            );
          }
        case CalendarEventEditScope.series:
          await _setSeriesStatus(
            row: row,
            status: CalendarEventStatus.cancelled,
          );
      }
      await _insertOperation(
        operationId: operationId,
        profileId: profileId,
        eventId: eventId,
        occurrenceId: current.id,
        command: 'cancel:${scope.name}',
      );
      await writeGuard.beforeCommit();
      return CalendarEventMutationOutcome.changed;
    });
  }

  @override
  Future<CalendarEventMutationOutcome> rescheduleEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft replacement,
    required String operationId,
  }) async {
    _validateOperationId(operationId);
    final normalized = _validateDraft(replacement);
    if (normalized.id == eventId) {
      throw const CalendarEventValidationException(
        'Rescheduling requires a new stable replacement identity.',
      );
    }
    final reports = await reportSource.readSeriesReports(eventId);
    _ensureOccurrenceIsEditable(
      eventId: eventId,
      originalDate: originalDate,
      reports: reports,
    );
    return database.transaction(() async {
      if (await _operationExists(operationId)) {
        return CalendarEventMutationOutcome.unchanged;
      }
      final row = await _requireRow(profileId: profileId, eventId: eventId);
      final current = await _requireOccurrence(
        row: row,
        originalDate: originalDate,
        reports: reports,
      );
      if (scope != CalendarEventEditScope.occurrence) {
        await _preserveReports(
          profileId: profileId,
          row: row,
          reports: reports,
          operationId: operationId,
        );
      }
      final replacementDraft = scope == CalendarEventEditScope.occurrence
          ? normalized.copyWith(recurrence: const CalendarRecurrenceRule())
          : normalized;
      await _writeEvent(
        profileId: profileId,
        eventId: replacementDraft.id,
        draft: replacementDraft,
        parentEventId: eventId,
      );
      switch (scope) {
        case CalendarEventEditScope.occurrence:
          await _insertExceptionFromOccurrence(
            profileId: profileId,
            occurrence: current,
            status: CalendarEventStatus.rescheduled,
            operationId: operationId,
            replacementEventId: replacementDraft.id,
          );
        case CalendarEventEditScope.thisAndFuture:
          if (originalDate == PlannerDate.parse(row.startDate)) {
            await _setSeriesStatus(
              row: row,
              status: CalendarEventStatus.rescheduled,
              replacementEventId: replacementDraft.id,
            );
          } else {
            await _truncateBefore(row, originalDate);
            await _insertExceptionFromOccurrence(
              profileId: profileId,
              occurrence: current,
              status: CalendarEventStatus.rescheduled,
              operationId: operationId,
              replacementEventId: replacementDraft.id,
            );
          }
        case CalendarEventEditScope.series:
          await _setSeriesStatus(
            row: row,
            status: CalendarEventStatus.rescheduled,
            replacementEventId: replacementDraft.id,
          );
      }
      await linkContextTransfer.transferOnReschedule(
        profileId: profileId,
        sourceEventId: eventId,
        sourceOccurrenceId: current.id,
        sourceOriginalDate: originalDate,
        scope: scope,
        replacementEventId: replacementDraft.id,
        replacementOriginalDate: replacementDraft.startDate,
        operationId: operationId,
      );
      await _insertOperation(
        operationId: operationId,
        profileId: profileId,
        eventId: eventId,
        occurrenceId: current.id,
        command: 'reschedule:${scope.name}',
      );
      await writeGuard.beforeCommit();
      return CalendarEventMutationOutcome.changed;
    });
  }

  CalendarEventDraft _validateDraft(CalendarEventDraft draft) {
    final normalized = draft.normalized();
    final zone = normalized.timeZoneId;
    if (zone != null && !timeZones.isValid(zone)) {
      throw CalendarEventValidationException('Unknown IANA time zone: $zone');
    }
    return normalized;
  }

  void _validateOperationId(String operationId) {
    if (!Uuid.isValidUUID(fromString: operationId)) {
      throw const CalendarEventValidationException(
        'Calendar Event operations require stable UUID identifiers.',
      );
    }
  }

  Future<CalendarEventRow?> _readRow({
    required String profileId,
    required String eventId,
  }) {
    return (database.select(database.calendarEvents)
          ..where(
            (table) =>
                table.id.equals(eventId) & table.profileId.equals(profileId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CalendarEventRow> _requireRow({
    required String profileId,
    required String eventId,
  }) async {
    final row = await _readRow(profileId: profileId, eventId: eventId);
    if (row == null) {
      throw StateError('Calendar Event not found');
    }
    return row;
  }

  Future<void> _writeEvent({
    required String profileId,
    required String eventId,
    required CalendarEventDraft draft,
    CalendarEventRow? existing,
    String? parentEventId,
  }) async {
    final now = clock.nowUtc();
    final values = CalendarEventsCompanion(
      title: Value<String>(draft.title),
      notes: Value<String?>(draft.notes),
      timing: Value<String>(draft.timing.name),
      startDate: Value<String>(draft.startDate.iso8601),
      startMinute: Value<int?>(draft.startMinute),
      endMinute: Value<int?>(draft.endMinute),
      timeZoneId: Value<String?>(draft.timeZoneId),
      locationText: Value<String?>(draft.locationText),
      requiresReport: Value<bool>(draft.requiresReport),
      activityTypeId: Value<String?>(draft.activityTypeId),
      activityTypeMappingVersion: Value<int?>(draft.activityTypeMappingVersion),
      contributionRuleKey: Value<String?>(draft.contributionRuleKey),
      recurrenceFrequency: Value<String>(draft.recurrence.frequency.name),
      recurrenceEndMode: Value<String>(draft.recurrence.endMode.name),
      recurrenceEndDate: Value<String?>(draft.recurrence.endDate?.iso8601),
      recurrenceCount: Value<int?>(draft.recurrence.occurrenceCount),
      status: const Value<String>('scheduled'),
      parentEventId: Value<String?>(parentEventId ?? existing?.parentEventId),
      replacementEventId: const Value<String?>(null),
      updatedAtUtc: Value<DateTime>(now),
    );
    if (existing == null) {
      await database
          .into(database.calendarEvents)
          .insert(
            CalendarEventsCompanion.insert(
              id: eventId,
              profileId: profileId,
              title: draft.title,
              notes: Value<String?>(draft.notes),
              timing: draft.timing.name,
              startDate: draft.startDate.iso8601,
              startMinute: Value<int?>(draft.startMinute),
              endMinute: Value<int?>(draft.endMinute),
              timeZoneId: Value<String?>(draft.timeZoneId),
              locationText: Value<String?>(draft.locationText),
              requiresReport: Value<bool>(draft.requiresReport),
              activityTypeId: Value<String?>(draft.activityTypeId),
              activityTypeMappingVersion: Value<int?>(
                draft.activityTypeMappingVersion,
              ),
              contributionRuleKey: Value<String?>(draft.contributionRuleKey),
              recurrenceFrequency: Value<String>(
                draft.recurrence.frequency.name,
              ),
              recurrenceEndMode: Value<String>(draft.recurrence.endMode.name),
              recurrenceEndDate: Value<String?>(
                draft.recurrence.endDate?.iso8601,
              ),
              recurrenceCount: Value<int?>(draft.recurrence.occurrenceCount),
              parentEventId: Value<String?>(parentEventId),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
    } else {
      await (database.update(
        database.calendarEvents,
      )..where((table) => table.id.equals(eventId))).write(values);
    }
  }

  CalendarEventDraft _draftFromRow(CalendarEventRow row) {
    return CalendarEventDraft(
      id: row.id,
      title: row.title,
      notes: row.notes,
      timing: CalendarEventTiming.values.byName(row.timing),
      startDate: PlannerDate.parse(row.startDate),
      startMinute: row.startMinute,
      endMinute: row.endMinute,
      timeZoneId: row.timeZoneId,
      locationText: row.locationText,
      requiresReport: row.requiresReport,
      activityTypeId: row.activityTypeId,
      activityTypeMappingVersion: row.activityTypeMappingVersion,
      contributionRuleKey: row.contributionRuleKey,
      recurrence: _ruleFromRow(row),
    );
  }

  CalendarRecurrenceRule _ruleFromRow(CalendarEventRow row) {
    return CalendarRecurrenceRule(
      frequency: CalendarRecurrenceFrequency.values.byName(
        row.recurrenceFrequency,
      ),
      endMode: CalendarRecurrenceEndMode.values.byName(row.recurrenceEndMode),
      endDate: row.recurrenceEndDate == null
          ? null
          : PlannerDate.parse(row.recurrenceEndDate!),
      occurrenceCount: row.recurrenceCount,
    );
  }

  Future<Map<String, CalendarEventExceptionRow>> _latestExceptions(
    String eventId,
  ) async {
    final rows =
        await (database.select(database.calendarEventExceptions)
              ..where((table) => table.eventId.equals(eventId))
              ..orderBy(<OrderingTerm Function(CalendarEventExceptions)>[
                (table) => OrderingTerm.asc(table.createdAtUtc),
              ]))
            .get();
    return <String, CalendarEventExceptionRow>{
      for (final row in rows) row.occurrenceId: row,
    };
  }

  Future<ActivityTypeRow?> _readActivityType(
    String profileId,
    String activityTypeId,
  ) {
    return (database.select(database.activityTypes)
          ..where(
            (table) =>
                table.profileId.equals(profileId) &
                table.id.equals(activityTypeId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<CalendarEventOccurrence?> _buildOccurrence({
    required CalendarEventRow row,
    required PlannerDate originalDate,
    required CalendarEventExceptionRow? exception,
    required Map<String, CalendarEventReportSnapshot> reportById,
  }) async {
    final rule = _ruleFromRow(row);
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: row.id,
      originalDate: originalDate,
    );
    if (rule.occurrenceIndexOn(
              startDate: PlannerDate.parse(row.startDate),
              targetDate: originalDate,
            ) ==
            null &&
        exception == null) {
      return null;
    }
    final effectiveDate = exception == null
        ? originalDate
        : PlannerDate.parse(exception.effectiveDate);
    final timing = CalendarEventTiming.values.byName(
      exception?.timing ?? row.timing,
    );
    final zoneId = exception?.timeZoneId ?? row.timeZoneId;
    final startMinute = exception?.startMinute ?? row.startMinute;
    final endMinute = exception?.endMinute ?? row.endMinute;
    DateTime? startUtc;
    DateTime? endUtc;
    DateTime? startDisplay;
    DateTime? endDisplay;
    PlannerDate displayDate = effectiveDate;
    if (timing == CalendarEventTiming.timed) {
      startUtc = timeZones.wallTimeToUtc(
        date: effectiveDate,
        minuteOfDay: startMinute!,
        timeZoneId: zoneId!,
      );
      endUtc = timeZones.wallTimeToUtc(
        date: effectiveDate,
        minuteOfDay: endMinute!,
        timeZoneId: zoneId,
      );
      startDisplay = timeZones.utcToDisplayWall(startUtc);
      endDisplay = timeZones.utcToDisplayWall(endUtc);
      displayDate = PlannerDate.fromDateTime(startDisplay);
    }
    var status = CalendarEventStatus.values.byName(
      exception?.status ?? row.status,
    );
    final report = reportById[occurrenceId];
    if (status == CalendarEventStatus.scheduled && report != null) {
      status = report.status;
    }
    final activityTypeId = exception?.activityTypeId ?? row.activityTypeId;
    final activityType = activityTypeId == null
        ? null
        : await _readActivityType(row.profileId, activityTypeId);
    return CalendarEventOccurrence(
      id: occurrenceId,
      eventId: row.id,
      profileId: row.profileId,
      title: exception?.title ?? row.title,
      notes: exception == null ? row.notes : exception.notes,
      timing: timing,
      originalDate: originalDate,
      displayDate: displayDate,
      startUtc: startUtc,
      endUtc: endUtc,
      startDisplay: startDisplay,
      endDisplay: endDisplay,
      timeZoneId: zoneId,
      displayTimeZoneId: timing == CalendarEventTiming.timed
          ? timeZones.displayTimeZoneId
          : null,
      locationText: exception == null
          ? row.locationText
          : exception.locationText,
      status: status,
      requiresReport: exception?.requiresReport ?? row.requiresReport,
      activityTypeId: activityTypeId,
      activityTypeMappingVersion:
          exception?.activityTypeMappingVersion ??
          row.activityTypeMappingVersion,
      activityTypeLabel: activityType?.label,
      activityTypeColorValue: activityType?.colorValue,
      contributionRuleKey: exception == null
          ? row.contributionRuleKey
          : exception.contributionRuleKey,
      recurrence: rule,
      replacementEventId:
          exception?.replacementEventId ?? row.replacementEventId,
      linkedTaskIds: await taskContextSource.readLinkedTaskIds(
        eventId: row.id,
        occurrenceId: occurrenceId,
      ),
    );
  }

  PlannerCalendarItem _toPlannerItem(CalendarEventOccurrence occurrence) {
    return PlannerCalendarItem(
      id: occurrence.id,
      eventId: occurrence.eventId,
      title: occurrence.title,
      date: occurrence.displayDate,
      originalDate: occurrence.originalDate,
      timing: occurrence.timing == CalendarEventTiming.allDay
          ? PlannerEventTiming.allDay
          : PlannerEventTiming.timed,
      state: switch (occurrence.status) {
        CalendarEventStatus.scheduled => PlannerEventState.scheduled,
        CalendarEventStatus.completedHappened =>
          PlannerEventState.completedHappened,
        CalendarEventStatus.partiallyCompleted =>
          PlannerEventState.partiallyCompleted,
        CalendarEventStatus.didNotHappen => PlannerEventState.didNotHappen,
        CalendarEventStatus.cancelled => PlannerEventState.cancelled,
        CalendarEventStatus.rescheduled => PlannerEventState.rescheduled,
      },
      requiresReport: occurrence.requiresReport,
      hasOutcomeReport:
          occurrence.status == CalendarEventStatus.completedHappened ||
          occurrence.status == CalendarEventStatus.partiallyCompleted ||
          occurrence.status == CalendarEventStatus.didNotHappen,
      startLocal: occurrence.startDisplay,
      endLocal: occurrence.endDisplay,
      startUtc: occurrence.startUtc,
      endUtc: occurrence.endUtc,
      locationText: occurrence.locationText,
      isRecurring: occurrence.isRecurring,
      replacementId: occurrence.replacementEventId,
      linkedTaskIds: occurrence.linkedTaskIds,
      timeZoneId: occurrence.timeZoneId,
      displayTimeZoneId: occurrence.displayTimeZoneId,
      activityTypeId: occurrence.activityTypeId,
      activityTypeLabel: occurrence.activityTypeLabel,
      activityTypeColorValue: occurrence.activityTypeColorValue,
    );
  }

  Future<CalendarEventOccurrence> _requireOccurrence({
    required CalendarEventRow row,
    required PlannerDate originalDate,
    required List<CalendarEventReportSnapshot> reports,
  }) async {
    final id = CalendarEventOccurrenceIdentity.forDate(
      eventId: row.id,
      originalDate: originalDate,
    );
    final occurrence = await _buildOccurrence(
      row: row,
      originalDate: originalDate,
      exception: (await _latestExceptions(row.id))[id],
      reportById: <String, CalendarEventReportSnapshot>{
        for (final report in reports) report.occurrenceId: report,
      },
    );
    if (occurrence == null) {
      throw StateError('Calendar Event occurrence not found');
    }
    return occurrence;
  }

  void _ensureOccurrenceIsEditable({
    required String eventId,
    required PlannerDate originalDate,
    required List<CalendarEventReportSnapshot> reports,
  }) {
    final id = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: originalDate,
    );
    if (reports.any((report) => report.occurrenceId == id)) {
      throw const CalendarEventValidationException(
        'Reported historical occurrences are immutable.',
      );
    }
  }

  Future<void> _preserveReports({
    required String profileId,
    required CalendarEventRow row,
    required List<CalendarEventReportSnapshot> reports,
    required String operationId,
  }) async {
    final existing = await _latestExceptions(row.id);
    for (final report in reports) {
      if (existing.containsKey(report.occurrenceId)) {
        continue;
      }
      final occurrence = await _buildOccurrence(
        row: row,
        originalDate: report.originalDate,
        exception: null,
        reportById: <String, CalendarEventReportSnapshot>{
          report.occurrenceId: report,
        },
      );
      if (occurrence == null) {
        continue;
      }
      await _insertExceptionFromOccurrence(
        profileId: profileId,
        occurrence: occurrence,
        status: report.status,
        operationId: '$operationId:${report.occurrenceId}',
      );
    }
  }

  Future<void> _insertExceptionFromOccurrence({
    required String profileId,
    required CalendarEventOccurrence occurrence,
    required CalendarEventStatus status,
    required String operationId,
    String? replacementEventId,
  }) {
    return _insertException(
      profileId: profileId,
      eventId: occurrence.eventId,
      originalDate: occurrence.originalDate,
      occurrenceId: occurrence.id,
      draft: CalendarEventDraft(
        id: occurrence.eventId,
        title: occurrence.title,
        notes: occurrence.notes,
        timing: occurrence.timing,
        startDate: occurrence.originalDate,
        startMinute: occurrence.startUtc == null
            ? null
            : _originMinute(occurrence.startUtc!, occurrence.timeZoneId!),
        endMinute: occurrence.endUtc == null
            ? null
            : _originMinute(occurrence.endUtc!, occurrence.timeZoneId!),
        timeZoneId: occurrence.timeZoneId,
        locationText: occurrence.locationText,
        requiresReport: occurrence.requiresReport,
        activityTypeId: occurrence.activityTypeId,
        activityTypeMappingVersion: occurrence.activityTypeMappingVersion,
        contributionRuleKey: occurrence.contributionRuleKey,
      ),
      status: status,
      operationId: operationId,
      replacementEventId: replacementEventId,
    );
  }

  Future<void> _insertException({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required String occurrenceId,
    required CalendarEventDraft draft,
    required CalendarEventStatus status,
    required String operationId,
    String? replacementEventId,
  }) async {
    await database
        .into(database.calendarEventExceptions)
        .insert(
          CalendarEventExceptionsCompanion.insert(
            id: CalendarEventExceptionIdentity.forOperation(
              operationId: operationId,
              occurrenceId: occurrenceId,
            ),
            profileId: profileId,
            eventId: eventId,
            occurrenceId: occurrenceId,
            originalDate: originalDate.iso8601,
            effectiveDate: draft.startDate.iso8601,
            title: draft.title,
            notes: Value<String?>(draft.notes),
            timing: draft.timing.name,
            startMinute: Value<int?>(draft.startMinute),
            endMinute: Value<int?>(draft.endMinute),
            timeZoneId: Value<String?>(draft.timeZoneId),
            locationText: Value<String?>(draft.locationText),
            requiresReport: Value<bool>(draft.requiresReport),
            activityTypeId: Value<String?>(draft.activityTypeId),
            activityTypeMappingVersion: Value<int?>(
              draft.activityTypeMappingVersion,
            ),
            contributionRuleKey: Value<String?>(draft.contributionRuleKey),
            status: status.name,
            replacementEventId: Value<String?>(replacementEventId),
            createdAtUtc: clock.nowUtc(),
          ),
        );
  }

  Future<bool> _operationExists(String operationId) async {
    return (await (database.select(database.calendarEventOperations)
              ..where((table) => table.operationId.equals(operationId))
              ..limit(1))
            .getSingleOrNull()) !=
        null;
  }

  Future<void> _insertOperation({
    required String operationId,
    required String profileId,
    required String eventId,
    required String occurrenceId,
    required String command,
  }) async {
    await database
        .into(database.calendarEventOperations)
        .insert(
          CalendarEventOperationsCompanion.insert(
            operationId: operationId,
            profileId: profileId,
            eventId: eventId,
            occurrenceId: Value<String?>(occurrenceId),
            command: command,
            createdAtUtc: clock.nowUtc(),
          ),
        );
  }

  Future<void> _truncateBefore(
    CalendarEventRow row,
    PlannerDate originalDate,
  ) async {
    await (database.update(
      database.calendarEvents,
    )..where((table) => table.id.equals(row.id))).write(
      CalendarEventsCompanion(
        recurrenceEndMode: const Value<String>('onDate'),
        recurrenceEndDate: Value<String>(originalDate.addDays(-1).iso8601),
        recurrenceCount: const Value<int?>(null),
        updatedAtUtc: Value<DateTime>(clock.nowUtc()),
      ),
    );
  }

  Future<void> _setSeriesStatus({
    required CalendarEventRow row,
    required CalendarEventStatus status,
    String? replacementEventId,
  }) async {
    await (database.update(
      database.calendarEvents,
    )..where((table) => table.id.equals(row.id))).write(
      CalendarEventsCompanion(
        status: Value<String>(status.name),
        replacementEventId: Value<String?>(replacementEventId),
        updatedAtUtc: Value<DateTime>(clock.nowUtc()),
      ),
    );
  }

  CalendarEventDraft _draftForSplit({
    required CalendarEventRow source,
    required PlannerDate targetDate,
    required CalendarEventDraft replacement,
  }) {
    var rule = replacement.recurrence;
    final sourceRule = _ruleFromRow(source);
    if (_sameRule(rule, sourceRule) &&
        sourceRule.endMode == CalendarRecurrenceEndMode.afterCount) {
      final index = sourceRule.occurrenceIndexOn(
        startDate: PlannerDate.parse(source.startDate),
        targetDate: targetDate,
      )!;
      rule = CalendarRecurrenceRule(
        frequency: rule.frequency,
        endMode: CalendarRecurrenceEndMode.afterCount,
        occurrenceCount: sourceRule.occurrenceCount! - index,
      );
    }
    return replacement.copyWith(startDate: targetDate, recurrence: rule);
  }

  bool _sameRule(CalendarRecurrenceRule left, CalendarRecurrenceRule right) {
    return left.frequency == right.frequency &&
        left.endMode == right.endMode &&
        left.endDate == right.endDate &&
        left.occurrenceCount == right.occurrenceCount;
  }

  int _originMinute(DateTime instant, String timeZoneId) {
    final wall = timeZones.utcToWall(value: instant, timeZoneId: timeZoneId);
    return wall.hour * 60 + wall.minute;
  }
}

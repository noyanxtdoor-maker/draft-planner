import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/task_event_link_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';
import 'package:rmplanner/features/planner/presentation/event_type_picker_dialog.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_slide_down_date_picker.dart';

enum CalendarEventFormMode { create, edit, reschedule }

final class CalendarEventFormScreen extends ConsumerStatefulWidget {
  const CalendarEventFormScreen.create({
    required this.initialDate,
    this.initialEventType,
    this.initialStartMinute,
    this.initialIndicatorKey,
    this.initialEventTypeId,
    this.sheetPresentation = false,
    this.sheetScrollController,
    this.sheetController,
    this.sheetMinChildSize = 0.36,
    this.sheetMaxChildSize = 0.94,
    super.key,
  }) : mode = CalendarEventFormMode.create,
       eventId = null,
       originalDate = null,
       scope = null,
       sourceTaskId = null;

  const CalendarEventFormScreen.createFromTask({
    required this.sourceTaskId,
    required this.initialDate,
    this.initialEventType,
    this.initialStartMinute,
    this.initialIndicatorKey,
    this.initialEventTypeId,
    this.sheetPresentation = false,
    this.sheetScrollController,
    this.sheetController,
    this.sheetMinChildSize = 0.36,
    this.sheetMaxChildSize = 0.94,
    super.key,
  }) : mode = CalendarEventFormMode.create,
       eventId = null,
       originalDate = null,
       scope = null;

  const CalendarEventFormScreen.edit({
    required this.eventId,
    required this.originalDate,
    required this.scope,
    this.sheetPresentation = false,
    this.sheetScrollController,
    this.sheetController,
    this.sheetMinChildSize = 0.36,
    this.sheetMaxChildSize = 0.94,
    super.key,
  }) : mode = CalendarEventFormMode.edit,
       initialDate = null,
       initialEventType = null,
       initialStartMinute = null,
       initialIndicatorKey = null,
       initialEventTypeId = null,
       sourceTaskId = null;

  const CalendarEventFormScreen.reschedule({
    required this.eventId,
    required this.originalDate,
    required this.scope,
    this.sheetPresentation = false,
    this.sheetScrollController,
    this.sheetController,
    this.sheetMinChildSize = 0.36,
    this.sheetMaxChildSize = 0.94,
    super.key,
  }) : mode = CalendarEventFormMode.reschedule,
       initialDate = null,
       initialEventType = null,
       initialStartMinute = null,
       initialIndicatorKey = null,
       initialEventTypeId = null,
       sourceTaskId = null;

  final CalendarEventFormMode mode;
  final PlannerDate? initialDate;
  final EventType? initialEventType;
  final int? initialStartMinute;
  final String? initialIndicatorKey;
  final String? initialEventTypeId;
  final String? eventId;
  final PlannerDate? originalDate;
  final CalendarEventEditScope? scope;
  final String? sourceTaskId;
  final bool sheetPresentation;
  final ScrollController? sheetScrollController;
  final DraggableScrollableController? sheetController;
  final double sheetMinChildSize;
  final double sheetMaxChildSize;

  @override
  ConsumerState<CalendarEventFormScreen> createState() =>
      _CalendarEventFormScreenState();
}

final class _CalendarEventFormScreenState
    extends ConsumerState<CalendarEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventTypeAnchorKey = GlobalKey();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  final _locationController = TextEditingController();
  final _timeZoneController = TextEditingController();
  final _countController = TextEditingController(text: '2');
  late final String _draftId;
  late final String _operationId;
  String? _linkId;
  late PlannerDate _date;
  CalendarEventTiming _timing = CalendarEventTiming.timed;
  CalendarEventStatus _currentStatus = CalendarEventStatus.scheduled;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _requiresReport = false;
  bool _isBackupAppointment = false;
  String? _backupForEventId;
  String? _backupRelationshipProvenance;
  CalendarRecurrenceFrequency _frequency = CalendarRecurrenceFrequency.none;
  CalendarRecurrenceEndMode _endMode = CalendarRecurrenceEndMode.never;
  PlannerDate? _recurrenceEndDate;
  bool _loading = false;
  bool _saving = false;
  bool _configurationLoading = true;
  bool _durationWasEntered = false;
  EventType? _selectedEventType;
  List<IndicatorOption> _indicatorOptions = const <IndicatorOption>[];
  String? _linkedIndicatorKey;
  bool _indicatorLinkTouched = false;
  bool _locationExpanded = false;
  bool _addressExpanded = false;
  TaskEventCanonicalSource _canonicalSource = TaskEventCanonicalSource.task;

  @override
  void initState() {
    super.initState();
    final initialEventType = widget.initialEventType;
    if (widget.mode == CalendarEventFormMode.create &&
        initialEventType != null) {
      _selectedEventType = initialEventType;
      _linkedIndicatorKey = initialEventType.isLockedWliType
          ? initialEventType.exactIndicatorKey
          : widget.initialIndicatorKey ?? initialEventType.exactIndicatorKey;
      _configurationLoading = false;
    }
    _notesFocusNode.addListener(_notesFocusChanged);
    final ids = ref.read(plannerIdentifierSourceProvider);
    _operationId = ids.nextUuid();
    if (widget.sourceTaskId != null) {
      _linkId = ids.nextUuid();
    }
    _draftId = switch (widget.mode) {
      CalendarEventFormMode.create ||
      CalendarEventFormMode.reschedule => ids.nextUuid(),
      CalendarEventFormMode.edit
          when widget.scope == CalendarEventEditScope.thisAndFuture =>
        ids.nextUuid(),
      CalendarEventFormMode.edit => widget.eventId!,
    };
    _date = widget.initialDate ?? widget.originalDate!;
    final initialStartMinute = widget.initialStartMinute;
    if (initialStartMinute != null) {
      _start = _timeFromMinute(initialStartMinute);
      _end = _timeFromMinute((initialStartMinute + 60).clamp(1, 1439));
    }
    if (_selectedEventType != null) {
      _applyEventTypeDefaults(
        _selectedEventType!,
        durationMinutes: _selectedEventType!.defaultDurationMinutes,
      );
    }
    _timeZoneController.text = ref
        .read(calendarEventControllerProvider.notifier)
        .displayTimeZoneId;
    if (widget.mode != CalendarEventFormMode.create) {
      _loading = true;
      unawaited(Future<void>.microtask(_loadExisting));
    } else if (widget.sourceTaskId != null) {
      unawaited(Future<void>.microtask(_loadSourceTask));
    }
    unawaited(Future<void>.microtask(_loadConfiguration));
  }

  Future<void> _loadConfiguration() async {
    final controller = ref.read(eventTypeControllerProvider.notifier);
    await controller.load();
    if (!mounted) {
      return;
    }
    final eventTypeState = ref.read(eventTypeControllerProvider);
    List<IndicatorOption> indicatorOptions = const <IndicatorOption>[];
    try {
      indicatorOptions = await ref
          .read(outcomeReportingControllerProvider.notifier)
          .readIndicatorOptions();
    } on Object {
      // The link remains optional if the existing indicator repository cannot
      // be read. The event form itself must still be usable.
    }
    if (!mounted) {
      return;
    }
    CalendarEventDraft? existingDraft;
    EventType? selected;
    var preferTypeDuration = false;
    if (widget.mode != CalendarEventFormMode.create) {
      existingDraft = await ref
          .read(calendarEventControllerProvider.notifier)
          .readEventDraft(widget.eventId!);
      final eventTypeId = existingDraft?.activityTypeId;
      if (eventTypeId != null) {
        selected = eventTypeState.eventTypes
            .where((type) => type.id == eventTypeId)
            .firstOrNull;
      }
    } else if (widget.initialEventType != null) {
      preferTypeDuration = true;
      selected = widget.initialEventType;
    } else if (widget.initialEventTypeId != null) {
      preferTypeDuration = true;
      selected = eventTypeState.eventTypes
          .where((type) => type.id == widget.initialEventTypeId)
          .firstOrNull;
    } else if (widget.initialIndicatorKey != null) {
      preferTypeDuration = true;
      selected = await controller.exactTypeForIndicator(
        widget.initialIndicatorKey!,
      );
    } else if (eventTypeState.settings.defaultEventTypeId != null) {
      selected = eventTypeState.eventTypes
          .where(
            (type) => type.id == eventTypeState.settings.defaultEventTypeId,
          )
          .firstOrNull;
    }
    selected ??= eventTypeState.eventTypes
        .where((type) => type.stableKey == SystemEventTypeKeys.other)
        .firstOrNull;
    final existingRule = ScheduledPotentialRule.tryParse(
      existingDraft?.contributionRuleKey,
    );
    final initialLink = selected?.isLockedWliType == true
        ? selected?.exactIndicatorKey
        : existingRule?.indicatorKey ??
              widget.initialIndicatorKey ??
              selected?.exactIndicatorKey;
    if (mounted) {
      setState(() {
        _configurationLoading = false;
        _selectedEventType = selected;
        _indicatorOptions = indicatorOptions;
        _linkedIndicatorKey = initialLink;
        if (selected?.isLockedWliType == true) {
          _requiresReport = true;
          _linkedIndicatorKey = selected!.exactIndicatorKey;
        }
        if (widget.mode == CalendarEventFormMode.create &&
            selected != null &&
            widget.initialEventType == null) {
          _applyEventTypeDefaults(
            selected,
            durationMinutes: preferTypeDuration
                ? selected.defaultDurationMinutes
                : eventTypeState.settings.defaultDurationMinutes,
          );
        }
      });
    }
  }

  void _applyEventTypeDefaults(EventType type, {int? durationMinutes}) {
    _requiresReport = type.isLockedWliType ? true : type.reportRequiredDefault;
    if (type.isLockedWliType) {
      _linkedIndicatorKey = type.exactIndicatorKey;
      _indicatorLinkTouched = false;
    }
    if (_durationWasEntered) {
      return;
    }
    final startMinute = _start.hour * 60 + _start.minute;
    final minimumEnd = (startMinute + 15).clamp(1, 1439);
    _end = _timeFromMinute(
      (startMinute + (durationMinutes ?? type.defaultDurationMinutes)).clamp(
        minimumEnd,
        1439,
      ),
    );
  }

  Future<void> _changeEventType() async {
    final selected = await showEventTypeDropdown(
      context: context,
      ref: ref,
      anchorKey: _eventTypeAnchorKey,
      selectedEventTypeId: _selectedEventType?.id,
      recommendedIndicatorKey: widget.initialIndicatorKey,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedEventType = selected;
      _applyEventTypeDefaults(selected);
      if (selected.isLockedWliType) {
        _linkedIndicatorKey = selected.exactIndicatorKey;
      } else if (!_indicatorLinkTouched) {
        _linkedIndicatorKey = selected.exactIndicatorKey;
      }
    });
  }

  Future<void> _loadSourceTask() async {
    final task = await ref
        .read(plannerControllerProvider.notifier)
        .readTask(widget.sourceTaskId!);
    if (mounted && task != null && _titleController.text.isEmpty) {
      setState(() => _titleController.text = task.title);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    _locationController.dispose();
    _timeZoneController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _notesFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildEventTypeField() {
    return Material(
      key: const Key('event-type-field'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: _changeEventType,
        child: SizedBox(
          key: _eventTypeAnchorKey,
          height: 60,
          child: InputDecorator(
            decoration: _measuredInputDecoration(
              labelText: _isContactEvent ? 'Contact Type' : 'Event Type',
              suffixIcon: const KeyedSubtree(
                key: Key('change-event-type-button'),
                child: Icon(Icons.arrow_drop_down, size: 24),
              ),
            ),
            child: Text(
              _selectedEventType?.label ?? 'Not selected',
              key: const Key('selected-event-type-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatField() {
    return DropdownButtonFormField<CalendarRecurrenceFrequency>(
      key: const Key('event-recurrence-frequency'),
      initialValue: _frequency,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, size: 24),
      decoration: _measuredInputDecoration(labelText: 'Repeat').copyWith(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      items: <DropdownMenuItem<CalendarRecurrenceFrequency>>[
        for (final value in CalendarRecurrenceFrequency.values)
          DropdownMenuItem<CalendarRecurrenceFrequency>(
            value: value,
            child: Text(_frequencyLabel(value), style: AppTypography.body),
          ),
      ],
      onChanged: (value) => setState(() {
        _frequency = value ?? CalendarRecurrenceFrequency.none;
        if (_frequency == CalendarRecurrenceFrequency.none) {
          _endMode = CalendarRecurrenceEndMode.never;
        }
      }),
    );
  }

  Future<void> _loadExisting() async {
    final controller = ref.read(calendarEventControllerProvider.notifier);
    final draft = await controller.readEventDraft(widget.eventId!);
    final occurrence = await controller.readOccurrence(
      eventId: widget.eventId!,
      originalDate: widget.originalDate!,
    );
    if (!mounted) {
      return;
    }
    if (draft == null) {
      setState(() => _loading = false);
      return;
    }
    _titleController.text = draft.title;
    _notesController.text = draft.notes ?? '';
    _locationController.text = draft.locationText ?? '';
    _locationExpanded = _locationController.text.trim().isNotEmpty;
    _addressExpanded = _locationExpanded;
    _timeZoneController.text =
        occurrence?.timeZoneId ??
        draft.timeZoneId ??
        ref.read(calendarEventControllerProvider.notifier).displayTimeZoneId;
    // Editing must round-trip the event's source-zone wall time. The
    // occurrence display values are intentionally converted for the planner
    // viewer and can represent a different local date/time when the device
    // zone differs from the event zone.
    final occurrenceStart = _sourceWallTime(occurrence, occurrence?.startUtc);
    final occurrenceEnd = _sourceWallTime(occurrence, occurrence?.endUtc);
    final occurrenceDate = occurrenceStart == null
        ? occurrence?.displayDate
        : PlannerDate.fromDateTime(occurrenceStart);
    _date =
        occurrenceDate ??
        (widget.mode == CalendarEventFormMode.reschedule
            ? widget.originalDate!
            : draft.startDate);
    _timing = draft.timing;
    _currentStatus = occurrence?.status ?? draft.status;
    final startWall = occurrenceStart ?? occurrence?.startDisplay;
    final endWall = occurrenceEnd ?? occurrence?.endDisplay;
    _start = startWall == null
        ? _timeFromMinute(draft.startMinute ?? 9 * 60)
        : TimeOfDay.fromDateTime(startWall);
    _end = endWall == null
        ? _timeFromMinute(draft.endMinute ?? 10 * 60)
        : TimeOfDay.fromDateTime(endWall);
    _durationWasEntered = true;
    _requiresReport = draft.requiresReport;
    _isBackupAppointment = draft.isBackupAppointment;
    _backupForEventId = draft.backupForEventId;
    _backupRelationshipProvenance = draft.backupRelationshipProvenance;
    _frequency =
        widget.mode == CalendarEventFormMode.reschedule &&
            widget.scope == CalendarEventEditScope.occurrence
        ? CalendarRecurrenceFrequency.none
        : draft.recurrence.frequency;
    _endMode = _frequency == CalendarRecurrenceFrequency.none
        ? CalendarRecurrenceEndMode.never
        : draft.recurrence.endMode;
    _recurrenceEndDate = draft.recurrence.endDate;
    _countController.text = (draft.recurrence.occurrenceCount ?? 2).toString();
    setState(() => _loading = false);
  }

  DateTime? _sourceWallTime(
    CalendarEventOccurrence? occurrence,
    DateTime? instant,
  ) {
    final timeZoneId = occurrence?.timeZoneId;
    if (instant == null || timeZoneId == null) {
      return null;
    }
    try {
      return IanaCalendarEventTimeZones(
        displayTimeZoneId: timeZoneId,
      ).utcToWall(value: instant, timeZoneId: timeZoneId);
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message =
        ref.watch(calendarEventControllerProvider) ??
        ref.watch(taskEventLinkControllerProvider);
    final lockedWli = _selectedEventType?.isLockedWliType == true;
    final bottomPadding = widget.sheetPresentation
        ? 24.0 + MediaQuery.of(context).viewInsets.bottom
        : 120.0;
    final content = _loading || _configurationLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            top: !widget.sheetPresentation,
            child: Form(
              key: _formKey,
              child: ListView(
                key: const Key('calendar-event-form-scroll'),
                controller: widget.sheetScrollController,
                padding: EdgeInsets.fromLTRB(
                  18,
                  widget.sheetPresentation ? 18 : 16,
                  18,
                  bottomPadding,
                ),
                children: <Widget>[
                  if (widget.scope != null) ...<Widget>[
                    _ScopeBanner(scope: widget.scope!),
                    const SizedBox(height: 16),
                  ],
                  if (widget.sourceTaskId != null) ...<Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _FormSectionLabel(
                              icon: Icons.link_outlined,
                              label: 'Task link',
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<TaskEventCanonicalSource>(
                              key: const Key('create-event-canonical-source'),
                              initialValue: _canonicalSource,
                              decoration: const InputDecoration(
                                labelText: 'Planning source',
                              ),
                              items: TaskEventCanonicalSource.values
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        taskEventCanonicalSourceLabel(value),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _canonicalSource = value!),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (message != null) ...<Widget>[
                    _ErrorBanner(message: message),
                    const SizedBox(height: 16),
                  ],
                  _buildEventTypeField(),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('event-title-field'),
                    controller: _titleController,
                    decoration: _measuredInputDecoration(labelText: 'Title'),
                    maxLines: 1,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('event-notes-field'),
                    controller: _notesController,
                    focusNode: _notesFocusNode,
                    decoration: _measuredInputDecoration(
                      labelText: 'Notes',
                      hintText: _notesFocusNode.hasFocus
                          ? 'What do you need to remember about this?'
                          : null,
                      alignLabelWithHint: true,
                    ),
                    minLines: _notesFocusNode.hasFocus ? 4 : 1,
                    maxLines: _notesFocusNode.hasFocus ? 6 : 1,
                  ),
                  const SizedBox(height: 32),
                  const _MeasuredFormSeparator(
                    key: Key('event-form-scheduling-separator'),
                  ),
                  const SizedBox(height: 32),
                  const _MeasuredFormSectionHeader(label: 'Scheduling Details'),
                  const SizedBox(height: 28),
                  _DateTile(
                    key: const Key('event-date-field'),
                    label: 'Date',
                    date: _date,
                    onTap: () => _selectDate(
                      initial: _date,
                      onSelected: (value) => setState(() => _date = value),
                    ),
                  ),
                  if (_timing == CalendarEventTiming.timed) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _TimeTile(
                            key: const Key('event-start-time'),
                            label: 'From',
                            value: _start,
                            onTap: () => _selectTime(
                              initial: _start,
                              onSelected: _setStartTime,
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: _TimeTile(
                            key: const Key('event-end-time'),
                            label: 'To',
                            value: _end,
                            onTap: () => _selectTime(
                              initial: _end,
                              onSelected: _setEndTime,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_timing == CalendarEventTiming.allDay)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'All day event',
                        style: AppTypography.secondary,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildRepeatField(),
                  if (_frequency !=
                      CalendarRecurrenceFrequency.none) ...<Widget>[
                    const SizedBox(height: 20),
                    DropdownButtonFormField<CalendarRecurrenceEndMode>(
                      key: const Key('event-recurrence-end-mode'),
                      initialValue: _endMode,
                      decoration: _measuredInputDecoration(
                        labelText: 'Recurrence end',
                      ),
                      items:
                          const <DropdownMenuItem<CalendarRecurrenceEndMode>>[
                            DropdownMenuItem<CalendarRecurrenceEndMode>(
                              value: CalendarRecurrenceEndMode.never,
                              child: Text('No end'),
                            ),
                            DropdownMenuItem<CalendarRecurrenceEndMode>(
                              value: CalendarRecurrenceEndMode.onDate,
                              child: Text('End on date'),
                            ),
                            DropdownMenuItem<CalendarRecurrenceEndMode>(
                              value: CalendarRecurrenceEndMode.afterCount,
                              child: Text('End after count'),
                            ),
                          ],
                      onChanged: (value) => setState(
                        () =>
                            _endMode = value ?? CalendarRecurrenceEndMode.never,
                      ),
                    ),
                    if (_endMode == CalendarRecurrenceEndMode.onDate)
                      _DateTile(
                        label: 'Last occurrence',
                        date: _recurrenceEndDate ?? _date,
                        onTap: () => _selectDate(
                          initial: _recurrenceEndDate ?? _date,
                          onSelected: (value) =>
                              setState(() => _recurrenceEndDate = value),
                        ),
                      ),
                    if (_endMode == CalendarRecurrenceEndMode.afterCount)
                      TextFormField(
                        key: const Key('event-recurrence-count'),
                        controller: _countController,
                        decoration: const InputDecoration(
                          labelText: 'Number of occurrences',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          return parsed == null || parsed < 1
                              ? 'Enter at least 1'
                              : null;
                        },
                      ),
                  ],
                  const SizedBox(height: 20),
                  SwitchListTile(
                    key: const Key('event-backup-appointment-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Backup Appointment'),
                    value: _isBackupAppointment,
                    onChanged: (value) {
                      FocusScope.of(context).unfocus();
                      setState(() => _isBackupAppointment = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildAddressLocationSection(),
                  const SizedBox(height: 32),
                  const _MeasuredFormSeparator(
                    key: Key('event-form-people-separator'),
                  ),
                  const SizedBox(height: 32),
                  _buildPeopleSection(),
                  const SizedBox(height: 32),
                  const _MeasuredFormSeparator(
                    key: Key('event-form-indicator-separator'),
                  ),
                  const SizedBox(height: 32),
                  _buildIndicatorLinkSection(),
                  const SizedBox(height: 32),
                  _FormSectionLabel(
                    icon: Icons.fact_check_outlined,
                    label: 'Reporting & progress context',
                    color: lockedWli ? const Color(0xFF8E9295) : null,
                    iconColor: lockedWli ? const Color(0xFF85898C) : null,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: lockedWli
                          ? const Color(0xFF26282A)
                          : Colors.transparent,
                    ),
                    child: SwitchListTile(
                      key: const Key('event-requires-report-switch'),
                      contentPadding: lockedWli
                          ? const EdgeInsets.symmetric(horizontal: 12)
                          : EdgeInsets.zero,
                      activeThumbColor: lockedWli
                          ? const Color(0xFF777B7E)
                          : null,
                      activeTrackColor: lockedWli
                          ? const Color(0xFF4B4F52)
                          : null,
                      inactiveThumbColor: lockedWli
                          ? const Color(0xFF777B7E)
                          : null,
                      inactiveTrackColor: lockedWli
                          ? const Color(0xFF4B4F52)
                          : null,
                      title: Text(
                        'Report required',
                        style: lockedWli
                            ? const TextStyle(color: Color(0xFF8E9295))
                            : null,
                      ),
                      subtitle: lockedWli
                          ? const Text(
                              'Locked for WLI reporting',
                              style: TextStyle(color: Color(0xFF6F7376)),
                            )
                          : null,
                      value: _requiresReport,
                      onChanged: lockedWli
                          ? null
                          : (value) {
                              FocusScope.of(context).unfocus();
                              setState(() => _requiresReport = value);
                            },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
    if (!widget.sheetPresentation) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_formHeading),
          actions: <Widget>[_buildSaveButton()],
        ),
        body: content,
      );
    }
    return Material(
      key: const Key('calendar-event-detail-sheet'),
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          GestureDetector(
            key: const Key('calendar-event-sheet-header'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _handleSheetDragUpdate,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 14),
                Container(
                  key: const Key('calendar-event-sheet-handle'),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        key: const Key('calendar-event-sheet-close'),
                        tooltip: 'Close',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        padding: EdgeInsets.zero,
                        iconSize: 28,
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close),
                      ),
                      const Spacer(),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  void _handleSheetDragUpdate(DragUpdateDetails details) {
    final controller = widget.sheetController;
    if (controller == null || !controller.isAttached) {
      return;
    }
    final delta = details.primaryDelta;
    if (delta == null) {
      return;
    }
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final nextSize = (controller.size - delta / viewportHeight)
        .clamp(widget.sheetMinChildSize, widget.sheetMaxChildSize)
        .toDouble();
    if ((nextSize - controller.size).abs() > 0.0001) {
      controller.jumpTo(nextSize);
    }
  }

  Widget _buildSaveButton() {
    return Semantics(
      button: true,
      label: 'Save',
      child: FilledButton(
        key: const Key('save-event-button'),
        onPressed: _saving || _loading || _configurationLoading ? null : _save,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: AppTheme.rose,
          foregroundColor: AppTheme.background,
          disabledBackgroundColor: AppTheme.rose.withValues(alpha: 0.35),
        ),
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildAddressLocationSection() {
    final expanded = _addressExpanded || _locationExpanded;
    return Column(
      key: const Key('event-address-location-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!expanded)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('add-address-button'),
                  onPressed: () => setState(() {
                    _addressExpanded = true;
                    _locationExpanded = false;
                  }),
                  style: _compactFormActionStyle(),
                  icon: const Icon(Icons.add, size: 24),
                  label: const Text('Address'),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('add-location-button'),
                  onPressed: () => setState(() {
                    _locationExpanded = true;
                    _addressExpanded = false;
                  }),
                  style: _compactFormActionStyle(),
                  icon: const Icon(Icons.add, size: 24),
                  label: const Text('Location'),
                ),
              ),
            ],
          )
        else ...<Widget>[
          TextFormField(
            key: const Key('event-location-field'),
            controller: _locationController,
            decoration: _measuredInputDecoration(
              labelText: _addressExpanded ? 'Address' : 'Location',
            ),
            textInputAction: TextInputAction.next,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('collapse-address-location-button'),
              onPressed: () => setState(() {
                _locationController.clear();
                _addressExpanded = false;
                _locationExpanded = false;
              }),
              style: _compactFormActionStyle(),
              icon: const Icon(Icons.close),
              label: const Text('Remove'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPeopleSection() {
    return Column(
      key: const Key('event-people-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _MeasuredFormSectionHeader(
          key: Key('people-section-header'),
          label: 'People',
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('add-people-button'),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('People can be added from Contacts.'),
              ),
            ),
            style: _rightAlignedFormActionStyle(),
            icon: const Icon(Icons.add, size: 24),
            label: const Text('People'),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorLinkSection() {
    final linked = _indicatorOption(_linkedIndicatorKey);
    final locked = _selectedEventType?.isLockedWliType == true;
    return Semantics(
      container: true,
      enabled: !locked,
      label: 'Link to Weekly Life Indicator',
      child: Material(
        color: locked ? const Color(0xFF26282A) : Colors.transparent,
        child: InkWell(
          key: const Key('weekly-life-indicator-link-section'),
          onTap: locked ? null : _chooseIndicator,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: locked ? const EdgeInsets.all(12) : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _MeasuredFormSectionHeader(
                  label: 'Link to Weekly Life Indicator',
                  color: locked ? const Color(0xFF8E9295) : null,
                  dividerColor: locked ? const Color(0xFF6F7376) : null,
                ),
                const SizedBox(height: 24),
                if (locked)
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.lock_outline,
                        size: 22,
                        color: Color(0xFF85898C),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          linked?.label ??
                              _selectedEventType?.label ??
                              'Automatically linked',
                          key: const Key('weekly-life-indicator-link-value'),
                          style: const TextStyle(
                            color: Color(0xFF8E9295),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (linked == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('weekly-life-indicator-link-button'),
                      onPressed: _chooseIndicator,
                      style: _rightAlignedFormActionStyle(),
                      icon: const Icon(Icons.add, size: 24),
                      label: const Text('Link to Weekly Life Indicator'),
                    ),
                  )
                else
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          linked.label,
                          key: const Key('weekly-life-indicator-link-value'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        key: const Key('weekly-life-indicator-change'),
                        onPressed: _chooseIndicator,
                        style: _rightAlignedFormActionStyle(),
                        child: const Text('Change'),
                      ),
                      IconButton(
                        key: const Key('weekly-life-indicator-remove'),
                        tooltip: 'Remove indicator link',
                        onPressed: () => setState(() {
                          _linkedIndicatorKey = null;
                          _indicatorLinkTouched = true;
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IndicatorOption? _indicatorOption(String? key) {
    if (key == null) {
      return null;
    }
    return _indicatorOptions.where((option) => option.key == key).firstOrNull;
  }

  Future<void> _chooseIndicator() async {
    if (_selectedEventType?.isLockedWliType == true) {
      return;
    }
    if (_indicatorOptions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Weekly Life Indicators are available.'),
          ),
        );
      }
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Link to Weekly Life Indicator',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  key: const Key('weekly-indicator-picker'),
                  shrinkWrap: true,
                  itemCount: _indicatorOptions.length,
                  itemBuilder: (context, index) {
                    final option = _indicatorOptions[index];
                    return ListTile(
                      key: Key('weekly-indicator-option-${option.key}'),
                      leading: const Icon(Icons.track_changes_outlined),
                      title: Text(option.label),
                      subtitle: Text(option.unit),
                      onTap: () => Navigator.of(sheetContext).pop(option.key),
                    );
                  },
                ),
              ),
              TextButton(
                key: const Key('weekly-indicator-picker-cancel'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _linkedIndicatorKey = selected;
      _indicatorLinkTouched = true;
    });
  }

  bool get _isContactEvent {
    if (_selectedEventType?.stableKey ==
        SystemEventTypeKeys.meaningfulConnection) {
      return true;
    }
    final value = _selectedEventType?.label;
    final normalized = value?.trim().toLowerCase();
    return normalized != null && normalized.contains('contact');
  }

  String get _formHeading => switch (widget.mode) {
    CalendarEventFormMode.create when widget.sourceTaskId != null =>
      'Create Event from Task',
    CalendarEventFormMode.create =>
      _selectedEventType == null
          ? 'Create Event'
          : 'Create ${_selectedEventType!.label}',
    CalendarEventFormMode.edit =>
      _selectedEventType == null
          ? 'Edit Event'
          : 'Edit ${_selectedEventType!.label} Event',
    CalendarEventFormMode.reschedule => 'Reschedule Event',
  };

  ButtonStyle _compactFormActionStyle() {
    return TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      foregroundColor: AppTheme.rose,
      textStyle: AppTypography.button,
    );
  }

  ButtonStyle _rightAlignedFormActionStyle() {
    return TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: EdgeInsets.zero,
      alignment: Alignment.centerRight,
      foregroundColor: AppTheme.rose,
      textStyle: AppTypography.button,
    );
  }

  String? _scheduledPotentialRule() {
    final indicatorKey = _linkedIndicatorKey;
    if (indicatorKey == null) {
      return null;
    }
    final unit = _indicatorOption(indicatorKey)?.unit ?? 'count';
    return ScheduledPotentialRule(
      indicatorKey: indicatorKey,
      value: IndicatorAmount(scaledValue: 1, scale: 0, unit: unit),
    ).encode();
  }

  Future<void> _save() async {
    ref.read(calendarEventControllerProvider.notifier).clearMessage();
    ref.read(taskEventLinkControllerProvider.notifier).clearMessage();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final startMinute = _start.hour * 60 + _start.minute;
    final endMinute = _end.hour * 60 + _end.minute;
    if (_timing == CalendarEventTiming.timed && endMinute < startMinute + 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be at least 15 minutes after start.'),
        ),
      );
      return;
    }
    final selectedType = _selectedEventType;
    if (selectedType?.isLockedWliType == true) {
      _requiresReport = true;
      _linkedIndicatorKey = selectedType!.exactIndicatorKey;
    }
    if (selectedType != null &&
        selectedType.indicatorKeys.length > 1 &&
        !await _confirmMultipleMappings(selectedType)) {
      return;
    }
    setState(() => _saving = true);
    final draft = CalendarEventDraft(
      id: _draftId,
      title: _titleController.text,
      notes: _notesController.text,
      timing: _timing,
      startDate: _date,
      status: _currentStatus,
      startMinute: _timing == CalendarEventTiming.timed ? startMinute : null,
      endMinute: _timing == CalendarEventTiming.timed ? endMinute : null,
      timeZoneId: _timing == CalendarEventTiming.timed
          ? _timeZoneController.text
          : null,
      locationText: _locationController.text,
      requiresReport: _requiresReport,
      activityTypeId: _selectedEventType?.id,
      activityTypeMappingVersion: _selectedEventType?.mappingVersion,
      contributionRuleKey: _scheduledPotentialRule(),
      isBackupAppointment: _isBackupAppointment,
      backupForEventId: _isBackupAppointment ? _backupForEventId : null,
      backupRelationshipProvenance: _isBackupAppointment
          ? _backupRelationshipProvenance ?? 'user-classified'
          : null,
      recurrence: CalendarRecurrenceRule(
        frequency: _frequency,
        endMode: _frequency == CalendarRecurrenceFrequency.none
            ? CalendarRecurrenceEndMode.never
            : _endMode,
        endDate: _endMode == CalendarRecurrenceEndMode.onDate
            ? _recurrenceEndDate ?? _date
            : null,
        occurrenceCount: _endMode == CalendarRecurrenceEndMode.afterCount
            ? int.tryParse(_countController.text)
            : null,
      ),
    );
    final controller = ref.read(calendarEventControllerProvider.notifier);
    final saved = switch (widget.mode) {
      CalendarEventFormMode.create when widget.sourceTaskId != null =>
        await ref
            .read(taskEventLinkControllerProvider.notifier)
            .createEventFromTask(
              taskId: widget.sourceTaskId!,
              event: draft,
              linkId: _linkId!,
              operationId: _operationId,
              canonicalSource: _canonicalSource,
            ),
      CalendarEventFormMode.create => await controller.saveEvent(draft),
      CalendarEventFormMode.edit => await controller.editEvent(
        eventId: widget.eventId!,
        originalDate: widget.originalDate!,
        scope: widget.scope!,
        draft: draft,
        operationId: _operationId,
      ),
      CalendarEventFormMode.reschedule => await controller.rescheduleEvent(
        eventId: widget.eventId!,
        originalDate: widget.originalDate!,
        scope: widget.scope!,
        replacement: draft,
        operationId: _operationId,
      ),
    };
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (saved) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmMultipleMappings(EventType type) async {
    final labels =
        type.indicatorKeys.map(_indicatorLabel).toList(growable: false)..sort();
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm Life Indicator mappings'),
            content: Text(
              '${type.label} is mapped to ${labels.join(', ')}. Continue?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Review'),
              ),
              FilledButton(
                key: const Key('confirm-multiple-indicator-mappings'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirm and save'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _selectDate({
    required PlannerDate initial,
    required ValueChanged<PlannerDate> onSelected,
  }) async {
    final value = await showSharedPlannerDatePicker(
      context: context,
      initialDate: initial.asLocalDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: 'Select Calendar Event date',
    );
    if (value != null) {
      onSelected(PlannerDate.fromDateTime(value));
    }
  }

  Future<void> _selectTime({
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value != null) {
      final minute = _snapMinute(value.hour * 60 + value.minute);
      onSelected(_timeFromMinute(minute));
    }
  }

  void _setStartTime(TimeOfDay value) {
    final startMinute = value.hour * 60 + value.minute;
    final endMinute = _end.hour * 60 + _end.minute;
    setState(() {
      _start = value;
      if (endMinute < startMinute + 15) {
        _end = _timeFromMinute((startMinute + 15).clamp(1, 1439));
      }
    });
  }

  void _setEndTime(TimeOfDay value) {
    final endMinute = value.hour * 60 + value.minute;
    final startMinute = _start.hour * 60 + _start.minute;
    setState(() {
      _end = endMinute < startMinute + 15
          ? _timeFromMinute((startMinute + 15).clamp(1, 1439))
          : value;
      _durationWasEntered = true;
    });
  }

  static int _snapMinute(int minute) {
    return ((minute / 15).round() * 15).clamp(0, 1439);
  }

  static TimeOfDay _timeFromMinute(int value) {
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }

  static String _frequencyLabel(CalendarRecurrenceFrequency value) {
    return switch (value) {
      CalendarRecurrenceFrequency.none => 'Does not repeat',
      CalendarRecurrenceFrequency.daily => 'Daily',
      CalendarRecurrenceFrequency.weekly => 'Weekly',
      CalendarRecurrenceFrequency.monthly => 'Monthly',
      CalendarRecurrenceFrequency.yearly => 'Yearly',
    };
  }

  static String _indicatorLabel(String key) {
    return switch (key) {
      'temple_visit' => 'Temple Visit',
      'scripture_study' => 'Scripture Study',
      'exercise' => 'Exercise',
      'budget_review' => 'Budget Review',
      'job_applications' => 'Job Applications',
      'meaningful_connections' => 'Meaningful Connections',
      _ => key,
    };
  }
}

final class _MeasuredFormSeparator extends StatelessWidget {
  const _MeasuredFormSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-18, 0),
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        height: 8,
        child: const ColoredBox(color: Color(0xFF45484A)),
      ),
    );
  }
}

final class _MeasuredFormSectionHeader extends StatelessWidget {
  const _MeasuredFormSectionHeader({
    required this.label,
    this.color,
    this.dividerColor,
    super.key,
  });

  final String label;
  final Color? color;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: AppTypography.sectionTitle.copyWith(color: color)),
        const SizedBox(height: 6),
        Divider(height: 1, thickness: 1, color: dividerColor),
      ],
    );
  }
}

final class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({
    required this.icon,
    required this.label,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 18,
          color: iconColor ?? Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.sectionTitle.copyWith(
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

final class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.scope});

  final CalendarEventEditScope scope;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('event-selected-scope'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Selected scope: ${calendarEventScopeLabel(scope)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

final class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
        border: Border.all(color: Theme.of(context).colorScheme.error),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message),
    );
  }
}

final class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    super.key,
  });

  final String label;
  final PlannerDate date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: InputDecorator(
          decoration: _outlinedFormDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined, size: 24),
          ),
          child: Text(
            _friendlyDate(date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body,
          ),
        ),
      ),
    );
  }

  static String _friendlyDate(PlannerDate value) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = value.asLocalDate;
    return '${_weekday(local.weekday)}, ${months[local.month - 1]} '
        '${local.day}, ${local.year}';
  }

  static String _weekday(int value) {
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdays[value - 1];
  }
}

final class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: InputDecorator(
          decoration: _outlinedFormDecoration(labelText: label),
          child: Text(
            value.format(context),
            maxLines: 1,
            style: AppTypography.body,
          ),
        ),
      ),
    );
  }
}

InputDecoration _outlinedFormDecoration({
  required String labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return _measuredInputDecoration(
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}

InputDecoration _measuredInputDecoration({
  required String labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? hintText,
  bool? alignLabelWithHint,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: AppTheme.outline, width: 1),
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    labelStyle: AppTypography.micro,
    floatingLabelStyle: AppTypography.micro,
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  );
}

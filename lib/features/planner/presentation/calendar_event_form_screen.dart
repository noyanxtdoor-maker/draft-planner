import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/task_event_link_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';
import 'package:rmplanner/features/planner/presentation/event_type_picker_dialog.dart';

enum CalendarEventFormMode { create, edit, reschedule }

final class CalendarEventFormScreen extends ConsumerStatefulWidget {
  const CalendarEventFormScreen.create({
    required this.initialDate,
    this.initialStartMinute,
    this.initialIndicatorKey,
    this.initialEventTypeId,
    this.sheetPresentation = false,
    super.key,
  }) : mode = CalendarEventFormMode.create,
       eventId = null,
       originalDate = null,
       scope = null,
       sourceTaskId = null;

  const CalendarEventFormScreen.createFromTask({
    required this.sourceTaskId,
    required this.initialDate,
    this.initialStartMinute,
    this.initialIndicatorKey,
    this.initialEventTypeId,
    this.sheetPresentation = false,
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
    super.key,
  }) : mode = CalendarEventFormMode.edit,
       initialDate = null,
       initialStartMinute = null,
       initialIndicatorKey = null,
       initialEventTypeId = null,
       sourceTaskId = null;

  const CalendarEventFormScreen.reschedule({
    required this.eventId,
    required this.originalDate,
    required this.scope,
    this.sheetPresentation = false,
    super.key,
  }) : mode = CalendarEventFormMode.reschedule,
       initialDate = null,
       initialStartMinute = null,
       initialIndicatorKey = null,
       initialEventTypeId = null,
       sourceTaskId = null;

  final CalendarEventFormMode mode;
  final PlannerDate? initialDate;
  final int? initialStartMinute;
  final String? initialIndicatorKey;
  final String? initialEventTypeId;
  final String? eventId;
  final PlannerDate? originalDate;
  final CalendarEventEditScope? scope;
  final String? sourceTaskId;
  final bool sheetPresentation;

  @override
  ConsumerState<CalendarEventFormScreen> createState() =>
      _CalendarEventFormScreenState();
}

final class _CalendarEventFormScreenState
    extends ConsumerState<CalendarEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();
  final _timeZoneController = TextEditingController();
  final _countController = TextEditingController(text: '2');
  late final String _draftId;
  late final String _operationId;
  String? _linkId;
  late PlannerDate _date;
  CalendarEventTiming _timing = CalendarEventTiming.timed;
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
  TaskEventCanonicalSource _canonicalSource = TaskEventCanonicalSource.task;

  @override
  void initState() {
    super.initState();
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
    final state = ref.read(eventTypeControllerProvider);
    EventType? selected;
    var preferTypeDuration = false;
    if (widget.mode != CalendarEventFormMode.create) {
      final draft = await ref
          .read(calendarEventControllerProvider.notifier)
          .readEventDraft(widget.eventId!);
      final eventTypeId = draft?.activityTypeId;
      if (eventTypeId != null) {
        selected = state.eventTypes
            .where((type) => type.id == eventTypeId)
            .firstOrNull;
      }
    } else if (widget.initialEventTypeId != null) {
      preferTypeDuration = true;
      selected = state.eventTypes
          .where((type) => type.id == widget.initialEventTypeId)
          .firstOrNull;
    } else if (widget.initialIndicatorKey != null) {
      preferTypeDuration = true;
      selected = await controller.exactTypeForIndicator(
        widget.initialIndicatorKey!,
      );
    } else if (state.settings.defaultEventTypeId != null) {
      selected = state.eventTypes
          .where((type) => type.id == state.settings.defaultEventTypeId)
          .firstOrNull;
    }
    selected ??= state.eventTypes
        .where((type) => type.stableKey == SystemEventTypeKeys.general)
        .firstOrNull;
    if (mounted) {
      setState(() {
        _configurationLoading = false;
        _selectedEventType = selected;
        if (widget.mode == CalendarEventFormMode.create && selected != null) {
          _applyEventTypeDefaults(
            selected,
            durationMinutes: preferTypeDuration
                ? selected.defaultDurationMinutes
                : state.settings.defaultDurationMinutes,
          );
        }
      });
    }
  }

  void _applyEventTypeDefaults(EventType type, {int? durationMinutes}) {
    _requiresReport = type.reportRequiredDefault;
    if (_durationWasEntered) {
      return;
    }
    final startMinute = _start.hour * 60 + _start.minute;
    _end = _timeFromMinute(
      (startMinute + (durationMinutes ?? type.defaultDurationMinutes)).clamp(
        1,
        1439,
      ),
    );
  }

  Future<void> _changeEventType() async {
    final selected = await showEventTypePicker(
      context: context,
      ref: ref,
      recommendedEventTypeId: _selectedEventType?.id,
      recommendedIndicatorKey: widget.initialIndicatorKey,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedEventType = selected;
      if (widget.mode == CalendarEventFormMode.create) {
        _applyEventTypeDefaults(selected);
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
    _locationController.dispose();
    _timeZoneController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final draft = await ref
        .read(calendarEventControllerProvider.notifier)
        .readEventDraft(widget.eventId!);
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
    _timeZoneController.text =
        draft.timeZoneId ??
        ref.read(calendarEventControllerProvider.notifier).displayTimeZoneId;
    _date = widget.mode == CalendarEventFormMode.reschedule
        ? widget.originalDate!
        : draft.startDate;
    _timing = draft.timing;
    _start = _timeFromMinute(draft.startMinute ?? 9 * 60);
    _end = _timeFromMinute(draft.endMinute ?? 10 * 60);
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

  @override
  Widget build(BuildContext context) {
    final message =
        ref.watch(calendarEventControllerProvider) ??
        ref.watch(taskEventLinkControllerProvider);
    final content = _loading || _configurationLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            top: !widget.sheetPresentation,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                children: <Widget>[
                  const _FormSectionLabel(
                    icon: Icons.category_outlined,
                    label: 'Event identity',
                  ),
                  const SizedBox(height: 8),
                  if (widget.scope != null) ...<Widget>[
                    _ScopeBanner(scope: widget.scope!),
                    const SizedBox(height: 14),
                  ],
                  if (widget.sourceTaskId != null) ...<Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'The Calendar Event and Task remain '
                              'independent. Creating this link never '
                              'completes either record.',
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<TaskEventCanonicalSource>(
                              key: const Key('create-event-canonical-source'),
                              initialValue: _canonicalSource,
                              decoration: const InputDecoration(
                                labelText: 'Planning source counted once',
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
                    const SizedBox(height: 14),
                  ],
                  if (message != null) ...<Widget>[
                    _ErrorBanner(message: message),
                    const SizedBox(height: 14),
                  ],
                  Card(
                    key: const Key('event-type-field'),
                    child: ListTile(
                      leading: _selectedEventType == null
                          ? const Icon(Icons.category_outlined)
                          : Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Color(_selectedEventType!.colorValue),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                      title: const Text(
                        'Event Type',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      subtitle: Text(
                        _selectedEventType?.label ?? 'Not selected',
                        key: const Key('selected-event-type-label'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: TextButton(
                        key: const Key('change-event-type-button'),
                        onPressed: _changeEventType,
                        child: const Text('Change'),
                      ),
                    ),
                  ),
                  if (_selectedEventType != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _EventTypeMappingNotice(type: _selectedEventType!),
                  ],
                  const SizedBox(height: 18),
                  const _FormSectionLabel(
                    icon: Icons.edit_note_outlined,
                    label: 'Basic details',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('event-title-field'),
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('event-notes-field'),
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    minLines: 2,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 18),
                  const _FormSectionLabel(
                    icon: Icons.schedule_outlined,
                    label: 'Date and time',
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    key: const Key('event-all-day-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All-day event'),
                    subtitle: const Text(
                      'All-day dates never shift through time-zone conversion',
                    ),
                    value: _timing == CalendarEventTiming.allDay,
                    onChanged: (value) => setState(
                      () => _timing = value
                          ? CalendarEventTiming.allDay
                          : CalendarEventTiming.timed,
                    ),
                  ),
                  _DateTile(
                    label: 'Event date',
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
                            label: 'Start',
                            value: _start,
                            onTap: () => _selectTime(
                              initial: _start,
                              onSelected: (value) =>
                                  setState(() => _start = value),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeTile(
                            key: const Key('event-end-time'),
                            label: 'End',
                            value: _end,
                            onTap: () => _selectTime(
                              initial: _end,
                              onSelected: (value) => setState(() {
                                _end = value;
                                _durationWasEntered = true;
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('event-backup-appointment-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Backup Appointment'),
                    subtitle: const Text(
                      'Keeps normal Event Type and report rules; scheduling '
                      'still creates no Actual',
                    ),
                    value: _isBackupAppointment,
                    onChanged: (value) =>
                        setState(() => _isBackupAppointment = value),
                  ),
                  const SizedBox(height: 18),
                  const _FormSectionLabel(
                    icon: Icons.place_outlined,
                    label: 'Location',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('event-location-field'),
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Typed location',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Choose on Map will appear in the authorized map '
                      'slice. No location permission is requested here.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CalendarRecurrenceFrequency>(
                    key: const Key('event-recurrence-frequency'),
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: <DropdownMenuItem<CalendarRecurrenceFrequency>>[
                      for (final value in CalendarRecurrenceFrequency.values)
                        DropdownMenuItem<CalendarRecurrenceFrequency>(
                          value: value,
                          child: Text(_frequencyLabel(value)),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _frequency = value ?? CalendarRecurrenceFrequency.none;
                      if (_frequency == CalendarRecurrenceFrequency.none) {
                        _endMode = CalendarRecurrenceEndMode.never;
                      }
                    }),
                  ),
                  if (_frequency !=
                      CalendarRecurrenceFrequency.none) ...<Widget>[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CalendarRecurrenceEndMode>(
                      key: const Key('event-recurrence-end-mode'),
                      initialValue: _endMode,
                      decoration: const InputDecoration(
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
                  const SizedBox(height: 18),
                  const _FormSectionLabel(
                    icon: Icons.fact_check_outlined,
                    label: 'Reporting and progress context',
                  ),
                  SwitchListTile(
                    key: const Key('event-requires-report-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Report required'),
                    subtitle: const Text(
                      'Elapsed time creates attention, never an outcome',
                    ),
                    value: _requiresReport,
                    onChanged: (value) =>
                        setState(() => _requiresReport = value),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('save-event-button'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : _saveLabel),
                  ),
                ],
              ),
            ),
          );
    if (!widget.sheetPresentation) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: content,
      );
    }
    return Material(
      key: const Key('calendar-event-detail-sheet'),
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            key: const Key('calendar-event-sheet-handle'),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Row(
              children: <Widget>[
                IconButton(
                  key: const Key('calendar-event-sheet-close'),
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  String get _title => switch (widget.mode) {
    CalendarEventFormMode.create when widget.sourceTaskId != null =>
      'Create Event from Task',
    CalendarEventFormMode.create => 'New Calendar Event',
    CalendarEventFormMode.edit => 'Edit Calendar Event',
    CalendarEventFormMode.reschedule => 'Reschedule Calendar Event',
  };

  String get _saveLabel => switch (widget.mode) {
    CalendarEventFormMode.create => 'Save Event',
    CalendarEventFormMode.edit =>
      'Save ${calendarEventScopeLabel(widget.scope!)}',
    CalendarEventFormMode.reschedule =>
      'Create replacement for ${calendarEventScopeLabel(widget.scope!)}',
  };

  String? _scheduledPotentialRule(EventType? type) {
    final indicatorKey = type?.exactIndicatorKey;
    if (indicatorKey == null) {
      return null;
    }
    return ScheduledPotentialRule(
      indicatorKey: indicatorKey,
      value: const IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
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
    if (_timing == CalendarEventTiming.timed && endMinute <= startMinute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    final selectedType = _selectedEventType;
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
      startMinute: _timing == CalendarEventTiming.timed ? startMinute : null,
      endMinute: _timing == CalendarEventTiming.timed ? endMinute : null,
      timeZoneId: _timing == CalendarEventTiming.timed
          ? _timeZoneController.text
          : null,
      locationText: _locationController.text,
      requiresReport: _requiresReport,
      activityTypeId: _selectedEventType?.id,
      activityTypeMappingVersion: _selectedEventType?.mappingVersion,
      contributionRuleKey: _scheduledPotentialRule(_selectedEventType),
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
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmMultipleMappings(EventType type) async {
    final labels =
        type.indicatorKeys
            .map(_EventTypeMappingNotice.indicatorLabel)
            .toList(growable: false)
          ..sort();
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm Life Indicator mappings'),
            content: Text(
              '${type.label} is explicitly mapped to ${labels.join(', ')}. '
              'Saving schedules the activity and creates no Actual. Continue?',
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
    final value = await showDatePicker(
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
      onSelected(value);
    }
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
}

final class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

final class _EventTypeMappingNotice extends StatelessWidget {
  const _EventTypeMappingNotice({required this.type});

  final EventType type;

  @override
  Widget build(BuildContext context) {
    final keys = type.indicatorKeys.toList(growable: false)..sort();
    final mapping = keys.isEmpty
        ? 'No Life Indicator mapping'
        : keys.map(indicatorLabel).join(', ');
    return Semantics(
      key: const Key('event-type-mapping-preview'),
      label: '$mapping. Scheduling creates no Actual progress.',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color(type.colorValue).withValues(alpha: 0.12),
          border: Border.all(
            color: Color(type.colorValue).withValues(alpha: 0.7),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.link_outlined, color: Color(type.colorValue), size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$mapping. This sets planning and reporting context only; '
                'saving never creates Actual.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String indicatorLabel(String key) {
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
  });

  final String label;
  final PlannerDate date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      subtitle: Text(date.iso8601),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(label),
      subtitle: Text(value.format(context)),
      onTap: onTap,
    );
  }
}

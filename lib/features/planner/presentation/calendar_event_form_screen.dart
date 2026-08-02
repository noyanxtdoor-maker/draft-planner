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
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';
import 'package:rmplanner/features/planner/presentation/event_type_picker_dialog.dart';

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
      _linkedIndicatorKey =
          widget.initialIndicatorKey ?? initialEventType.exactIndicatorKey;
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
        .where((type) => type.stableKey == SystemEventTypeKeys.general)
        .firstOrNull;
    final existingRule = ScheduledPotentialRule.tryParse(
      existingDraft?.contributionRuleKey,
    );
    final initialLink =
        existingRule?.indicatorKey ??
        widget.initialIndicatorKey ??
        selected?.exactIndicatorKey;
    if (mounted) {
      setState(() {
        _configurationLoading = false;
        _selectedEventType = selected;
        _indicatorOptions = indicatorOptions;
        _linkedIndicatorKey = initialLink;
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
    _requiresReport = type.reportRequiredDefault;
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
      if (!_indicatorLinkTouched) {
        _linkedIndicatorKey = selected.exactIndicatorKey;
      }
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
        draft.timeZoneId ??
        ref.read(calendarEventControllerProvider.notifier).displayTimeZoneId;
    _date = widget.mode == CalendarEventFormMode.reschedule
        ? widget.originalDate!
        : draft.startDate;
    _timing = draft.timing;
    _currentStatus = occurrence?.status ?? draft.status;
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
                key: const Key('calendar-event-form-scroll'),
                controller: widget.sheetScrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: <Widget>[
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
                    const SizedBox(height: 14),
                  ],
                  if (message != null) ...<Widget>[
                    _ErrorBanner(message: message),
                    const SizedBox(height: 14),
                  ],
                  Material(
                    key: const Key('event-type-field'),
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _changeEventType,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _isContactEvent
                              ? 'Contact Type'
                              : 'Event Type',
                          prefixIcon: _selectedEventType == null
                              ? const Icon(Icons.category_outlined)
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(
                                          _selectedEventType!.colorValue,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          suffixIcon: TextButton(
                            key: const Key('change-event-type-button'),
                            onPressed: _changeEventType,
                            child: const Text('Change'),
                          ),
                        ),
                        child: Text(
                          _selectedEventType?.label ?? 'Not selected',
                          key: const Key('selected-event-type-label'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(height: 4),
                  if (widget.mode != CalendarEventFormMode.create) ...<Widget>[
                    _buildCurrentStatusField(),
                    const SizedBox(height: 12),
                  ],
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
                    focusNode: _notesFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: _notesFocusNode.hasFocus
                          ? null
                          : 'What do you need to remember about this?',
                      helperText: _notesFocusNode.hasFocus
                          ? 'What do you need to remember about this?'
                          : null,
                      prefixIcon: Icon(Icons.notes),
                      alignLabelWithHint: true,
                    ),
                    minLines: 2,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 18),
                  const _FormSectionLabel(
                    icon: Icons.schedule_outlined,
                    label: 'Scheduling Details',
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    key: const Key('event-all-day-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All-day event'),
                    value: _timing == CalendarEventTiming.allDay,
                    onChanged: (value) {
                      FocusScope.of(context).unfocus();
                      setState(
                        () => _timing = value
                            ? CalendarEventTiming.allDay
                            : CalendarEventTiming.timed,
                      );
                    },
                  ),
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
                        const SizedBox(width: 10),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CalendarRecurrenceFrequency>(
                    key: const Key('event-recurrence-frequency'),
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Repeat',
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 18),
                  _buildAddressLocationSection(),
                  const SizedBox(height: 16),
                  _buildPeopleSection(),
                  const SizedBox(height: 16),
                  _buildIndicatorLinkSection(),
                  const SizedBox(height: 18),
                  const _FormSectionLabel(
                    icon: Icons.fact_check_outlined,
                    label: 'Optional — Reporting & progress context',
                  ),
                  SwitchListTile(
                    key: const Key('event-requires-report-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Report required'),
                    value: _requiresReport,
                    onChanged: (value) {
                      FocusScope.of(context).unfocus();
                      setState(() => _requiresReport = value);
                    },
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          GestureDetector(
            key: const Key('calendar-event-sheet-header'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _handleSheetDragUpdate,
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
                        tooltip: 'Close',
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
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
            : const Text('Save'),
      ),
    );
  }

  Widget _buildAddressLocationSection() {
    final expanded = _addressExpanded || _locationExpanded;
    return Column(
      key: const Key('event-address-location-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _FormSectionLabel(
          icon: Icons.place_outlined,
          label: 'Address and Location',
        ),
        const Divider(height: 18),
        if (!expanded)
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  key: const Key('add-address-button'),
                  onPressed: () => setState(() {
                    _addressExpanded = true;
                    _locationExpanded = false;
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('+ Address'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  key: const Key('add-location-button'),
                  onPressed: () => setState(() {
                    _locationExpanded = true;
                    _addressExpanded = false;
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('+ Location'),
                ),
              ),
            ],
          )
        else ...<Widget>[
          TextFormField(
            key: const Key('event-location-field'),
            controller: _locationController,
            decoration: InputDecoration(
              labelText: _addressExpanded ? 'Address' : 'Location',
              prefixIcon: Icon(
                _addressExpanded ? Icons.home_outlined : Icons.place_outlined,
              ),
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
              icon: const Icon(Icons.close),
              label: const Text('Remove'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentStatusField() {
    const statuses = <CalendarEventStatus>[
      CalendarEventStatus.scheduled,
      CalendarEventStatus.completedHappened,
      CalendarEventStatus.partiallyCompleted,
      CalendarEventStatus.didNotHappen,
    ];
    return DropdownButtonFormField<CalendarEventStatus>(
      key: const Key('event-current-status-field'),
      initialValue: statuses.contains(_currentStatus)
          ? _currentStatus
          : CalendarEventStatus.scheduled,
      decoration: const InputDecoration(
        labelText: 'Current Status',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      items: <DropdownMenuItem<CalendarEventStatus>>[
        for (final status in statuses)
          DropdownMenuItem<CalendarEventStatus>(
            value: status,
            child: Text(
              calendarEventOutcomeLabel(
                status: status,
                isContactEvent: _isContactEvent,
              ),
            ),
          ),
      ],
      onChanged: (value) =>
          setState(() => _currentStatus = value ?? _currentStatus),
    );
  }

  Widget _buildPeopleSection() {
    return Column(
      key: const Key('event-people-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          key: const Key('people-section-header'),
          children: <Widget>[
            const Icon(Icons.people_outline),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'People',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              key: const Key('add-people-button'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('People can be added from Contacts.'),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('+ People'),
            ),
          ],
        ),
        const Divider(height: 18),
      ],
    );
  }

  Widget _buildIndicatorLinkSection() {
    final linked = _indicatorOption(_linkedIndicatorKey);
    return Semantics(
      container: true,
      label: 'Link to Weekly Life Indicator',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('weekly-life-indicator-link-section'),
          onTap: _chooseIndicator,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.track_changes_outlined),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Link to Weekly Life Indicator',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (linked == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('weekly-life-indicator-link-button'),
                      onPressed: _chooseIndicator,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Link Indicator'),
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
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
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
    final value = _selectedEventType?.stableKey ?? _selectedEventType?.label;
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: _outlinedFormDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: const Icon(Icons.chevron_right),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _friendlyDate(date),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              date.iso8601,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white60),
            ),
          ],
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: _outlinedFormDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
        ),
        child: Text(
          value.format(context),
          style: const TextStyle(fontWeight: FontWeight.w700),
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
  return InputDecoration(
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

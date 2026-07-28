import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

enum CalendarEventFormMode { create, edit, reschedule }

final class CalendarEventFormScreen extends ConsumerStatefulWidget {
  const CalendarEventFormScreen.create({required this.initialDate, super.key})
    : mode = CalendarEventFormMode.create,
      eventId = null,
      originalDate = null,
      scope = null;

  const CalendarEventFormScreen.edit({
    required this.eventId,
    required this.originalDate,
    required this.scope,
    super.key,
  }) : mode = CalendarEventFormMode.edit,
       initialDate = null;

  const CalendarEventFormScreen.reschedule({
    required this.eventId,
    required this.originalDate,
    required this.scope,
    super.key,
  }) : mode = CalendarEventFormMode.reschedule,
       initialDate = null;

  final CalendarEventFormMode mode;
  final PlannerDate? initialDate;
  final String? eventId;
  final PlannerDate? originalDate;
  final CalendarEventEditScope? scope;

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
  late PlannerDate _date;
  CalendarEventTiming _timing = CalendarEventTiming.timed;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _requiresReport = false;
  CalendarRecurrenceFrequency _frequency = CalendarRecurrenceFrequency.none;
  CalendarRecurrenceEndMode _endMode = CalendarRecurrenceEndMode.never;
  PlannerDate? _recurrenceEndDate;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ids = ref.read(plannerIdentifierSourceProvider);
    _operationId = ids.nextUuid();
    _draftId = switch (widget.mode) {
      CalendarEventFormMode.create ||
      CalendarEventFormMode.reschedule => ids.nextUuid(),
      CalendarEventFormMode.edit
          when widget.scope == CalendarEventEditScope.thisAndFuture =>
        ids.nextUuid(),
      CalendarEventFormMode.edit => widget.eventId!,
    };
    _date = widget.initialDate ?? widget.originalDate!;
    _timeZoneController.text = ref
        .read(calendarEventControllerProvider.notifier)
        .displayTimeZoneId;
    if (widget.mode != CalendarEventFormMode.create) {
      _loading = true;
      unawaited(Future<void>.microtask(_loadExisting));
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
    _requiresReport = draft.requiresReport;
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
    final message = ref.watch(calendarEventControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                  children: <Widget>[
                    if (widget.scope != null) ...<Widget>[
                      _ScopeBanner(scope: widget.scope!),
                      const SizedBox(height: 14),
                    ],
                    if (message != null) ...<Widget>[
                      _ErrorBanner(message: message),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      key: const Key('event-title-field'),
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
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
                                onSelected: (value) =>
                                    setState(() => _end = value),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('event-time-zone-field'),
                        controller: _timeZoneController,
                        decoration: const InputDecoration(
                          labelText: 'Original IANA time zone',
                          helperText: 'Example: Asia/Manila',
                          prefixIcon: Icon(Icons.public),
                        ),
                        validator: (value) {
                          final zone = value?.trim() ?? '';
                          if (zone.isEmpty) {
                            return 'Time zone is required';
                          }
                          return ref
                                  .read(
                                    calendarEventControllerProvider.notifier,
                                  )
                                  .isValidTimeZone(zone)
                              ? null
                              : 'Use a valid IANA time zone';
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('event-location-field'),
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Typed location (optional)',
                        helperText: 'No location permission is required',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('event-notes-field'),
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      minLines: 2,
                      maxLines: 5,
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
                          () => _endMode =
                              value ?? CalendarRecurrenceEndMode.never,
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
            ),
    );
  }

  String get _title => switch (widget.mode) {
    CalendarEventFormMode.create => 'New Calendar Event',
    CalendarEventFormMode.edit => 'Edit Calendar Event',
    CalendarEventFormMode.reschedule => 'Reschedule Calendar Event',
  };

  String get _saveLabel => switch (widget.mode) {
    CalendarEventFormMode.create => 'Create Event',
    CalendarEventFormMode.edit =>
      'Save ${calendarEventScopeLabel(widget.scope!)}',
    CalendarEventFormMode.reschedule =>
      'Create replacement for ${calendarEventScopeLabel(widget.scope!)}',
  };

  Future<void> _save() async {
    ref.read(calendarEventControllerProvider.notifier).clearMessage();
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class OutcomeReportScreen extends ConsumerStatefulWidget {
  const OutcomeReportScreen.task({required String taskId, super.key})
    : sourceType = OutcomeSourceType.task,
      sourceId = taskId,
      correctionReportId = null,
      initialDate = null,
      initialOutcome = null;

  const OutcomeReportScreen.manual({required this.initialDate, super.key})
    : sourceType = OutcomeSourceType.manual,
      sourceId = null,
      correctionReportId = null,
      initialOutcome = null;

  const OutcomeReportScreen.correction({
    required this.correctionReportId,
    super.key,
  }) : sourceType = null,
       sourceId = null,
       initialDate = null,
       initialOutcome = null;

  final OutcomeSourceType? sourceType;
  final String? sourceId;
  final PlannerDate? initialDate;
  final OutcomeKind? initialOutcome;
  final String? correctionReportId;

  @override
  ConsumerState<OutcomeReportScreen> createState() =>
      _OutcomeReportScreenState();
}

final class _OutcomeReportScreenState
    extends ConsumerState<OutcomeReportScreen> {
  final _privateNotes = TextEditingController();
  final _correctionReason = TextEditingController();
  final _manualLabel = TextEditingController(text: 'Activity Report');
  final _partialValue = TextEditingController();
  final Map<String, TextEditingController> _contributionValues =
      <String, TextEditingController>{};
  final Set<String> _selectedIndicators = <String>{};

  Timer? _autosaveTimer;
  OutcomeReportSource? _source;
  OutcomeReport? _correctedReport;
  List<IndicatorOption> _indicatorOptions = const <IndicatorOption>[];
  OutcomeKind? _outcome;
  PlannerDate? _activityDate;
  String _partialUnit = 'count';
  String? _reportId;
  String? _loadError;
  String? _formError;
  bool _loading = true;
  bool _submitting = false;
  bool _draftSaved = false;
  bool _didHydrate = false;

  bool get _isCorrection => widget.correctionReportId != null;
  bool get _isManual => _source?.type == OutcomeSourceType.manual;
  bool get _correctionChangesActual =>
      (_correctedReport?.affectedActual ?? false) ||
      _selectedIndicators.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _privateNotes.dispose();
    _correctionReason.dispose();
    _manualLabel.dispose();
    _partialValue.dispose();
    for (final controller in _contributionValues.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final controller = ref.read(outcomeReportingControllerProvider.notifier);
    try {
      OutcomeReportSource? source;
      OutcomeReport? corrected;
      if (_isCorrection) {
        corrected = await controller.readReport(widget.correctionReportId!);
        if (corrected == null ||
            corrected.status != OutcomeReportStatus.submitted) {
          throw const OutcomeReportValidationException(
            'Only the current effective report can be corrected.',
          );
        }
        source = corrected.source;
      } else {
        source = switch (widget.sourceType) {
          OutcomeSourceType.task => await controller.readTaskSource(
            widget.sourceId!,
          ),
          OutcomeSourceType.event => throw StateError(
            'Calendar Event status is saved from Current Status.',
          ),
          OutcomeSourceType.manual => OutcomeReportSource(
            type: OutcomeSourceType.manual,
            sourceId: ref.read(plannerIdentifierSourceProvider).nextUuid(),
            label: _manualLabel.text,
            activityDate:
                widget.initialDate ??
                ref.read(plannerDateSourceProvider).today(),
          ),
          null => null,
        };
      }
      if (source == null) {
        throw const OutcomeReportValidationException(
          'This reporting source is no longer available.',
        );
      }

      final options = await controller.readIndicatorOptions();
      final draft = await controller.readDraft(source.slotKey);
      final effectiveEntries = corrected == null
          ? const <ActivityLedgerEntry>[]
          : (await controller.readLedgerHistory())
                .where(
                  (entry) =>
                      entry.sourceReportId == corrected!.id &&
                      entry.type == ActivityLedgerEntryType.contribution &&
                      entry.isEffective,
                )
                .toList(growable: false);
      if (!mounted) {
        return;
      }

      final seed = draft;
      _source = source;
      _correctedReport = corrected;
      _indicatorOptions = options;
      _reportId =
          seed?.id ?? ref.read(plannerIdentifierSourceProvider).nextUuid();
      _outcome = seed?.outcome ?? corrected?.outcome ?? widget.initialOutcome;
      _activityDate =
          seed?.activityDate ?? corrected?.activityDate ?? source.activityDate;
      _privateNotes.text = seed?.privateNotes ?? corrected?.privateNotes ?? '';
      _correctionReason.text = seed?.correctionReason ?? '';
      final factual = seed?.factualValue ?? corrected?.factualValue;
      if (factual != null) {
        _partialValue.text = factual.displayValue;
        _partialUnit = factual.unit;
      }
      if (_isManual) {
        _manualLabel.text = seed?.source.label ?? source.label;
      }

      final contributions = seed?.draftContributions.isNotEmpty == true
          ? seed!.draftContributions
          : effectiveEntries
                .map(
                  (entry) => ContributionDraft(
                    ruleKey: entry.ruleKey,
                    indicatorKey: entry.indicatorKey,
                    value: entry.value,
                  ),
                )
                .toList(growable: false);
      for (final option in options) {
        final contribution = contributions
            .where((item) => item.indicatorKey == option.key)
            .firstOrNull;
        final valueController = TextEditingController(
          text: contribution?.value.displayValue ?? '1',
        );
        valueController.addListener(_scheduleAutosave);
        _contributionValues[option.key] = valueController;
        if (contribution != null) {
          _selectedIndicators.add(option.key);
        }
      }

      _didHydrate = true;
      setState(() {
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error is OutcomeReportValidationException
            ? error.message
            : 'The report could not be opened. No local data was changed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerMessage = ref.watch(outcomeReportingControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCorrection ? 'Correct Report' : 'Activity Report'),
        actions: <Widget>[
          if (!_loading && _loadError == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _draftSaved ? 'Draft saved' : 'Draft',
                  key: const Key('report-draft-status'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _MessagePane(message: _loadError!)
            : ListView(
                key: const Key('outcome-report-form'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  _SourceHeader(source: _source!, correction: _isCorrection),
                  const SizedBox(height: 16),
                  if (_isManual) ...<Widget>[
                    TextField(
                      key: const Key('manual-report-label'),
                      controller: _manualLabel,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Activity label',
                        helperText:
                            'Describe the activity factually; titles never '
                            'classify contributions.',
                      ),
                      onChanged: (_) => _changed(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  OutlinedButton.icon(
                    key: const Key('report-activity-date'),
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Activity date · ${_activityDate!.iso8601}'),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'What happened?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<OutcomeKind>(
                    groupValue: _outcome,
                    onChanged: (value) {
                      setState(() {
                        _outcome = value;
                        if (value == OutcomeKind.didNotHappen) {
                          _selectedIndicators.clear();
                        }
                      });
                      _changed();
                    },
                    child: Column(
                      children: <Widget>[
                        for (final outcome in OutcomeKind.values)
                          RadioListTile<OutcomeKind>(
                            key: Key('report-outcome-${outcome.name}'),
                            value: outcome,
                            contentPadding: EdgeInsets.zero,
                            title: Text(_outcomeLabel(outcome)),
                          ),
                      ],
                    ),
                  ),
                  if (_outcome == OutcomeKind.partiallyCompleted) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: const Key('report-partial-value'),
                            controller: _partialValue,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Factual amount completed',
                            ),
                            onChanged: (_) => _changed(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 128,
                          child: DropdownButtonFormField<String>(
                            key: const Key('report-partial-unit'),
                            initialValue: _partialUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(
                                value: 'count',
                                child: Text('Count'),
                              ),
                              DropdownMenuItem(
                                value: 'minutes',
                                child: Text('Minutes'),
                              ),
                              DropdownMenuItem(
                                value: 'hours',
                                child: Text('Hours'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _partialUnit = value);
                              _changed();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Qualifying contributions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Optional. Select explicitly—Next Transfer never infers '
                    'a Life Indicator from a title or note.',
                  ),
                  const SizedBox(height: 8),
                  if (_indicatorOptions.isEmpty)
                    const _MessageCard(
                      message:
                          'No approved Life Indicators are available for this '
                          'Local Profile.',
                    )
                  else
                    for (final option in _indicatorOptions)
                      _ContributionTile(
                        option: option,
                        selected: _selectedIndicators.contains(option.key),
                        enabled: _outcome != OutcomeKind.didNotHappen,
                        valueController: _contributionValues[option.key]!,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedIndicators.add(option.key);
                            } else {
                              _selectedIndicators.remove(option.key);
                            }
                          });
                          _changed();
                        },
                      ),
                  const SizedBox(height: 18),
                  TextField(
                    key: const Key('report-private-notes'),
                    controller: _privateNotes,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Private notes (optional)',
                      helperText:
                          'Non-contributory; excluded from diagnostics and '
                          'notification previews.',
                    ),
                    onChanged: (_) => _changed(),
                  ),
                  if (_isCorrection) ...<Widget>[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('report-correction-reason'),
                      controller: _correctionReason,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: _correctionChangesActual
                            ? 'Correction reason (required)'
                            : 'Correction reason (optional)',
                        helperText:
                            'The original report and reversed ledger entries '
                            'remain in audit history.',
                      ),
                      onChanged: (_) => _changed(),
                    ),
                  ],
                  if (_formError != null ||
                      controllerMessage != null) ...<Widget>[
                    const SizedBox(height: 14),
                    _MessageCard(
                      message: _formError ?? controllerMessage!,
                      error: _formError != null,
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const Key('submit-outcome-report'),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isCorrection ? 'Save Correction' : 'Submit Report',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Submission is saved offline in one transaction. Actual '
                    'is read-only and comes only from effective ledger entries.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  void _changed() {
    if (!_didHydrate) {
      return;
    }
    setState(() {
      _draftSaved = false;
      _formError = null;
    });
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (!_didHydrate || _submitting) {
      return;
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 550), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    final draft = _buildDraft(forSubmission: false);
    if (draft == null) {
      return;
    }
    final saved = await ref
        .read(outcomeReportingControllerProvider.notifier)
        .saveDraft(draft);
    if (!mounted || saved == null) {
      return;
    }
    setState(() {
      _reportId = saved.id;
      _draftSaved = true;
    });
  }

  Future<void> _submit() async {
    _autosaveTimer?.cancel();
    final draft = _buildDraft(forSubmission: true);
    if (draft == null) {
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    final result = await ref
        .read(outcomeReportingControllerProvider.notifier)
        .submit(
          draft: draft,
          operationId: ref.read(plannerIdentifierSourceProvider).nextUuid(),
        );
    if (!mounted) {
      return;
    }
    if (result == null) {
      setState(() => _submitting = false);
      return;
    }
    Navigator.of(context).pop(true);
  }

  OutcomeReportDraft? _buildDraft({required bool forSubmission}) {
    final source = _source;
    final reportId = _reportId;
    final activityDate = _activityDate;
    if (source == null || reportId == null || activityDate == null) {
      return null;
    }
    try {
      if (_isManual && _manualLabel.text.trim().isEmpty) {
        throw const OutcomeReportValidationException(
          'Enter a factual activity label.',
        );
      }
      if (forSubmission && _outcome == null) {
        throw const OutcomeReportValidationException(
          'Choose what factually happened before submitting.',
        );
      }
      final factualValue = _outcome == OutcomeKind.partiallyCompleted
          ? _parseValue(
              _partialValue.text,
              unit: _partialUnit,
              required: forSubmission,
            )
          : null;
      final contributions = <ContributionDraft>[];
      for (final option in _indicatorOptions) {
        if (!_selectedIndicators.contains(option.key)) {
          continue;
        }
        final value = _parseValue(
          _contributionValues[option.key]!.text,
          unit: option.unit,
          required: forSubmission,
        );
        if (value != null) {
          contributions.add(
            ContributionDraft(
              ruleKey: 'user-selected:${option.key}',
              indicatorKey: option.key,
              value: value,
            ),
          );
        }
      }
      if (_outcome == OutcomeKind.didNotHappen && contributions.isNotEmpty) {
        throw const OutcomeReportValidationException(
          'Did Not Attempt cannot create a contribution.',
        );
      }
      final normalizedSource = OutcomeReportSource(
        type: source.type,
        sourceId: source.sourceId,
        label: _isManual ? _manualLabel.text : source.label,
        activityDate: activityDate,
        eventId: source.eventId,
        occurrenceId: source.occurrenceId,
        originalDate: source.originalDate,
        eventTypeLabel: source.eventTypeLabel,
        isContactEvent: source.isContactEvent,
      );
      return OutcomeReportDraft(
        id: reportId,
        source: normalizedSource,
        activityDate: activityDate,
        outcome: _outcome,
        factualValue: factualValue,
        privateNotes: _privateNotes.text,
        correctsReportId: widget.correctionReportId,
        correctionReason: _correctionReason.text,
        contributions: contributions,
      );
    } on OutcomeReportValidationException catch (error) {
      if (forSubmission && mounted) {
        setState(() => _formError = error.message);
      }
      return null;
    }
  }

  IndicatorValue? _parseValue(
    String raw, {
    required String unit,
    required bool required,
  }) {
    final text = raw.trim();
    if (text.isEmpty) {
      if (required) {
        throw const OutcomeReportValidationException(
          'Enter a positive factual amount.',
        );
      }
      return null;
    }
    final allowedScale = IndicatorUnitPolicy.allowedScale(unit);
    final match = RegExp(r'^([0-9]+)(?:\.([0-9]+))?$').firstMatch(text);
    if (match == null) {
      throw const OutcomeReportValidationException(
        'Amounts must use positive numbers only.',
      );
    }
    final decimals = match.group(2) ?? '';
    if (decimals.length > allowedScale) {
      throw OutcomeReportValidationException(
        '$unit values allow at most $allowedScale decimal places.',
      );
    }
    try {
      final normalizedDecimals = decimals.padRight(allowedScale, '0');
      final scaled =
          int.parse(match.group(1)!) * _powerOfTen(allowedScale) +
          (normalizedDecimals.isEmpty ? 0 : int.parse(normalizedDecimals));
      if (scaled <= 0 || scaled > IndicatorUnitPolicy.maximumScaledValue) {
        throw const OutcomeReportValidationException(
          'Enter a positive amount within the supported range.',
        );
      }
      return IndicatorValue(
        scaledValue: scaled,
        scale: allowedScale,
        unit: unit,
      );
    } on FormatException {
      throw const OutcomeReportValidationException(
        'Enter a positive amount within the supported range.',
      );
    }
  }

  Future<void> _chooseDate() async {
    final current = _activityDate!;
    final result = await showDatePicker(
      context: context,
      initialDate: current.asLocalDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: 'Select factual activity date',
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _activityDate = PlannerDate.fromDateTime(result));
    _changed();
  }

  static int _powerOfTen(int exponent) {
    var value = 1;
    for (var index = 0; index < exponent; index++) {
      value *= 10;
    }
    return value;
  }

  String _outcomeLabel(OutcomeKind outcome) {
    return switch (outcome) {
      OutcomeKind.completedHappened =>
        (_source?.isContactEvent ?? false) ? 'Contacted' : 'Completed',
      OutcomeKind.partiallyCompleted => 'Missed - Attempted',
      OutcomeKind.didNotHappen => 'Did Not Attempt',
    };
  }
}

final class _SourceHeader extends StatelessWidget {
  const _SourceHeader({required this.source, required this.correction});

  final OutcomeReportSource source;
  final bool correction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(switch (source.type) {
              OutcomeSourceType.task => Icons.task_alt_outlined,
              OutcomeSourceType.event => Icons.event_outlined,
              OutcomeSourceType.manual => Icons.edit_note_outlined,
            }),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    correction ? 'Correction' : _sourceLabel(source.type),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    source.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sourceLabel(OutcomeSourceType type) {
    return switch (type) {
      OutcomeSourceType.task => 'Task report',
      OutcomeSourceType.event => 'Calendar Event report',
      OutcomeSourceType.manual => 'Manual Activity Report',
    };
  }
}

final class _ContributionTile extends StatelessWidget {
  const _ContributionTile({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.valueController,
    required this.onSelected,
  });

  final IndicatorOption option;
  final bool selected;
  final bool enabled;
  final TextEditingController valueController;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: <Widget>[
          CheckboxListTile(
            key: Key('report-indicator-${option.key}'),
            value: selected && enabled,
            onChanged: enabled ? (value) => onSelected(value ?? false) : null,
            title: Text(option.label),
            subtitle: Text('Explicit contribution · ${option.unit}'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (selected && enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TextField(
                key: Key('report-indicator-value-${option.key}'),
                controller: valueController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: IndicatorUnitPolicy.allowedScale(option.unit) > 0,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${option.unit})',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _MessagePane extends StatelessWidget {
  const _MessagePane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

final class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: error
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      child: Text(message),
    );
  }
}

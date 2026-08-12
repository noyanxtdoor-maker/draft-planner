import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class IndicatorEditScreen extends ConsumerStatefulWidget {
  const IndicatorEditScreen({
    required this.indicatorKey,
    required this.periodStart,
    super.key,
  });

  final String indicatorKey;
  final PlannerDate periodStart;

  @override
  ConsumerState<IndicatorEditScreen> createState() =>
      _IndicatorEditScreenState();
}

final class _IndicatorEditScreenState
    extends ConsumerState<IndicatorEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _indicatorController = TextEditingController();
  final _eventTypeController = TextEditingController();
  LifeIndicatorSummary? _indicator;
  EventType? _eventType;
  Object? _error;
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final period = IndicatorPeriod(
      start: widget.periodStart,
      end: widget.periodStart.addDays(6),
    );
    try {
      final indicator = await ref
          .read(homeIndicatorControllerProvider.notifier)
          .readDetail(widget.indicatorKey, period);
      final eventType = await ref
          .read(eventTypeControllerProvider.notifier)
          .exactTypeForIndicator(widget.indicatorKey);
      if (!mounted) {
        return;
      }
      if (indicator == null || eventType == null) {
        setState(() {
          _loading = false;
          _error = StateError('The linked WLI Event Type was not found.');
        });
        return;
      }
      _indicatorController.text = indicator.summary.label;
      _eventTypeController.text = eventType.label;
      setState(() {
        _indicator = indicator.summary;
        _eventType = eventType;
        _loading = false;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    _eventTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: InternalAppBar(title: Text('Edit Indicator')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _indicator == null || _eventType == null) {
      return Scaffold(
        appBar: InternalAppBar(title: const Text('Edit Indicator')),
        body: Center(
          child: Text(
            _error == null
                ? 'Indicator unavailable.'
                : 'Unable to edit this indicator.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: InternalAppBar(
        title: const Text('Edit Indicator'),
        actions: <Widget>[
          FilledButton(
            key: const Key('save-indicator-names'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              Text(
                'WLI title and Event Type name are independent display labels. '
                'Their stable IDs and reporting relationship stay unchanged.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('indicator-display-name-field'),
                controller: _indicatorController,
                decoration: const InputDecoration(labelText: 'Life Goal title'),
                textInputAction: TextInputAction.next,
                validator: _requiredLabel,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('event-type-display-name-field'),
                controller: _eventTypeController,
                decoration: const InputDecoration(
                  labelText: 'Linked Event Type name',
                ),
                validator: _requiredLabel,
              ),
              const SizedBox(height: 20),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline),
                title: Text('Relationship locked'),
                subtitle: Text(
                  'The first six Event Types remain linked and report-required.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredLabel(String? value) {
    return value == null || value.trim().isEmpty ? 'Enter a name.' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final indicatorLabel = _indicatorController.text.trim();
    final eventTypeLabel = _eventTypeController.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(homeIndicatorControllerProvider.notifier)
          .renameIndicator(
            indicatorKey: widget.indicatorKey,
            label: indicatorLabel,
          );
      await ref
          .read(eventTypeControllerProvider.notifier)
          .renameSystemType(eventTypeId: _eventType!.id, label: eventTypeLabel);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The name was not saved. Active display names must be unique.',
            ),
          ),
        );
      }
    }
  }
}

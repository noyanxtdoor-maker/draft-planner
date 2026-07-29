import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_form_screen.dart';
import 'package:rmplanner/features/planner/presentation/event_type_picker_dialog.dart';

final class CalendarEventCreateGateScreen extends ConsumerStatefulWidget {
  const CalendarEventCreateGateScreen({
    required this.initialDate,
    this.initialStartMinute,
    this.initialIndicatorKey,
    this.initialEventTypeId,
    this.sourceTaskId,
    super.key,
  });

  final PlannerDate initialDate;
  final int? initialStartMinute;
  final String? initialIndicatorKey;
  final String? initialEventTypeId;
  final String? sourceTaskId;

  @override
  ConsumerState<CalendarEventCreateGateScreen> createState() =>
      _CalendarEventCreateGateScreenState();
}

final class _CalendarEventCreateGateScreenState
    extends ConsumerState<CalendarEventCreateGateScreen> {
  String? _selectedEventTypeId;
  var _pickerScheduled = false;

  @override
  void initState() {
    super.initState();
    _selectedEventTypeId = widget.initialEventTypeId;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEventTypeId = _selectedEventTypeId;
    if (selectedEventTypeId != null) {
      final sourceTaskId = widget.sourceTaskId;
      if (sourceTaskId != null) {
        return CalendarEventFormScreen.createFromTask(
          sourceTaskId: sourceTaskId,
          initialDate: widget.initialDate,
          initialStartMinute: widget.initialStartMinute,
          initialEventTypeId: selectedEventTypeId,
          initialIndicatorKey: widget.initialIndicatorKey,
        );
      }
      return CalendarEventFormScreen.create(
        initialDate: widget.initialDate,
        initialStartMinute: widget.initialStartMinute,
        initialIndicatorKey: widget.initialIndicatorKey,
        initialEventTypeId: selectedEventTypeId,
      );
    }

    if (!_pickerScheduled) {
      _pickerScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_selectType());
      });
    }
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Opening Select Event Type',
          ),
        ),
      ),
    );
  }

  Future<void> _selectType() async {
    final selected = await showEventTypePicker(
      context: context,
      ref: ref,
      recommendedIndicatorKey: widget.initialIndicatorKey,
    );
    if (!mounted) {
      return;
    }
    if (selected == null) {
      if (context.canPop()) {
        context.pop(false);
      } else {
        context.go(RoutePaths.planner);
      }
      return;
    }
    setState(() => _selectedEventTypeId = selected.id);
  }
}

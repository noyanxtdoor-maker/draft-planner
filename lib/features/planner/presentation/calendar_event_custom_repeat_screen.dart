import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class CalendarCustomRepeatResult {
  const CalendarCustomRepeatResult({
    required this.frequency,
    required this.pattern,
  });

  final CalendarRecurrenceFrequency frequency;
  final CalendarRecurrencePattern pattern;
}

enum _CustomRepeatUnit { day, week, month }

final class CalendarEventCustomRepeatScreen extends StatefulWidget {
  const CalendarEventCustomRepeatScreen({
    required this.startDate,
    this.initialFrequency = CalendarRecurrenceFrequency.weekly,
    this.initialPattern,
    super.key,
  });

  final PlannerDate startDate;
  final CalendarRecurrenceFrequency initialFrequency;
  final CalendarRecurrencePattern? initialPattern;

  @override
  State<CalendarEventCustomRepeatScreen> createState() =>
      _CalendarEventCustomRepeatScreenState();
}

final class _CalendarEventCustomRepeatScreenState
    extends State<CalendarEventCustomRepeatScreen> {
  late final TextEditingController _intervalController;
  late _CustomRepeatUnit _unit;
  late Set<int> _weekdays;
  late CalendarRecurrenceMonthlyMode _monthlyMode;
  String? _intervalError;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    final pattern = widget.initialPattern;
    _intervalController = TextEditingController(
      text: (pattern?.interval ?? 1).toString(),
    );
    _unit = switch (widget.initialFrequency) {
      CalendarRecurrenceFrequency.daily => _CustomRepeatUnit.day,
      CalendarRecurrenceFrequency.monthly => _CustomRepeatUnit.month,
      CalendarRecurrenceFrequency.weekly ||
      CalendarRecurrenceFrequency.none ||
      CalendarRecurrenceFrequency.yearly => _CustomRepeatUnit.week,
    };
    _weekdays = <int>{...(pattern?.weeklyWeekdays ?? const <int>{})};
    if (_weekdays.isEmpty) {
      _weekdays.add(widget.startDate.weekday);
    }
    _monthlyMode =
        pattern?.monthlyMode ?? CalendarRecurrenceMonthlyMode.dayOfMonth;
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  CalendarRecurrenceFrequency get _frequency => switch (_unit) {
    _CustomRepeatUnit.day => CalendarRecurrenceFrequency.daily,
    _CustomRepeatUnit.week => CalendarRecurrenceFrequency.weekly,
    _CustomRepeatUnit.month => CalendarRecurrenceFrequency.monthly,
  };

  bool? get _allWeekdaysValue {
    if (_weekdays.isEmpty) {
      return false;
    }
    if (_weekdays.length == DateTime.daysPerWeek) {
      return true;
    }
    return null;
  }

  void _finish() {
    final interval = int.tryParse(_intervalController.text.trim());
    if (interval == null || interval < 1) {
      setState(() => _intervalError = 'Use 1 or more');
      return;
    }
    if (_unit == _CustomRepeatUnit.week && _weekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least one day.')));
      return;
    }
    final result = CalendarCustomRepeatResult(
      frequency: _frequency,
      pattern: CalendarRecurrencePattern(
        interval: interval,
        weeklyWeekdays: _unit == _CustomRepeatUnit.week
            ? Set<int>.unmodifiable(_weekdays)
            : const <int>{},
        monthlyMode: _monthlyMode,
      ).normalizedFor(_frequency),
    );
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finish();
        }
      },
      child: Scaffold(
        appBar: InternalAppBar(
          title: const Text('Repeat'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('custom-repeat-back'),
            tooltip: 'Back',
            onPressed: _finish,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('custom-repeat-screen'),
            padding: InternalScreen.pagePadding,
            children: <Widget>[
              const Text('Repeats Every', style: InternalScreen.sectionHeading),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    child: TextFormField(
                      key: const Key('custom-repeat-interval'),
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(errorText: _intervalError),
                      onChanged: (value) {
                        final interval = int.tryParse(value.trim());
                        setState(() {
                          _intervalError = interval == null || interval < 1
                              ? 'Use 1 or more'
                              : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<_CustomRepeatUnit>(
                      key: const Key('custom-repeat-unit'),
                      initialValue: _unit,
                      decoration: const InputDecoration(),
                      items: const <DropdownMenuItem<_CustomRepeatUnit>>[
                        DropdownMenuItem<_CustomRepeatUnit>(
                          value: _CustomRepeatUnit.day,
                          child: Text('Day'),
                        ),
                        DropdownMenuItem<_CustomRepeatUnit>(
                          value: _CustomRepeatUnit.week,
                          child: Text('Week'),
                        ),
                        DropdownMenuItem<_CustomRepeatUnit>(
                          value: _CustomRepeatUnit.month,
                          child: Text('Month'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _unit = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_unit == _CustomRepeatUnit.week) ...<Widget>[
                const SizedBox(height: 28),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text('Days', style: InternalScreen.sectionHeading),
                    ),
                    const Text('All', style: InternalScreen.body),
                    Checkbox(
                      key: const Key('custom-repeat-all-weekdays'),
                      value: _allWeekdaysValue,
                      tristate: true,
                      onChanged: (_) {
                        setState(() {
                          if (_weekdays.length == DateTime.daysPerWeek) {
                            _weekdays.clear();
                          } else {
                            _weekdays = <int>{
                              DateTime.monday,
                              DateTime.tuesday,
                              DateTime.wednesday,
                              DateTime.thursday,
                              DateTime.friday,
                              DateTime.saturday,
                              DateTime.sunday,
                            };
                          }
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 1),
                for (
                  var weekday = DateTime.monday;
                  weekday <= DateTime.sunday;
                  weekday++
                )
                  CheckboxListTile(
                    key: Key('custom-repeat-weekday-$weekday'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(_weekdayLabel(weekday)),
                    value: _weekdays.contains(weekday),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _weekdays.add(weekday);
                        } else {
                          _weekdays.remove(weekday);
                        }
                      });
                    },
                  ),
              ],
              if (_unit == _CustomRepeatUnit.month) ...<Widget>[
                const SizedBox(height: 28),
                RadioGroup<CalendarRecurrenceMonthlyMode>(
                  groupValue: _monthlyMode,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _monthlyMode = value);
                    }
                  },
                  child: Column(
                    children: <Widget>[
                      RadioListTile<CalendarRecurrenceMonthlyMode>(
                        key: const Key('custom-repeat-month-day'),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Monthly on day ${widget.startDate.day}'),
                        value: CalendarRecurrenceMonthlyMode.dayOfMonth,
                      ),
                      RadioListTile<CalendarRecurrenceMonthlyMode>(
                        key: const Key('custom-repeat-month-nth'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Monthly on ${_ordinal((widget.startDate.day - 1) ~/ DateTime.daysPerWeek + 1)} '
                          '${_weekdayLabel(widget.startDate.weekday)}',
                        ),
                        value: CalendarRecurrenceMonthlyMode.nthWeekday,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _weekdayLabel(int weekday) {
    return const <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][weekday - DateTime.monday];
  }

  static String _ordinal(int value) {
    return switch (value) {
      1 => 'first',
      2 => 'second',
      3 => 'third',
      4 => 'fourth',
      5 => 'fifth',
      _ => '${value}th',
    };
  }
}

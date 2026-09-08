import 'package:flutter/material.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/unsaved_changes_guard.dart';

final class AvailabilityEditResult {
  const AvailabilityEditResult(this.windows);
  final List<ContactAvailability> windows;
}

final class AvailabilityEditor extends StatefulWidget {
  const AvailabilityEditor({required this.initialWindows, super.key});
  final List<ContactAvailability> initialWindows;
  @override
  State<AvailabilityEditor> createState() => _AvailabilityEditorState();
}

final class _AvailabilityEditorState extends State<AvailabilityEditor> {
  late List<ContactAvailability> _windows;
  int _weekday = DateTime.monday;
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 21, minute: 0);
  @override
  void initState() {
    super.initState();
    _windows = List.of(widget.initialWindows);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _addWindow() {
    final startMinute = _start.hour * 60 + _start.minute;
    final endMinute = _end.hour * 60 + _end.minute;
    if (endMinute <= startMinute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(
      () => _windows.add(
        ContactAvailability(
          weekday: _weekday,
          startMinute: startMinute,
          endMinute: endMinute,
        ),
      ),
    );
  }

  bool get _isDirty {
    if (_windows.length != widget.initialWindows.length) {
      return true;
    }
    for (var index = 0; index < _windows.length; index++) {
      final current = _windows[index];
      final initial = widget.initialWindows[index];
      if (current.weekday != initial.weekday ||
          current.startMinute != initial.startMinute ||
          current.endMinute != initial.endMinute) {
        return true;
      }
    }
    return false;
  }

  void _saveAndLeave() => Navigator.pop(
    context,
    AvailabilityEditResult(List.unmodifiable(_windows)),
  );

  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }
    final decision = await showUnsavedChangesGuard(context);
    if (!mounted) {
      return;
    }
    switch (decision) {
      case UnsavedChangesDecision.saveAndLeave:
        _saveAndLeave();
        return;
      case UnsavedChangesDecision.discardAndLeave:
        Navigator.pop(context);
        return;
      case UnsavedChangesDecision.keepEditing:
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Availability'),
      leading: IconButton(
        key: const Key('availability-cancel'),
        onPressed: _requestClose,
        icon: const Icon(Icons.close),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('availability-save'),
          onPressed: _saveAndLeave,
          child: const Text('Save'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        DropdownButtonFormField<int>(
          key: const Key('availability-weekday'),
          initialValue: _weekday,
          decoration: const InputDecoration(labelText: 'Day'),
          items: <DropdownMenuItem<int>>[
            for (var day = DateTime.monday; day <= DateTime.sunday; day++)
              DropdownMenuItem(value: day, child: Text(_weekdayName(day))),
          ],
          onChanged: (value) => setState(() => _weekday = value ?? _weekday),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                key: const Key('availability-start-time'),
                onTap: () => _pickTime(isStart: true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'From'),
                  child: Text(_formatMinute(_start.hour * 60 + _start.minute)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                key: const Key('availability-end-time'),
                onTap: () => _pickTime(isStart: false),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'To'),
                  child: Text(_formatMinute(_end.hour * 60 + _end.minute)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('availability-add'),
          onPressed: _addWindow,
          icon: const Icon(Icons.add),
          label: const Text('Add availability'),
        ),
        if (_windows.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          for (var i = 0; i < _windows.length; i++)
            ListTile(
              key: Key('availability-row-$i'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_weekdayName(_windows[i].weekday)}  '
                '${_formatMinute(_windows[i].startMinute)} – '
                '${_formatMinute(_windows[i].endMinute)}',
              ),
              trailing: IconButton(
                key: Key('availability-remove-$i'),
                onPressed: () => setState(() => _windows.removeAt(i)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
        ],
      ],
    ),
  );
}

String _weekdayName(int weekday) => switch (weekday) {
  DateTime.monday => 'Monday',
  DateTime.tuesday => 'Tuesday',
  DateTime.wednesday => 'Wednesday',
  DateTime.thursday => 'Thursday',
  DateTime.friday => 'Friday',
  DateTime.saturday => 'Saturday',
  DateTime.sunday => 'Sunday',
  _ => 'Day $weekday',
};

String _formatMinute(int minuteOfDay) {
  final hour24 = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

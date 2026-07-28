import 'package:flutter/material.dart';

final class CalendarEventUnavailableScreen extends StatelessWidget {
  const CalendarEventUnavailableScreen({this.eventId, super.key});

  final String? eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar Event')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.event_busy_outlined, size: 52),
                const SizedBox(height: 18),
                Text(
                  eventId == null
                      ? 'Calendar Event creation is not available in this build.'
                      : 'Calendar Event details are not available in this build.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tasks and Calendar Events remain separate. Planner can '
                  'identify their distinct presentation without inventing '
                  'event creation, recurrence, or outcomes.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return to Planner'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

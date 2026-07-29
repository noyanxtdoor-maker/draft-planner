import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';

final class PlannerSettingsScreen extends ConsumerWidget {
  const PlannerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventTypeControllerProvider);
    final controller = ref.read(eventTypeControllerProvider.notifier);
    final settings = state.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Planner and Calendar')),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: <Widget>[
                  if (state.message != null) ...<Widget>[
                    MaterialBanner(
                      content: Text(state.message!),
                      actions: <Widget>[
                        TextButton(
                          onPressed: controller.clearMessage,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Section(
                    title: 'Event defaults',
                    children: <Widget>[
                      ListTile(
                        key: const Key('event-types-settings-link'),
                        leading: const Icon(Icons.category_outlined),
                        title: const Text('Event Types'),
                        subtitle: const Text(
                          'Colors, icons, defaults, and explicit indicator '
                          'mappings',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(RoutePaths.eventTypes),
                      ),
                      DropdownButtonFormField<String?>(
                        key: const Key('default-event-type-setting'),
                        initialValue: settings.defaultEventTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Default Event Type',
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            child: Text('General / ask each time'),
                          ),
                          for (final type in state.eventTypes)
                            DropdownMenuItem<String?>(
                              value: type.id,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(
                            defaultEventTypeId: value,
                            clearDefaultEventType: value == null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: const Key('default-duration-setting'),
                        initialValue: settings.defaultDurationMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Default duration',
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 minutes'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 minutes'),
                          ),
                          DropdownMenuItem(
                            value: 45,
                            child: Text('45 minutes'),
                          ),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                          DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                          DropdownMenuItem(value: 120, child: Text('2 hours')),
                        ],
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(defaultDurationMinutes: value),
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Timeline',
                    children: <Widget>[
                      _HourSetting(
                        label: 'Visible start hour',
                        value: settings.visibleStartHour,
                        values: List<int>.generate(13, (index) => index),
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(visibleStartHour: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HourSetting(
                        label: 'Visible end hour',
                        value: settings.visibleEndHour,
                        values: List<int>.generate(12, (index) => index + 13),
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(visibleEndHour: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: const Key('time-snap-setting'),
                        initialValue: settings.snapMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Time snapping',
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem(value: 5, child: Text('5 minutes')),
                          DropdownMenuItem(
                            value: 10,
                            child: Text('10 minutes'),
                          ),
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 minutes'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 minutes'),
                          ),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                        ],
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(snapMinutes: value),
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('use-24-hour-setting'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('24-hour time'),
                        value: settings.use24HourTime,
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(use24HourTime: value),
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('current-time-line-setting'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show current-time line'),
                        value: settings.showCurrentTime,
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(showCurrentTime: value),
                        ),
                      ),
                      DropdownButtonFormField<PlannerInitialScrollBehavior>(
                        key: const Key('initial-scroll-setting'),
                        initialValue: settings.initialScrollBehavior,
                        decoration: const InputDecoration(
                          labelText: 'Open timeline at',
                        ),
                        items:
                            const <
                              DropdownMenuItem<PlannerInitialScrollBehavior>
                            >[
                              DropdownMenuItem(
                                value: PlannerInitialScrollBehavior.currentTime,
                                child: Text('Current time'),
                              ),
                              DropdownMenuItem(
                                value:
                                    PlannerInitialScrollBehavior.visibleStart,
                                child: Text('Visible start hour'),
                              ),
                              DropdownMenuItem(
                                value: PlannerInitialScrollBehavior.dayStart,
                                child: Text('Top of visible day'),
                              ),
                            ],
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(initialScrollBehavior: value),
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Display',
                    children: <Widget>[
                      SwitchListTile(
                        key: const Key('quick-edit-setting'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Quick edit on timeline'),
                        subtitle: const Text(
                          'Long-press to move; use the lower handle to resize',
                        ),
                        value: settings.quickEditEnabled,
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(quickEditEnabled: value),
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('show-completed-setting'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show completed items'),
                        value: settings.showCompletedItems,
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(showCompletedItems: value),
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('show-cancelled-setting'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show cancelled items'),
                        value: settings.showCancelledItems,
                        onChanged: (value) => controller.saveSettings(
                          settings.copyWith(showCancelledItems: value),
                        ),
                      ),
                    ],
                  ),
                  const _DeferredNotificationNotice(),
                ],
              ),
      ),
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

final class _HourSetting extends StatelessWidget {
  const _HourSetting({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<int>>[
        for (final hour in values)
          DropdownMenuItem<int>(value: hour, child: Text(_label(hour))),
      ],
      onChanged: onChanged,
    );
  }

  String _label(int hour) {
    if (hour == 24) {
      return '12:00 AM (next day)';
    }
    final display = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$display:00 ${hour >= 12 ? 'PM' : 'AM'}';
  }
}

final class _DeferredNotificationNotice extends StatelessWidget {
  const _DeferredNotificationNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.notifications_none),
        title: Text('Notification behavior'),
        subtitle: Text(
          'Notification permission, scheduling, quiet hours, and privacy '
          'behavior remain deferred to their approved device-services slice. '
          'Event creation stays local and never depends on notification access.',
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

final class EventTypesScreen extends ConsumerStatefulWidget {
  const EventTypesScreen({super.key});

  @override
  ConsumerState<EventTypesScreen> createState() => _EventTypesScreenState();
}

final class _EventTypesScreenState extends ConsumerState<EventTypesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(eventTypeControllerProvider.notifier)
            .load(includeArchived: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventTypeControllerProvider);
    final controller = ref.read(eventTypeControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Types'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restore system defaults',
            onPressed: () => _restoreDefaults(context, controller),
            icon: const Icon(Icons.restore),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('create-custom-event-type'),
        tooltip: 'Create custom Event Type',
        onPressed: () => context.push(RoutePaths.eventTypeCreate),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: <Widget>[
                  if (state.message != null)
                    MaterialBanner(
                      content: Text(state.message!),
                      actions: <Widget>[
                        TextButton(
                          onPressed: controller.clearMessage,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  for (final type in state.eventTypes)
                    Card(
                      child: ListTile(
                        key: Key('event-type-${type.stableKey}'),
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            type.colorValue,
                          ).withValues(alpha: 0.2),
                          child: Icon(
                            _icon(type.icon),
                            color: Color(type.colorValue),
                          ),
                        ),
                        title: Text(type.label),
                        subtitle: Text(_subtitle(type)),
                        trailing: type.isSystem
                            ? const Tooltip(
                                message: 'Protected system type',
                                child: Icon(Icons.lock_outline, size: 19),
                              )
                            : IconButton(
                                tooltip: type.isArchived
                                    ? 'Restore Event Type'
                                    : 'Archive Event Type',
                                onPressed: () => controller.setArchived(
                                  type,
                                  !type.isArchived,
                                ),
                                icon: Icon(
                                  type.isArchived
                                      ? Icons.unarchive_outlined
                                      : Icons.archive_outlined,
                                ),
                              ),
                        onTap: type.isSystem
                            ? null
                            : () => context.push(
                                '${RoutePaths.eventTypes}/${type.id}/edit',
                              ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _restoreDefaults(
    BuildContext context,
    EventTypeController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore system defaults?'),
        content: const Text(
          'System Event Type appearance and mappings will be restored. '
          'Existing events, reports, mappings captured on history, and ledger '
          'entries are not changed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.restoreSystemDefaults();
    }
  }

  static String _subtitle(EventType type) {
    final mapping = type.indicatorKeys.isEmpty
        ? 'No Life Indicator mapping'
        : type.indicatorKeys.join(', ');
    final kind = type.isSystem ? 'System' : 'Custom';
    final archived = type.isArchived ? ' · Archived' : '';
    return '$kind$archived · $mapping · '
        '${type.defaultDurationMinutes} min default';
  }

  static IconData _icon(EventTypeIcon icon) {
    return switch (icon) {
      EventTypeIcon.calendar => Icons.event_outlined,
      EventTypeIcon.temple => Icons.church_outlined,
      EventTypeIcon.scripture => Icons.menu_book_outlined,
      EventTypeIcon.exercise => Icons.fitness_center,
      EventTypeIcon.budget => Icons.pie_chart_outline,
      EventTypeIcon.job => Icons.work_outline,
      EventTypeIcon.connection => Icons.people_outline,
      EventTypeIcon.appointment => Icons.schedule,
      EventTypeIcon.work => Icons.business_center_outlined,
      EventTypeIcon.personal => Icons.person_outline,
    };
  }
}

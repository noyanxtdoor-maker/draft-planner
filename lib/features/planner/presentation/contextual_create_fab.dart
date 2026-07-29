import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';

enum CreateActionDestination { home, planner, pathways, contacts, more }

enum ContextualCreateAction { task, person, contact, event }

extension ContextualCreateActionLabel on ContextualCreateAction {
  String get label => switch (this) {
    ContextualCreateAction.task => 'Task',
    ContextualCreateAction.person => '+ Person',
    ContextualCreateAction.contact => 'Contact',
    ContextualCreateAction.event => 'Event',
  };

  IconData get icon => switch (this) {
    ContextualCreateAction.task => Icons.task_alt_outlined,
    ContextualCreateAction.person => Icons.person_add_alt_1_outlined,
    ContextualCreateAction.contact => Icons.connect_without_contact_outlined,
    ContextualCreateAction.event => Icons.event_outlined,
  };
}

final class ContextualCreateFab extends StatelessWidget {
  const ContextualCreateFab({
    required this.destination,
    required this.onSelected,
    this.buttonKey = const Key('contextual-create-fab'),
    super.key,
  });

  final CreateActionDestination destination;
  final ValueChanged<ContextualCreateAction> onSelected;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: buttonKey,
      tooltip: 'Create',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onPressed: () => _showMenu(context),
      child: const Icon(Icons.add, size: 30),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final order = _orderFor(destination);
    final selected = await showModalBottomSheet<ContextualCreateAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: ListView(
            key: const Key('contextual-create-menu'),
            shrinkWrap: true,
            children: <Widget>[
              Text(
                'Create',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < order.length; index++)
                ListTile(
                  key: _actionKey(order[index]),
                  leading: Icon(
                    order[index].icon,
                    color: index == 0 ? AppTheme.rose : Colors.white70,
                  ),
                  title: Text(
                    order[index].label,
                    style: TextStyle(
                      color: index == 0 ? AppTheme.rose : Colors.white,
                      fontWeight: index == 0
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  trailing: index == 0
                      ? const Text(
                          'Quick action',
                          style: TextStyle(color: AppTheme.rose, fontSize: 12),
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(order[index]),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && context.mounted) {
      onSelected(selected);
    }
  }

  static List<ContextualCreateAction> _orderFor(
    CreateActionDestination destination,
  ) {
    return switch (destination) {
      CreateActionDestination.home => const <ContextualCreateAction>[
        ContextualCreateAction.event,
        ContextualCreateAction.task,
        ContextualCreateAction.person,
        ContextualCreateAction.contact,
      ],
      CreateActionDestination.planner => const <ContextualCreateAction>[
        ContextualCreateAction.event,
        ContextualCreateAction.task,
        ContextualCreateAction.person,
        ContextualCreateAction.contact,
      ],
      CreateActionDestination.pathways => const <ContextualCreateAction>[
        ContextualCreateAction.task,
        ContextualCreateAction.event,
        ContextualCreateAction.contact,
        ContextualCreateAction.person,
      ],
      CreateActionDestination.contacts => const <ContextualCreateAction>[
        ContextualCreateAction.person,
        ContextualCreateAction.contact,
        ContextualCreateAction.task,
        ContextualCreateAction.event,
      ],
      CreateActionDestination.more => const <ContextualCreateAction>[
        ContextualCreateAction.event,
        ContextualCreateAction.task,
        ContextualCreateAction.person,
        ContextualCreateAction.contact,
      ],
    };
  }

  static Key _actionKey(ContextualCreateAction action) {
    return switch (action) {
      ContextualCreateAction.task => const Key('create-task-action'),
      ContextualCreateAction.event => const Key('create-calendar-event-action'),
      ContextualCreateAction.person => const Key('create-person-action'),
      ContextualCreateAction.contact => const Key('create-contact-action'),
    };
  }
}

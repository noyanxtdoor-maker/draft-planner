import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/recommended_event_colors.dart';

const List<String> _suggestedGroupNames = <String>[
  'Family',
  'Friends',
  'Work',
  'School',
  'Clients',
  'Team',
  'Other',
];

/// Group manager for user-owned Groups. Every saved Group can be renamed,
/// recolored, or permanently deleted. Suggested names are optional shortcuts,
/// never protected records or an automatically recreated catalog.
final class ContactGroupsScreen extends ConsumerStatefulWidget {
  const ContactGroupsScreen({super.key});

  @override
  ConsumerState<ContactGroupsScreen> createState() =>
      _ContactGroupsScreenState();
}

final class _ContactGroupsScreenState
    extends ConsumerState<ContactGroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(contactGroupsProvider);
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Manage Groups')),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Groups could not be opened.')),
        data: (groups) {
          final active = groups.where((g) => !g.isArchived).toList();
          final archived = groups.where((g) => g.isArchived).toList();
          final existingNames = groups
              .map((group) => group.name.trim().toLowerCase())
              .toSet();
          final suggestions = _suggestedGroupNames
              .where((name) => !existingNames.contains(name.toLowerCase()))
              .toList(growable: false);
          return ListView(
            key: const Key('contact-groups-list'),
            padding: InternalScreen.pagePadding,
            children: <Widget>[
              for (final group in active)
                _GroupRow(
                  group: group,
                  onEdit: () => _editGroup(group),
                  onDelete: () => _confirmHardDelete(group),
                ),
              if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No groups yet. Create one or choose a suggestion to give '
                    'your contacts a shared color.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.secondaryTextOf(context)),
                  ),
                ),
              if (suggestions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Suggested groups',
                  style: InternalScreen.sectionHeading,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (var index = 0; index < suggestions.length; index += 1)
                      ActionChip(
                        key: Key(
                          'suggested-group-${suggestions[index].toLowerCase()}',
                        ),
                        label: Text(suggestions[index]),
                        onPressed: () =>
                            _createSuggestedGroup(suggestions[index], index),
                      ),
                  ],
                ),
              ],
              if (archived.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                const Text(
                  'Previously archived',
                  style: InternalScreen.sectionHeading,
                ),
                const SizedBox(height: 4),
                for (final group in archived)
                  _GroupRow(
                    group: group,
                    onEdit: () => _editGroup(group),
                    onDelete: () => _confirmHardDelete(group),
                    isLegacyArchived: true,
                  ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create-group-fab'),
        heroTag: 'contact-groups-fab',
        onPressed: () => _editGroup(null),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }

  Future<void> _editGroup(ContactGroup? group) async {
    final result = await showModalBottomSheet<_GroupEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _GroupEditor(group: group),
    );
    if (result == null || !mounted) {
      return;
    }
    final save = result as _GroupEditorSave;
    final repository = ref.read(contactRepositoryProvider);
    final profileId = ref.read(contactProfileIdProvider);
    try {
      if (group == null) {
        await repository.createGroup(
          profileId: profileId,
          name: save.name,
          colorValue: save.color,
        );
      } else {
        await repository.updateGroup(
          profileId: profileId,
          groupId: group.id,
          name: save.name,
          colorValue: save.color,
        );
      }
    } on ContactValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createSuggestedGroup(String name, int index) async {
    final color = RecommendedEventColorPalette
        .colors[index % RecommendedEventColorPalette.colors.length]
        .argb;
    final repository = ref.read(contactRepositoryProvider);
    final profileId = ref.read(contactProfileIdProvider);
    try {
      await repository.createGroup(
        profileId: profileId,
        name: name,
        colorValue: color,
      );
    } on ContactValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _confirmHardDelete(ContactGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: Key('group-delete-dialog-${group.id}'),
        title: const Text('Delete group permanently?'),
        content: Text(
          '“${group.name}” will be removed from every Contact that uses it. '
          'Contacts stay in place, but this cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('group-delete-confirm-${group.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final repository = ref.read(contactRepositoryProvider);
    final profileId = ref.read(contactProfileIdProvider);
    try {
      await repository.hardDeleteGroup(profileId: profileId, groupId: group.id);
    } on ContactValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

sealed class _GroupEditorResult {
  const _GroupEditorResult();
}

final class _GroupEditorSave extends _GroupEditorResult {
  const _GroupEditorSave(this.name, this.color);

  final String name;
  final int color;
}

final class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    this.isLegacyArchived = false,
  });

  final ContactGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isLegacyArchived;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        key: Key('group-row-${group.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(group.colorValue),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isLegacyArchived)
                    Text(
                      'Previously archived',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryTextOf(context),
                      ),
                    ),
                ],
              ),
            ),
            Tooltip(
              message: 'Edit ${group.name}',
              child: IconButton(
                key: Key('group-edit-${group.id}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            Tooltip(
              message: 'Delete ${group.name} permanently',
              child: IconButton(
                key: Key('group-delete-${group.id}'),
                onPressed: onDelete,
                color: Theme.of(context).colorScheme.error,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _GroupEditor extends StatefulWidget {
  const _GroupEditor({this.group});

  final ContactGroup? group;

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

final class _GroupEditorState extends State<_GroupEditor> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.group?.name ?? '',
  );
  late int _color =
      widget.group?.colorValue ??
      RecommendedEventColorPalette.colors.first.argb;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.group == null ? 'New Group' : 'Edit Group',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('group-name-field'),
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: AppTheme.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Color', style: InternalScreen.fieldLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final color in RecommendedEventColorPalette.colors)
                  InkWell(
                    key: Key('group-color-${color.argb.toRadixString(16)}'),
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = color.argb),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(color.argb),
                        border: color.argb == _color
                            ? Border.all(
                                color: AppTheme.onFillTextOf(context, 1.0),
                                width: 2.5,
                              )
                            : Border.all(
                                color: AppTheme.outlineOf(context),
                                width: 1,
                              ),
                      ),
                      child: color.argb == _color
                          ? const Icon(
                              Icons.check,
                              size: 20,
                              color: Color(0xFF101113),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('group-save'),
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group name cannot be blank.'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(_GroupEditorSave(name, _color));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/recommended_event_colors.dart';

/// Group manager: create, rename, recolor, and archive Groups.  Colors come
/// from the shared Next Transfer Recommended palette so Contact identity
/// belongs to the same faded tonal family as the Planner.
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
      appBar: InternalAppBar(title: const Text('Groups')),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Groups could not be opened.')),
        data: (groups) {
          final active = groups.where((g) => !g.isArchived).toList();
          final archived = groups.where((g) => g.isArchived).toList();
          return ListView(
            key: const Key('contact-groups-list'),
            padding: InternalScreen.pagePadding,
            children: <Widget>[
              for (final group in active)
                _GroupRow(group: group, onTap: () => _editGroup(group)),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No groups yet. Create one to give your contacts a shared color.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9CA0A6)),
                  ),
                ),
              if (archived.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                const Text('Archived', style: InternalScreen.sectionHeading),
                const SizedBox(height: 4),
                for (final group in archived)
                  _GroupRow(group: group, onTap: () => _editGroup(group)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create-group-fab'),
        heroTag: 'contact-groups-fab',
        onPressed: () => _editGroup(null),
        backgroundColor: AppTheme.rose,
        foregroundColor: AppTheme.background,
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
    if (result is _GroupEditorArchive) {
      if (group != null) {
        await _archive(group);
      }
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

  Future<void> _archive(ContactGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive group?'),
        content: Text(
          '${group.name} stays on existing Contacts, but is hidden from '
          'new assignments and is no longer anyone\'s primary group.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final repository = ref.read(contactRepositoryProvider);
    final profileId = ref.read(contactProfileIdProvider);
    await repository.archiveGroup(profileId: profileId, groupId: group.id);
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

final class _GroupEditorArchive extends _GroupEditorResult {
  const _GroupEditorArchive();
}

final class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.onTap});

  final ContactGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('group-row-${group.id}'),
        onTap: onTap,
        child: Padding(
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
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA0A6)),
            ],
          ),
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
                fillColor: const Color(0xFF181A1E),
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
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(
                                color: const Color(0xFF454850),
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
            if (widget.group != null) ...<Widget>[
              const SizedBox(height: 4),
              TextButton(
                key: const Key('group-archive'),
                onPressed: () =>
                    Navigator.of(context).pop(const _GroupEditorArchive()),
                child: const Text(
                  'Archive group',
                  style: TextStyle(color: AppTheme.rose),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

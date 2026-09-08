import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';

final class AddPeopleArgs {
  const AddPeopleArgs({
    this.initialIds = const <String>[],
    this.allowCreate = true,
    this.displayLabel = 'People',
  });

  final List<String> initialIds;
  final bool allowCreate;
  final String displayLabel;
}

/// Add People selector for Event/Task forms.
///
/// Search + grouped list + an always-available "+ New Contact" inline create
/// path.  Toggling selection edits only this screen's local draft; the caller
/// receives the final list via `Navigator.pop(result)`, so the parent Event
/// draft stays fully intact across the round trip.
final class AddPeopleScreen extends ConsumerStatefulWidget {
  const AddPeopleScreen({required this.args, super.key});

  final AddPeopleArgs args;

  @override
  ConsumerState<AddPeopleScreen> createState() => _AddPeopleScreenState();
}

final class _AddPeopleScreenState extends ConsumerState<AddPeopleScreen> {
  final _searchController = TextEditingController();
  late final Set<String> _selected = <String>{...widget.args.initialIds};
  bool _showSelected = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsControllerProvider);
    final groups =
        ref.watch(contactGroupsProvider).value ?? const <ContactGroup>[];
    return Scaffold(
      appBar: InternalAppBar(
        title: Text('Add ${widget.args.displayLabel}'),
        actions: <Widget>[
          FilledButton(
            key: const Key('add-people-done'),
            onPressed: () => Navigator.of(context).pop(_selected.toList()),
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(_selected.isEmpty ? 'Done' : 'Add ${_selected.length}'),
          ),
        ],
      ),
      body: _build(state, groups),
    );
  }

  Widget _build(ContactsState state, List<ContactGroup> groups) {
    final all = state.contacts;
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? all
        : all
              .where(
                (summary) =>
                    summary.contact.displayName.toLowerCase().contains(query) ||
                    summary.contact.firstName?.toLowerCase().contains(query) ==
                        true ||
                    summary.contact.lastName?.toLowerCase().contains(query) ==
                        true,
              )
              .toList();
    final selectedRows = all
        .where((summary) => _selected.contains(summary.contact.id))
        .toList();
    final others = visible
        .where((summary) => !_selected.contains(summary.contact.id))
        .toList();
    final grouped = <String?, List<ContactSummary>>{};
    for (final summary in others) {
      grouped
          .putIfAbsent(summary.primaryGroup?.id, () => <ContactSummary>[])
          .add(summary);
    }
    final groupOrder = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) {
          return 1;
        }
        if (b == null) {
          return -1;
        }
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('add-people-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search contacts',
              prefixIcon: const Icon(Icons.search, size: 22),
              filled: true,
              fillColor: AppTheme.surfaceOf(context),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide(
                  color: AppTheme.surfaceVariantOf(context),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide(
                  color: AppTheme.surfaceVariantOf(context),
                ),
              ),
            ),
          ),
        ),
        if (widget.args.allowCreate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: TextButton.icon(
              key: const Key('add-people-new-contact'),
              onPressed: _createContactInline,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle: AppTypography.button,
              ),
              icon: const Icon(Icons.person_add_alt, size: 22),
              label: const Text('New Contact'),
            ),
          ),
        Expanded(
          child: ListView(
            key: const Key('add-people-list'),
            padding: const EdgeInsets.only(bottom: 32),
            children: <Widget>[
              if (selectedRows.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'People Added (${selectedRows.length})',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _showSelected ? 'Hide' : 'Show',
                        onPressed: () =>
                            setState(() => _showSelected = !_showSelected),
                        icon: Icon(
                          _showSelected ? Icons.expand_less : Icons.expand_more,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showSelected)
                  for (final summary in selectedRows)
                    ContactListRow(
                      summary: summary,
                      leading: Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      trailing: IconButton(
                        key: Key('remove-selected-${summary.contact.id}'),
                        tooltip: 'Remove',
                        onPressed: () => setState(
                          () => _selected.remove(summary.contact.id),
                        ),
                        icon: const Icon(Icons.close, size: 22),
                      ),
                    ),
                const Divider(height: 24, thickness: 1),
              ],
              for (final groupId in groupOrder) ...<Widget>[
                if (groupId == null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Other',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                groups
                                        .where((g) => g.id == groupId)
                                        .firstOrNull
                                        ?.colorValue !=
                                    null
                                ? Color(
                                    groups
                                        .where((g) => g.id == groupId)
                                        .first
                                        .colorValue,
                                  )
                                : AppTheme.secondaryTextOf(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          groups
                                  .where((g) => g.id == groupId)
                                  .firstOrNull
                                  ?.name ??
                              'Group',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final summary in grouped[groupId]!)
                  ContactListRow(
                    summary: summary,
                    onTap: () =>
                        setState(() => _selected.add(summary.contact.id)),
                    trailing: IconButton(
                      key: Key('add-people-${summary.contact.id}'),
                      tooltip: 'Add',
                      onPressed: () =>
                          setState(() => _selected.add(summary.contact.id)),
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
              ],
              if (others.isEmpty && selectedRows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No more contacts to add.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.secondaryTextOf(context)),
                  ),
                ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No contacts yet. Add one to start planning with people.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.secondaryTextOf(context)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createContactInline() async {
    final created = await context.push<Contact>(RoutePaths.contactCreate);
    if (created != null && mounted) {
      setState(() => _selected.add(created.id));
    }
  }
}

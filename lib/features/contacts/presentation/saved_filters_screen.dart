import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/filter_builder_screen.dart';

final class SavedFilterSelection {
  const SavedFilterSelection({
    required this.criteria,
    required this.appliedFilter,
  });

  final ContactFilterCriteria criteria;
  final SavedContactFilter appliedFilter;
}

/// Saved Filters manager.  System filters are protected; user filters can be
/// renamed/reconfigured or deleted with confirmation.  Tapping a filter
/// applies it and returns to the Contacts list.
final class SavedFiltersScreen extends ConsumerStatefulWidget {
  const SavedFiltersScreen({super.key, this.asOverlay = false});

  final bool asOverlay;

  @override
  ConsumerState<SavedFiltersScreen> createState() => _SavedFiltersScreenState();
}

final class _SavedFiltersScreenState extends ConsumerState<SavedFiltersScreen> {
  bool _editMode = false;

  static SavedContactFilter _system(
    String id,
    String name,
    ContactFilterCriteria criteria,
  ) {
    return SavedContactFilter(
      id: 'system:$id',
      profileId: '',
      name: name,
      isSystem: true,
      criteria: criteria,
      sortBy: ContactSortBy.name,
      createdAtUtc: DateTime(2020),
      updatedAtUtc: DateTime(2020),
    );
  }

  List<SavedContactFilter> _systemFilters() {
    return <SavedContactFilter>[
      _system('all', 'All Contacts', const ContactFilterCriteria()),
      _system(
        'favorites',
        'Favorites',
        const ContactFilterCriteria(favoritesOnly: true),
      ),
      _system(
        'today',
        'Has Events Today',
        const ContactFilterCriteria(withEventsToday: true),
      ),
      _system(
        'archived',
        'Archived',
        const ContactFilterCriteria(archivedOnly: true),
      ),
      // C3 truthful semantics: a future Event is NOT "Needs Follow-Up". The
      // false label is replaced with the actual criterion it represents.
      _system(
        'future',
        'Has Future Events',
        const ContactFilterCriteria(withFutureEvents: true),
      ),
      _system(
        'no-future',
        'No Future Events',
        const ContactFilterCriteria(withoutFutureEvents: true),
      ),
      _system(
        'has-phone',
        'Has Phone',
        const ContactFilterCriteria(hasPhone: true),
      ),
      _system(
        'has-email',
        'Has Email',
        const ContactFilterCriteria(hasEmail: true),
      ),
      _system(
        'has-address',
        'Has Address',
        const ContactFilterCriteria(hasAddress: true),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final userFilters =
        ref.watch(savedContactFiltersProvider).value ??
        const <SavedContactFilter>[];
    final appliedId = ref.watch(contactsControllerProvider).appliedFilter?.id;
    return Scaffold(
      backgroundColor: widget.asOverlay ? AppTheme.surfaceOf(context) : null,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.asOverlay,
        title: const Text('Saved Filters'),
        actions: <Widget>[
          TextButton(
            key: const Key('edit-saved-filters'),
            onPressed: () => setState(() => _editMode = !_editMode),
            child: Text(_editMode ? 'Done' : 'Edit'),
          ),
          if (widget.asOverlay)
            IconButton(
              key: const Key('saved-filters-close'),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('saved-filters-list'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Standard Views',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              for (final filter in _systemFilters())
                _FilterRow(
                  key: Key('standard-filter-${filter.id}'),
                  filter: filter,
                  selected: appliedId == filter.id,
                  onTap: () => _apply(filter),
                ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Saved Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (userFilters.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'Save a filter here for one-tap access to a view you use often.',
                    style: TextStyle(color: AppTheme.secondaryTextOf(context)),
                  ),
                ),
              for (final filter in userFilters)
                _FilterRow(
                  key: Key('saved-filter-${filter.id}'),
                  filter: filter,
                  selected: appliedId == filter.id,
                  onTap: _editMode
                      ? () => _editUserFilter(filter)
                      : () => _apply(filter),
                  onEdit: _editMode ? () => _editUserFilter(filter) : null,
                  onDelete: _editMode ? () => _deleteUserFilter(filter) : null,
                ),
              const SizedBox(height: 4),
              TextButton.icon(
                key: const Key('new-filter-button'),
                onPressed: _createFilter,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                icon: const Icon(Icons.add, size: 22),
                label: const Text('New Filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _apply(SavedContactFilter filter) {
    Navigator.of(context).pop(
      SavedFilterSelection(criteria: filter.criteria, appliedFilter: filter),
    );
  }

  Future<void> _createFilter() async {
    final result = await context.push<FilterBuilderResult>(
      RoutePaths.filterBuilder,
      extra: const FilterBuilderArgs(),
    );
    if (result != null && mounted) {
      await _applyResult(result);
    }
  }

  Future<void> _editUserFilter(SavedContactFilter filter) async {
    final result = await context.push<FilterBuilderResult>(
      RoutePaths.filterBuilder,
      extra: FilterBuilderArgs(
        initialCriteria: filter.criteria,
        initialName: filter.name,
        initialDescription: filter.description,
        initialDisplayedFields: filter.displayedFields,
        initialSortBy: filter.sortBy,
        saveAsFilter: true,
        editingFilterId: filter.id,
      ),
    );
    if (result != null && mounted && result.savedFilterName != null) {
      await _applyResult(result);
    }
  }

  Future<void> _applyResult(FilterBuilderResult result) async {
    final controller = ref.read(contactsControllerProvider.notifier);
    if (result.savedFilter != null) {
      controller.applyFilter(
        result.criteria,
        appliedFilter: result.savedFilter,
      );
    } else {
      controller.applyFilter(result.criteria, updateCurrentView: false);
    }
    ref.invalidate(savedContactFiltersProvider);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteUserFilter(SavedContactFilter filter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('${filter.name} will be removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-filter'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final profileId = ref.read(contactProfileIdProvider);
    try {
      await ref
          .read(contactRepositoryProvider)
          .deleteSavedFilter(profileId: profileId, filterId: filter.id);
      if (ref.read(contactsControllerProvider).appliedFilter?.id == filter.id) {
        ref
            .read(contactsControllerProvider.notifier)
            .applyFilter(
              const ContactFilterCriteria(),
              clearAppliedFilter: true,
            );
      }
      ref.invalidate(savedContactFiltersProvider);
    } on ContactValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

final class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final SavedContactFilter filter;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(
                filter.criteria.isEmpty
                    ? Icons.people_outline
                    : filter.criteria.favoritesOnly
                    ? Icons.star_outline
                    : Icons.filter_alt_outlined,
                size: 22,
                color: AppTheme.secondaryTextOf(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      filter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (filter.description.trim().isNotEmpty)
                      Text(
                        filter.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryTextOf(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  key: Key('edit-filter-${filter.id}'),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 21),
                ),
              if (selected)
                Icon(
                  Icons.check,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (onDelete != null) ...<Widget>[
                const SizedBox(width: 4),
                IconButton(
                  key: Key('delete-filter-${filter.id}'),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 22),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

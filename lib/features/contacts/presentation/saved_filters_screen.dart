import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/filter_builder_screen.dart';

final class SavedFilterSelection {
  const SavedFilterSelection({
    required this.criteria,
    this.appliedFilter,
    this.standardView,
  });

  final ContactFilterCriteria criteria;
  final SavedContactFilter? appliedFilter;
  final ContactStandardView? standardView;
}

/// Compatibility route for the existing direct `/contacts/filters` path.
/// The normal Contacts workflow uses [ContactViewSelectorPanel] inline below
/// the app bar; it never opens this route or a modal overlay.
final class SavedFiltersScreen extends StatelessWidget {
  const SavedFiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Filters')),
      body: ContactViewSelectorPanel(
        onSelected: (selection) => Navigator.of(context).pop(selection),
      ),
    );
  }
}

final class ContactViewSelectorPanel extends ConsumerStatefulWidget {
  const ContactViewSelectorPanel({required this.onSelected, super.key});

  final ValueChanged<SavedFilterSelection> onSelected;

  @override
  ConsumerState<ContactViewSelectorPanel> createState() =>
      _ContactViewSelectorPanelState();
}

final class _ContactViewSelectorPanelState
    extends ConsumerState<ContactViewSelectorPanel> {
  @override
  Widget build(BuildContext context) {
    final userFilters =
        ref.watch(savedContactFiltersProvider).value ??
        const <SavedContactFilter>[];
    return ListView(
      key: const Key('contact-view-selector-panel'),
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        const _SelectorSectionTitle('Contact Filters'),
        if (userFilters.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Save a filter for one-tap access to a view you use often.',
              style: TextStyle(color: AppTheme.secondaryTextOf(context)),
            ),
          ),
        for (final filter in userFilters)
          _AreaFilterRow(
            key: Key('area-filter-${filter.id}'),
            filter: filter,
            onApply: () => _apply(filter),
            onEdit: () => _editUserFilter(filter),
            onDelete: () => _deleteUserFilter(filter),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('area-filter-create'),
              onPressed: _createFilter,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              icon: const Icon(Icons.add, size: 24),
              label: const Text(
                'Contact Filter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        const _SelectorSectionTitle('Standard Filters'),
        _StandardFilterRow(
          key: const Key('standard-filter-status'),
          label: 'Status',
          icon: _StandardFilterIconKind.status,
          onTap: () => _applyStandard(
            const ContactStandardView(filter: ContactStandardFilter.status),
          ),
        ),
        for (final filter in const <ContactStandardFilter>[
          ContactStandardFilter.recentlyViewed,
          ContactStandardFilter.recentlyContacted,
          ContactStandardFilter.noRecentContact,
          ContactStandardFilter.recentlyCreated,
        ])
          _StandardFilterRow(
            key: Key('standard-filter-${filter.name}'),
            label: ContactStandardView(filter: filter).label,
            icon: _StandardFilterIconKind.forFilter(filter),
            onTap: () => _applyStandard(ContactStandardView(filter: filter)),
          ),
      ],
    );
  }

  void _apply(SavedContactFilter filter) {
    widget.onSelected(
      SavedFilterSelection(criteria: filter.criteria, appliedFilter: filter),
    );
  }

  void _applyStandard(ContactStandardView view) {
    widget.onSelected(
      SavedFilterSelection(
        criteria: const ContactFilterCriteria(),
        standardView: view,
      ),
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
    if (result.savedFilter == null) {
      return;
    }
    ref.invalidate(savedContactFiltersProvider);
    widget.onSelected(
      SavedFilterSelection(
        criteria: result.criteria,
        appliedFilter: result.savedFilter,
      ),
    );
  }

  Future<void> _deleteUserFilter(SavedContactFilter filter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Contact Filter?'),
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

final class _SelectorSectionTitle extends StatelessWidget {
  const _SelectorSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              height: 22 / 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppTheme.sectionDividerOf(context)),
        ],
      ),
    );
  }
}

final class _AreaFilterRow extends StatelessWidget {
  const _AreaFilterRow({
    required this.filter,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final SavedContactFilter filter;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onApply,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  filter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 21 / 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              IconButton(
                key: Key('edit-filter-${filter.id}'),
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                key: Key('delete-filter-${filter.id}'),
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _StandardFilterRow extends StatelessWidget {
  const _StandardFilterRow({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final _StandardFilterIconKind icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: <Widget>[
              _StandardFilterIcon(kind: icon),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  height: 21 / 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StandardFilterIconKind {
  status(
    'assets/icons/contacts/standard_filters/status-list-circle-outline.svg',
  ),
  recentlyViewed(
    'assets/icons/contacts/standard_filters/recently-viewed-eye-outline.svg',
  ),
  recentlyContacted(
    'assets/icons/contacts/standard_filters/recently-contacted-link-outline.svg',
  ),
  noRecentContact(
    'assets/icons/contacts/standard_filters/no-recent-contact-unlink-outline.svg',
  ),
  recentlyCreated(
    'assets/icons/contacts/standard_filters/recently-created-person-add-outline.svg',
  );

  const _StandardFilterIconKind(this.assetPath);

  final String assetPath;

  factory _StandardFilterIconKind.forFilter(ContactStandardFilter filter) {
    return switch (filter) {
      ContactStandardFilter.recentlyViewed => recentlyViewed,
      ContactStandardFilter.recentlyContacted => recentlyContacted,
      ContactStandardFilter.noRecentContact => noRecentContact,
      ContactStandardFilter.recentlyCreated => recentlyCreated,
      ContactStandardFilter.status => status,
    };
  }
}

final class _StandardFilterIcon extends StatelessWidget {
  const _StandardFilterIcon({required this.kind});

  final _StandardFilterIconKind kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('standard-filter-icon-${kind.name}'),
      width: 24,
      height: 24,
      child: SvgPicture.asset(
        kind.assetPath,
        key: Key('standard-filter-svg-${kind.name}'),
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

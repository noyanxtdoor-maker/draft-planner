import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/shell/global_drawer_controller.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';
import 'package:rmplanner/features/contacts/presentation/contact_filter_controls.dart';
import 'package:rmplanner/features/contacts/presentation/filter_builder_screen.dart';
import 'package:rmplanner/features/contacts/presentation/saved_filters_screen.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';

/// Root Contacts tab.  Shows the current saved view/filter, active filter
/// chips, and a sectioned list (Favorites first, then primary-group
/// sections).  Root-level list density stays calm: 72 dp rows, 16 dp margins.
final class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

final class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  bool _selectorExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsControllerProvider);
    final groups =
        ref.watch(contactGroupsProvider).value ?? const <ContactGroup>[];
    final tags = ref.watch(contactTagsProvider).value ?? const <ContactTag>[];
    final topBarForeground = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.surfaceOf(context),
        foregroundColor: topBarForeground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 64,
        leading: IconButton(
          key: const Key('contacts-menu-button'),
          tooltip: 'Open navigation',
          onPressed: () => GlobalDrawerScope.of(context).open(),
          icon: const Icon(Icons.menu, size: 24),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Contacts',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            _CurrentFilterRow(
              appliedFilter: state.appliedFilter,
              standardView: state.standardView,
              isFiltered: !state.criteria.isEmpty,
              expanded: _selectorExpanded,
              onTap: () =>
                  setState(() => _selectorExpanded = !_selectorExpanded),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('contacts-filter-button'),
            tooltip: 'Filter',
            iconSize: 28,
            onPressed: () => unawaited(_openFilterBuilder()),
            icon: FilterPlusIcon(color: topBarForeground),
          ),
          IconButton(
            key: const Key('contacts-search-button'),
            tooltip: 'Search',
            iconSize: 24,
            onPressed: () => context.push(RoutePaths.contactSearch),
            icon: Icon(Icons.search, color: topBarForeground),
          ),
          PopupMenuButton<String>(
            key: const Key('contacts-overflow-menu'),
            tooltip: 'More options',
            iconSize: 24,
            icon: Icon(Icons.more_vert, color: topBarForeground),
            onSelected: (value) => _handleOverflow(value),
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'import',
                child: Text('Import from device'),
              ),
              PopupMenuItem<String>(
                value: 'groups',
                child: Text('Manage groups'),
              ),
              PopupMenuItem<String>(
                value: 'merge',
                child: Text('Find duplicates'),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(value: 'sort', child: Text('Sort')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: switch (state.status) {
        ContactsLoadStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        ContactsLoadStatus.failure => _FailureState(
          message: state.message,
          onRetry: () =>
              ref.read(contactsControllerProvider.notifier).refresh(),
        ),
        ContactsLoadStatus.ready =>
          _selectorExpanded
              ? ContactViewSelectorPanel(
                  onSelected: (selection) {
                    final controller = ref.read(
                      contactsControllerProvider.notifier,
                    );
                    if (selection.standardView != null) {
                      controller.applyStandardView(selection.standardView!);
                    } else {
                      controller.applyFilter(
                        selection.criteria,
                        appliedFilter: selection.appliedFilter,
                      );
                    }
                    if (mounted) {
                      setState(() => _selectorExpanded = false);
                    }
                  },
                )
              : _buildBody(state, groups, tags),
      },
      floatingActionButton: FloatingActionButton(
        key: const Key('add-contact-fab'),
        heroTag: 'contacts-fab',
        tooltip: 'Add Contact',
        onPressed: () => context.push(RoutePaths.contactCreate),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.person_add_alt, size: 28),
      ),
    );
  }

  void _handleOverflow(String value) {
    switch (value) {
      case 'import':
        unawaited(context.push(RoutePaths.deviceImport));
      case 'groups':
        unawaited(context.push(RoutePaths.contactGroups));
      case 'merge':
        unawaited(context.push(RoutePaths.mergeContacts));
      case 'sort':
        _showSortSheet();
    }
  }

  /// C3: the filter/funnel action opens the canonical filter builder directly
  /// and applies its criteria to the current view (same engine as saved
  /// filters; never a second filter model).
  Future<void> _openFilterBuilder() async {
    final state = ref.read(contactsControllerProvider);
    final result = await context.push<FilterBuilderResult>(
      RoutePaths.filterBuilder,
      extra: FilterBuilderArgs(
        initialCriteria: state.criteria,
        initialSortBy: state.sortBy,
      ),
    );
    if (result != null && mounted) {
      final controller = ref.read(contactsControllerProvider.notifier);
      if (result.savedFilter != null) {
        controller.applyFilter(
          result.criteria,
          appliedFilter: result.savedFilter,
        );
      } else {
        controller.applyFilter(result.criteria, updateCurrentView: false);
      }
    }
  }

  void _showSortSheet() {
    final controller = ref.read(contactsControllerProvider.notifier);
    final current = ref.read(contactsControllerProvider).sortBy;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sort',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
              for (final value in ContactSortBy.values)
                ListTile(
                  key: Key('sort-option-${value.name}'),
                  leading: Icon(switch (value) {
                    ContactSortBy.name ||
                    ContactSortBy.nameDesc => Icons.sort_by_alpha,
                    _ => Icons.schedule,
                  }),
                  title: Text(_sortOptionLabel(value)),
                  trailing: current == value
                      ? Icon(
                          Icons.check,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.setSort(value);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _sortOptionLabel(ContactSortBy value) {
    return switch (value) {
      ContactSortBy.name => 'Name (A–Z)',
      ContactSortBy.nameDesc => 'Name (Z–A)',
      ContactSortBy.recentlyAdded => 'Recently added',
      ContactSortBy.oldestAdded => 'Oldest added',
      ContactSortBy.status => 'Status',
      ContactSortBy.lastViewed => 'Last Viewed',
      ContactSortBy.nextEvent => 'Next Event',
      ContactSortBy.lastEvent => 'Last Event',
      ContactSortBy.lastHappenedEvent => 'Last Happened Event',
      ContactSortBy.leastRecentEvent => 'Least Recent Event',
      ContactSortBy.leastRecentHappenedEvent => 'Least Recent Happened Event',
    };
  }

  Widget _buildBody(
    ContactsState state,
    List<ContactGroup> groups,
    List<ContactTag> tags,
  ) {
    final contacts = state.contacts;
    final sections = contacts.isEmpty
        ? const <Widget>[]
        : _sectionsFor(
            contacts,
            criteria: state.criteria,
            sortBy: state.sortBy,
            standardView: state.standardView,
            displayedFields:
                state.displayedFieldsOverride ??
                state.appliedFilter?.displayedFields ??
                ContactDisplayedFieldCodec.defaults,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.appliedFilter != null &&
            state.appliedFilter!.description.trim().isNotEmpty)
          _SavedFilterBanner(filter: state.appliedFilter!),
        _QuickFilterStrip(
          criteria: state.criteria,
          groups: groups,
          tags: tags,
          displayedFields:
              state.displayedFieldsOverride ??
              state.appliedFilter?.displayedFields ??
              ContactDisplayedFieldCodec.defaults,
          displayedFieldsOverridden: state.displayedFieldsOverride != null,
          onChanged: (criteria) => ref
              .read(contactsControllerProvider.notifier)
              .applyQuickFilter(criteria),
          onDisplayedFieldsChanged: (fields) => ref
              .read(contactsControllerProvider.notifier)
              .setDisplayedFieldsOverride(fields),
          onReset: () =>
              ref.read(contactsControllerProvider.notifier).clearAdHocFilters(),
        ),
        _ActiveFilterChips(
          criteria: state.criteria,
          groups: groups,
          tags: tags,
          onRemove: (category) {
            final current = ref.read(contactsControllerProvider).criteria;
            ref
                .read(contactsControllerProvider.notifier)
                .applyQuickFilter(
                  clearContactFilterCategory(current, category),
                );
          },
          onClearAll: () =>
              ref.read(contactsControllerProvider.notifier).clearAdHocFilters(),
        ),
        Expanded(
          child: contacts.isEmpty
              ? _EmptyState(anyFilter: !state.criteria.isEmpty)
              : ListView.builder(
                  key: const Key('contacts-list'),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: sections.length,
                  itemBuilder: (context, index) => sections[index],
                ),
        ),
      ],
    );
  }

  List<Widget> _sectionsFor(
    List<ContactSummary> contacts, {
    required ContactFilterCriteria criteria,
    required ContactSortBy sortBy,
    required ContactStandardView? standardView,
    required List<ContactDisplayedField> displayedFields,
  }) {
    final widgets = <Widget>[];
    if (standardView?.filter == ContactStandardFilter.status &&
        standardView?.statusBucket == null) {
      assert(
        contacts.every((summary) => summary.statusBucket != null),
        'Aggregate Status summaries must carry canonical repository buckets.',
      );
      final smartOrder = ContactSmartStatus.values;
      for (final smart in smartOrder) {
        final members = contacts
            .where((summary) => summary.smartStatus == smart)
            .toList(growable: false);
        if (members.isEmpty) continue;
        widgets.add(
          _SectionHeader(
            title: contactSmartStatusLabel(smart),
            showMajorDivider: widgets.isNotEmpty,
            key: Key('contacts-status-section-${smart.name}'),
          ),
        );
        for (final summary in members) {
          widgets.add(
            _row(summary, displayedFields: displayedFields, statusMode: true),
          );
        }
      }
      for (final bucket in ContactStatusBucket.values) {
        final members = contacts
            .where(
              (summary) =>
                  summary.smartStatus == null && summary.statusBucket == bucket,
            )
            .toList(growable: false);
        if (members.isEmpty) {
          continue;
        }
        widgets.add(
          _SectionHeader(
            title: contactStatusBucketLabel(bucket),
            showMajorDivider: widgets.isNotEmpty,
            key: Key('contacts-status-section-${bucket.name}'),
          ),
        );
        for (final summary in members) {
          widgets.add(
            _row(summary, displayedFields: displayedFields, statusMode: true),
          );
        }
      }
      return widgets;
    }
    if (criteria.isEmpty && sortBy == ContactSortBy.name) {
      final favorites = contacts
          .where((summary) => summary.contact.isFavorite)
          .toList();
      final others = contacts
          .where((summary) => !summary.contact.isFavorite)
          .toList();
      if (favorites.isNotEmpty) {
        widgets.add(
          _SectionHeader(
            title: 'Favorites',
            showMajorDivider: widgets.isNotEmpty,
            key: const Key('contacts-favorites-section'),
          ),
        );
        for (final summary in favorites) {
          widgets.add(_row(summary, displayedFields: displayedFields));
        }
      }
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
      for (final groupId in groupOrder) {
        final members = grouped[groupId]!;
        final primaryGroup = members.first.primaryGroup;
        if (groupId == null) {
          widgets.add(
            _SectionHeader(
              title: 'Other',
              showMajorDivider: widgets.isNotEmpty,
              key: Key('contacts-other-section'),
            ),
          );
        } else if (primaryGroup != null) {
          widgets.add(
            _SectionHeader(
              title: primaryGroup.name,
              showMajorDivider: widgets.isNotEmpty,
              key: Key('contacts-section-${primaryGroup.id}'),
            ),
          );
        }
        for (final summary in members) {
          widgets.add(_row(summary, displayedFields: displayedFields));
        }
      }
      return widgets;
    }
    for (final summary in contacts) {
      widgets.add(_row(summary, displayedFields: displayedFields));
    }
    return widgets;
  }

  Widget _row(
    ContactSummary summary, {
    required List<ContactDisplayedField> displayedFields,
    bool statusMode = false,
  }) {
    return ContactListRow(
      summary: summary,
      displayedFields: statusMode
          ? const <ContactDisplayedField>[]
          : displayedFields,
      statusContextLine: statusMode ? _statusContextLine(summary) : null,
      onTap: () => context.push(RoutePaths.contactDetail(summary.contact.id)),
    );
  }

  String _statusContextLine(ContactSummary summary) {
    final date = summary.latestQualifyingInteractionDate;
    if (date == null) return 'No recorded interaction yet';
    final days = DateTime.now().toLocal().difference(date).inDays;
    final label = days <= 0
        ? 'today'
        : days == 1
        ? '1 day ago'
        : '$days days ago';
    return 'Last interaction: $label';
  }
}

final class _CurrentFilterRow extends StatelessWidget {
  const _CurrentFilterRow({
    required this.onTap,
    required this.isFiltered,
    required this.expanded,
    this.standardView,
    this.appliedFilter,
  });

  final VoidCallback onTap;
  final bool isFiltered;
  final bool expanded;
  final ContactStandardView? standardView;
  final SavedContactFilter? appliedFilter;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('current-filter-row'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(top: 1, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    isFiltered
                        ? 'Filtered'
                        : standardView?.label ??
                              appliedFilter?.name ??
                              'All Contacts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.secondaryTextOf(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppTheme.secondaryTextOf(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.showMajorDivider = true,
    super.key,
  });

  final String title;
  final bool showMajorDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showMajorDivider) const FullWidthSectionDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 7),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17,
              height: 22 / 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: AppTheme.sectionDividerOf(context)),
        ),
      ],
    );
  }
}

final class _SavedFilterBanner extends StatelessWidget {
  const _SavedFilterBanner({required this.filter});

  final SavedContactFilter filter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.filter_alt_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                filter.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.criteria,
    required this.groups,
    required this.tags,
    required this.onRemove,
    required this.onClearAll,
  });

  final ContactFilterCriteria criteria;
  final List<ContactGroup> groups;
  final List<ContactTag> tags;
  final ValueChanged<ContactFilterCategory> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) {
      return const SizedBox.shrink();
    }
    final categories = ContactFilterCategory.values
        .where((category) => contactFilterCategoryIsActive(criteria, category))
        .toList(growable: false);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        key: const Key('active-filter-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return TextButton(
              key: const Key('active-filter-clear-all'),
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear All'),
            );
          }
          final category = categories[index - 1];
          return InputChip(
            key: Key('active-filter-chip-${category.name}'),
            label: Text(
              '${contactFilterCategoryLabel(category)}: '
              '${contactFilterCategorySummary(criteria, category, groups: groups, tags: tags)}',
              style: const TextStyle(fontSize: 13),
            ),
            visualDensity: VisualDensity.compact,
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => onRemove(category),
            side: BorderSide(color: AppTheme.surfaceVariantOf(context)),
            backgroundColor: AppTheme.surfaceOf(context),
            labelStyle: TextStyle(color: AppTheme.onFillTextOf(context, 1.0)),
            deleteIconColor: AppTheme.secondaryTextOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}

final class _QuickFilterStrip extends StatelessWidget {
  const _QuickFilterStrip({
    required this.criteria,
    required this.groups,
    required this.tags,
    required this.onChanged,
    required this.displayedFields,
    required this.displayedFieldsOverridden,
    required this.onDisplayedFieldsChanged,
    required this.onReset,
  });

  final ContactFilterCriteria criteria;
  final List<ContactGroup> groups;
  final List<ContactTag> tags;
  final ValueChanged<ContactFilterCriteria> onChanged;
  final List<ContactDisplayedField> displayedFields;
  final bool displayedFieldsOverridden;
  final ValueChanged<List<ContactDisplayedField>> onDisplayedFieldsChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        key: const Key('contacts-quick-filter-strip'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: quickFilterCategories.length + 2,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          if (index == 0) {
            return QuickFilterResetButton(
              active: !criteria.isEmpty || displayedFieldsOverridden,
              onPressed: onReset,
            );
          }
          if (index == 1) {
            return QuickFilterChip(
              key: const Key('contacts-quick-filter-displayedFields'),
              label: 'Displayed Fields',
              summary:
                  displayedFields.length ==
                      ContactDisplayedFieldCodec.defaults.length
                  ? 'All'
                  : '${displayedFields.length} selected',
              active: displayedFieldsOverridden,
              onPressed: () => _openDisplayedFields(context),
            );
          }
          final category = quickFilterCategories[index - 2];
          final active = contactFilterCategoryIsActive(criteria, category);
          final label = contactFilterCategoryLabel(category);
          final summary = contactFilterCategorySummary(
            criteria,
            category,
            groups: groups,
            tags: tags,
          );
          return QuickFilterChip(
            key: Key('contacts-quick-filter-${category.name}'),
            label: label,
            summary: summary,
            active: active,
            onPressed: () => _open(context, category),
          );
        },
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    ContactFilterCategory category,
  ) async {
    final result = await showContactFilterCategorySheet(
      context: context,
      category: category,
      criteria: criteria,
      groups: groups,
      tags: tags,
      onValidChanged: onChanged,
    );
    if (result != null) onChanged(result);
  }

  Future<void> _openDisplayedFields(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DisplayedFieldsSheet(
        initial: displayedFields,
        onChanged: onDisplayedFieldsChanged,
      ),
    );
  }
}

final class _DisplayedFieldsSheet extends StatefulWidget {
  const _DisplayedFieldsSheet({required this.initial, required this.onChanged});

  final List<ContactDisplayedField> initial;
  final ValueChanged<List<ContactDisplayedField>> onChanged;

  @override
  State<_DisplayedFieldsSheet> createState() => _DisplayedFieldsSheetState();
}

final class _DisplayedFieldsSheetState extends State<_DisplayedFieldsSheet> {
  late Set<ContactDisplayedField> _selected = widget.initial.toSet();

  @override
  Widget build(BuildContext context) {
    final all = _selected.length == ContactDisplayedField.values.length;
    final none = _selected.isEmpty;
    return Material(
      key: const Key('displayed-fields-sheet'),
      color: AppTheme.surfaceOf(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            Container(width: 36, height: 4, color: AppTheme.outlineOf(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Displayed Fields',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    all
                        ? 'All'
                        : none
                        ? 'None'
                        : 'Some',
                  ),
                  TriStateMasterCheckbox(
                    value: all
                        ? true
                        : none
                        ? false
                        : null,
                    onChanged: (_) => _setAll(!all),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final field in ContactDisplayedField.values)
                    CheckboxListTile(
                      key: Key('displayed-fields-option-${field.name}'),
                      controlAffinity: ListTileControlAffinity.trailing,
                      title: Text(_label(field)),
                      value: _selected.contains(field),
                      onChanged: (value) => _toggle(field, value == true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setAll(bool value) {
    setState(
      () => _selected = value
          ? ContactDisplayedField.values.toSet()
          : <ContactDisplayedField>{},
    );
    _notifyValid();
  }

  void _toggle(ContactDisplayedField field, bool value) {
    setState(() {
      if (value) {
        _selected.add(field);
      } else {
        _selected.remove(field);
      }
    });
    _notifyValid();
  }

  void _notifyValid() {
    widget.onChanged(
      ContactDisplayedField.values
          .where(_selected.contains)
          .toList(growable: false),
    );
  }

  static String _label(ContactDisplayedField field) => switch (field) {
    ContactDisplayedField.currentGroup => 'Current Group',
    ContactDisplayedField.tags => 'Tags',
    ContactDisplayedField.nextEvent => 'Next Event Date',
    ContactDisplayedField.lastEvent => 'Last Event Date',
    ContactDisplayedField.lastHappenedEvent => 'Last Happened Event Date',
    ContactDisplayedField.contactMethod => 'Contact Method',
    ContactDisplayedField.address => 'Address',
    ContactDisplayedField.lastInteraction => 'Last Interaction',
    ContactDisplayedField.lastViewed => 'Last Viewed',
    ContactDisplayedField.createdDate => 'Created Date',
  };
}

final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.anyFilter});

  final bool anyFilter;

  @override
  Widget build(BuildContext context) {
    final hasNoContacts = !anyFilter;
    // Short viewports (landscape, split-screen, large font) must never
    // overflow: center when there is room, scroll when there is not.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.people_outline,
                    size: 56,
                    color: AppTheme.outlineOf(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasNoContacts ? 'No contacts yet' : 'No matches',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasNoContacts
                        ? 'Keep people you want to remember, follow up with, or plan time with.'
                        : 'Try another name, phone, email, group, or tag.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.secondaryTextOf(context),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('empty-add-contact'),
                    onPressed: () => context.push(RoutePaths.contactCreate),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Contact'),
                  ),
                  if (hasNoContacts) ...<Widget>[
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('empty-import-contacts'),
                      onPressed: () => context.push(RoutePaths.deviceImport),
                      child: const Text('Import from device'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.secondaryTextOf(context),
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Contacts could not be opened.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.secondaryTextOf(context)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

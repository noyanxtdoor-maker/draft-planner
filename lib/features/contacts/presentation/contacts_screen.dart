import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
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
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsControllerProvider);
    final groups =
        ref.watch(contactGroupsProvider).value ?? const <ContactGroup>[];
    final tags = ref.watch(contactTagsProvider).value ?? const <ContactTag>[];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Contacts', style: AppTypography.appBarTitle),
            const SizedBox(height: 2),
            _CurrentFilterRow(
              appliedFilter: state.appliedFilter,
              onTap: () async {
                final result = await context.push<SavedFilterSelection>(
                  RoutePaths.savedFilters,
                );
                if (result != null && mounted) {
                  ref
                      .read(contactsControllerProvider.notifier)
                      .applyFilter(
                        result.criteria,
                        appliedFilter: result.appliedFilter,
                      );
                }
              },
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('contacts-search-button'),
            tooltip: 'Search',
            iconSize: 24,
            onPressed: () => context.push(RoutePaths.contactSearch),
            icon: const Icon(Icons.search),
          ),
          PopupMenuButton<String>(
            key: const Key('contacts-overflow-menu'),
            tooltip: 'More options',
            iconSize: 24,
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
        ContactsLoadStatus.ready => _buildBody(state, groups, tags),
      },
      floatingActionButton: FloatingActionButton(
        key: const Key('add-contact-fab'),
        heroTag: 'contacts-fab',
        tooltip: 'Add Contact',
        onPressed: () => context.push(RoutePaths.contactCreate),
        backgroundColor: AppTheme.rose,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add, size: 28),
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
              ListTile(
                key: const Key('sort-by-name'),
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Name (A–Z)'),
                trailing: current == ContactSortBy.name
                    ? const Icon(Icons.check, color: AppTheme.rose)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.setSort(ContactSortBy.name);
                },
              ),
              ListTile(
                key: const Key('sort-by-recent'),
                leading: const Icon(Icons.schedule),
                title: const Text('Recently added'),
                trailing: current == ContactSortBy.recentlyAdded
                    ? const Icon(Icons.check, color: AppTheme.rose)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.setSort(ContactSortBy.recentlyAdded);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ContactsState state,
    List<ContactGroup> groups,
    List<ContactTag> tags,
  ) {
    final contacts = state.contacts;
    if (contacts.isEmpty) {
      final anyFilter = !state.criteria.isEmpty;
      return _EmptyState(anyFilter: anyFilter);
    }
    final sections = _sectionsFor(
      contacts,
      criteria: state.criteria,
      sortBy: state.sortBy,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ActiveFilterChips(
          criteria: state.criteria,
          groups: groups,
          tags: tags,
          onRemove: (key) => _removeCriterion(key, groups, tags),
        ),
        Expanded(
          child: ListView.builder(
            key: const Key('contacts-list'),
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: sections.length,
            itemBuilder: (context, index) => sections[index],
          ),
        ),
      ],
    );
  }

  void _removeCriterion(
    String key,
    List<ContactGroup> groups,
    List<ContactTag> tags,
  ) {
    final criteria = ref.read(contactsControllerProvider).criteria;
    final updated = switch (key) {
      'favorites' => criteria.copyWithJson(favoritesOnly: false),
      'eventsToday' => criteria.copyWithJson(withEventsToday: false),
      'futureEvents' => criteria.copyWithJson(withFutureEvents: false),
      'withoutFuture' => criteria.copyWithJson(withoutFutureEvents: false),
      'noInteraction' => criteria.copyWithJson(noInteractionYet: false),
      'hasPhone' => criteria.copyWithJson(hasPhone: false),
      'hasEmail' => criteria.copyWithJson(hasEmail: false),
      'hasAddress' => criteria.copyWithJson(hasAddress: false),
      'archived' => criteria.copyWithJson(includeArchived: false),
      _ => criteria,
    };
    // Group/tag chips remove a single id from the list.
    final groupId = key.startsWith('group:') ? key.substring(6) : null;
    final tagId = key.startsWith('tag:') ? key.substring(4) : null;
    var finalCriteria = updated;
    if (groupId != null) {
      finalCriteria = ContactFilterCriteria(
        groupIds: criteria.groupIds.where((id) => id != groupId).toList(),
        tagIds: criteria.tagIds,
        favoritesOnly: criteria.favoritesOnly,
        availabilityWeekdays: criteria.availabilityWeekdays,
        hasPhone: criteria.hasPhone,
        hasEmail: criteria.hasEmail,
        hasAddress: criteria.hasAddress,
        withEventsToday: criteria.withEventsToday,
        withFutureEvents: criteria.withFutureEvents,
        withoutFutureEvents: criteria.withoutFutureEvents,
        noInteractionYet: criteria.noInteractionYet,
        source: criteria.source,
        includeArchived: criteria.includeArchived,
        eventHistoryAny: criteria.eventHistoryAny,
      );
    } else if (tagId != null) {
      finalCriteria = ContactFilterCriteria(
        groupIds: criteria.groupIds,
        tagIds: criteria.tagIds.where((id) => id != tagId).toList(),
        favoritesOnly: criteria.favoritesOnly,
        availabilityWeekdays: criteria.availabilityWeekdays,
        hasPhone: criteria.hasPhone,
        hasEmail: criteria.hasEmail,
        hasAddress: criteria.hasAddress,
        withEventsToday: criteria.withEventsToday,
        withFutureEvents: criteria.withFutureEvents,
        withoutFutureEvents: criteria.withoutFutureEvents,
        noInteractionYet: criteria.noInteractionYet,
        source: criteria.source,
        includeArchived: criteria.includeArchived,
        eventHistoryAny: criteria.eventHistoryAny,
      );
    }
    ref
        .read(contactsControllerProvider.notifier)
        .applyFilter(finalCriteria, appliedFilter: null);
  }

  List<Widget> _sectionsFor(
    List<ContactSummary> contacts, {
    required ContactFilterCriteria criteria,
    required ContactSortBy sortBy,
  }) {
    final widgets = <Widget>[];
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
            dotColor: AppTheme.rose,
            key: const Key('contacts-favorites-section'),
          ),
        );
        for (final summary in favorites) {
          widgets.add(_row(summary));
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
            const _SectionHeader(
              title: 'Other',
              key: Key('contacts-other-section'),
            ),
          );
        } else if (primaryGroup != null) {
          widgets.add(
            _SectionHeader(
              title: primaryGroup.name,
              dotColor: Color(primaryGroup.colorValue),
              key: Key('contacts-section-${primaryGroup.id}'),
            ),
          );
        }
        for (final summary in members) {
          widgets.add(_row(summary));
        }
      }
      return widgets;
    }
    for (final summary in contacts) {
      widgets.add(_row(summary));
    }
    return widgets;
  }

  Widget _row(ContactSummary summary) {
    return ContactListRow(
      summary: summary,
      onTap: () => context.push(RoutePaths.contactDetail(summary.contact.id)),
    );
  }
}

final class _CurrentFilterRow extends StatelessWidget {
  const _CurrentFilterRow({required this.onTap, this.appliedFilter});

  final VoidCallback onTap;
  final SavedContactFilter? appliedFilter;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('current-filter-row'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              appliedFilter?.name ?? 'All Contacts',
              style: const TextStyle(
                color: Color(0xFF9CA0A6),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Color(0xFF9CA0A6),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.dotColor, super.key});

  final String title;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: <Widget>[
          if (dotColor != null) ...<Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
  });

  final ContactFilterCriteria criteria;
  final List<ContactGroup> groups;
  final List<ContactTag> tags;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) {
      return const SizedBox.shrink();
    }
    final labels = <(String, String)>[];
    void add(String key, String label) => labels.add((key, label));
    for (final id in criteria.groupIds) {
      final group = groups.where((g) => g.id == id).firstOrNull;
      if (group != null) {
        add('group:$id', group.name);
      }
    }
    for (final id in criteria.tagIds) {
      final tag = tags.where((t) => t.id == id).firstOrNull;
      if (tag != null) {
        add('tag:$id', tag.name);
      }
    }
    if (criteria.favoritesOnly) {
      add('favorites', 'Favorites');
    }
    if (criteria.withEventsToday) {
      add('eventsToday', 'Events Today');
    }
    if (criteria.withFutureEvents) {
      add('futureEvents', 'Future Events');
    }
    if (criteria.withoutFutureEvents) {
      add('withoutFuture', 'No Future Events');
    }
    if (criteria.noInteractionYet) {
      add('noInteraction', 'No Interaction Yet');
    }
    if (criteria.hasPhone) {
      add('hasPhone', 'Has Phone');
    }
    if (criteria.hasEmail) {
      add('hasEmail', 'Has Email');
    }
    if (criteria.hasAddress) {
      add('hasAddress', 'Has Address');
    }
    if (criteria.includeArchived) {
      add('archived', 'Archived');
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        key: const Key('active-filter-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = labels[index];
          return InputChip(
            key: Key('active-filter-chip-${entry.$2}'),
            label: Text(entry.$2, style: const TextStyle(fontSize: 13)),
            visualDensity: VisualDensity.compact,
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => onRemove(entry.$1),
            side: const BorderSide(color: Color(0xFF2A2D31)),
            backgroundColor: const Color(0xFF181A1E),
            labelStyle: const TextStyle(color: Colors.white),
            deleteIconColor: const Color(0xFF9CA0A6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
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
                  const Icon(
                    Icons.people_outline,
                    size: 56,
                    color: Color(0xFF454850),
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
                    style: const TextStyle(
                      color: Color(0xFF9CA0A6),
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
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA0A6)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Contacts could not be opened.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA0A6)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

extension on ContactFilterCriteria {
  ContactFilterCriteria copyWithJson({
    bool? favoritesOnly,
    bool? withEventsToday,
    bool? withFutureEvents,
    bool? withoutFutureEvents,
    bool? noInteractionYet,
    bool? hasPhone,
    bool? hasEmail,
    bool? hasAddress,
    bool? includeArchived,
  }) {
    return ContactFilterCriteria(
      groupIds: groupIds,
      tagIds: tagIds,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      availabilityWeekdays: availabilityWeekdays,
      hasPhone: hasPhone ?? this.hasPhone,
      hasEmail: hasEmail ?? this.hasEmail,
      hasAddress: hasAddress ?? this.hasAddress,
      withEventsToday: withEventsToday ?? this.withEventsToday,
      withFutureEvents: withFutureEvents ?? this.withFutureEvents,
      withoutFutureEvents: withoutFutureEvents ?? this.withoutFutureEvents,
      noInteractionYet: noInteractionYet ?? this.noInteractionYet,
      source: source,
      includeArchived: includeArchived ?? this.includeArchived,
      eventHistoryAny: eventHistoryAny,
    );
  }
}

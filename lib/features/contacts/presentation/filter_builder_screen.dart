import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

final class FilterBuilderArgs {
  const FilterBuilderArgs({
    this.initialCriteria = const ContactFilterCriteria(),
    this.initialName,
    this.saveAsFilter = false,
  });

  final ContactFilterCriteria initialCriteria;
  final String? initialName;
  final bool saveAsFilter;
}

final class FilterBuilderResult {
  const FilterBuilderResult({
    required this.criteria,
    required this.sortBy,
    this.savedFilterName,
  });

  final ContactFilterCriteria criteria;
  final ContactSortBy sortBy;
  final String? savedFilterName;
}

/// Full-screen filter builder.  Modified-filter exit shows a discard
/// confirmation; nothing is silently lost.
final class FilterBuilderScreen extends ConsumerStatefulWidget {
  const FilterBuilderScreen({required this.args, super.key});

  final FilterBuilderArgs args;

  @override
  ConsumerState<FilterBuilderScreen> createState() =>
      _FilterBuilderScreenState();
}

final class _FilterBuilderScreenState
    extends ConsumerState<FilterBuilderScreen> {
  late ContactFilterCriteria _criteria = widget.args.initialCriteria;
  late ContactSortBy _sortBy = ContactSortBy.name;
  late bool _saveAsFilter = widget.args.saveAsFilter;
  late final TextEditingController _nameController = TextEditingController(
    text: widget.args.initialName ?? '',
  );
  bool _dirty = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        ref.watch(contactGroupsProvider).value ?? const <ContactGroup>[];
    final tags = ref.watch(contactTagsProvider).value ?? const <ContactTag>[];
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_maybeExit());
      },
      child: Scaffold(
        appBar: InternalAppBar(
          title: const Text('Filter'),
          leading: IconButton(
            key: const Key('filter-builder-close'),
            tooltip: 'Close',
            iconSize: 28,
            onPressed: _maybeExit,
            icon: const Icon(Icons.close),
          ),
          actions: <Widget>[
            FilledButton(
              key: const Key('filter-builder-apply'),
              onPressed: () => _apply(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                backgroundColor: AppTheme.rose,
                foregroundColor: AppTheme.background,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('filter-builder-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Save as Saved Filter')),
                  Switch(
                    key: const Key('save-as-filter-switch'),
                    value: _saveAsFilter,
                    onChanged: (value) => setState(() {
                      _saveAsFilter = value;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              if (_saveAsFilter) ...<Widget>[
                TextField(
                  key: const Key('filter-name-field'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Filter name',
                    filled: true,
                    fillColor: const Color(0xFF181A1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onChanged: (_) => _dirty = true,
                ),
              ],
              const SizedBox(height: 12),
              _sectionDivider(),
              const SizedBox(height: 16),
              const Text('Sort By', style: InternalScreen.sectionHeading),
              const SizedBox(height: 8),
              DropdownButtonFormField<ContactSortBy>(
                key: const Key('filter-sort-by'),
                initialValue: _sortBy,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF181A1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                items: const <DropdownMenuItem<ContactSortBy>>[
                  DropdownMenuItem<ContactSortBy>(
                    value: ContactSortBy.name,
                    child: Text('Name (A–Z)'),
                  ),
                  DropdownMenuItem<ContactSortBy>(
                    value: ContactSortBy.recentlyAdded,
                    child: Text('Recently added'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                      _dirty = true;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              _sectionDivider(),
              const SizedBox(height: 12),
              _CategoryRow(
                key: const Key('filter-category-groups'),
                label: 'Groups',
                summary: _groupsSummary(groups),
                onTap: () => _pickGroups(groups),
              ),
              _CategoryRow(
                key: const Key('filter-category-tags'),
                label: 'Tags',
                summary: _tagsSummary(tags),
                onTap: () => _pickTags(tags),
              ),
              _CategoryRow(
                key: const Key('filter-category-favorites'),
                label: 'Favorites',
                summary: _criteria.favoritesOnly ? 'Favorites only' : 'Any',
                onTap: () => _pickFavorites(),
              ),
              _CategoryRow(
                key: const Key('filter-category-availability'),
                label: 'Availability',
                summary: _availabilitySummary(),
                onTap: () => _pickAvailability(),
              ),
              _CategoryRow(
                key: const Key('filter-category-methods'),
                label: 'Contact Methods',
                summary: _methodsSummary(),
                onTap: () => _pickMethods(),
              ),
              _CategoryRow(
                key: const Key('filter-category-history'),
                label: 'Event History',
                summary: _historySummary(),
                onTap: () => _pickHistory(),
              ),
              _CategoryRow(
                key: const Key('filter-category-source'),
                label: 'Source',
                summary: _sourceSummary(),
                onTap: () => _pickSource(),
              ),
              _CategoryRow(
                key: const Key('filter-category-archived'),
                label: 'Archived',
                summary: _criteria.includeArchived ? 'Included' : 'Hidden',
                onTap: () => _pickArchived(),
              ),
              const SizedBox(height: 16),
              _sectionDivider(),
              const SizedBox(height: 12),
              _QuickToggle(
                key: const Key('filter-quick-events-today'),
                label: 'With Events Today Only',
                value: _criteria.withEventsToday,
                onChanged: (value) => setState(() {
                  _criteria = _withEventsToday(value);
                  _dirty = true;
                }),
              ),
              _QuickToggle(
                key: const Key('filter-quick-future-events'),
                label: 'With Future Events Only',
                value: _criteria.withFutureEvents,
                onChanged: (value) => setState(() {
                  _criteria = _withFutureEvents(value);
                  _dirty = true;
                }),
              ),
              _QuickToggle(
                key: const Key('filter-quick-without-future'),
                label: 'Without Future Events Only',
                value: _criteria.withoutFutureEvents,
                onChanged: (value) => setState(() {
                  _criteria = _withoutFutureEvents(value);
                  _dirty = true;
                }),
              ),
              _QuickToggle(
                key: const Key('filter-quick-no-interaction'),
                label: 'No Interaction Yet',
                value: _criteria.noInteractionYet,
                onChanged: (value) => setState(() {
                  _criteria = _noInteractionYet(value);
                  _dirty = true;
                }),
              ),
              _QuickToggle(
                key: const Key('filter-quick-has-phone'),
                label: 'Has Phone',
                value: _criteria.hasPhone,
                onChanged: (value) => setState(() {
                  _criteria = _hasPhone(value);
                  _dirty = true;
                }),
              ),
              _QuickToggle(
                key: const Key('filter-quick-has-email'),
                label: 'Has Email',
                value: _criteria.hasEmail,
                onChanged: (value) => setState(() {
                  _criteria = _hasEmail(value);
                  _dirty = true;
                }),
              ),
              _QuickToggle(
                key: const Key('filter-quick-has-address'),
                label: 'Has Address',
                value: _criteria.hasAddress,
                onChanged: (value) => setState(() {
                  _criteria = _hasAddress(value);
                  _dirty = true;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionDivider() {
    return Container(
      height: 8,
      width: double.infinity,
      color: const Color(0xFF45484A),
    );
  }

  String _groupsSummary(List<ContactGroup> groups) {
    if (_criteria.groupIds.isEmpty) {
      return 'All';
    }
    final names = groups
        .where((group) => _criteria.groupIds.contains(group.id))
        .map((group) => group.name)
        .toList();
    return names.isEmpty ? 'Selected' : names.join(', ');
  }

  String _tagsSummary(List<ContactTag> tags) {
    if (_criteria.tagIds.isEmpty) {
      return 'All';
    }
    final names = tags
        .where((tag) => _criteria.tagIds.contains(tag.id))
        .map((tag) => tag.name)
        .toList();
    return names.isEmpty ? 'Selected' : names.join(', ');
  }

  String _availabilitySummary() {
    if (_criteria.availabilityWeekdays.isEmpty) {
      return 'Any';
    }
    const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _criteria.availabilityWeekdays.map((d) => names[d - 1]).join(', ');
  }

  String _methodsSummary() {
    final labels = <String>[
      if (_criteria.hasPhone) 'Phone',
      if (_criteria.hasEmail) 'Email',
      if (_criteria.hasAddress) 'Address',
    ];
    return labels.isEmpty ? 'Any' : labels.join(', ');
  }

  String _historySummary() {
    final labels = <String>[
      if (_criteria.withEventsToday) 'Events Today',
      if (_criteria.withFutureEvents) 'Future Events',
      if (_criteria.withoutFutureEvents) 'No Future Events',
      if (_criteria.noInteractionYet) 'No Interaction',
      if (_criteria.eventHistoryAny) 'Has History',
    ];
    return labels.isEmpty ? 'Any' : labels.join(', ');
  }

  String _sourceSummary() {
    return switch (_criteria.source) {
      null => 'Any',
      ContactSource.manual => 'Manual',
      ContactSource.deviceImport => 'Device Import',
      ContactSource.betterCalendarImport => 'BetterCalendar Import',
    };
  }

  Future<void> _pickGroups(List<ContactGroup> groups) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CheckboxSheet(
        title: 'Groups',
        options: groups.map((group) => (group.name, group.id)).toList(),
        selected: _criteria.groupIds.toSet(),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _criteria = _withGroupIds(selected.toList());
        _dirty = true;
      });
    }
  }

  Future<void> _pickTags(List<ContactTag> tags) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CheckboxSheet(
        title: 'Tags',
        options: tags.map((tag) => (tag.name, tag.id)).toList(),
        selected: _criteria.tagIds.toSet(),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _criteria = _withTagIds(selected.toList());
        _dirty = true;
      });
    }
  }

  Future<void> _pickFavorites() async {
    final value = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Favorites',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              title: const Text('Any'),
              trailing: !_criteria.favoritesOnly
                  ? const Icon(Icons.check, color: AppTheme.rose)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            ListTile(
              title: const Text('Favorites only'),
              trailing: _criteria.favoritesOnly
                  ? const Icon(Icons.check, color: AppTheme.rose)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _criteria = _favoritesOnly(value);
        _dirty = true;
      });
    }
  }

  Future<void> _pickAvailability() async {
    const names = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final selected = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CheckboxSheet<int>(
        title: 'Availability',
        options: <(String, int)>[
          for (var day = 1; day <= 7; day++) (names[day - 1], day),
        ],
        selected: _criteria.availabilityWeekdays.toSet(),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _criteria = _withWeekdays(selected.toList());
        _dirty = true;
      });
    }
  }

  Future<void> _pickMethods() async {
    final result =
        await showModalBottomSheet<({bool phone, bool email, bool address})>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Contact Methods',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Has Phone'),
                  value: _criteria.hasPhone,
                  onChanged: (value) => Navigator.of(sheetContext).pop((
                    phone: value ?? false,
                    email: _criteria.hasEmail,
                    address: _criteria.hasAddress,
                  )),
                ),
                CheckboxListTile(
                  title: const Text('Has Email'),
                  value: _criteria.hasEmail,
                  onChanged: (value) => Navigator.of(sheetContext).pop((
                    phone: _criteria.hasPhone,
                    email: value ?? false,
                    address: _criteria.hasAddress,
                  )),
                ),
                CheckboxListTile(
                  title: const Text('Has Address'),
                  value: _criteria.hasAddress,
                  onChanged: (value) => Navigator.of(sheetContext).pop((
                    phone: _criteria.hasPhone,
                    email: _criteria.hasEmail,
                    address: value ?? false,
                  )),
                ),
              ],
            ),
          ),
        );
    if (result != null && mounted) {
      setState(() {
        _criteria = _methods(result.phone, result.email, result.address);
        _dirty = true;
      });
    }
  }

  Future<void> _pickHistory() async {
    final result =
        await showModalBottomSheet<
          ({
            bool today,
            bool future,
            bool withoutFuture,
            bool noInteraction,
            bool any,
          })
        >(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Event History',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Has Events Today'),
                  value: _criteria.withEventsToday,
                  onChanged: (value) =>
                      _popHistory(sheetContext, today: value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('With Future Events'),
                  value: _criteria.withFutureEvents,
                  onChanged: (value) =>
                      _popHistory(sheetContext, future: value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Without Future Events'),
                  value: _criteria.withoutFutureEvents,
                  onChanged: (value) =>
                      _popHistory(sheetContext, withoutFuture: value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('No Interaction Yet'),
                  value: _criteria.noInteractionYet,
                  onChanged: (value) =>
                      _popHistory(sheetContext, noInteraction: value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Has Event History'),
                  value: _criteria.eventHistoryAny,
                  onChanged: (value) =>
                      _popHistory(sheetContext, any: value ?? false),
                ),
              ],
            ),
          ),
        );
    if (result != null && mounted) {
      setState(() {
        _criteria = _history(
          result.today,
          result.future,
          result.withoutFuture,
          result.noInteraction,
          result.any,
        );
        _dirty = true;
      });
    }
  }

  void _popHistory(
    BuildContext sheetContext, {
    bool? today,
    bool? future,
    bool? withoutFuture,
    bool? noInteraction,
    bool? any,
  }) {
    Navigator.of(sheetContext).pop((
      today: today ?? _criteria.withEventsToday,
      future: future ?? _criteria.withFutureEvents,
      withoutFuture: withoutFuture ?? _criteria.withoutFutureEvents,
      noInteraction: noInteraction ?? _criteria.noInteractionYet,
      any: any ?? _criteria.eventHistoryAny,
    ));
  }

  Future<void> _pickSource() async {
    final value = await showModalBottomSheet<ContactSource?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Source',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              title: const Text('Any'),
              trailing: _criteria.source == null
                  ? const Icon(Icons.check, color: AppTheme.rose)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(null),
            ),
            ListTile(
              title: const Text('Manual'),
              trailing: _criteria.source == ContactSource.manual
                  ? const Icon(Icons.check, color: AppTheme.rose)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(ContactSource.manual),
            ),
            ListTile(
              title: const Text('Device Import'),
              trailing: _criteria.source == ContactSource.deviceImport
                  ? const Icon(Icons.check, color: AppTheme.rose)
                  : null,
              onTap: () =>
                  Navigator.of(sheetContext).pop(ContactSource.deviceImport),
            ),
          ],
        ),
      ),
    );
    if (mounted && value != _criteria.source) {
      setState(() {
        _criteria = _withSource(value);
        _dirty = true;
      });
    }
  }

  Future<void> _pickArchived() async {
    final value = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Archived',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              title: const Text('Hidden'),
              trailing: !_criteria.includeArchived
                  ? const Icon(Icons.check, color: AppTheme.rose)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            ListTile(
              title: const Text('Included'),
              trailing: _criteria.includeArchived
                  ? const Icon(Icons.check, color: AppTheme.rose)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _criteria = _includeArchived(value);
        _dirty = true;
      });
    }
  }

  Future<void> _apply() async {
    final name = _saveAsFilter ? _nameController.text.trim() : null;
    if (_saveAsFilter && (name == null || name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name the filter to save it.')),
      );
      return;
    }
    if (_saveAsFilter && name != null) {
      final profileId = ref.read(contactProfileIdProvider);
      try {
        await ref
            .read(contactRepositoryProvider)
            .saveSavedFilter(
              profileId: profileId,
              draft: SavedContactFilterDraft(
                name: name,
                criteria: _criteria,
                sortBy: _sortBy,
              ),
            );
      } on ContactValidationException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      }
    }
    if (mounted) {
      Navigator.of(context).pop(
        FilterBuilderResult(
          criteria: _criteria,
          sortBy: _sortBy,
          savedFilterName: name,
        ),
      );
    }
  }

  Future<void> _maybeExit() async {
    if (!_dirty) {
      unawaited(Navigator.of(context).maybePop());
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard filter changes?'),
        content: const Text(
          'This filter has unsaved changes that will be lost.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const Key('confirm-discard-filter'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  // Criteria mutators (rebuild with a single field changed).
  ContactFilterCriteria _withGroupIds(List<String> ids) =>
      ContactFilterCriteria(
        groupIds: ids,
        tagIds: _criteria.tagIds,
        favoritesOnly: _criteria.favoritesOnly,
        availabilityWeekdays: _criteria.availabilityWeekdays,
        hasPhone: _criteria.hasPhone,
        hasEmail: _criteria.hasEmail,
        hasAddress: _criteria.hasAddress,
        withEventsToday: _criteria.withEventsToday,
        withFutureEvents: _criteria.withFutureEvents,
        withoutFutureEvents: _criteria.withoutFutureEvents,
        noInteractionYet: _criteria.noInteractionYet,
        source: _criteria.source,
        includeArchived: _criteria.includeArchived,
        eventHistoryAny: _criteria.eventHistoryAny,
      );

  ContactFilterCriteria _withTagIds(List<String> ids) => ContactFilterCriteria(
    groupIds: _criteria.groupIds,
    tagIds: ids,
    favoritesOnly: _criteria.favoritesOnly,
    availabilityWeekdays: _criteria.availabilityWeekdays,
    hasPhone: _criteria.hasPhone,
    hasEmail: _criteria.hasEmail,
    hasAddress: _criteria.hasAddress,
    withEventsToday: _criteria.withEventsToday,
    withFutureEvents: _criteria.withFutureEvents,
    withoutFutureEvents: _criteria.withoutFutureEvents,
    noInteractionYet: _criteria.noInteractionYet,
    source: _criteria.source,
    includeArchived: _criteria.includeArchived,
    eventHistoryAny: _criteria.eventHistoryAny,
  );

  ContactFilterCriteria _favoritesOnly(bool value) => ContactFilterCriteria(
    groupIds: _criteria.groupIds,
    tagIds: _criteria.tagIds,
    favoritesOnly: value,
    availabilityWeekdays: _criteria.availabilityWeekdays,
    hasPhone: _criteria.hasPhone,
    hasEmail: _criteria.hasEmail,
    hasAddress: _criteria.hasAddress,
    withEventsToday: _criteria.withEventsToday,
    withFutureEvents: _criteria.withFutureEvents,
    withoutFutureEvents: _criteria.withoutFutureEvents,
    noInteractionYet: _criteria.noInteractionYet,
    source: _criteria.source,
    includeArchived: _criteria.includeArchived,
    eventHistoryAny: _criteria.eventHistoryAny,
  );

  ContactFilterCriteria _withWeekdays(List<int> weekdays) =>
      ContactFilterCriteria(
        groupIds: _criteria.groupIds,
        tagIds: _criteria.tagIds,
        favoritesOnly: _criteria.favoritesOnly,
        availabilityWeekdays: weekdays,
        hasPhone: _criteria.hasPhone,
        hasEmail: _criteria.hasEmail,
        hasAddress: _criteria.hasAddress,
        withEventsToday: _criteria.withEventsToday,
        withFutureEvents: _criteria.withFutureEvents,
        withoutFutureEvents: _criteria.withoutFutureEvents,
        noInteractionYet: _criteria.noInteractionYet,
        source: _criteria.source,
        includeArchived: _criteria.includeArchived,
        eventHistoryAny: _criteria.eventHistoryAny,
      );

  ContactFilterCriteria _methods(bool phone, bool email, bool address) =>
      ContactFilterCriteria(
        groupIds: _criteria.groupIds,
        tagIds: _criteria.tagIds,
        favoritesOnly: _criteria.favoritesOnly,
        availabilityWeekdays: _criteria.availabilityWeekdays,
        hasPhone: phone,
        hasEmail: email,
        hasAddress: address,
        withEventsToday: _criteria.withEventsToday,
        withFutureEvents: _criteria.withFutureEvents,
        withoutFutureEvents: _criteria.withoutFutureEvents,
        noInteractionYet: _criteria.noInteractionYet,
        source: _criteria.source,
        includeArchived: _criteria.includeArchived,
        eventHistoryAny: _criteria.eventHistoryAny,
      );

  ContactFilterCriteria _history(
    bool today,
    bool future,
    bool withoutFuture,
    bool noInteraction,
    bool any,
  ) => ContactFilterCriteria(
    groupIds: _criteria.groupIds,
    tagIds: _criteria.tagIds,
    favoritesOnly: _criteria.favoritesOnly,
    availabilityWeekdays: _criteria.availabilityWeekdays,
    hasPhone: _criteria.hasPhone,
    hasEmail: _criteria.hasEmail,
    hasAddress: _criteria.hasAddress,
    withEventsToday: today,
    withFutureEvents: future,
    withoutFutureEvents: withoutFuture,
    noInteractionYet: noInteraction,
    source: _criteria.source,
    includeArchived: _criteria.includeArchived,
    eventHistoryAny: any,
  );

  ContactFilterCriteria _withSource(ContactSource? source) =>
      ContactFilterCriteria(
        groupIds: _criteria.groupIds,
        tagIds: _criteria.tagIds,
        favoritesOnly: _criteria.favoritesOnly,
        availabilityWeekdays: _criteria.availabilityWeekdays,
        hasPhone: _criteria.hasPhone,
        hasEmail: _criteria.hasEmail,
        hasAddress: _criteria.hasAddress,
        withEventsToday: _criteria.withEventsToday,
        withFutureEvents: _criteria.withFutureEvents,
        withoutFutureEvents: _criteria.withoutFutureEvents,
        noInteractionYet: _criteria.noInteractionYet,
        source: source,
        includeArchived: _criteria.includeArchived,
        eventHistoryAny: _criteria.eventHistoryAny,
      );

  ContactFilterCriteria _includeArchived(bool value) => ContactFilterCriteria(
    groupIds: _criteria.groupIds,
    tagIds: _criteria.tagIds,
    favoritesOnly: _criteria.favoritesOnly,
    availabilityWeekdays: _criteria.availabilityWeekdays,
    hasPhone: _criteria.hasPhone,
    hasEmail: _criteria.hasEmail,
    hasAddress: _criteria.hasAddress,
    withEventsToday: _criteria.withEventsToday,
    withFutureEvents: _criteria.withFutureEvents,
    withoutFutureEvents: _criteria.withoutFutureEvents,
    noInteractionYet: _criteria.noInteractionYet,
    source: _criteria.source,
    includeArchived: value,
    eventHistoryAny: _criteria.eventHistoryAny,
  );

  ContactFilterCriteria _withEventsToday(bool value) => _history(
    value,
    _criteria.withFutureEvents,
    _criteria.withoutFutureEvents,
    _criteria.noInteractionYet,
    _criteria.eventHistoryAny,
  );

  ContactFilterCriteria _withFutureEvents(bool value) => _history(
    _criteria.withEventsToday,
    value,
    _criteria.withoutFutureEvents,
    _criteria.noInteractionYet,
    _criteria.eventHistoryAny,
  );

  ContactFilterCriteria _withoutFutureEvents(bool value) => _history(
    _criteria.withEventsToday,
    _criteria.withFutureEvents,
    value,
    _criteria.noInteractionYet,
    _criteria.eventHistoryAny,
  );

  ContactFilterCriteria _noInteractionYet(bool value) => _history(
    _criteria.withEventsToday,
    _criteria.withFutureEvents,
    _criteria.withoutFutureEvents,
    value,
    _criteria.eventHistoryAny,
  );

  ContactFilterCriteria _hasPhone(bool value) =>
      _methods(value, _criteria.hasEmail, _criteria.hasAddress);

  ContactFilterCriteria _hasEmail(bool value) =>
      _methods(_criteria.hasPhone, value, _criteria.hasAddress);

  ContactFilterCriteria _hasAddress(bool value) =>
      _methods(_criteria.hasPhone, _criteria.hasEmail, value);
}

final class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.summary,
    required this.onTap,
    super.key,
  });

  final String label;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            Text(
              summary,
              style: const TextStyle(color: Color(0xFF9CA0A6), fontSize: 14),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF9CA0A6)),
          ],
        ),
      ),
    );
  }
}

final class _QuickToggle extends StatelessWidget {
  const _QuickToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 16)),
      value: value,
      onChanged: onChanged,
    );
  }
}

final class _CheckboxSheet<T> extends StatefulWidget {
  const _CheckboxSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<(String, T)> options;
  final Set<T> selected;

  @override
  State<_CheckboxSheet<T>> createState() => _CheckboxSheetState<T>();
}

final class _CheckboxSheetState<T> extends State<_CheckboxSheet<T>> {
  late final Set<T> _selected = <T>{...widget.selected};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final option in widget.options)
                    CheckboxListTile(
                      title: Text(option.$1),
                      value: _selected.contains(option.$2),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(option.$2);
                          } else {
                            _selected.remove(option.$2);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

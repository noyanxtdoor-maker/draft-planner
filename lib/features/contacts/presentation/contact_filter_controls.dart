import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';

enum ContactFilterCategory {
  groups,
  tags,
  favorites,
  availability,
  contactMethods,
  eventHistory,
  source,
  archived,
  phone,
  email,
  address,
  socialProfile,
  withEventsToday,
  withFutureEvents,
  withoutFutureEvents,
}

/// Contacts Home is a compact, horizontal fast-access projection of the same
/// canonical Filter Builder criteria. Sorting deliberately remains elsewhere.
const List<ContactFilterCategory> quickFilterCategories = <ContactFilterCategory>[
  ContactFilterCategory.groups,
  ContactFilterCategory.tags,
  ContactFilterCategory.favorites,
  ContactFilterCategory.availability,
  ContactFilterCategory.phone,
  ContactFilterCategory.email,
  ContactFilterCategory.address,
  ContactFilterCategory.socialProfile,
  ContactFilterCategory.eventHistory,
  ContactFilterCategory.withEventsToday,
  ContactFilterCategory.withFutureEvents,
  ContactFilterCategory.withoutFutureEvents,
  ContactFilterCategory.source,
  ContactFilterCategory.archived,
];

/// Categories rendered inside the Filter builder.  The old combined
/// "Contact Methods" row is replaced by the dedicated Phone / Email / Address /
/// Social Profile categories.
const List<ContactFilterCategory> filterBuilderCategories = <ContactFilterCategory>[
  ContactFilterCategory.groups,
  ContactFilterCategory.tags,
  ContactFilterCategory.favorites,
  ContactFilterCategory.availability,
  ContactFilterCategory.phone,
  ContactFilterCategory.email,
  ContactFilterCategory.address,
  ContactFilterCategory.socialProfile,
  ContactFilterCategory.eventHistory,
  ContactFilterCategory.source,
  ContactFilterCategory.archived,
];

enum ContactFilterSelectionState { all, some, none }

bool contactFilterCategoryUsesNeutralAll(ContactFilterCategory category) =>
    switch (category) {
      ContactFilterCategory.groups ||
      ContactFilterCategory.tags ||
      ContactFilterCategory.availability ||
      ContactFilterCategory.phone ||
      ContactFilterCategory.email ||
      ContactFilterCategory.address ||
      ContactFilterCategory.socialProfile ||
      ContactFilterCategory.eventHistory => true,
      _ => false,
    };

bool contactFilterCategoryIsBoolean(ContactFilterCategory category) =>
    switch (category) {
      ContactFilterCategory.favorites ||
      ContactFilterCategory.withEventsToday ||
      ContactFilterCategory.withFutureEvents ||
      ContactFilterCategory.withoutFutureEvents => true,
      _ => false,
    };

String contactFilterCategoryLabel(ContactFilterCategory category) {
  return switch (category) {
    ContactFilterCategory.groups => 'Groups',
    ContactFilterCategory.tags => 'Tags',
    ContactFilterCategory.favorites => 'Favorites',
    ContactFilterCategory.availability => 'Availability',
    ContactFilterCategory.contactMethods => 'Contact Methods',
    ContactFilterCategory.eventHistory => 'Event History',
    ContactFilterCategory.source => 'Source',
    ContactFilterCategory.archived => 'Archived',
    ContactFilterCategory.phone => 'Phone',
    ContactFilterCategory.email => 'Email',
    ContactFilterCategory.address => 'Address',
    ContactFilterCategory.socialProfile => 'Social Profile',
    ContactFilterCategory.withEventsToday => 'With Events Today',
    ContactFilterCategory.withFutureEvents => 'With Future Events',
    ContactFilterCategory.withoutFutureEvents => 'Without Future Events',
  };
}

bool contactFilterCategoryIsActive(
  ContactFilterCriteria criteria,
  ContactFilterCategory category,
) {
  return switch (category) {
    ContactFilterCategory.groups => criteria.groupIds.isNotEmpty,
    ContactFilterCategory.tags => criteria.tagIds.isNotEmpty,
    ContactFilterCategory.favorites => criteria.favoritesOnly,
    ContactFilterCategory.availability =>
      criteria.availabilityWeekdays.isNotEmpty,
    ContactFilterCategory.contactMethods =>
      criteria.hasPhone || criteria.hasEmail || criteria.hasAddress,
    ContactFilterCategory.eventHistory =>
      criteria.noInteractionYet || criteria.eventHistoryAny,
    ContactFilterCategory.source => criteria.source != null,
    ContactFilterCategory.archived =>
      criteria.includeArchived || criteria.archivedOnly,
    ContactFilterCategory.phone => criteria.phoneLabels.isNotEmpty,
    ContactFilterCategory.email => criteria.emailLabels.isNotEmpty,
    ContactFilterCategory.address => criteria.addressLabels.isNotEmpty,
    ContactFilterCategory.socialProfile => criteria.socialLabels.isNotEmpty,
    ContactFilterCategory.withEventsToday => criteria.withEventsToday,
    ContactFilterCategory.withFutureEvents => criteria.withFutureEvents,
    ContactFilterCategory.withoutFutureEvents => criteria.withoutFutureEvents,
  };
}

ContactFilterSelectionState contactFilterCategoryState(
  ContactFilterCriteria criteria,
  ContactFilterCategory category, {
  List<ContactGroup> groups = const <ContactGroup>[],
  List<ContactTag> tags = const <ContactTag>[],
}) {
  final optionCount = switch (category) {
    ContactFilterCategory.groups => groups.length,
    ContactFilterCategory.tags => tags.length,
    ContactFilterCategory.favorites => 1,
    ContactFilterCategory.availability => 7,
    ContactFilterCategory.contactMethods => 3,
    ContactFilterCategory.eventHistory => 2,
    ContactFilterCategory.source => 3,
    ContactFilterCategory.archived => 2,
    ContactFilterCategory.phone => 5,
    ContactFilterCategory.email => 5,
    ContactFilterCategory.address => 2,
    ContactFilterCategory.socialProfile => 9,
    ContactFilterCategory.withEventsToday => 1,
    ContactFilterCategory.withFutureEvents => 1,
    ContactFilterCategory.withoutFutureEvents => 1,
  };
  if (optionCount == 0 || !contactFilterCategoryIsActive(criteria, category)) {
    return ContactFilterSelectionState.all;
  }
  final selectedCount = switch (category) {
    ContactFilterCategory.groups => criteria.groupIds.length,
    ContactFilterCategory.tags => criteria.tagIds.length,
    ContactFilterCategory.favorites => criteria.favoritesOnly ? 1 : 0,
    ContactFilterCategory.availability => criteria.availabilityWeekdays.length,
    ContactFilterCategory.contactMethods => <bool>[
      criteria.hasPhone,
      criteria.hasEmail,
      criteria.hasAddress,
    ].where((value) => value).length,
    ContactFilterCategory.eventHistory => <bool>[
      criteria.noInteractionYet,
      criteria.eventHistoryAny,
    ].where((value) => value).length,
    ContactFilterCategory.source => criteria.source == null ? 0 : 1,
    ContactFilterCategory.archived => <bool>[
      criteria.includeArchived && !criteria.archivedOnly,
      criteria.archivedOnly,
    ].where((value) => value).length,
    ContactFilterCategory.phone => criteria.phoneLabels.length,
    ContactFilterCategory.email => criteria.emailLabels.length,
    ContactFilterCategory.address => criteria.addressLabels.length,
    ContactFilterCategory.socialProfile => criteria.socialLabels.length,
    ContactFilterCategory.withEventsToday => criteria.withEventsToday ? 1 : 0,
    ContactFilterCategory.withFutureEvents => criteria.withFutureEvents ? 1 : 0,
    ContactFilterCategory.withoutFutureEvents =>
      criteria.withoutFutureEvents ? 1 : 0,
  };
  if (selectedCount == 0) {
    return ContactFilterSelectionState.all;
  }
  return selectedCount == optionCount
      ? ContactFilterSelectionState.all
      : ContactFilterSelectionState.some;
}

String contactFilterCategorySummary(
  ContactFilterCriteria criteria,
  ContactFilterCategory category, {
  List<ContactGroup> groups = const <ContactGroup>[],
  List<ContactTag> tags = const <ContactTag>[],
}) {
  if (!contactFilterCategoryIsActive(criteria, category)) {
    return 'All';
  }
  return switch (category) {
    ContactFilterCategory.groups => _selectedNames(
      criteria.groupIds,
      groups.map((group) => (group.id, group.name)),
    ),
    ContactFilterCategory.tags => _selectedNames(
      criteria.tagIds,
      tags.map((tag) => (tag.id, tag.name)),
    ),
    ContactFilterCategory.favorites => 'Favorites',
    ContactFilterCategory.availability => _weekdaySummary(
      criteria.availabilityWeekdays,
    ),
    ContactFilterCategory.contactMethods => _joinLabels(<String>[
      if (criteria.hasPhone) 'Phone',
      if (criteria.hasEmail) 'Email',
      if (criteria.hasAddress) 'Address',
    ]),
    ContactFilterCategory.eventHistory => _joinLabels(<String>[
      if (criteria.noInteractionYet) 'No Interaction',
      if (criteria.eventHistoryAny) 'Has History',
    ]),
    ContactFilterCategory.source => switch (criteria.source) {
      ContactSource.manual => 'Manual',
      ContactSource.deviceImport => 'Device Import',
      ContactSource.betterCalendarImport => 'BetterCalendar',
      null => 'All',
    },
    ContactFilterCategory.archived =>
      criteria.archivedOnly ? 'Archived only' : 'Included',
    ContactFilterCategory.phone => _joinLabels(
      criteria.phoneLabels.map(_phoneLabelName).toList(growable: false),
    ),
    ContactFilterCategory.email => _joinLabels(
      criteria.emailLabels.map(_emailLabelName).toList(growable: false),
    ),
    ContactFilterCategory.address => _joinLabels(
      criteria.addressLabels.map(_addressLabelName).toList(growable: false),
    ),
    ContactFilterCategory.socialProfile => _joinLabels(
      criteria.socialLabels.map(_socialLabelName).toList(growable: false),
    ),
    ContactFilterCategory.withEventsToday => 'On',
    ContactFilterCategory.withFutureEvents => 'On',
    ContactFilterCategory.withoutFutureEvents => 'On',
  };
}

ContactFilterCriteria clearContactFilterCategory(
  ContactFilterCriteria criteria,
  ContactFilterCategory category,
) {
  return switch (category) {
    ContactFilterCategory.groups => _copyCriteria(criteria, groupIds: const []),
    ContactFilterCategory.tags => _copyCriteria(criteria, tagIds: const []),
    ContactFilterCategory.favorites => _copyCriteria(
      criteria,
      favoritesOnly: false,
    ),
    ContactFilterCategory.availability => _copyCriteria(
      criteria,
      availabilityWeekdays: const [],
    ),
    ContactFilterCategory.contactMethods => _copyCriteria(
      criteria,
      hasPhone: false,
      hasEmail: false,
      hasAddress: false,
    ),
    ContactFilterCategory.eventHistory => _copyCriteria(
      criteria,
      noInteractionYet: false,
      eventHistoryAny: false,
    ),
    ContactFilterCategory.source => _copyCriteria(
      criteria,
      source: null,
      replaceSource: true,
    ),
    ContactFilterCategory.archived => _copyCriteria(
      criteria,
      includeArchived: false,
      archivedOnly: false,
    ),
    ContactFilterCategory.phone => _copyCriteria(criteria, phoneLabels: const []),
    ContactFilterCategory.email => _copyCriteria(criteria, emailLabels: const []),
    ContactFilterCategory.address => _copyCriteria(
      criteria,
      addressLabels: const [],
    ),
    ContactFilterCategory.socialProfile => _copyCriteria(
      criteria,
      socialLabels: const [],
    ),
    ContactFilterCategory.withEventsToday => _copyCriteria(
      criteria,
      withEventsToday: false,
    ),
    ContactFilterCategory.withFutureEvents => _copyCriteria(
      criteria,
      withFutureEvents: false,
    ),
    ContactFilterCategory.withoutFutureEvents => _copyCriteria(
      criteria,
      withoutFutureEvents: false,
    ),
  };
}

Future<ContactFilterCriteria?> showContactFilterCategorySheet({
  required BuildContext context,
  required ContactFilterCategory category,
  required ContactFilterCriteria criteria,
  List<ContactGroup> groups = const <ContactGroup>[],
  List<ContactTag> tags = const <ContactTag>[],
  ValueChanged<ContactFilterCriteria>? onValidChanged,
}) {
  return showModalBottomSheet<ContactFilterCriteria>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _ContactFilterCategorySheet(
      category: category,
      criteria: criteria,
      groups: groups,
      tags: tags,
      onValidChanged: onValidChanged,
    ),
  );
}

final class ContactFilterOption {
  const ContactFilterOption(this.key, this.label);

  final String key;
  final String label;
}

List<ContactFilterOption> contactFilterOptions({
  required ContactFilterCategory category,
  List<ContactGroup> groups = const <ContactGroup>[],
  List<ContactTag> tags = const <ContactTag>[],
}) {
  return switch (category) {
    ContactFilterCategory.groups =>
      groups
          .map((group) => ContactFilterOption(group.id, group.name))
          .toList(growable: false),
    ContactFilterCategory.tags =>
      tags
          .map((tag) => ContactFilterOption(tag.id, tag.name))
          .toList(growable: false),
    ContactFilterCategory.favorites => const <ContactFilterOption>[
      ContactFilterOption('favorites', 'Favorites'),
    ],
    ContactFilterCategory.availability => <ContactFilterOption>[
      for (var day = 1; day <= 7; day++)
        ContactFilterOption('$day', _weekdayName(day)),
    ],
    ContactFilterCategory.contactMethods => const <ContactFilterOption>[
      ContactFilterOption('phone', 'Phone'),
      ContactFilterOption('email', 'Email'),
      ContactFilterOption('address', 'Address'),
    ],
    ContactFilterCategory.eventHistory => const <ContactFilterOption>[
      ContactFilterOption('no-interaction', 'No Interaction Yet'),
      ContactFilterOption('history', 'Has Event History'),
    ],
    ContactFilterCategory.source => const <ContactFilterOption>[
      ContactFilterOption('all', 'All'),
      ContactFilterOption('manual', 'Manual'),
      ContactFilterOption('device-import', 'Device Import'),
      ContactFilterOption('better-calendar-import', 'BetterCalendar Import'),
    ],
    ContactFilterCategory.archived => const <ContactFilterOption>[
      ContactFilterOption('active', 'Active'),
      ContactFilterOption('included', 'Include archived'),
      ContactFilterOption('only', 'Archived only'),
    ],
    ContactFilterCategory.phone => const <ContactFilterOption>[
      ContactFilterOption(ContactPhoneFilterKeys.noPhone, 'No Phone'),
      ContactFilterOption(ContactPhoneFilterKeys.mobile, 'Mobile'),
      ContactFilterOption(ContactPhoneFilterKeys.home, 'Home'),
      ContactFilterOption(ContactPhoneFilterKeys.work, 'Work'),
      ContactFilterOption(ContactPhoneFilterKeys.other, 'Other'),
    ],
    ContactFilterCategory.email => const <ContactFilterOption>[
      ContactFilterOption(ContactEmailFilterKeys.noEmail, 'No Email'),
      ContactFilterOption(ContactEmailFilterKeys.personal, 'Personal'),
      ContactFilterOption(ContactEmailFilterKeys.work, 'Work'),
      ContactFilterOption(ContactEmailFilterKeys.family, 'Family'),
      ContactFilterOption(ContactEmailFilterKeys.other, 'Other'),
    ],
    ContactFilterCategory.address => const <ContactFilterOption>[
      ContactFilterOption(ContactAddressFilterKeys.notRecorded, 'Not Recorded'),
      ContactFilterOption(ContactAddressFilterKeys.recorded, 'Address Recorded'),
    ],
    ContactFilterCategory.socialProfile => const <ContactFilterOption>[
      ContactFilterOption(ContactSocialFilterKeys.noSocial, 'No Social'),
      ContactFilterOption(ContactSocialFilterKeys.facebook, 'Facebook'),
      ContactFilterOption(ContactSocialFilterKeys.messenger, 'Messenger'),
      ContactFilterOption(ContactSocialFilterKeys.whatsapp, 'WhatsApp'),
      ContactFilterOption(ContactSocialFilterKeys.line, 'LINE'),
      ContactFilterOption(ContactSocialFilterKeys.skype, 'Skype'),
      ContactFilterOption(ContactSocialFilterKeys.instagram, 'Instagram'),
      ContactFilterOption(ContactSocialFilterKeys.x, 'X'),
      ContactFilterOption(ContactSocialFilterKeys.other, 'Other'),
    ],
    ContactFilterCategory.withEventsToday => const <ContactFilterOption>[
      ContactFilterOption('today', 'With Events Today'),
    ],
    ContactFilterCategory.withFutureEvents => const <ContactFilterOption>[
      ContactFilterOption('future', 'With Future Events'),
    ],
    ContactFilterCategory.withoutFutureEvents => const <ContactFilterOption>[
      ContactFilterOption('without-future', 'Without Future Events'),
    ],
  };
}

Set<String> contactFilterActiveKeys(
  ContactFilterCriteria criteria,
  ContactFilterCategory category,
) {
  return switch (category) {
    ContactFilterCategory.groups => criteria.groupIds.toSet(),
    ContactFilterCategory.tags => criteria.tagIds.toSet(),
    ContactFilterCategory.favorites =>
      criteria.favoritesOnly ? <String>{'favorites'} : <String>{},
    ContactFilterCategory.availability =>
      criteria.availabilityWeekdays.map((day) => '$day').toSet(),
    ContactFilterCategory.contactMethods => <String>{
      if (criteria.hasPhone) 'phone',
      if (criteria.hasEmail) 'email',
      if (criteria.hasAddress) 'address',
    },
    ContactFilterCategory.eventHistory => <String>{
      if (criteria.noInteractionYet) 'no-interaction',
      if (criteria.eventHistoryAny) 'history',
    },
    ContactFilterCategory.source => <String>{
      if (criteria.source == null) 'all',
      if (criteria.source == ContactSource.manual) 'manual',
      if (criteria.source == ContactSource.deviceImport) 'device-import',
      if (criteria.source == ContactSource.betterCalendarImport)
        'better-calendar-import',
    },
    ContactFilterCategory.archived => <String>{
      if (!criteria.includeArchived && !criteria.archivedOnly) 'active',
      if (criteria.includeArchived && !criteria.archivedOnly) 'included',
      if (criteria.archivedOnly) 'only',
    },
    ContactFilterCategory.phone => criteria.phoneLabels.toSet(),
    ContactFilterCategory.email => criteria.emailLabels.toSet(),
    ContactFilterCategory.address => criteria.addressLabels.toSet(),
    ContactFilterCategory.socialProfile => criteria.socialLabels.toSet(),
    ContactFilterCategory.withEventsToday =>
      criteria.withEventsToday ? <String>{'today'} : <String>{},
    ContactFilterCategory.withFutureEvents =>
      criteria.withFutureEvents ? <String>{'future'} : <String>{},
    ContactFilterCategory.withoutFutureEvents => criteria.withoutFutureEvents
      ? <String>{'without-future'}
      : <String>{},
  };
}

ContactFilterCriteria contactFilterCriteriaForSelection(
  ContactFilterCriteria criteria,
  ContactFilterCategory category,
  Set<String> selected,
) {
  return switch (category) {
    ContactFilterCategory.groups => _copyCriteria(
      criteria,
      groupIds: selected.toList()..sort(),
    ),
    ContactFilterCategory.tags => _copyCriteria(
      criteria,
      tagIds: selected.toList()..sort(),
    ),
    ContactFilterCategory.favorites => _copyCriteria(
      criteria,
      favoritesOnly: selected.contains('favorites'),
    ),
    ContactFilterCategory.availability => _copyCriteria(
      criteria,
      availabilityWeekdays: selected.map(int.parse).toList()..sort(),
    ),
    ContactFilterCategory.contactMethods => _copyCriteria(
      criteria,
      hasPhone: selected.contains('phone'),
      hasEmail: selected.contains('email'),
      hasAddress: selected.contains('address'),
    ),
    ContactFilterCategory.eventHistory => _copyCriteria(
      criteria,
      noInteractionYet: selected.contains('no-interaction'),
      eventHistoryAny: selected.contains('history'),
    ),
    ContactFilterCategory.source => _copyCriteria(
      criteria,
      source: switch (selected.single) {
        'all' => null,
        'manual' => ContactSource.manual,
        'device-import' => ContactSource.deviceImport,
        _ => ContactSource.betterCalendarImport,
      },
      replaceSource: true,
    ),
    ContactFilterCategory.archived => _copyCriteria(
      criteria,
      includeArchived: selected.contains('included'),
      archivedOnly: selected.contains('only'),
    ),
    ContactFilterCategory.phone => _copyCriteria(
      criteria,
      phoneLabels: selected.toList()..sort(),
    ),
    ContactFilterCategory.email => _copyCriteria(
      criteria,
      emailLabels: selected.toList()..sort(),
    ),
    ContactFilterCategory.address => _copyCriteria(
      criteria,
      addressLabels: selected.toList()..sort(),
    ),
    ContactFilterCategory.socialProfile => _copyCriteria(
      criteria,
      socialLabels: selected.toList()..sort(),
    ),
    ContactFilterCategory.withEventsToday => _copyCriteria(
      criteria,
      withEventsToday: selected.contains('today'),
    ),
    ContactFilterCategory.withFutureEvents => _copyCriteria(
      criteria,
      withFutureEvents: selected.contains('future'),
      withoutFutureEvents: selected.contains('future')
          ? false
          : criteria.withoutFutureEvents,
    ),
    ContactFilterCategory.withoutFutureEvents => _copyCriteria(
      criteria,
      withoutFutureEvents: selected.contains('without-future'),
      withFutureEvents: selected.contains('without-future')
          ? false
          : criteria.withFutureEvents,
    ),
  };
}

String contactFilterValidationLabel(ContactFilterCategory category) {
  return switch (category) {
    ContactFilterCategory.groups => 'group',
    ContactFilterCategory.tags => 'tag',
    ContactFilterCategory.favorites => 'favorite',
    ContactFilterCategory.availability => 'availability day',
    ContactFilterCategory.contactMethods => 'contact method',
    ContactFilterCategory.eventHistory => 'event history option',
    ContactFilterCategory.source => 'source',
    ContactFilterCategory.archived => 'archived option',
    ContactFilterCategory.phone => 'phone option',
    ContactFilterCategory.email => 'email option',
    ContactFilterCategory.address => 'address option',
    ContactFilterCategory.socialProfile => 'social profile',
    ContactFilterCategory.withEventsToday => 'events today',
    ContactFilterCategory.withFutureEvents => 'future events',
    ContactFilterCategory.withoutFutureEvents => 'without future events',
  };
}

final class _ContactFilterCategorySheet extends StatefulWidget {
  const _ContactFilterCategorySheet({
    required this.category,
    required this.criteria,
    required this.groups,
    required this.tags,
    this.onValidChanged,
  });

  final ContactFilterCategory category;
  final ContactFilterCriteria criteria;
  final List<ContactGroup> groups;
  final List<ContactTag> tags;
  final ValueChanged<ContactFilterCriteria>? onValidChanged;

  @override
  State<_ContactFilterCategorySheet> createState() =>
      _ContactFilterCategorySheetState();
}

final class _ContactFilterCategorySheetState
    extends State<_ContactFilterCategorySheet> {
  late final List<ContactFilterOption> _options = _buildOptions();
  late Set<String> _selected = _initialSelection();
  bool _showValidation = false;

  ContactFilterSelectionState get _state {
    if (_options.isEmpty) {
      return ContactFilterSelectionState.all;
    }
    if (contactFilterCategoryIsBoolean(widget.category)) {
      return _selected.isEmpty
          ? ContactFilterSelectionState.all
          : ContactFilterSelectionState.some;
    }
    if (widget.category == ContactFilterCategory.source &&
        _selected.contains('all')) {
      return ContactFilterSelectionState.all;
    }
    if (widget.category == ContactFilterCategory.archived &&
        _selected.contains('active')) {
      return ContactFilterSelectionState.all;
    }
    if (_selected.isEmpty) {
      return ContactFilterSelectionState.all;
    }
    if (_selected.length == _options.length) {
      return ContactFilterSelectionState.all;
    }
    return ContactFilterSelectionState.some;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final label = contactFilterCategoryLabel(widget.category);
    return Material(
      key: Key('filter-sheet-${widget.category.name}'),
      color: AppTheme.surfaceOf(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 12),
            Center(
              child: Container(
                key: const Key('filter-sheet-handle'),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineOf(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    switch (state) {
                      ContactFilterSelectionState.all => 'All',
                      ContactFilterSelectionState.some => 'Some',
                      ContactFilterSelectionState.none => 'None',
                    },
                    key: const Key('filter-sheet-master-state'),
                    style: TextStyle(
                      color: state == ContactFilterSelectionState.none
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TriStateMasterCheckbox(
                    key: const Key('filter-sheet-master-checkbox'),
                    value: switch (state) {
                      ContactFilterSelectionState.all => true,
                      ContactFilterSelectionState.some => null,
                      ContactFilterSelectionState.none => false,
                    },
                    onChanged: (_) => _toggleAll(),
                  ),
                ],
              ),
            ),
            if (_showValidation && _options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Select at least one ${contactFilterValidationLabel(widget.category)}.',
                  key: const Key('filter-sheet-validation'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  return CheckboxListTile(
                    key: Key(
                      'filter-sheet-option-${widget.category.name}-${option.key}',
                    ),
                    minTileHeight: 52,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(option.label),
                    value: _selected.contains(option.key),
                    onChanged: (value) => _toggle(option.key, value == true),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ContactFilterOption> _buildOptions() {
    return contactFilterOptions(
      category: widget.category,
      groups: widget.groups,
      tags: widget.tags,
    );
  }

  Set<String> _initialSelection() {
    if (contactFilterCategoryIsBoolean(widget.category) ||
        widget.category == ContactFilterCategory.source ||
        widget.category == ContactFilterCategory.archived) {
      return _activeKeys(widget.criteria);
    }
    final state = contactFilterCategoryState(
      widget.criteria,
      widget.category,
      groups: widget.groups,
      tags: widget.tags,
    );
    if (state == ContactFilterSelectionState.all) {
      return _options.map((option) => option.key).toSet();
    }
    return _activeKeys(widget.criteria);
  }

  Set<String> _activeKeys(ContactFilterCriteria criteria) {
    return contactFilterActiveKeys(criteria, widget.category);
  }

  void _toggleAll() {
    setState(() {
      if (widget.category == ContactFilterCategory.source) {
        _selected = <String>{'all'};
      } else if (widget.category == ContactFilterCategory.archived) {
        _selected = <String>{'active'};
      } else if (contactFilterCategoryIsBoolean(widget.category)) {
        _selected = _selected.isEmpty
            ? <String>{_options.single.key}
            : <String>{};
      } else {
        _selected = _options.map((option) => option.key).toSet();
      }
      _showValidation = false;
    });
    _notifyValid();
  }

  void _toggle(String key, bool checked) {
    setState(() {
      if (checked) {
        if (widget.category == ContactFilterCategory.source) {
          _selected = <String>{key};
        } else if (widget.category == ContactFilterCategory.archived) {
          _selected = <String>{key};
        } else {
          _selected = {..._selected, key};
        }
      } else {
        _selected.remove(key);
        if (contactFilterCategoryUsesNeutralAll(widget.category) &&
            _selected.isEmpty) {
          _selected = _options.map((option) => option.key).toSet();
        }
      }
      _showValidation = false;
    });
    _notifyValid();
  }

  void _notifyValid() {
    final criteria = _options.isEmpty || _selected.length == _options.length
        ? clearContactFilterCategory(widget.criteria, widget.category)
        : _criteriaForSelection();
    widget.onValidChanged?.call(criteria);
  }

  ContactFilterCriteria _criteriaForSelection() {
    return contactFilterCriteriaForSelection(
      widget.criteria,
      widget.category,
      _selected,
    );
  }
}

ContactFilterCriteria _copyCriteria(
  ContactFilterCriteria value, {
  List<String>? groupIds,
  List<String>? tagIds,
  bool? favoritesOnly,
  List<int>? availabilityWeekdays,
  bool? hasPhone,
  bool? hasEmail,
  bool? hasAddress,
  bool? withEventsToday,
  bool? withFutureEvents,
  bool? withoutFutureEvents,
  bool? noInteractionYet,
  ContactSource? source,
  bool replaceSource = false,
  bool? includeArchived,
  bool? archivedOnly,
  bool? eventHistoryAny,
  List<String>? phoneLabels,
  List<String>? emailLabels,
  List<String>? addressLabels,
  List<String>? socialLabels,
}) {
  return ContactFilterCriteria(
    groupIds: groupIds ?? value.groupIds,
    tagIds: tagIds ?? value.tagIds,
    favoritesOnly: favoritesOnly ?? value.favoritesOnly,
    availabilityWeekdays: availabilityWeekdays ?? value.availabilityWeekdays,
    hasPhone: hasPhone ?? value.hasPhone,
    hasEmail: hasEmail ?? value.hasEmail,
    hasAddress: hasAddress ?? value.hasAddress,
    withEventsToday: withEventsToday ?? value.withEventsToday,
    withFutureEvents: withFutureEvents ?? value.withFutureEvents,
    withoutFutureEvents: withoutFutureEvents ?? value.withoutFutureEvents,
    noInteractionYet: noInteractionYet ?? value.noInteractionYet,
    source: replaceSource ? source : value.source,
    includeArchived: includeArchived ?? value.includeArchived,
    archivedOnly: archivedOnly ?? value.archivedOnly,
    eventHistoryAny: eventHistoryAny ?? value.eventHistoryAny,
    phoneLabels: phoneLabels ?? value.phoneLabels,
    emailLabels: emailLabels ?? value.emailLabels,
    addressLabels: addressLabels ?? value.addressLabels,
    socialLabels: socialLabels ?? value.socialLabels,
  );
}

String _phoneLabelName(String key) {
  return switch (key) {
    ContactPhoneFilterKeys.noPhone => 'No Phone',
    ContactPhoneFilterKeys.mobile => 'Mobile',
    ContactPhoneFilterKeys.home => 'Home',
    ContactPhoneFilterKeys.work => 'Work',
    ContactPhoneFilterKeys.other => 'Other',
    _ => key,
  };
}

String _emailLabelName(String key) {
  return switch (key) {
    ContactEmailFilterKeys.noEmail => 'No Email',
    ContactEmailFilterKeys.personal => 'Personal',
    ContactEmailFilterKeys.work => 'Work',
    ContactEmailFilterKeys.family => 'Family',
    ContactEmailFilterKeys.other => 'Other',
    _ => key,
  };
}

String _addressLabelName(String key) {
  return switch (key) {
    ContactAddressFilterKeys.notRecorded => 'Not Recorded',
    ContactAddressFilterKeys.recorded => 'Address Recorded',
    _ => key,
  };
}

String _socialLabelName(String key) {
  return switch (key) {
    ContactSocialFilterKeys.noSocial => 'No Social',
    ContactSocialFilterKeys.facebook => 'Facebook',
    ContactSocialFilterKeys.messenger => 'Messenger',
    ContactSocialFilterKeys.whatsapp => 'WhatsApp',
    ContactSocialFilterKeys.line => 'LINE',
    ContactSocialFilterKeys.skype => 'Skype',
    ContactSocialFilterKeys.instagram => 'Instagram',
    ContactSocialFilterKeys.x => 'X',
    ContactSocialFilterKeys.other => 'Other',
    _ => key,
  };
}

String _selectedNames(
  List<String> selected,
  Iterable<(String, String)> options,
) {
  final names = <String>[];
  for (final option in options) {
    if (selected.contains(option.$1)) {
      names.add(option.$2);
    }
  }
  if (names.isEmpty) {
    return '${selected.length} selected';
  }
  return names.length <= 2 ? names.join(', ') : '${names.length} selected';
}

String _joinLabels(List<String> labels) => labels.join(' + ');

String _weekdaySummary(List<int> weekdays) {
  const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays.map((day) => names[day - 1]).join(', ');
}

String _weekdayName(int day) {
  const names = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[day - 1];
}

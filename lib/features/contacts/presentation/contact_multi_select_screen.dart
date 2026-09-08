import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_recipient_classifier.dart';
import 'package:rmplanner/features/contacts/presentation/external_handoff.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';

enum ContactSelectionPurpose { generic, text, email, delete, lifecycle }

/// Route arguments for the multi-select picker.
final class MultiSelectArgs {
  const MultiSelectArgs({
    this.initialIds = const <String>[],
    this.title = 'Select Contacts',
    this.allowSmsHandoff = true,
    this.purpose = ContactSelectionPurpose.generic,
    this.groupTargetId,
    this.groupTargetName,
  });

  final List<String> initialIds;
  final String title;
  final bool allowSmsHandoff;
  final ContactSelectionPurpose purpose;
  /// Group Detail supplies this only to make current primary membership
  /// explicit before the caller confirms a reassignment.
  final String? groupTargetId;
  final String? groupTargetName;
}

/// Dedicated selection mode: checkbox rows with group-color dots, Select All /
/// Select None, a live count, and an optional external mass-SMS handoff.
/// The caller receives the final id list via `Navigator.pop(result)`; nothing
/// is persisted by this screen and returning from the SMS app creates NO
/// factual outcome.
final class ContactMultiSelectScreen extends ConsumerStatefulWidget {
  const ContactMultiSelectScreen({required this.args, super.key});

  final MultiSelectArgs args;

  @override
  ConsumerState<ContactMultiSelectScreen> createState() =>
      _ContactMultiSelectScreenState();
}

final class _ContactMultiSelectScreenState
    extends ConsumerState<ContactMultiSelectScreen> {
  late final Set<String> _selected = <String>{...widget.args.initialIds};
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.args.purpose != ContactSelectionPurpose.generic) {
      return _PurposeSpecificContactSelection(args: widget.args);
    }
    final state = ref.watch(contactsControllerProvider);
    final all = state.contacts;
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? all
        : all.where((summary) {
            final contact = summary.contact;
            return contact.displayName.toLowerCase().contains(query) ||
                (contact.firstName?.toLowerCase().contains(query) ?? false) ||
                (contact.lastName?.toLowerCase().contains(query) ?? false);
          }).toList();
    final allVisibleSelected =
        visible.isNotEmpty &&
        visible.every((s) => _selected.contains(s.contact.id));

    return Scaffold(
      appBar: InternalAppBar(
        leading: IconButton(
          key: const Key('multi-select-close'),
          tooltip: 'Cancel',
          iconSize: 28,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(widget.args.title),
        actions: <Widget>[
          FilledButton(
            key: const Key('multi-select-done'),
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
            child: Text('Done (${_selected.length})'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('multi-select-search'),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Text(
                  '${_selected.length} selected',
                  style: TextStyle(
                    color: AppTheme.secondaryTextOf(context),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('multi-select-all'),
                  onPressed: allVisibleSelected
                      ? () => setState(
                          () => _selected.removeAll(
                            visible.map((s) => s.contact.id),
                          ),
                        )
                      : () => setState(
                          () => _selected.addAll(
                            visible.map((s) => s.contact.id),
                          ),
                        ),
                  child: Text(
                    allVisibleSelected ? 'Clear visible' : 'Select All',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'No contacts match.',
                      style: TextStyle(
                        color: AppTheme.secondaryTextOf(context),
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const Key('multi-select-list'),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final summary = visible[index];
                      final checked = _selected.contains(summary.contact.id);
                      return CheckboxListTile(
                        key: Key('multi-select-row-${summary.contact.id}'),
                        value: checked,
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(summary.contact.id);
                          } else {
                            _selected.remove(summary.contact.id);
                          }
                        }),
                        activeColor: Theme.of(context).colorScheme.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Row(
                          children: <Widget>[
                            ContactGroupDot(summary: summary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                summary.contact.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: _selectionSubtitle(summary).isEmpty
                            ? null
                            : Text(
                                _selectionSubtitle(summary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                      );
                    },
                  ),
          ),
          if (widget.args.allowSmsHandoff) ...<Widget>[
            const Divider(height: 1, thickness: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('multi-select-text'),
                        onPressed: _selected.isEmpty
                            ? null
                            : () => _startHandoff(ContactRecipientAction.text),
                        style: _handoffButtonStyle(context),
                        icon: const Icon(Icons.chat_outlined, size: 20),
                        label: const Text('Text'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('multi-select-email'),
                        onPressed: _selected.isEmpty
                            ? null
                            : () => _startHandoff(ContactRecipientAction.email),
                        style: _handoffButtonStyle(context),
                        icon: const Icon(Icons.email_outlined, size: 20),
                        label: const Text('Email'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _handoffButtonStyle(BuildContext context) =>
      FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        disabledBackgroundColor: AppTheme.surfaceVariantOf(context),
        disabledForegroundColor: AppTheme.disabledForegroundOf(context),
      );

  Future<void> _startHandoff(ContactRecipientAction action) async {
    final review = await _recipientReview(action);
    if (!mounted) {
      return;
    }
    if (!review.hasRecipients) {
      final actionLabel = action == ContactRecipientAction.text
          ? 'text-capable phone'
          : 'email address';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'None of the selected contacts have a valid $actionLabel.',
          ),
        ),
      );
      return;
    }
    if (review.needsReview) {
      final continueHandoff = await _showRecipientReview(context, review);
      if (!continueHandoff || !mounted) {
        return;
      }
    }
    final launched = switch (action) {
      ContactRecipientAction.text => await ExternalHandoff.launchMassSms(
        review.recipients,
      ),
      ContactRecipientAction.email => await ExternalHandoff.launchMassEmail(
        review.recipients,
      ),
    };
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == ContactRecipientAction.text
                ? 'No messaging app is available for handoff.'
                : 'No email app is available for handoff.',
          ),
        ),
      );
    }
  }

  Future<ContactRecipientReview> _recipientReview(
    ContactRecipientAction action,
  ) async {
    final profileId = ref.read(contactProfileIdProvider);
    final repository = ref.read(contactRepositoryProvider);
    final state = ref.read(contactsControllerProvider);
    final details = <ContactDetail>[];
    final unavailable = <ContactRecipientExclusion>[];
    for (final summary in state.contacts) {
      if (!_selected.contains(summary.contact.id)) {
        continue;
      }
      try {
        details.add(
          await repository.readContactDetail(
            profileId: profileId,
            contactId: summary.contact.id,
          ),
        );
      } on Object {
        unavailable.add(
          ContactRecipientExclusion(
            contactId: summary.contact.id,
            displayName: summary.contact.displayName,
            reason: 'Contact is no longer available',
          ),
        );
      }
    }
    final classified = classifyContactRecipients(
      details: details,
      action: action,
    );
    return ContactRecipientReview(
      action: action,
      recipients: classified.recipients,
      excluded: <ContactRecipientExclusion>[
        ...classified.excluded,
        ...unavailable,
      ],
    );
  }

  Future<bool> _showRecipientReview(
    BuildContext context,
    ContactRecipientReview review,
  ) async {
    final verb = review.action == ContactRecipientAction.text
        ? 'text'
        : 'email';
    return await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '${_selected.length} selected',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${review.readyCount} contact${review.readyCount == 1 ? '' : 's'} ready to $verb',
                ),
                Text(
                  '${review.excludedCount} contact${review.excludedCount == 1 ? '' : 's'} excluded',
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: review.excluded.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final excluded = review.excluded[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(excluded.displayName),
                        subtitle: Text(excluded.reason),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        key: const Key('recipient-review-cancel'),
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('recipient-review-continue'),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  String _selectionSubtitle(ContactSummary summary) {
    final targetId = widget.args.groupTargetId;
    final targetName = widget.args.groupTargetName;
    if (targetId != null && targetName != null) {
      if (summary.primaryGroup?.id == targetId) {
        return 'Already in $targetName';
      }
      return summary.primaryGroup?.name ?? 'No group';
    }
    return summary.subtitle;
  }
}

/// The final More-menu action modes deliberately load their own all-active
/// universe.  They never inherit Contacts Main's current Status/search/saved
/// filter narrowing, and only the requested purpose appears in the UI.
final class _PurposeSpecificContactSelection extends ConsumerStatefulWidget {
  const _PurposeSpecificContactSelection({required this.args});

  final MultiSelectArgs args;

  @override
  ConsumerState<_PurposeSpecificContactSelection> createState() =>
      _PurposeSpecificContactSelectionState();
}

final class _PurposeSpecificContactSelectionState
    extends ConsumerState<_PurposeSpecificContactSelection> {
  late final Set<String> _selected = <String>{...widget.args.initialIds};
  final TextEditingController _searchController = TextEditingController();
  List<ContactSummary>? _all;
  bool _loading = true;

  ContactSelectionPurpose get _purpose => widget.args.purpose;
  ContactRecipientAction get _recipientAction =>
      _purpose == ContactSelectionPurpose.text
      ? ContactRecipientAction.text
      : ContactRecipientAction.email;

  String get _title => switch (_purpose) {
    ContactSelectionPurpose.text => 'Text Contacts',
    ContactSelectionPurpose.email => 'Email Contacts',
    ContactSelectionPurpose.delete => 'Delete Contacts',
    ContactSelectionPurpose.lifecycle => 'Select Contacts',
    ContactSelectionPurpose.generic => widget.args.title,
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadUniverse());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUniverse() async {
    final profileId = ref.read(contactProfileIdProvider);
    final repository = ref.read(contactRepositoryProvider);
    try {
      late final List<ContactSummary> summaries;
      if (_purpose == ContactSelectionPurpose.delete ||
          _purpose == ContactSelectionPurpose.lifecycle) {
        summaries = await repository.readContacts(
          profileId: profileId,
          criteria: const ContactFilterCriteria(),
          sortBy: ContactSortBy.name,
          today: ref.read(plannerDateSourceProvider).today(),
        );
      } else {
        final candidates = await repository.readRecipientCandidates(
          profileId: profileId,
        );
        final identities = <String>{};
        summaries = <ContactSummary>[
          for (final candidate in candidates)
            if (_isFirstEligibleCandidate(candidate, identities))
              candidate.summary,
        ];
      }
      if (!mounted) return;
      setState(() {
        _all = summaries;
        _selected.retainAll(summaries.map((summary) => summary.contact.id));
        _loading = false;
      });
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isFirstEligibleCandidate(
    ContactRecipientCandidate candidate,
    Set<String> identities,
  ) {
    final recipient = contactRecipientFor(candidate.detail, _recipientAction);
    return recipient != null &&
        identities.add(contactRecipientIdentity(recipient, _recipientAction));
  }

  @override
  Widget build(BuildContext context) {
    final all = _all ?? const <ContactSummary>[];
    final query = _searchController.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? all
        : all.where((summary) {
            final contact = summary.contact;
            return contact.displayName.toLowerCase().contains(query) ||
                (contact.firstName?.toLowerCase().contains(query) ?? false) ||
                (contact.lastName?.toLowerCase().contains(query) ?? false);
          }).toList(growable: false);
    final allVisibleSelected =
        visible.isNotEmpty &&
        visible.every((summary) => _selected.contains(summary.contact.id));
    return Scaffold(
      appBar: InternalAppBar(
        leading: IconButton(
          key: const Key('multi-select-close'),
          tooltip: 'Cancel',
          iconSize: 28,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(_title),
        actions: _purpose == ContactSelectionPurpose.lifecycle
            ? const <Widget>[]
            : <Widget>[
                FilledButton(
                  key: const Key('multi-select-done'),
                  onPressed: _selected.isEmpty ? null : _primaryAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(80, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  ),
                  child: Text('$_primaryLabel (${_selected.length})'),
                ),
              ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('multi-select-search'),
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
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Text(
                  '${_selected.length} selected',
                  style: TextStyle(
                    color: AppTheme.secondaryTextOf(context),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('multi-select-all'),
                  onPressed: visible.isEmpty
                      ? null
                      : allVisibleSelected
                      ? () => setState(
                          () => _selected.removeAll(
                            visible.map((summary) => summary.contact.id),
                          ),
                        )
                      : () => setState(
                          () => _selected.addAll(
                            visible.map((summary) => summary.contact.id),
                          ),
                        ),
                  child: Text(allVisibleSelected ? 'Clear visible' : 'Select All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildList(visible)),
          if (_purpose == ContactSelectionPurpose.lifecycle)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('multi-select-archive'),
                        onPressed: _selected.isEmpty ? null : _confirmArchive,
                        child: const Text('Archive'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('multi-select-delete'),
                        onPressed: _selected.isEmpty ? null : _confirmDelete,
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _primaryLabel =>
      _purpose == ContactSelectionPurpose.delete ? 'Delete' : 'Continue';

  Widget _buildList(List<ContactSummary> visible) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (visible.isEmpty) {
      final message = _purpose == ContactSelectionPurpose.text
          ? 'No text-capable contacts yet.'
          : _purpose == ContactSelectionPurpose.email
          ? 'No contacts with a usable email address yet.'
          : 'No contacts match.';
      return Center(
        child: Text(
          message,
          key: const Key('multi-select-empty'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      key: const Key('multi-select-list'),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final summary = visible[index];
        final checked = _selected.contains(summary.contact.id);
        return CheckboxListTile(
          key: Key('multi-select-row-${summary.contact.id}'),
          value: checked,
          onChanged: (value) => setState(() {
            if (value == true) {
              _selected.add(summary.contact.id);
            } else {
              _selected.remove(summary.contact.id);
            }
          }),
          activeColor: Theme.of(context).colorScheme.primary,
          controlAffinity: ListTileControlAffinity.leading,
          title: Row(
            children: <Widget>[
              ContactGroupDot(summary: summary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.contact.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          subtitle: summary.subtitle.isEmpty
              ? null
              : Text(summary.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }

  Future<void> _primaryAction() async {
    if (_purpose == ContactSelectionPurpose.delete) {
      await _confirmDelete();
    } else {
      await _startHandoff();
    }
  }

  Future<void> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${_selected.length} contacts?'),
        content: const Text(
          'These contacts will move to Archived contacts. You can restore them from Archived contacts.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('multi-select-confirm-archive'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final profileId = ref.read(contactProfileIdProvider);
    final repository = ref.read(contactRepositoryProvider);
    for (final id in _selected) {
      await repository.archiveContact(profileId: profileId, contactId: id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _startHandoff() async {
    final review = await _recipientReview();
    if (!mounted) return;
    if (!review.hasRecipients) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_purpose == ContactSelectionPurpose.text
              ? 'No selected contacts still have a valid text-capable phone.'
              : 'No selected contacts still have a usable email address.'),
        ),
      );
      return;
    }
    if (review.needsReview && !await _showRecipientReview(context, review)) {
      return;
    }
    if (!mounted) return;
    final launched = _purpose == ContactSelectionPurpose.text
        ? await ExternalHandoff.launchMassSms(review.recipients)
        : await ExternalHandoff.launchMassEmail(review.recipients);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_purpose == ContactSelectionPurpose.text
              ? 'No messaging app is available for handoff.'
              : 'No email app is available for handoff.'),
        ),
      );
    }
  }

  Future<ContactRecipientReview> _recipientReview() async {
    final profileId = ref.read(contactProfileIdProvider);
    final repository = ref.read(contactRepositoryProvider);
    final names = <String, String>{
      for (final summary in _all ?? const <ContactSummary>[])
        summary.contact.id: summary.contact.displayName,
    };
    final details = <ContactDetail>[];
    final unavailable = <ContactRecipientExclusion>[];
    for (final id in _selected) {
      try {
        details.add(await repository.readContactDetail(profileId: profileId, contactId: id));
      } on Object {
        unavailable.add(ContactRecipientExclusion(
          contactId: id,
          displayName: names[id] ?? 'Contact',
          reason: 'Contact is no longer available',
        ));
      }
    }
    final classified = classifyContactRecipients(
      details: details,
      action: _recipientAction,
    );
    return ContactRecipientReview(
      action: _recipientAction,
      recipients: classified.recipients,
      excluded: <ContactRecipientExclusion>[...classified.excluded, ...unavailable],
    );
  }

  Future<void> _confirmDelete() async {
    if (_purpose == ContactSelectionPurpose.lifecycle) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Delete ${_selected.length} contacts?'),
          content: const Text(
            'These contacts will move to Recently Deleted. You can restore them from Recently Deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('multi-select-confirm-delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final profileId = ref.read(contactProfileIdProvider);
      await ref.read(contactRepositoryProvider).moveContactsToRecentlyDeleted(
        profileId: profileId,
        contactIds: _selected,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<_DeleteAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${_selected.length} contacts?'),
        content: const Text(
          'These contacts will move to Recently Deleted. You can restore them from Recently Deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DeleteAction.archive),
            child: const Text('Archive instead'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('multi-select-confirm-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(_DeleteAction.delete),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final profileId = ref.read(contactProfileIdProvider);
    final repository = ref.read(contactRepositoryProvider);
    if (choice == _DeleteAction.archive) {
      for (final id in _selected) {
        await repository.archiveContact(profileId: profileId, contactId: id);
      }
    } else {
      await repository.moveContactsToRecentlyDeleted(
        profileId: profileId,
        contactIds: _selected,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _showRecipientReview(
    BuildContext context,
    ContactRecipientReview review,
  ) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) => _ResponsiveRecipientReviewSheet(
            selectedCount: _selected.length,
            review: review,
          ),
        ) ??
        false;
  }
}

enum _DeleteAction { archive, delete }

final class _ResponsiveRecipientReviewSheet extends StatelessWidget {
  const _ResponsiveRecipientReviewSheet({
    required this.selectedCount,
    required this.review,
  });

  final int selectedCount;
  final ContactRecipientReview review;

  @override
  Widget build(BuildContext context) {
    final listHeight = math.min(
      240.0,
      math.max(88.0, MediaQuery.sizeOf(context).height * .30),
    );
    final verb = review.action == ContactRecipientAction.text ? 'text' : 'email';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('$selectedCount selected', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${review.readyCount} contact${review.readyCount == 1 ? '' : 's'} ready to $verb'),
            Text('${review.excludedCount} contact${review.excludedCount == 1 ? '' : 's'} newly excluded'),
            const SizedBox(height: 8),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                key: const Key('recipient-review-exclusions'),
                itemCount: review.excluded.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final excluded = review.excluded[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(excluded.displayName),
                    subtitle: Text(excluded.reason),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    key: const Key('recipient-review-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('recipient-review-continue'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

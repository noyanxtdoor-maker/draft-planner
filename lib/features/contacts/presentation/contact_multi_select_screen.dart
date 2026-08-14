import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/external_handoff.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';

/// Route arguments for the multi-select picker.
final class MultiSelectArgs {
  const MultiSelectArgs({
    this.initialIds = const <String>[],
    this.title = 'Select Contacts',
    this.allowSmsHandoff = true,
  });

  final List<String> initialIds;
  final String title;
  final bool allowSmsHandoff;
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
                  '${_selected.length} / ${all.length} selected',
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
                    allVisibleSelected ? 'Select None' : 'Select All',
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
                        subtitle: summary.subtitle.isEmpty
                            ? null
                            : Text(
                                summary.subtitle,
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
                child: FilledButton.icon(
                  key: const Key('multi-select-send-message'),
                  onPressed: _selected.isEmpty ? null : _sendMessage,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor: AppTheme.surfaceVariantOf(
                      context,
                    ),
                    disabledForegroundColor: AppTheme.disabledForegroundOf(
                      context,
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  label: Text(
                    _selected.isEmpty
                        ? 'Send Message'
                        : 'Send Message (${_selected.length})',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final profileId = ref.read(contactProfileIdProvider);
    final repository = ref.read(contactRepositoryProvider);
    final phones = <String>[];
    for (final id in _selected) {
      try {
        final detail = await repository.readContactDetail(
          profileId: profileId,
          contactId: id,
        );
        phones.addAll(
          detail.methods
              .where(
                (method) =>
                    method.type == ContactMethodType.phone &&
                    method.rawValue.isNotEmpty,
              )
              .map((method) => method.rawValue),
        );
      } on Object {
        // A missing/deleted Contact simply contributes no number.
      }
    }
    if (phones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('None of the selected contacts have a phone number.'),
          ),
        );
      }
      return;
    }
    final launched = await ExternalHandoff.launchMassSms(phones);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messaging app is available for handoff.'),
        ),
      );
      return;
    }
    // Returning from the messaging app creates NO factual outcome — the user
    // decides whether to record anything, and that record is a plain note.
    if (!mounted) {
      return;
    }
    await ExternalHandoff.showReturnSheet(
      context,
      contactDisplayName:
          '${_selected.length} contact${_selected.length == 1 ? '' : 's'}',
      onAddNote: (note) async {
        final repository = ref.read(contactRepositoryProvider);
        final profileId = ref.read(contactProfileIdProvider);
        for (final id in _selected) {
          await repository.addNote(
            profileId: profileId,
            contactId: id,
            text: note,
          );
        }
      },
    );
  }
}

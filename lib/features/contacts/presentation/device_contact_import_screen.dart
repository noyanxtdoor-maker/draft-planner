import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

/// Reads device contacts as lightweight drafts.  Injectable so tests can
/// drive the whole import flow without a real address book.
typedef DeviceContactsReader = Future<List<DeviceContactDraft>> Function();

/// Default reader backed by flutter_contacts.  Reads only display names and
/// phone/email values; nothing is uploaded, and the caller (the screen) only
/// imports the rows the user explicitly selects.
Future<List<DeviceContactDraft>> _readDeviceContacts() async {
  final contacts = await FlutterContacts.getAll(
    properties: const {
      ContactProperty.name,
      ContactProperty.phone,
      ContactProperty.email,
    },
  );
  return <DeviceContactDraft>[
    for (final contact in contacts)
      if ((contact.displayName ?? '').trim().isNotEmpty)
        DeviceContactDraft(
          displayName: contact.displayName!.trim(),
          firstName: contact.name?.first,
          lastName: contact.name?.last,
          phones: <String>[
            for (final phone in contact.phones)
              if (phone.number.trim().isNotEmpty) phone.number.trim(),
          ],
          emails: <String>[
            for (final email in contact.emails)
              if (email.address.trim().isNotEmpty) email.address.trim(),
          ],
        ),
  ];
}

/// Selected-only device contact import.
///
/// Permission is requested just in time, on an explicit user tap.  A denied
/// permission keeps every manual workflow fully functional.  Even with
/// permission granted, only the Contacts the user checks are imported; the
/// repository flags duplicates by normalized phone/email and never merges
/// silently.  Imported records stay in the local profile.
final class DeviceContactImportScreen extends ConsumerStatefulWidget {
  const DeviceContactImportScreen({
    this.deviceReader = _readDeviceContacts,
    super.key,
  });

  final DeviceContactsReader deviceReader;

  @override
  ConsumerState<DeviceContactImportScreen> createState() =>
      _DeviceContactImportScreenState();
}

enum _ImportPhase {
  explain,
  loading,
  denied,
  failed,
  select,
  importing,
  result,
}

final class _DeviceContactImportScreenState
    extends ConsumerState<DeviceContactImportScreen> {
  _ImportPhase _phase = _ImportPhase.explain;
  List<DeviceContactDraft> _deviceContacts = <DeviceContactDraft>[];
  final Set<int> _selectedIndexes = <int>{};
  String? _error;
  ContactImportResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Import from Device')),
      body: switch (_phase) {
        _ImportPhase.explain => _buildExplain(),
        _ImportPhase.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        _ImportPhase.denied => _buildDenied(),
        _ImportPhase.failed => _buildFailed(),
        _ImportPhase.select => _buildSelect(),
        _ImportPhase.importing => const Center(
          child: CircularProgressIndicator(),
        ),
        _ImportPhase.result => _buildResult(),
      },
    );
  }

  Widget _buildExplain() {
    return ListView(
      padding: InternalScreen.pagePadding,
      children: <Widget>[
        const SizedBox(height: 8),
        const Icon(Icons.contact_page_outlined, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Import selected contacts from your device',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          'Only the contacts you select are imported, and they stay on this '
          'device inside your private profile. Nothing is uploaded.',
          style: TextStyle(
            color: AppTheme.secondaryTextOf(context),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Next Transfer only reads names and phone/email values — never '
          'messages, call logs, or photos.',
          style: TextStyle(
            color: AppTheme.secondaryTextOf(context),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('device-import-start'),
          onPressed: () => unawaited(_startImport()),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          icon: const Icon(Icons.contact_page_outlined, size: 20),
          label: const Text('Import from device'),
        ),
      ],
    );
  }

  Widget _buildDenied() {
    return ListView(
      padding: InternalScreen.pagePadding,
      children: <Widget>[
        const SizedBox(height: 8),
        const Icon(Icons.contact_page_outlined, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Permission denied',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(
              color: AppTheme.warningOf(context),
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Contacts stay in your head and your manual workflow. You can still '
          'create, edit, search, group, and link contacts by hand, and '
          'everything continues to work offline.',
          style: TextStyle(
            color: AppTheme.secondaryTextOf(context),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('device-import-denied-done'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Continue without import'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('device-import-retry'),
          onPressed: () => unawaited(_startImport()),
          child: const Text('Try again'),
        ),
      ],
    );
  }

  Widget _buildFailed() {
    return ListView(
      padding: InternalScreen.pagePadding,
      children: <Widget>[
        const SizedBox(height: 8),
        const Icon(Icons.error_outline, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Contacts could not be read',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          _error ??
              'This device could not provide its contact list right now. '
                  'Manual contact workflows are unaffected.',
          style: TextStyle(
            color: AppTheme.secondaryTextOf(context),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('device-import-failed-done'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Continue without import'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('device-import-failed-retry'),
          onPressed: () => unawaited(_startImport()),
          child: const Text('Try again'),
        ),
      ],
    );
  }

  Widget _buildSelect() {
    final selectedCount = _selectedIndexes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$selectedCount of ${_deviceContacts.length} selected',
                  style: TextStyle(
                    color: AppTheme.secondaryTextOf(context),
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                key: const Key('device-import-select-all'),
                onPressed: () => setState(() {
                  if (selectedCount == _deviceContacts.length) {
                    _selectedIndexes.clear();
                  } else {
                    _selectedIndexes.addAll(
                      List<int>.generate(
                        _deviceContacts.length,
                        (index) => index,
                      ),
                    );
                  }
                }),
                child: Text(
                  selectedCount == _deviceContacts.length
                      ? 'Select None'
                      : 'Select All',
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: _deviceContacts.isEmpty
              ? Center(
                  child: Text(
                    'No contacts found on this device.',
                    style: TextStyle(
                      color: AppTheme.secondaryTextOf(context),
                    ),
                  ),
                )
              : ListView.builder(
                  key: const Key('device-import-list'),
                  itemCount: _deviceContacts.length,
                  itemBuilder: (context, index) {
                    final draft = _deviceContacts[index];
                    final methodText = <String>[
                      ...draft.phones.take(2),
                      ...draft.emails.take(1),
                    ].join(' • ');
                    return CheckboxListTile(
                      key: Key('device-import-row-$index'),
                      value: _selectedIndexes.contains(index),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selectedIndexes.add(index);
                        } else {
                          _selectedIndexes.remove(index);
                        }
                      }),
                      activeColor: Theme.of(context).colorScheme.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        draft.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: methodText.isEmpty
                          ? null
                          : Text(
                              methodText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                    );
                  },
                ),
        ),
        const Divider(height: 1, thickness: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: FilledButton(
              key: const Key('device-import-confirm'),
              onPressed: selectedCount == 0 ? null : () => unawaited(_import()),
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
              child: Text(
                selectedCount == 0
                    ? 'Select contacts'
                    : 'Import $selectedCount',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    return ListView(
      padding: InternalScreen.pagePadding,
      children: <Widget>[
        const SizedBox(height: 8),
        Icon(
          result.createdCount > 0
              ? Icons.check_circle_outline
              : Icons.info_outline,
          size: 56,
          color: result.createdCount > 0
              ? AppTheme.rose
              : AppTheme.secondaryTextOf(context),
        ),
        const SizedBox(height: 16),
        Text(
          result.createdCount > 0
              ? '${result.createdCount} contact'
                    '${result.createdCount == 1 ? '' : 's'} imported'
              : 'Nothing new imported',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (result.duplicateContactIds.isNotEmpty) ...<Widget>[
          Text(
            'Possible duplicates were NOT merged — they were left untouched:',
            style: TextStyle(
              color: AppTheme.secondaryTextOf(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          for (final name in result.duplicateContactIds.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 16,
                    color: AppTheme.warningOf(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('device-import-done'),
          onPressed: () => Navigator.of(context).maybePop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Future<void> _startImport() async {
    setState(() => _phase = _ImportPhase.loading);
    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      final granted =
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
      if (!mounted) {
        return;
      }
      if (!granted) {
        setState(() => _phase = _ImportPhase.denied);
        return;
      }
      final drafts = await widget.deviceReader();
      if (!mounted) {
        return;
      }
      setState(() {
        _deviceContacts = drafts;
        _selectedIndexes.clear();
        _phase = _ImportPhase.select;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _error = 'Device contacts could not be read.';
          _phase = _ImportPhase.failed;
        });
      }
    }
  }

  Future<void> _import() async {
    setState(() => _phase = _ImportPhase.importing);
    final drafts = <DeviceContactDraft>[
      for (final index in _selectedIndexes.toList()..sort())
        _deviceContacts[index],
    ];
    try {
      final result = await ref
          .read(contactRepositoryProvider)
          .importDeviceContacts(
            profileId: ref.read(contactProfileIdProvider),
            drafts: drafts,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _phase = _ImportPhase.result;
      });
    } on ContactValidationException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _phase = _ImportPhase.select;
        });
      }
    }
  }
}

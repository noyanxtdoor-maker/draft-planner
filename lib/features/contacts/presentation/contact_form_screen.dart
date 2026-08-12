import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';

enum ContactFormMode { create, edit }

/// Progressive Add/Edit Contact form.  Only name + groups are visible by
/// default; Phone, Email, Social, Address, Availability, and Notes expand on
/// demand.  A usable display name is required; no phone or email is ever
/// required.
final class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen.create({super.key})
    : mode = ContactFormMode.create,
      contactId = null;

  const ContactFormScreen.edit({required this.contactId, super.key})
    : mode = ContactFormMode.edit;

  final ContactFormMode mode;
  final String? contactId;

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

final class _MethodRow {
  _MethodRow({required this.type, required this.controller});

  final ContactMethodType type;
  final TextEditingController controller;
}

final class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final List<_MethodRow> _methodRows = <_MethodRow>[];
  final List<ContactAvailability> _availability = <ContactAvailability>[];
  List<String> _groupIds = <String>[];
  String? _primaryGroupId;
  ContactPreferredMethod _preferredMethod = ContactPreferredMethod.message;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == ContactFormMode.edit) {
      _loading = true;
      unawaited(Future<void>.microtask(_loadExisting));
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    for (final row in _methodRows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final detail = await ref.read(
        contactDetailProvider(widget.contactId!).future,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _firstNameController.text = detail.contact.firstName ?? '';
        _lastNameController.text = detail.contact.lastName ?? '';
        _addressController.text = detail.contact.addressText ?? '';
        _preferredMethod = detail.contact.preferredContactMethod;
        _groupIds = detail.groups.map((group) => group.id).toList();
        _primaryGroupId = detail.primaryGroupId;
        _availability.addAll(detail.availability);
        for (final method in detail.methods) {
          _methodRows.add(
            _MethodRow(
              type: method.type,
              controller: TextEditingController(text: method.rawValue),
            ),
          );
        }
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String get _displayName =>
      '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
          .trim();

  @override
  Widget build(BuildContext context) {
    final groups =
        ref.watch(contactGroupsProvider).value ?? const <ContactGroup>[];
    return Scaffold(
      appBar: InternalAppBar(
        title: Text(
          widget.mode == ContactFormMode.create
              ? 'Add Contact'
              : 'Edit Contact',
        ),
        leading: IconButton(
          key: const Key('contact-form-close'),
          tooltip: 'Close',
          iconSize: 28,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
        actions: <Widget>[_buildSaveButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  key: const Key('contact-form-scroll'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                  children: <Widget>[
                    _field(
                      key: const Key('contact-first-name'),
                      controller: _firstNameController,
                      label: 'First Name',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    _field(
                      key: const Key('contact-last-name'),
                      controller: _lastNameController,
                      label: 'Last Name',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 28),
                    _GroupsField(
                      groups: groups,
                      selectedIds: _groupIds,
                      primaryGroupId: _primaryGroupId,
                      onChanged: (ids, primaryId) => setState(() {
                        _groupIds = ids;
                        _primaryGroupId = primaryId;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _PreferredMethodField(
                      value: _preferredMethod,
                      onChanged: (value) =>
                          setState(() => _preferredMethod = value),
                    ),
                    const Divider(height: 32),
                    for (final row in _methodRows) ...<Widget>[
                      _MethodRowTile(
                        row: row,
                        onRemove: () => setState(() => _methodRows.remove(row)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_addressController.text.isEmpty &&
                        !_addressExpanded) ...<Widget>[
                      _ProgressiveRow(
                        key: const Key('add-address-row'),
                        icon: Icons.place_outlined,
                        label: 'Address',
                        onTap: () => setState(() => _addressExpanded = true),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_addressExpanded) ...<Widget>[
                      _field(
                        key: const Key('contact-address'),
                        controller: _addressController,
                        label: 'Address',
                        onChanged: (_) => setState(() {}),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('remove-address'),
                          onPressed: () {
                            _addressController.clear();
                            setState(() => _addressExpanded = false);
                          },
                          child: const Text('Remove'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_availability.isEmpty) ...<Widget>[
                      _ProgressiveRow(
                        key: const Key('add-availability-row'),
                        icon: Icons.schedule_outlined,
                        label: 'Availability',
                        onTap: _editAvailability,
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_availability.isNotEmpty) ...<Widget>[
                      _AvailabilityTile(
                        windows: _availability,
                        onEdit: _editAvailability,
                        onRemove: (window) =>
                            setState(() => _availability.remove(window)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_noteController.text.isEmpty &&
                        !_notesExpanded) ...<Widget>[
                      _ProgressiveRow(
                        key: const Key('add-notes-row'),
                        icon: Icons.notes_outlined,
                        label: 'Notes',
                        onTap: () => setState(() => _notesExpanded = true),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_notesExpanded) ...<Widget>[
                      TextFormField(
                        key: const Key('contact-notes'),
                        controller: _noteController,
                        maxLines: 4,
                        decoration: _decoration('Notes'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  bool _addressExpanded = false;
  bool _notesExpanded = false;

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    bool required = false,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 17),
      decoration: _decoration(label),
      validator: required
          ? (value) => (value ?? '').trim().isEmpty ? 'Required' : null
          : null,
    );
  }

  Widget _buildSaveButton() {
    return Semantics(
      button: true,
      label: 'Save',
      child: FilledButton(
        key: const Key('save-contact-button'),
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: AppTheme.rose,
          foregroundColor: AppTheme.background,
        ),
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save'),
      ),
    );
  }

  Future<void> _editAvailability() async {
    final result = await showModalBottomSheet<List<ContactAvailability>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _AvailabilityEditor(
        initial: List<ContactAvailability>.from(_availability),
      ),
    );
    if (result != null && mounted) {
      setState(
        () => _availability
          ..clear()
          ..addAll(result),
      );
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final displayName = _displayName;
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A Contact needs a usable name.')),
      );
      return;
    }
    setState(() => _saving = true);
    final ids = ref.read(plannerIdentifierSourceProvider);
    final contactId = widget.mode == ContactFormMode.create
        ? ids.nextUuid()
        : widget.contactId!;
    final draft = ContactDraft(
      id: contactId,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      displayName: displayName,
      preferredContactMethod: _preferredMethod,
      isFavorite: false,
      addressText: _addressController.text,
      source: ContactSource.manual,
      methods: <ContactMethodDraft>[
        for (final row in _methodRows)
          if (row.controller.text.trim().isNotEmpty)
            ContactMethodDraft(type: row.type, value: row.controller.text),
      ],
      groupIds: _groupIds,
      primaryGroupId: _primaryGroupId,
      availability: List<ContactAvailability>.from(_availability),
      initialNoteText: widget.mode == ContactFormMode.create
          ? _noteController.text
          : null,
    );
    final profileId = ref.read(contactProfileIdProvider);
    try {
      final contact = widget.mode == ContactFormMode.create
          ? await ref
                .read(contactRepositoryProvider)
                .createContact(profileId: profileId, draft: draft)
          : await ref
                .read(contactRepositoryProvider)
                .updateContact(
                  profileId: profileId,
                  contactId: contactId,
                  draft: draft,
                );
      if (widget.mode == ContactFormMode.edit &&
          _noteController.text.trim().isNotEmpty) {
        await ref
            .read(contactRepositoryProvider)
            .addNote(
              profileId: profileId,
              contactId: contactId,
              text: _noteController.text,
            );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(contact);
    } on ContactValidationException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact could not be saved. Your input is intact.'),
          ),
        );
      }
    }
  }
}

InputDecoration _decoration(String label) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: AppTheme.outline, width: 1),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: InternalScreen.fieldLabel,
    filled: true,
    fillColor: const Color(0xFF181A1E),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  );
}

final class _ProgressiveRow extends StatelessWidget {
  const _ProgressiveRow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        foregroundColor: AppTheme.rose,
        textStyle: AppTypography.button,
      ),
      icon: Icon(icon, size: 22),
      label: Text(label),
    );
  }
}

final class _GroupsField extends StatelessWidget {
  const _GroupsField({
    required this.groups,
    required this.selectedIds,
    required this.primaryGroupId,
    required this.onChanged,
  });

  final List<ContactGroup> groups;
  final List<String> selectedIds;
  final String? primaryGroupId;
  final void Function(List<String> ids, String? primaryId) onChanged;

  @override
  Widget build(BuildContext context) {
    final activeGroups = groups
        .where((group) => !group.isArchived)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          key: const Key('contact-groups-field'),
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final result = await showModalBottomSheet<(List<String>, String?)>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (sheetContext) => _GroupPicker(
                groups: activeGroups,
                selectedIds: selectedIds,
                primaryGroupId: primaryGroupId,
              ),
            );
            if (result != null) {
              onChanged(result.$1, result.$2);
            }
          },
          child: InputDecorator(
            decoration: _decoration(
              'Groups',
            ).copyWith(suffixIcon: const Icon(Icons.arrow_drop_down, size: 24)),
            child: selectedIds.isEmpty
                ? const Text(
                    'No groups',
                    style: TextStyle(color: Color(0xFF9CA0A6), fontSize: 16),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final id in selectedIds)
                        Builder(
                          builder: (context) {
                            final group = groups
                                .where((g) => g.id == id)
                                .firstOrNull;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1E21),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: group == null
                                      ? const Color(0xFF2A2D31)
                                      : Color(group.colorValue),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (id == primaryGroupId) ...<Widget>[
                                    const Icon(
                                      Icons.star,
                                      size: 12,
                                      color: AppTheme.rose,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    group?.name ?? 'Group',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

final class _GroupPicker extends StatefulWidget {
  const _GroupPicker({
    required this.groups,
    required this.selectedIds,
    required this.primaryGroupId,
  });

  final List<ContactGroup> groups;
  final List<String> selectedIds;
  final String? primaryGroupId;

  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

final class _GroupPickerState extends State<_GroupPicker> {
  late final Set<String> _selected;
  String? _primary;

  @override
  void initState() {
    super.initState();
    _selected = <String>{...widget.selectedIds};
    _primary = widget.primaryGroupId;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                'Groups',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'A group can be primary for its color accent.',
                style: TextStyle(color: Color(0xFF9CA0A6), fontSize: 13),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final group in widget.groups)
                    CheckboxListTile(
                      key: Key('group-option-${group.id}'),
                      value: _selected.contains(group.id),
                      activeColor: Color(group.colorValue),
                      title: Row(
                        children: <Widget>[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(group.colorValue),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(group.name),
                        ],
                      ),
                      secondary: group.id == _primary
                          ? const Icon(
                              Icons.star,
                              color: AppTheme.rose,
                              size: 20,
                            )
                          : null,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(group.id);
                            _primary ??= group.id;
                          } else {
                            _selected.remove(group.id);
                            if (_primary == group.id) {
                              _primary = _selected.isEmpty
                                  ? null
                                  : _selected.first;
                            }
                          }
                        });
                      },
                    ),
                  if (widget.groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Create a group from the Contacts menu first.',
                        style: TextStyle(color: Color(0xFF9CA0A6)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                key: const Key('groups-picker-done'),
                onPressed: () =>
                    Navigator.of(context).pop((_selected.toList(), _primary)),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PreferredMethodField extends StatelessWidget {
  const _PreferredMethodField({required this.value, required this.onChanged});

  final ContactPreferredMethod value;
  final ValueChanged<ContactPreferredMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Preferred contact method',
          style: InternalScreen.fieldLabel,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ContactPreferredMethod>(
          segments: const <ButtonSegment<ContactPreferredMethod>>[
            ButtonSegment<ContactPreferredMethod>(
              value: ContactPreferredMethod.message,
              icon: Icon(Icons.chat_outlined, size: 18),
              label: Text('Message'),
            ),
            ButtonSegment<ContactPreferredMethod>(
              value: ContactPreferredMethod.call,
              icon: Icon(Icons.call_outlined, size: 18),
              label: Text('Call'),
            ),
            ButtonSegment<ContactPreferredMethod>(
              value: ContactPreferredMethod.email,
              icon: Icon(Icons.mail_outline, size: 18),
              label: Text('Email'),
            ),
          ],
          selected: <ContactPreferredMethod>{value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

final class _MethodRowTile extends StatelessWidget {
  const _MethodRowTile({required this.row, required this.onRemove});

  final _MethodRow row;
  final VoidCallback onRemove;

  static const Map<ContactMethodType, String> _typeLabel =
      <ContactMethodType, String>{
        ContactMethodType.phone: 'Phone',
        ContactMethodType.email: 'Email',
        ContactMethodType.social: 'Social Profile',
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: TextFormField(
            key: Key('contact-method-${row.type.name}'),
            controller: row.controller,
            keyboardType: row.type == ContactMethodType.phone
                ? TextInputType.phone
                : row.type == ContactMethodType.email
                ? TextInputType.emailAddress
                : TextInputType.text,
            decoration: _decoration(_typeLabel[row.type]!),
            onChanged: (_) {},
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: Key('remove-method-${row.type.name}'),
          tooltip: 'Remove',
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 22),
        ),
      ],
    );
  }
}

final class _AvailabilityTile extends StatelessWidget {
  const _AvailabilityTile({
    required this.windows,
    required this.onEdit,
    required this.onRemove,
  });

  final List<ContactAvailability> windows;
  final VoidCallback onEdit;
  final ValueChanged<ContactAvailability> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text('Availability', style: InternalScreen.sectionHeading),
            ),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ],
        ),
        for (final window in windows)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule, size: 20),
            title: Text(
              '${_weekdayName(window.weekday)}  '
              '${_formatMinute(window.startMinute)} – ${_formatMinute(window.endMinute)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onRemove(window),
            ),
          ),
      ],
    );
  }

  static String _weekdayName(int weekday) {
    const names = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  static String _formatMinute(int minute) {
    final hour24 = minute ~/ 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minuteText = (minute % 60).toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minuteText $period';
  }
}

final class _AvailabilityEditor extends StatefulWidget {
  const _AvailabilityEditor({required this.initial});

  final List<ContactAvailability> initial;

  @override
  State<_AvailabilityEditor> createState() => _AvailabilityEditorState();
}

final class _AvailabilityEditorState extends State<_AvailabilityEditor> {
  late final List<ContactAvailability> _windows = <ContactAvailability>[
    ...widget.initial,
  ];
  int _weekday = DateTime.monday;
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 21, minute: 0);

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Availability',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('availability-weekday'),
              initialValue: _weekday,
              decoration: _decoration('Day'),
              items: <DropdownMenuItem<int>>[
                for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                  DropdownMenuItem<int>(
                    value: day,
                    child: Text(_weekdayName(day)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _weekday = value ?? _weekday),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: true),
                    child: InputDecorator(
                      decoration: _decoration('From'),
                      child: Text(
                        _formatMinute(_start.hour * 60 + _start.minute),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: false),
                    child: InputDecorator(
                      decoration: _decoration('To'),
                      child: Text(_formatMinute(_end.hour * 60 + _end.minute)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('availability-add-window'),
              onPressed: () {
                final startMinute = _start.hour * 60 + _start.minute;
                final endMinute = _end.hour * 60 + _end.minute;
                if (endMinute <= startMinute) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End time must be after start time.'),
                    ),
                  );
                  return;
                }
                setState(() {
                  _windows.add(
                    ContactAvailability(
                      weekday: _weekday,
                      startMinute: startMinute,
                      endMinute: endMinute,
                    ),
                  );
                });
              },
              child: const Text('Add window'),
            ),
            if (_windows.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (final window in _windows)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_weekdayName(window.weekday)}  '
                    '${_formatMinute(window.startMinute)} – ${_formatMinute(window.endMinute)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _windows.remove(window)),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('availability-done'),
              onPressed: () => Navigator.of(context).pop(_windows),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayName(int weekday) {
    const names = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  static String _formatMinute(int minute) {
    final hour24 = minute ~/ 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minuteText = (minute % 60).toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minuteText $period';
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/contact_reference_style.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_method_entry_row.dart';
import 'package:rmplanner/features/contacts/presentation/contact_method_visuals.dart';
import 'package:rmplanner/features/contacts/presentation/unsaved_changes_guard.dart';

/// Payload emitted only by the scoped Contact Information editor. Address,
/// map, Group, and all other Contact owners belong to their own scoped flows.
final class ContactInformationEditResult {
  const ContactInformationEditResult({
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.preferredContactMethod,
    required this.methods,
  });

  final String firstName;
  final String lastName;
  final String displayName;
  final ContactPreferredMethod preferredContactMethod;
  final List<ContactMethodDraft> methods;
}

/// The saved Contact counterpart of Add Contact's method-entry presentation.
/// It preserves A1's narrow identity-and-methods result boundary.
final class ContactInformationEditor extends StatefulWidget {
  const ContactInformationEditor({required this.detail, super.key});

  final ContactDetail detail;

  @override
  State<ContactInformationEditor> createState() =>
      _ContactInformationEditorState();
}

final class _ContactInformationEditorState
    extends State<ContactInformationEditor> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late ContactPreferredMethod _preferredContactMethod;
  late final List<_MethodDraftRow> _methods;
  String? _expandedMethodKey;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(
      text: widget.detail.contact.firstName ?? '',
    );
    _lastName = TextEditingController(
      text: widget.detail.contact.lastName ?? '',
    );
    _preferredContactMethod = widget.detail.contact.preferredContactMethod;
    _methods = widget.detail.methods
        .map(_MethodDraftRow.fromMethod)
        .toList(growable: true);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    for (final method in _methods) {
      method.dispose();
    }
    super.dispose();
  }

  void _add(ContactMethodType type) {
    setState(
      () => _methods.add(
        _MethodDraftRow.empty(
          type,
          socialLabel: type == ContactMethodType.social
              ? nextSocialProfileLabel(
                  _methods
                      .where((method) => method.type == type)
                      .map((method) => method.label),
                )
              : null,
        ),
      ),
    );
  }

  ContactInformationEditResult _result() {
    final displayName = '${_firstName.text.trim()} ${_lastName.text.trim()}'
        .trim();
    return ContactInformationEditResult(
      firstName: _firstName.text,
      lastName: _lastName.text,
      displayName: displayName.isEmpty
          ? widget.detail.contact.displayName
          : displayName,
      preferredContactMethod: _preferredContactMethod,
      methods: _methods
          .where((method) => method.controller.text.trim().isNotEmpty)
          .map((method) => method.toDraft())
          .toList(growable: false),
    );
  }

  bool get _isDirty {
    if (_firstName.text != (widget.detail.contact.firstName ?? '') ||
        _lastName.text != (widget.detail.contact.lastName ?? '') ||
        _preferredContactMethod !=
            widget.detail.contact.preferredContactMethod) {
      return true;
    }
    final current = _result().methods;
    final initial = widget.detail.methods;
    if (current.length != initial.length) {
      return true;
    }
    for (var index = 0; index < current.length; index++) {
      final draft = current[index];
      final method = initial[index];
      if (draft.id != method.id ||
          draft.type != method.type ||
          draft.value != method.rawValue ||
          draft.label != method.label ||
          draft.isPrimary != method.isPrimary ||
          draft.receivesTexts != method.receivesTexts ||
          draft.hasWhatsApp != method.hasWhatsApp) {
        return true;
      }
    }
    return false;
  }

  void _saveAndLeave() => Navigator.of(context).pop(_result());

  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    switch (await showUnsavedChangesGuard(context)) {
      case UnsavedChangesDecision.saveAndLeave:
        if (mounted) {
          _saveAndLeave();
        }
        return;
      case UnsavedChangesDecision.discardAndLeave:
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      case UnsavedChangesDecision.keepEditing:
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_requestClose());
        }
      },
      child: Scaffold(
        backgroundColor: ContactReferenceStyle.canvasOf(context),
        appBar: InternalAppBar(
          backgroundColor: ContactReferenceStyle.canvasOf(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Text(
            'Contact Information',
            style: TextStyle(
              color: ContactReferenceStyle.onCanvasOf(context),
              fontSize: 26,
              fontWeight: FontWeight.w400,
            ),
          ),
          leading: IconButton(
            key: const Key('contact-information-cancel'),
            tooltip: 'Close',
            iconSize: 26,
            onPressed: _requestClose,
            icon: const Icon(Icons.close),
          ),
          actions: <Widget>[
            Semantics(
              button: true,
              label: 'Save',
              child: SizedBox.square(
                dimension: 40,
                child: FilledButton(
                  key: const Key('contact-information-save'),
                  onPressed: _saveAndLeave,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    backgroundColor: ContactReferenceStyle.actionOf(context),
                    foregroundColor: Colors.white,
                  ),
                  child: const Icon(Icons.check, size: 20),
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: ListView(
              key: const Key('contact-information-scroll'),
              padding: const EdgeInsets.only(top: 16, bottom: 48),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _nameField(
                        key: const Key('contact-information-first-name'),
                        controller: _firstName,
                        label: 'First Name',
                      ),
                      const SizedBox(height: 16),
                      _nameField(
                        key: const Key('contact-information-last-name'),
                        controller: _lastName,
                        label: 'Last Name',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _ContactInformationSectionDivider(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final type in ContactMethodType.values)
                        _MethodSection(
                          type: type,
                          rows: _methods
                              .where((row) => row.type == type)
                              .toList(),
                          expandedMethodKey: _expandedMethodKey,
                          onAdd: () => _add(type),
                          onRemove: (row) => setState(() {
                            _methods.remove(row);
                            if (_expandedMethodKey == row.key) {
                              _expandedMethodKey = null;
                            }
                            row.dispose();
                          }),
                          onExpand: (row) => setState(() {
                            _expandedMethodKey = _expandedMethodKey == row.key
                                ? null
                                : row.key;
                          }),
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

final class _MethodDraftRow {
  _MethodDraftRow({
    required this.type,
    required this.controller,
    this.id,
    this.label,
    this.isPrimary = false,
    this.receivesTexts = false,
    this.hasWhatsApp = false,
  });

  factory _MethodDraftRow.fromMethod(ContactMethod method) => _MethodDraftRow(
    id: method.id,
    type: method.type,
    controller: TextEditingController(text: method.rawValue),
    label: method.label,
    isPrimary: method.isPrimary,
    receivesTexts: method.receivesTexts ?? false,
    hasWhatsApp: method.hasWhatsApp ?? false,
  );

  factory _MethodDraftRow.empty(
    ContactMethodType type, {
    String? socialLabel,
  }) => _MethodDraftRow(
    type: type,
    controller: TextEditingController(),
    label: switch (type) {
      ContactMethodType.phone => 'Mobile',
      ContactMethodType.email => 'Personal',
      ContactMethodType.social => socialLabel ?? 'Facebook',
    },
  );

  final String? id;
  final ContactMethodType type;
  final TextEditingController controller;
  String? label;
  bool isPrimary;
  bool receivesTexts;
  bool hasWhatsApp;

  String get key => id ?? '${type.name}-${controller.hashCode}';

  ContactMethodDraft toDraft() => ContactMethodDraft(
    id: id,
    type: type,
    value: controller.text,
    label: label,
    isPrimary: isPrimary,
    receivesTexts: type == ContactMethodType.phone ? receivesTexts : null,
    hasWhatsApp: type == ContactMethodType.phone ? hasWhatsApp : null,
  );

  void dispose() => controller.dispose();
}

final class _MethodSection extends StatelessWidget {
  const _MethodSection({
    required this.type,
    required this.rows,
    required this.expandedMethodKey,
    required this.onAdd,
    required this.onRemove,
    required this.onExpand,
    required this.onChanged,
  });

  final ContactMethodType type;
  final List<_MethodDraftRow> rows;
  final String? expandedMethodKey;
  final VoidCallback onAdd;
  final ValueChanged<_MethodDraftRow> onRemove;
  final ValueChanged<_MethodDraftRow> onExpand;
  final VoidCallback onChanged;

  String get _preferredLabel => switch (type) {
    ContactMethodType.phone => 'Preferred Phone',
    ContactMethodType.email => 'Preferred Email',
    ContactMethodType.social => 'Preferred Social',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final row in rows)
          _SavedMethodRow(
            key: ValueKey(row.key),
            row: row,
            preferredLabel: _preferredLabel,
            expanded: expandedMethodKey == row.key,
            onRemove: () => onRemove(row),
            onExpand: () => onExpand(row),
            onPrimary: () {
              for (final candidate in rows) {
                candidate.isPrimary = identical(candidate, row);
              }
              onChanged();
            },
            onChanged: onChanged,
          ),
        ContactMethodEntryRow(
          key: Key('contact-information-add-${type.name}'),
          type: type,
          hasExistingRows: rows.isNotEmpty,
          includeAddQualifier: true,
          onTap: onAdd,
        ),
      ],
    );
  }
}

final class _SavedMethodRow extends StatelessWidget {
  const _SavedMethodRow({
    required this.row,
    required this.preferredLabel,
    required this.expanded,
    required this.onRemove,
    required this.onExpand,
    required this.onPrimary,
    required this.onChanged,
    super.key,
  });

  final _MethodDraftRow row;
  final String preferredLabel;
  final bool expanded;
  final VoidCallback onRemove;
  final VoidCallback onExpand;
  final VoidCallback onPrimary;
  final VoidCallback onChanged;

  List<String> get _labels => switch (row.type) {
    ContactMethodType.phone => const <String>[
      'Mobile',
      'Home',
      'Work',
      'Other',
    ],
    ContactMethodType.email => const <String>[
      'Personal',
      'Work',
      'Family',
      'Other',
    ],
    ContactMethodType.social => activeSocialProfileLabels,
  };

  @override
  Widget build(BuildContext context) {
    final selected =
        row.label ??
        (row.type == ContactMethodType.social ? _labels.first : _labels.last);
    final labels = <String>[
      ..._labels,
      if (!_labels.contains(selected) &&
          (row.type != ContactMethodType.social ||
              canonicalSocialProfileKey(selected) == null))
        selected,
    ];
    final action = ContactReferenceStyle.actionOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Semantics(
                label:
                    '${_typeLabel(row.type)} type: ${row.type == ContactMethodType.social ? socialProfileDisplayLabel(selected) : selected}',
                button: true,
                child: PopupMenuButton<String>(
                  tooltip: 'Select ${row.type.name} label',
                  initialValue: selected,
                  onSelected: (value) {
                    row.label = value;
                    onChanged();
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    for (final label in labels)
                      PopupMenuItem<String>(
                        value: label,
                        child: Text(
                          row.type == ContactMethodType.social
                              ? socialProfileDisplayLabel(label)
                              : label,
                        ),
                      ),
                  ],
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        contactMethodVisual(
                          type: row.type,
                          label: selected,
                          color: action,
                          size: 24,
                        ),
                        Icon(Icons.arrow_drop_down, color: action, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextFormField(
                  key: Key('contact-information-method-${row.key}'),
                  controller: row.controller,
                  keyboardType: row.type == ContactMethodType.phone
                      ? TextInputType.phone
                      : row.type == ContactMethodType.email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => onChanged(),
                  decoration: _methodDecoration(context, _typeLabel(row.type)),
                ),
              ),
              IconButton(
                key: Key('contact-information-remove-${row.key}'),
                tooltip: 'Remove',
                color: ContactReferenceStyle.destructiveOf(context),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 22),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: TextButton(
              key: Key('contact-information-more-${row.key}'),
              onPressed: onExpand,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                foregroundColor: action,
              ),
              child: Text(
                expanded ? 'Less ▴' : 'More ▾',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Column(
                children: <Widget>[
                  CheckboxListTile(
                    key: Key('contact-information-primary-${row.key}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -3),
                    value: row.isPrimary,
                    onChanged: (value) {
                      if (value ?? false) {
                        onPrimary();
                      } else {
                        row.isPrimary = false;
                        onChanged();
                      }
                    },
                    title: Text(preferredLabel),
                  ),
                  if (row.type == ContactMethodType.phone) ...<Widget>[
                    SwitchListTile(
                      key: Key('contact-information-texts-${row.key}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      value: row.receivesTexts,
                      onChanged: (value) {
                        row.receivesTexts = value;
                        onChanged();
                      },
                      title: const Text('Receives Texts'),
                    ),
                    SwitchListTile(
                      key: Key('contact-information-whatsapp-${row.key}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -3),
                      value: row.hasWhatsApp,
                      onChanged: (value) {
                        row.hasWhatsApp = value;
                        onChanged();
                      },
                      title: const Text('Has WhatsApp'),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final class _ContactInformationSectionDivider extends StatelessWidget {
  const _ContactInformationSectionDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: ContactReferenceStyle.lineOf(context));
}

String _typeLabel(ContactMethodType type) => switch (type) {
  ContactMethodType.phone => 'Phone',
  ContactMethodType.email => 'Email',
  ContactMethodType.social => 'Social Profile',
};

InputDecoration _methodDecoration(BuildContext context, String hint) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: ContactReferenceStyle.lineOf(context)),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: ContactReferenceStyle.actionOf(context),
        width: 2,
      ),
    ),
  );
}

import 'package:flutter/material.dart';

/// The explicit-save Contact editors share this decision rather than silently
/// throwing away a partially edited, scoped draft when their close affordance
/// is used.
enum UnsavedChangesDecision { saveAndLeave, discardAndLeave, keepEditing }

Future<UnsavedChangesDecision?> showUnsavedChangesGuard(BuildContext context) =>
    showDialog<UnsavedChangesDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your changes before leaving this editor?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(UnsavedChangesDecision.keepEditing),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(UnsavedChangesDecision.discardAndLeave),
            child: const Text('Discard & leave'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(UnsavedChangesDecision.saveAndLeave),
            child: const Text('Save & leave'),
          ),
        ],
      ),
    );

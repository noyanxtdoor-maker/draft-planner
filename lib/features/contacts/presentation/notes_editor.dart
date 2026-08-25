import 'package:flutter/material.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/unsaved_changes_guard.dart';

final class NotesEditResult {
  const NotesEditResult({
    required this.additions,
    required this.updates,
    required this.deletions,
  });

  final List<String> additions;
  final Map<String, String> updates;
  final Set<String> deletions;
}

final class NotesEditor extends StatefulWidget {
  const NotesEditor({required this.initialNotes, super.key});

  final List<ContactNote> initialNotes;

  @override
  State<NotesEditor> createState() => _NotesEditorState();
}

final class _NotesEditorState extends State<NotesEditor> {
  late List<_EditableNote> _notes;

  @override
  void initState() {
    super.initState();
    _notes = widget.initialNotes
        .map((note) => _EditableNote(id: note.id, text: note.noteText))
        .toList();
  }

  Future<void> _addNote() async {
    final text = await _editText(title: 'Add Note');
    if (text == null || text.isEmpty || !mounted) {
      return;
    }
    setState(
      () => _notes = <_EditableNote>[_EditableNote(text: text), ..._notes],
    );
  }

  Future<void> _editNote(int index) async {
    final note = _notes[index];
    final text = await _editText(title: 'Edit Note', initialText: note.text);
    if (text == null || text.isEmpty || !mounted) {
      return;
    }
    setState(() => _notes[index] = note.copyWith(text: text));
  }

  Future<String?> _editText({required String title, String initialText = ''}) =>
      showDialog<String>(
        context: context,
        builder: (_) => _NoteTextDialog(title: title, initialText: initialText),
      );

  NotesEditResult _result() {
    final original = <String, String>{
      for (final note in widget.initialNotes) note.id: note.noteText,
    };
    final currentIds = _notes
        .map((note) => note.id)
        .whereType<String>()
        .toSet();
    return NotesEditResult(
      additions: _notes
          .where((note) => note.id == null)
          .map((note) => note.text)
          .toList(growable: false),
      updates: <String, String>{
        for (final note in _notes)
          if (note.id != null && original[note.id] != note.text)
            note.id!: note.text,
      },
      deletions: original.keys.where((id) => !currentIds.contains(id)).toSet(),
    );
  }

  bool get _isDirty {
    final result = _result();
    return result.additions.isNotEmpty ||
        result.updates.isNotEmpty ||
        result.deletions.isNotEmpty;
  }

  void _saveAndLeave() => Navigator.pop(context, _result());

  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }
    final decision = await showUnsavedChangesGuard(context);
    if (!mounted) {
      return;
    }
    switch (decision) {
      case UnsavedChangesDecision.saveAndLeave:
        _saveAndLeave();
        return;
      case UnsavedChangesDecision.discardAndLeave:
        Navigator.pop(context);
        return;
      case UnsavedChangesDecision.keepEditing:
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notes'),
      leading: IconButton(
        key: const Key('notes-editor-cancel'),
        onPressed: _requestClose,
        icon: const Icon(Icons.close),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('notes-editor-save'),
          onPressed: _saveAndLeave,
          child: const Text('Save'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        TextButton.icon(
          key: const Key('notes-editor-add'),
          onPressed: _addNote,
          icon: const Icon(Icons.add),
          label: const Text('Add Note'),
        ),
        if (_notes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('No notes yet.'),
          ),
        for (var index = 0; index < _notes.length; index++)
          ListTile(
            key: Key('notes-editor-note-${_notes[index].id ?? 'new-$index'}'),
            contentPadding: EdgeInsets.zero,
            title: Text(_notes[index].text),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  key: Key(
                    'notes-editor-edit-${_notes[index].id ?? 'new-$index'}',
                  ),
                  onPressed: () => _editNote(index),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key(
                    'notes-editor-delete-${_notes[index].id ?? 'new-$index'}',
                  ),
                  onPressed: () => setState(() => _notes.removeAt(index)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

final class _EditableNote {
  const _EditableNote({this.id, required this.text});

  final String? id;
  final String text;

  _EditableNote copyWith({required String text}) =>
      _EditableNote(id: id, text: text);
}

final class _NoteTextDialog extends StatefulWidget {
  const _NoteTextDialog({required this.title, required this.initialText});

  final String title;
  final String initialText;

  @override
  State<_NoteTextDialog> createState() => _NoteTextDialogState();
}

final class _NoteTextDialogState extends State<_NoteTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: availableHeight * 0.52),
        child: TextField(
          key: const Key('notes-editor-input'),
          controller: _controller,
          autofocus: true,
          minLines: 6,
          maxLines: null,
          expands: false,
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('notes-editor-entry-save'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

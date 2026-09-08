import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/notes_editor.dart';

void main() {
  testWidgets('A5 Notes editor is scoped and Cancel writes no result', (
    tester,
  ) async {
    final result = await _openEditor(
      tester,
      <ContactNote>[_note('note-1', 'Original note')],
      close: (tester) =>
          tester.tap(find.byKey(const Key('notes-editor-cancel'))),
    );

    expect(result, isNull);
  });

  testWidgets('A5 Notes editor saves additions and edits', (tester) async {
    final result = await _openEditor(
      tester,
      <ContactNote>[_note('note-1', 'Original note')],
      close: (tester) async {
        await tester.tap(find.byKey(const Key('notes-editor-edit-note-1')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('notes-editor-input')),
          'Edited note',
        );
        await tester.tap(find.byKey(const Key('notes-editor-entry-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('notes-editor-add')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('notes-editor-input')),
          'New note',
        );
        await tester.tap(find.byKey(const Key('notes-editor-entry-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('notes-editor-save')));
      },
    );

    expect(result!.updates, <String, String>{'note-1': 'Edited note'});
    expect(result.additions, <String>['New note']);
    expect(result.deletions, isEmpty);
  });

  testWidgets('A5 Notes editor defers deletion until Save', (tester) async {
    final result = await _openEditor(
      tester,
      <ContactNote>[_note('note-1', 'Original note')],
      close: (tester) async {
        await tester.tap(find.byKey(const Key('notes-editor-delete-note-1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('notes-editor-save')));
      },
    );

    expect(result!.deletions, <String>{'note-1'});
  });
}

ContactNote _note(String id, String text) => ContactNote(
  id: id,
  contactId: 'contact-1',
  noteText: text,
  createdAtUtc: DateTime.utc(2026, 8, 24, 12),
  updatedAtUtc: DateTime.utc(2026, 8, 24, 12),
);

Future<NotesEditResult?> _openEditor(
  WidgetTester tester,
  List<ContactNote> notes, {
  required Future<void> Function(WidgetTester tester) close,
}) async {
  late Future<NotesEditResult?> result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          key: const Key('open-notes-editor'),
          onPressed: () {
            result = Navigator.of(context).push<NotesEditResult>(
              MaterialPageRoute<NotesEditResult>(
                builder: (_) => NotesEditor(initialNotes: notes),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-notes-editor')));
  await tester.pumpAndSettle();

  expect(find.text('Notes'), findsOneWidget);
  expect(find.byKey(const Key('notes-editor-add')), findsOneWidget);
  expect(find.text('Address'), findsNothing);
  expect(find.text('Groups'), findsNothing);
  expect(find.text('Availability'), findsNothing);
  expect(find.text('Favorite'), findsNothing);
  expect(find.text('Tags'), findsNothing);

  await close(tester);
  await tester.pumpAndSettle();
  return result;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/availability_editor.dart';

void main() {
  testWidgets(
    'A4 editor exposes only Availability controls and Cancel writes nothing',
    (tester) async {
      final result = await _openEditor(
        tester,
        const <ContactAvailability>[
          ContactAvailability(weekday: 1, startMinute: 540, endMinute: 1020),
        ],
        close: (tester) =>
            tester.tap(find.byKey(const Key('availability-cancel'))),
      );

      expect(result, isNull);
    },
  );

  testWidgets('A4 editor saves multiple Availability rows and reopens values', (
    tester,
  ) async {
    final saved = await _openEditor(
      tester,
      const <ContactAvailability>[],
      close: (tester) async {
        await tester.tap(find.byKey(const Key('availability-add')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('availability-add')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('availability-save')));
      },
    );

    expect(saved!.windows, hasLength(2));
    final reopened = await _openEditor(
      tester,
      saved.windows,
      close: (tester) =>
          tester.tap(find.byKey(const Key('availability-cancel'))),
      expectedRows: 2,
    );
    expect(reopened, isNull);
  });

  testWidgets('A4 editor saves clear-all Availability', (tester) async {
    final cleared = await _openEditor(
      tester,
      const <ContactAvailability>[
        ContactAvailability(weekday: 1, startMinute: 540, endMinute: 1020),
        ContactAvailability(weekday: 5, startMinute: 780, endMinute: 900),
      ],
      close: (tester) async {
        await tester.tap(find.byKey(const Key('availability-remove-1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('availability-remove-0')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('availability-save')));
      },
      expectedRows: 2,
    );

    expect(cleared!.windows, isEmpty);
  });
}

Future<AvailabilityEditResult?> _openEditor(
  WidgetTester tester,
  List<ContactAvailability> initialWindows, {
  required Future<void> Function(WidgetTester tester) close,
  int? expectedRows,
}) async {
  late Future<AvailabilityEditResult?> result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          key: const Key('open-availability-editor'),
          onPressed: () {
            result = Navigator.of(context).push<AvailabilityEditResult>(
              MaterialPageRoute<AvailabilityEditResult>(
                builder: (_) =>
                    AvailabilityEditor(initialWindows: initialWindows),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-availability-editor')));
  await tester.pumpAndSettle();

  expect(find.text('Availability'), findsOneWidget);
  expect(find.byKey(const Key('availability-weekday')), findsOneWidget);
  expect(find.text('From'), findsOneWidget);
  expect(find.text('To'), findsOneWidget);
  expect(find.text('Address'), findsNothing);
  expect(find.text('Groups'), findsNothing);
  expect(find.text('Notes'), findsNothing);
  if (expectedRows != null) {
    expect(
      find.byKey(Key('availability-row-${expectedRows - 1}')),
      findsOneWidget,
    );
  }

  await close(tester);
  await tester.pumpAndSettle();
  return result;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/presentation/address_map_editor.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/presentation/map_pin_section.dart';

void main() {
  Widget buildEditor({String? address, MapCoordinate? coordinate}) =>
      MaterialApp(
        home: AddressMapEditor(
          key: ValueKey<String>(
            '${address ?? ''}/${coordinate?.description ?? ''}',
          ),
          displayName: 'Maria Santos',
          initialAddress: address,
          initialCoordinate: coordinate,
        ),
      );

  testWidgets('A2 editor exposes only Address and saved-location controls', (
    tester,
  ) async {
    await tester.pumpWidget(buildEditor());
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Saved Location'), findsOneWidget);
    expect(find.text('Set saved location'), findsOneWidget);
    for (final forbidden in <String>[
      'First Name',
      'Last Name',
      'Phone',
      'Email',
      'Social',
      'Groups',
      'Favorite',
      'Availability',
      'Notes',
      'Tags',
      'Expand Options',
      'Preferred Contact Method',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('A2 represents address-only, pin-only, both, and neither', (
    tester,
  ) async {
    await tester.pumpWidget(buildEditor(address: '42 Main Street'));
    expect(find.byKey(const Key('address-map-set-coordinate')), findsOneWidget);
    expect(find.text('42 Main Street'), findsOneWidget);

    const pin = MapCoordinate(latitude: 14.5995, longitude: 120.9842);
    await tester.pumpWidget(buildEditor(coordinate: pin));
    expect(find.byKey(const Key('address-map-coordinate')), findsOneWidget);
    expect(find.byType(ContactLocationPreview), findsOneWidget);

    await tester.pumpWidget(
      buildEditor(address: '42 Main Street', coordinate: pin),
    );
    expect(find.text('42 Main Street'), findsOneWidget);
    expect(find.byType(ContactLocationPreview), findsOneWidget);

    await tester.pumpWidget(buildEditor());
    expect(find.byKey(const Key('address-map-set-coordinate')), findsOneWidget);
  });

  testWidgets('A2 cancel returns no write result', (tester) async {
    AddressMapEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<AddressMapEditResult>(
                  builder: (_) => const AddressMapEditor(
                    displayName: 'Maria Santos',
                    initialAddress: null,
                    initialCoordinate: null,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('address-map-cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}

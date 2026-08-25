import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_information_editor.dart';

void main() {
  final detail = ContactDetail(
    contact: Contact(
      id: 'contact-a1',
      profileId: 'profile-a1',
      firstName: 'Maria',
      lastName: 'Santos',
      displayName: 'Maria Santos',
      preferredContactMethod: ContactPreferredMethod.message,
      isFavorite: true,
      lifecycleState: ContactLifecycleState.active,
      source: ContactSource.deviceImport,
      createdAtUtc: DateTime.utc(2026, 8, 1),
      updatedAtUtc: DateTime.utc(2026, 8, 2),
    ),
    methods: <ContactMethod>[
      const ContactMethod(
        id: 'mobile',
        contactId: 'contact-a1',
        type: ContactMethodType.phone,
        rawValue: '+63 917 555 0100',
        normalizedValue: '639175550100',
        label: 'Mobile',
        isPrimary: true,
        receivesTexts: true,
        hasWhatsApp: true,
      ),
      const ContactMethod(
        id: 'email',
        contactId: 'contact-a1',
        type: ContactMethodType.email,
        rawValue: 'maria@example.com',
        normalizedValue: 'maria@example.com',
        label: 'Personal',
        isPrimary: true,
      ),
      const ContactMethod(
        id: 'social',
        contactId: 'contact-a1',
        type: ContactMethodType.social,
        rawValue: 'maria.santos',
        normalizedValue: 'maria.santos',
        label: 'Messenger',
        isPrimary: true,
      ),
    ],
  );

  testWidgets('C5 editor exposes the approved Contact Information surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ContactInformationEditor(detail: detail)),
    );

    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('+ Add Phone'), findsOneWidget);
    expect(find.text('+ Add Email'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('+ Add Social Profile'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('+ Add Social Profile'), findsOneWidget);
    expect(find.byKey(const Key('contact-information-save')), findsOneWidget);
    expect(find.text('More ▾'), findsNWidgets(3));
    expect(find.text('Preferred Phone'), findsNothing);
    expect(find.text('Preferred Email'), findsNothing);
    expect(find.text('Preferred Social'), findsNothing);
    expect(find.text('Receives Texts'), findsNothing);
    expect(find.text('Has WhatsApp'), findsNothing);
    for (final forbidden in <String>[
      'Address',
      'Map',
      'Groups',
      'Favorite',
      'Availability',
      'Notes',
      'Tags',
      'Expand Options',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
    expect(find.byType(Card), findsNothing);
    expect(find.byIcon(Icons.mail_outline), findsWidgets);
    expect(find.byType(SvgPicture), findsWidgets);

    await tester.tap(find.byKey(const Key('contact-information-more-mobile')));
    await tester.pump();
    expect(find.text('Preferred Phone'), findsOneWidget);
    expect(find.text('Receives Texts'), findsOneWidget);
    expect(find.text('Has WhatsApp'), findsOneWidget);
    expect(find.text('Less ▴'), findsOneWidget);
  });

  testWidgets('A1 cancel returns no scoped write payload', (tester) async {
    ContactInformationEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push(
                MaterialPageRoute<ContactInformationEditResult>(
                  builder: (_) => ContactInformationEditor(detail: detail),
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
    await tester.tap(find.byKey(const Key('contact-information-cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets(
    'A1 save retains method IDs, labels, values, and phone capability state',
    (tester) async {
      ContactInformationEditResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push(
                  MaterialPageRoute<ContactInformationEditResult>(
                    builder: (_) => ContactInformationEditor(detail: detail),
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
      await tester.tap(find.byKey(const Key('contact-information-save')));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      final mobile = result!.methods.singleWhere(
        (method) => method.id == 'mobile',
      );
      expect(mobile.label, 'Mobile');
      expect(mobile.value, '+63 917 555 0100');
      expect(mobile.receivesTexts, isTrue);
      expect(mobile.hasWhatsApp, isTrue);
      expect(
        result!.methods.map((method) => method.id),
        containsAll(<String>['mobile', 'email', 'social']),
      );
    },
  );
}

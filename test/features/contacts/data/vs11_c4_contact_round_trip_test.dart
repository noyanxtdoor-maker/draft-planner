import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

import '../../../support/test_dependencies.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 8, 23, 12));

  Future<({DriftContactRepository contacts, String profileId})>
  arrange() async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    return (
      contacts: DriftContactRepository(
        database: database,
        clock: clock,
        identifiers: UuidIdentifierSource(),
      ),
      profileId: profile.id,
    );
  }

  ContactDraft newManualDraft(
    String id, {
    String firstName = 'Marilyn',
    String lastName = 'Gomez',
    List<ContactMethodDraft> methods = const <ContactMethodDraft>[],
    String? addressText,
  }) {
    return ContactDraft(
      id: id,
      firstName: firstName,
      lastName: lastName,
      displayName: '$firstName $lastName'.trim(),
      preferredContactMethod: ContactPreferredMethod.message,
      isFavorite: false,
      addressText: addressText,
      methods: methods,
      requiresNewManualContactValidation: true,
    );
  }

  test(
    'C4 new manual Contact requires names but permits no contact method',
    () async {
      final harness = await arrange();

      Future<void> expectRejected(ContactDraft draft) async {
        await expectLater(
          harness.contacts.createContact(
            profileId: harness.profileId,
            draft: draft,
          ),
          throwsA(isA<ContactValidationException>()),
        );
      }

      await expectRejected(newManualDraft('blank-first', firstName: ''));
      await expectRejected(newManualDraft('blank-last', lastName: ''));
      final noMethod = await harness.contacts.createContact(
        profileId: harness.profileId,
        draft: newManualDraft('zero-methods'),
      );
      expect(noMethod.id, 'zero-methods');
      final noMethodDetail = await harness.contacts.readContactDetail(
        profileId: harness.profileId,
        contactId: noMethod.id,
      );
      expect(noMethodDetail.methods, isEmpty);

      final addressOnly = await harness.contacts.createContact(
        profileId: harness.profileId,
        draft: newManualDraft('address-only', addressText: '42 Main Street'),
      );
      expect(addressOnly.id, 'address-only');
      await expectRejected(
        newManualDraft(
          'invalid-email',
          methods: const <ContactMethodDraft>[
            ContactMethodDraft(
              type: ContactMethodType.email,
              value: 'not-an-email',
            ),
          ],
        ),
      );

      for (final entry in <(String, ContactMethodDraft)>[
        (
          'phone',
          const ContactMethodDraft(
            type: ContactMethodType.phone,
            value: '+63 917 555 0100',
          ),
        ),
        (
          'email',
          const ContactMethodDraft(
            type: ContactMethodType.email,
            value: 'marilyn@example.com',
          ),
        ),
        (
          'social',
          const ContactMethodDraft(
            type: ContactMethodType.social,
            value: '@marilyn',
          ),
        ),
      ]) {
        final created = await harness.contacts.createContact(
          profileId: harness.profileId,
          draft: newManualDraft(
            'accepted-${entry.$1}',
            methods: <ContactMethodDraft>[entry.$2],
          ),
        );
        expect(created.id, 'accepted-${entry.$1}');
      }
    },
  );

  test(
    'C4 update preserves favorite, tags, labels, primary metadata, and row IDs',
    () async {
      final harness = await arrange();
      const contactId = 'c4-preservation';
      await harness.contacts.createContact(
        profileId: harness.profileId,
        draft: const ContactDraft(
          id: contactId,
          firstName: 'Marilyn',
          lastName: 'Gomez',
          displayName: 'Marilyn Gomez',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: true,
          methods: <ContactMethodDraft>[
            ContactMethodDraft(
              type: ContactMethodType.phone,
              value: '+63 917 555 0100',
              label: 'Mobile',
              isPrimary: true,
            ),
            ContactMethodDraft(
              type: ContactMethodType.social,
              value: 'marilyn-hangouts',
              label: 'Google Hangouts',
            ),
          ],
          tagNames: <String>['Friend', 'Work'],
        ),
      );
      final before = await harness.contacts.readContactDetail(
        profileId: harness.profileId,
        contactId: contactId,
      );
      final phoneBefore = before.methods.singleWhere(
        (method) => method.type == ContactMethodType.phone,
      );
      final socialBefore = before.methods.singleWhere(
        (method) => method.type == ContactMethodType.social,
      );

      await harness.contacts.updateContact(
        profileId: harness.profileId,
        contactId: contactId,
        draft: ContactDraft(
          id: contactId,
          firstName: 'Marilyn',
          lastName: 'Gomez',
          displayName: 'Marilyn Gomez',
          preferredContactMethod: ContactPreferredMethod.email,
          isFavorite: true,
          methods: <ContactMethodDraft>[
            ContactMethodDraft(
              id: phoneBefore.id,
              type: ContactMethodType.phone,
              value: '+63 917 555 0199',
              label: phoneBefore.label,
              isPrimary: phoneBefore.isPrimary,
            ),
            ContactMethodDraft(
              id: socialBefore.id,
              type: ContactMethodType.social,
              value: socialBefore.rawValue,
              label: socialBefore.label,
              isPrimary: socialBefore.isPrimary,
            ),
            const ContactMethodDraft(
              type: ContactMethodType.email,
              value: 'marilyn@work.example',
              label: 'Work',
            ),
          ],
          tagNames: before.tags.map((tag) => tag.name).toList(),
        ),
      );

      final after = await harness.contacts.readContactDetail(
        profileId: harness.profileId,
        contactId: contactId,
      );
      final phoneAfter = after.methods.singleWhere(
        (method) => method.type == ContactMethodType.phone,
      );
      final socialAfter = after.methods.singleWhere(
        (method) => method.type == ContactMethodType.social,
      );
      expect(after.contact.isFavorite, isTrue);
      expect(after.tags.map((tag) => tag.name), <String>['Friend', 'Work']);
      expect(phoneAfter.id, phoneBefore.id);
      expect(phoneAfter.label, 'Mobile');
      expect(phoneAfter.isPrimary, isTrue);
      expect(phoneAfter.normalizedValue, '639175550199');
      expect(socialAfter.id, socialBefore.id);
      expect(socialAfter.label, 'Google Hangouts');
      expect(
        after.methods.where((method) => method.type == ContactMethodType.email),
        hasLength(1),
      );

      await harness.contacts.updateContact(
        profileId: harness.profileId,
        contactId: contactId,
        draft: ContactDraft(
          id: contactId,
          firstName: 'Marilyn',
          lastName: 'Gomez',
          displayName: 'Marilyn Gomez',
          preferredContactMethod: ContactPreferredMethod.email,
          isFavorite: true,
          methods: <ContactMethodDraft>[
            ContactMethodDraft(
              id: phoneAfter.id,
              type: ContactMethodType.phone,
              value: phoneAfter.rawValue,
              label: phoneAfter.label,
              isPrimary: phoneAfter.isPrimary,
            ),
          ],
          tagNames: after.tags.map((tag) => tag.name).toList(),
        ),
      );
      final afterDelete = await harness.contacts.readContactDetail(
        profileId: harness.profileId,
        contactId: contactId,
      );
      expect(afterDelete.methods, hasLength(1));
      expect(afterDelete.methods.single.id, phoneBefore.id);
      expect(afterDelete.tags.map((tag) => tag.name), <String>[
        'Friend',
        'Work',
      ]);
    },
  );

  test(
    'C4 legacy display-only Contacts remain editable but complete rows cannot degrade',
    () async {
      final harness = await arrange();
      const legacyId = 'c4-legacy-display-only';
      await harness.contacts.createContact(
        profileId: harness.profileId,
        draft: const ContactDraft(
          id: legacyId,
          firstName: '',
          lastName: '',
          displayName: 'Imported Alias',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
          source: ContactSource.deviceImport,
        ),
      );
      await harness.contacts.updateContact(
        profileId: harness.profileId,
        contactId: legacyId,
        draft: const ContactDraft(
          id: legacyId,
          firstName: '',
          lastName: '',
          displayName: 'Imported Alias',
          preferredContactMethod: ContactPreferredMethod.call,
          isFavorite: true,
          source: ContactSource.manual,
        ),
      );
      final legacy = await harness.contacts.readContactDetail(
        profileId: harness.profileId,
        contactId: legacyId,
      );
      expect(legacy.contact.displayName, 'Imported Alias');
      expect(legacy.contact.source, ContactSource.deviceImport);
      expect(legacy.contact.isFavorite, isTrue);
      expect(legacy.methods, isEmpty);

      const completeId = 'c4-complete-contact';
      await harness.contacts.createContact(
        profileId: harness.profileId,
        draft: const ContactDraft(
          id: completeId,
          firstName: 'Complete',
          lastName: 'Contact',
          displayName: 'Complete Contact',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
          methods: <ContactMethodDraft>[
            ContactMethodDraft(
              type: ContactMethodType.phone,
              value: '+63 917 555 0100',
            ),
          ],
        ),
      );
      await expectLater(
        harness.contacts.updateContact(
          profileId: harness.profileId,
          contactId: completeId,
          draft: const ContactDraft(
            id: completeId,
            firstName: 'Complete',
            lastName: 'Contact',
            displayName: 'Complete Contact',
            preferredContactMethod: ContactPreferredMethod.message,
            isFavorite: true,
          ),
        ),
        throwsA(isA<ContactValidationException>()),
      );
    },
  );
}

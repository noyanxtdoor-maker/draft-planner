import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_recipient_classifier.dart';

void main() {
  final created = DateTime.utc(2026, 8, 25);

  ContactDetail detail(String id, List<ContactMethod> methods) => ContactDetail(
    contact: Contact(
      id: id,
      profileId: 'profile',
      firstName: id,
      lastName: null,
      displayName: id,
      preferredContactMethod: ContactPreferredMethod.message,
      isFavorite: false,
      lifecycleState: ContactLifecycleState.active,
      source: ContactSource.manual,
      createdAtUtc: created,
      updatedAtUtc: created,
    ),
    methods: methods,
  );

  ContactMethod method({
    required String id,
    required String contactId,
    required ContactMethodType type,
    required String value,
    bool primary = false,
    bool? receivesTexts,
  }) => ContactMethod(
    id: id,
    contactId: contactId,
    type: type,
    rawValue: value,
    normalizedValue: value,
    isPrimary: primary,
    receivesTexts: receivesTexts,
  );

  test(
    'Text chooses one primary text-capable phone and excludes factual gaps',
    () {
      final review = classifyContactRecipients(
        action: ContactRecipientAction.text,
        details: <ContactDetail>[
          detail('Primary', <ContactMethod>[
            method(
              id: 'p1',
              contactId: 'Primary',
              type: ContactMethodType.phone,
              value: '0917 111 2222',
              receivesTexts: true,
            ),
            method(
              id: 'p2',
              contactId: 'Primary',
              type: ContactMethodType.phone,
              value: '+63 917 333 4444',
              primary: true,
              receivesTexts: true,
            ),
          ]),
          detail('No capability', <ContactMethod>[
            method(
              id: 'p3',
              contactId: 'No capability',
              type: ContactMethodType.phone,
              value: '0917 555 6666',
              receivesTexts: false,
            ),
          ]),
          detail('Bad', <ContactMethod>[
            method(
              id: 'p4',
              contactId: 'Bad',
              type: ContactMethodType.phone,
              value: 'abc',
              receivesTexts: true,
            ),
          ]),
          detail('Duplicate', <ContactMethod>[
            method(
              id: 'p5',
              contactId: 'Duplicate',
              type: ContactMethodType.phone,
              value: '+63 917 333 4444',
              receivesTexts: true,
            ),
          ]),
        ],
      );

      expect(review.recipients, <String>['+63 917 333 4444']);
      expect(review.excluded.map((excluded) => excluded.reason), <String>[
        'No text-capable phone',
        'Invalid phone number',
        'Duplicate recipient',
      ]);
    },
  );

  test(
    'Email chooses primary then stable fallback and deduplicates addresses',
    () {
      final review = classifyContactRecipients(
        action: ContactRecipientAction.email,
        details: <ContactDetail>[
          detail('Primary', <ContactMethod>[
            method(
              id: 'e1',
              contactId: 'Primary',
              type: ContactMethodType.email,
              value: 'first@example.com',
            ),
            method(
              id: 'e2',
              contactId: 'Primary',
              type: ContactMethodType.email,
              value: 'primary@example.com',
              primary: true,
            ),
          ]),
          detail('Fallback', <ContactMethod>[
            method(
              id: 'e3',
              contactId: 'Fallback',
              type: ContactMethodType.email,
              value: 'fallback@example.com',
            ),
            method(
              id: 'e4',
              contactId: 'Fallback',
              type: ContactMethodType.email,
              value: 'later@example.com',
            ),
          ]),
          detail('Invalid', <ContactMethod>[
            method(
              id: 'e5',
              contactId: 'Invalid',
              type: ContactMethodType.email,
              value: 'not-an-email',
            ),
          ]),
          detail('Duplicate', <ContactMethod>[
            method(
              id: 'e6',
              contactId: 'Duplicate',
              type: ContactMethodType.email,
              value: 'PRIMARY@example.com',
            ),
          ]),
        ],
      );

      expect(review.recipients, <String>[
        'primary@example.com',
        'fallback@example.com',
      ]);
      expect(review.excluded.map((excluded) => excluded.reason), <String>[
        'Invalid email address',
        'Duplicate recipient',
      ]);
    },
  );
}

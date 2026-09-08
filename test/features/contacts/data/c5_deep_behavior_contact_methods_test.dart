import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test('C5 phone capabilities and per-type preferred methods persist safely',
      () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(database: database)
        .completeOnboarding();
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 12)),
      identifiers: UuidIdentifierSource(),
    );

    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: 'c5-method-capabilities',
        firstName: 'Maria',
        lastName: 'Santos',
        displayName: 'Maria Santos',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
        methods: <ContactMethodDraft>[
          ContactMethodDraft(
            type: ContactMethodType.phone,
            value: '+63 917 555 0100',
            label: 'Mobile',
            receivesTexts: true,
            hasWhatsApp: true,
            isPrimary: true,
          ),
          ContactMethodDraft(
            type: ContactMethodType.phone,
            value: '+63 917 555 0101',
            label: 'Home',
            receivesTexts: false,
            hasWhatsApp: false,
          ),
          ContactMethodDraft(
            type: ContactMethodType.email,
            value: 'maria@example.com',
            isPrimary: true,
          ),
          ContactMethodDraft(
            type: ContactMethodType.social,
            value: 'maria.santos',
            label: 'Messenger',
            isPrimary: true,
          ),
        ],
      ),
    );

    final detail = await contacts.readContactDetail(
      profileId: profile.id,
      contactId: 'c5-method-capabilities',
    );
    final mobile = detail.methods.singleWhere((method) => method.label == 'Mobile');
    final home = detail.methods.singleWhere((method) => method.label == 'Home');
    expect(mobile.receivesTexts, isTrue);
    expect(mobile.hasWhatsApp, isTrue);
    expect(home.receivesTexts, isFalse);
    expect(home.hasWhatsApp, isFalse);
    expect(
      detail.methods.where((method) => method.type == ContactMethodType.phone && method.isPrimary),
      hasLength(1),
    );
    expect(
      detail.methods.where((method) => method.type == ContactMethodType.email && method.isPrimary),
      hasLength(1),
    );
    expect(
      detail.methods.where((method) => method.type == ContactMethodType.social && method.isPrimary),
      hasLength(1),
    );
  });

  test('C5 tolerates legacy duplicate primaries and normalizes only scoped save',
      () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(database: database)
        .completeOnboarding();
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 12)),
      identifiers: UuidIdentifierSource(),
    );
    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: 'c5-legacy-primary',
        firstName: 'Legacy',
        lastName: 'Primary',
        displayName: 'Legacy Primary',
        preferredContactMethod: ContactPreferredMethod.call,
        isFavorite: false,
      ),
    );
    await database.into(database.contactMethods).insert(
          ContactMethodsCompanion.insert(
            id: 'legacy-phone-a',
            contactId: 'c5-legacy-primary',
            type: ContactMethodType.phone.name,
            rawValue: '+63 917 555 0100',
            normalizedValue: '639175550100',
            isPrimary: const Value<bool>(true),
          ),
        );
    await database.into(database.contactMethods).insert(
          ContactMethodsCompanion.insert(
            id: 'legacy-phone-b',
            contactId: 'c5-legacy-primary',
            type: ContactMethodType.phone.name,
            rawValue: '+63 917 555 0101',
            normalizedValue: '639175550101',
            isPrimary: const Value<bool>(true),
          ),
        );

    final legacy = await contacts.readContactDetail(
      profileId: profile.id,
      contactId: 'c5-legacy-primary',
    );
    expect(
      legacy.methods.where((method) => method.isPrimary),
      hasLength(2),
      reason: 'reading legacy rows must not rewrite or reject them',
    );

    await contacts.updateContactIdentityAndMethods(
      profileId: profile.id,
      contactId: 'c5-legacy-primary',
      firstName: 'Legacy',
      lastName: 'Primary',
      displayName: 'Legacy Primary',
      preferredContactMethod: ContactPreferredMethod.call,
      methods: legacy.methods
          .map(
            (method) => ContactMethodDraft(
              id: method.id,
              type: method.type,
              value: method.rawValue,
              label: method.label,
              isPrimary: method.isPrimary,
              receivesTexts: method.receivesTexts,
              hasWhatsApp: method.hasWhatsApp,
            ),
          )
          .toList(),
    );
    final normalized = await contacts.readContactDetail(
      profileId: profile.id,
      contactId: 'c5-legacy-primary',
    );
    expect(
      normalized.methods.where((method) => method.isPrimary),
      hasLength(1),
    );
  });

  test('A1 scoped save preserves excluded Contact facts', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(database: database)
        .completeOnboarding();
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 12)),
      identifiers: UuidIdentifierSource(),
    );
    final group = await contacts.createGroup(
      profileId: profile.id,
      name: 'Family',
      colorValue: 0xff336699,
    );
    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: 'c5-a1-preservation',
        firstName: 'Imported',
        lastName: '',
        displayName: 'Imported Contact',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: true,
        source: ContactSource.deviceImport,
        addressText: '42 Stable Address',
        tagNames: <String>['Dormant Tag'],
        availability: <ContactAvailability>[
          ContactAvailability(weekday: 1, startMinute: 480, endMinute: 540),
        ],
        initialNoteText: 'Preserved note',
        methods: <ContactMethodDraft>[
          ContactMethodDraft(
            type: ContactMethodType.phone,
            value: '+63 917 555 0199',
            label: 'Mobile',
          ),
        ],
      ),
    );
    await contacts.setContactGroups(
      profileId: profile.id,
      contactId: 'c5-a1-preservation',
      groupIds: <String>[group.id],
      primaryGroupId: group.id,
    );
    final before = await contacts.readContactDetail(
      profileId: profile.id,
      contactId: 'c5-a1-preservation',
    );
    await contacts.updateContactIdentityAndMethods(
      profileId: profile.id,
      contactId: 'c5-a1-preservation',
      firstName: 'Imported',
      lastName: 'Edited',
      displayName: 'Imported Edited',
      preferredContactMethod: ContactPreferredMethod.call,
      methods: before.methods
          .map(
            (method) => ContactMethodDraft(
              id: method.id,
              type: method.type,
              value: method.rawValue,
              label: method.label,
              isPrimary: true,
              receivesTexts: method.receivesTexts,
              hasWhatsApp: method.hasWhatsApp,
            ),
          )
          .toList(),
    );
    final after = await contacts.readContactDetail(
      profileId: profile.id,
      contactId: 'c5-a1-preservation',
    );
    expect(after.contact.addressText, '42 Stable Address');
    expect(after.contact.isFavorite, isTrue);
    expect(after.contact.source, ContactSource.deviceImport);
    expect(after.groups.single.id, group.id);
    expect(after.primaryGroupId, group.id);
    expect(after.tags.single.name, 'Dormant Tag');
    expect(after.availability, hasLength(1));
    expect(after.notes.single.noteText, 'Preserved note');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_filter_controls.dart';

void main() {
  final stamp = DateTime.utc(2026, 8, 24);
  final groups = <ContactGroup>[
    ContactGroup(
      id: 'group-1',
      profileId: 'profile-1',
      name: 'Group 1',
      colorValue: 0xFF1565C0,
      isArchived: false,
      sortOrder: 0,
      createdAtUtc: stamp,
      updatedAtUtc: stamp,
    ),
    ContactGroup(
      id: 'group-2',
      profileId: 'profile-1',
      name: 'Group 2',
      colorValue: 0xFF2E7D32,
      isArchived: false,
      sortOrder: 1,
      createdAtUtc: stamp,
      updatedAtUtc: stamp,
    ),
  ];
  const tags = <ContactTag>[
    ContactTag(id: 'tag-1', profileId: 'profile-1', name: 'Tag 1'),
    ContactTag(id: 'tag-2', profileId: 'profile-1', name: 'Tag 2'),
  ];

  test(
    'C4 genuine multi-select state law is All then None then Some then All',
    () {
      const category = ContactFilterCategory.availability;
      var criteria = const ContactFilterCriteria();
      expect(
        contactFilterCategoryState(criteria, category),
        ContactFilterSelectionState.all,
      );

      criteria = contactFilterCriteriaForSelection(
        criteria,
        category,
        <String>{},
      );
      expect(
        criteria.availabilitySelectionMode,
        ContactFilterSelectionMode.none,
      );
      expect(criteria.isEmpty, isFalse);
      expect(contactFilterCategoryIsActive(criteria, category), isTrue);
      expect(
        contactFilterCategoryState(criteria, category),
        ContactFilterSelectionState.none,
      );

      criteria = contactFilterCriteriaForSelection(criteria, category, <String>{
        '1',
      });
      expect(
        criteria.availabilitySelectionMode,
        ContactFilterSelectionMode.some,
      );
      expect(
        contactFilterCategoryState(criteria, category),
        ContactFilterSelectionState.some,
      );

      criteria = clearContactFilterCategory(criteria, category);
      expect(
        criteria.availabilitySelectionMode,
        ContactFilterSelectionMode.all,
      );
      expect(criteria.isEmpty, isTrue);
      expect(contactFilterCategoryIsActive(criteria, category), isFalse);
      expect(
        contactFilterCategoryState(criteria, category),
        ContactFilterSelectionState.all,
      );
    },
  );

  test(
    'C4 final individual uncheck is explicit None for every genuine multi-select',
    () {
      final cases =
          <
            (
              ContactFilterCategory category,
              Set<String> selected,
              List<ContactGroup> groups,
              List<ContactTag> tags,
            )
          >[
            (ContactFilterCategory.groups, <String>{'group-1'}, groups, tags),
            (ContactFilterCategory.tags, <String>{'tag-1'}, groups, tags),
            (ContactFilterCategory.availability, <String>{'1'}, groups, tags),
            (
              ContactFilterCategory.contactMethods,
              <String>{'phone'},
              groups,
              tags,
            ),
            (
              ContactFilterCategory.eventHistory,
              <String>{'history'},
              groups,
              tags,
            ),
            (ContactFilterCategory.phone, <String>{'mobile'}, groups, tags),
            (ContactFilterCategory.email, <String>{'personal'}, groups, tags),
            (ContactFilterCategory.address, <String>{'recorded'}, groups, tags),
            (
              ContactFilterCategory.socialProfile,
              <String>{'facebook'},
              groups,
              tags,
            ),
          ];

      for (final item in cases) {
        final some = contactFilterCriteriaForSelection(
          const ContactFilterCriteria(),
          item.$1,
          item.$2,
        );
        expect(
          contactFilterCategoryState(
            some,
            item.$1,
            groups: item.$3,
            tags: item.$4,
          ),
          ContactFilterSelectionState.some,
          reason: item.$1.name,
        );
        final none = contactFilterCriteriaForSelection(
          some,
          item.$1,
          <String>{},
        );
        expect(
          contactFilterSelectionModeForCategory(none, item.$1),
          ContactFilterSelectionMode.none,
          reason: item.$1.name,
        );
        expect(contactFilterCategoryIsActive(none, item.$1), isTrue);
      }
    },
  );

  test('C4 zero-option Tags and Favorites retain their distinct semantics', () {
    const none = ContactFilterCriteria(
      tagSelectionMode: ContactFilterSelectionMode.none,
    );
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(),
        ContactFilterCategory.tags,
        tags: <ContactTag>[],
      ),
      ContactFilterSelectionState.none,
    );
    expect(
      contactFilterCategoryIsActive(
        const ContactFilterCriteria(),
        ContactFilterCategory.tags,
      ),
      isFalse,
    );
    expect(none.isEmpty, isFalse);
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(),
        ContactFilterCategory.favorites,
      ),
      ContactFilterSelectionState.none,
    );
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(favoritesOnly: true),
        ContactFilterCategory.favorites,
      ),
      ContactFilterSelectionState.all,
    );
    expect(
      contactFilterCategoryIsActive(
        const ContactFilterCriteria(favoritesOnly: true),
        ContactFilterCategory.favorites,
      ),
      isTrue,
    );
  });

  test('C4 Source and Archived state uses their actual option contracts', () {
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(),
        ContactFilterCategory.source,
      ),
      ContactFilterSelectionState.all,
    );
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(source: ContactSource.manual),
        ContactFilterCategory.source,
      ),
      ContactFilterSelectionState.some,
    );
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(),
        ContactFilterCategory.archived,
      ),
      ContactFilterSelectionState.all,
    );
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(includeArchived: true),
        ContactFilterCategory.archived,
      ),
      ContactFilterSelectionState.some,
    );
    expect(
      contactFilterCategoryState(
        const ContactFilterCriteria(archivedOnly: true),
        ContactFilterCategory.archived,
      ),
      ContactFilterSelectionState.some,
    );
  });

  test(
    'C4 saved criteria reopen explicit None and preserve legacy mode behavior',
    () {
      const explicitNone = ContactFilterCriteria(
        phoneSelectionMode: ContactFilterSelectionMode.none,
      );
      final reopened = ContactFilterCriteria.decode(explicitNone.encode());
      expect(reopened.phoneSelectionMode, ContactFilterSelectionMode.none);
      expect(reopened.isEmpty, isFalse);
      expect(
        contactFilterCategoryIsActive(reopened, ContactFilterCategory.phone),
        isTrue,
      );

      final legacyAll = ContactFilterCriteria.decode('{"phoneLabels":[]}');
      expect(legacyAll.phoneSelectionMode, ContactFilterSelectionMode.all);
      expect(legacyAll.isEmpty, isTrue);

      final legacySome = ContactFilterCriteria.decode(
        '{"phoneLabels":["mobile"]}',
      );
      expect(legacySome.phoneSelectionMode, ContactFilterSelectionMode.some);
      expect(legacySome.phoneLabels, <String>['mobile']);
    },
  );
}

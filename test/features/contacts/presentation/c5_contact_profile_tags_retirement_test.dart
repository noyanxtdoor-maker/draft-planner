import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('C5 Profile stays Profile + Timeline and exposes factual sections', () {
    final detail = source(
      'lib/features/contacts/presentation/contact_detail_screen.dart',
    );
    expect(detail, contains("label: 'Profile'"));
    expect(detail, contains("label: 'Timeline'"));
    expect(detail, isNot(contains("label: 'Progress'")));
    for (final label in <String>[
      'Contact Information',
      'Address & Map',
      'Groups',
      'Upcoming / Follow-Up',
      'Availability',
      'Notes',
      'Record Details',
      'Created',
      'Updated',
      'Origin',
    ]) {
      expect(detail, contains("'$label'"));
    }
    expect(detail, isNot(contains('Groups & Tags')));
    expect(detail, isNot(contains('No groups or tags.')));
    expect(detail, contains('profile-map-pin'));
    expect(detail, isNot(contains('profile-open-in-maps')));
    expect(detail, contains('profile-map-preview'));
    expect(detail, contains('mapTransientFocusProvider'));
    expect(detail, contains('title.toUpperCase()'));
    expect(detail, contains("key: const Key('contact-detail-favorite')"));
    expect(detail, isNot(contains("Key('contact-detail-fab')")));
    expect(
      detail.indexOf("title: 'Address & Map'"),
      lessThan(detail.indexOf("title: 'Groups'")),
    );
    expect(
      detail.indexOf("title: 'Groups'"),
      lessThan(detail.indexOf("title: 'Upcoming / Follow-Up'")),
    );
    expect(detail, isNot(contains("Key('create-follow-up-empty')")));
  });

  test('C5 Profile action color follows the selected theme primary', () {
    final style = source('lib/app/theme/contact_reference_style.dart');
    expect(style, contains('Theme.of(context).colorScheme.primary'));
    expect(style, isNot(contains('_isLight(context) ? action')));
  });

  test('C5 Contact Detail is nested under the shell-owned Contacts route', () {
    final router = source('lib/app/router/app_router.dart');
    final contacts = router.indexOf('name: RouteNames.contacts');
    final detail = router.indexOf('name: RouteNames.contactDetail');
    expect(contacts, isNonNegative);
    expect(detail, greaterThan(contacts));
    expect(
      router.substring(contacts, detail),
      contains('routes: <RouteBase>['),
    );
    expect(router, contains("path: 'contact/:contactId'"));
  });

  test('C5 active Contacts UX does not expose Tags', () {
    expect(
      source('lib/features/contacts/presentation/contact_form_screen.dart'),
      isNot(contains('_buildExpandedOptions(tags)')),
    );
    expect(
      source('lib/features/contacts/presentation/contact_search_screen.dart'),
      isNot(contains('groups, or tags')),
    );
    expect(
      source('lib/features/contacts/presentation/widgets/contact_widgets.dart'),
      isNot(contains("lines.add('Tags:")),
    );
    final filters = source(
      'lib/features/contacts/presentation/contact_filter_controls.dart',
    );
    expect(
      filters,
      isNot(
        contains(
          'ContactFilterCategory.tags,\n      ContactFilterCategory.favorites',
        ),
      ),
    );
  });

  test('legacy Tag criteria decode but are neutral for active editing', () {
    const raw = ContactFilterCriteria(
      tagIds: <String>['legacy-tag'],
      tagSelectionMode: ContactFilterSelectionMode.some,
    );
    final decoded = ContactFilterCriteria.decode(raw.encode());
    expect(decoded.tagIds, <String>['legacy-tag']);
    expect(decoded.tagSelectionMode, ContactFilterSelectionMode.some);
    final neutral = decoded.withoutRetiredTags();
    expect(neutral.tagIds, isEmpty);
    expect(neutral.tagSelectionMode, ContactFilterSelectionMode.all);
  });

  test('new default displayed fields omit retired Tags', () {
    expect(
      ContactDisplayedFieldCodec.defaults,
      isNot(contains(ContactDisplayedField.tags)),
    );
  });

  test(
    'owner-review Profile action treatment uses factual ordered SVG actions',
    () {
      final detail = source(
        'lib/features/contacts/presentation/contact_detail_screen.dart',
      );
      final whatsapp = detail.indexOf("Key('handoff-whatsapp')");
      final message = detail.indexOf("Key('handoff-message')");
      final call = detail.indexOf("Key('handoff-call')");
      expect(whatsapp, isNonNegative);
      expect(message, greaterThan(whatsapp));
      expect(call, greaterThan(message));
      expect(
        detail,
        contains('assets/icons/contacts/social/whatsapp-action.svg'),
      );
      expect(detail, contains('assets/icons/contacts/social/phone-action.svg'));
      expect(detail, contains('ColorFilter.mode('));
      final addressSection = detail.substring(
        detail.indexOf('final class _AddressMapSection'),
        detail.indexOf('final class _ProfileMapPreview'),
      );
      expect(addressSection, isNot(contains('Icons.place_outlined')));
      expect(detail, contains('profile-map-preview'));
    },
  );

  test('Pass C: Contact Information method rows use the header rule only', () {
    final detail = source(
      'lib/features/contacts/presentation/contact_detail_screen.dart',
    );
    final information = detail.substring(
      detail.indexOf('final class _ContactInformation'),
      detail.indexOf('final class _HandoffButtons'),
    );
    expect(
      RegExp('showBottomDivider: false').allMatches(information),
      hasLength(3),
      reason:
          'Phone, Email, and Social method rows use whitespace rather than '
          'individual bottom rules.',
    );
    expect(
      detail,
      contains(
        'Container(height: 1, color: ContactReferenceStyle.lineOf(context))',
      ),
      reason: 'The Contact Information section-header rule remains intact.',
    );
  });
}

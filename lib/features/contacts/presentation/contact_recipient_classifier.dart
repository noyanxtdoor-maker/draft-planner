import 'package:rmplanner/features/contacts/domain/contact.dart';

/// The factual, non-persisting recipient decision for one selected Contact.
///
/// A selected Contact is not automatically a usable external recipient.  The
/// classifier makes that distinction explicit before an SMS or email composer
/// is opened, and deliberately chooses at most one method for each Contact.
enum ContactRecipientAction { text, email }

final class ContactRecipientExclusion {
  const ContactRecipientExclusion({
    required this.contactId,
    required this.displayName,
    required this.reason,
  });

  final String contactId;
  final String displayName;
  final String reason;
}

final class ContactRecipientReview {
  const ContactRecipientReview({
    required this.action,
    required this.recipients,
    required this.excluded,
  });

  final ContactRecipientAction action;
  final List<String> recipients;
  final List<ContactRecipientExclusion> excluded;

  int get readyCount => recipients.length;
  int get excludedCount => excluded.length;
  bool get hasRecipients => recipients.isNotEmpty;
  bool get needsReview => excluded.isNotEmpty;
}

/// Classifies selected [details] in the caller's stable Contacts order.
///
/// It reads only already-persisted Contact/Method facts and never normalizes
/// or writes a Contact.  Phone values need a reasonable number of digits for
/// an external SMS recipient; email values use the app's existing basic
/// handoff validation shape.
ContactRecipientReview classifyContactRecipients({
  required Iterable<ContactDetail> details,
  required ContactRecipientAction action,
}) {
  final recipients = <String>[];
  final dedupe = <String>{};
  final excluded = <ContactRecipientExclusion>[];

  for (final detail in details) {
    final candidate = switch (action) {
      _ => contactRecipientFor(detail, action),
    };
    if (candidate == null) {
      excluded.add(
        ContactRecipientExclusion(
          contactId: detail.contact.id,
          displayName: detail.contact.displayName,
          reason: switch (action) {
            ContactRecipientAction.text => _textExclusionReason(detail),
            ContactRecipientAction.email => _emailExclusionReason(detail),
          },
        ),
      );
      continue;
    }

    final identity = switch (action) {
      _ => contactRecipientIdentity(candidate, action),
    };
    if (!dedupe.add(identity)) {
      excluded.add(
        ContactRecipientExclusion(
          contactId: detail.contact.id,
          displayName: detail.contact.displayName,
          reason: 'Duplicate recipient',
        ),
      );
      continue;
    }
    recipients.add(candidate);
  }

  return ContactRecipientReview(
    action: action,
    recipients: List<String>.unmodifiable(recipients),
    excluded: List<ContactRecipientExclusion>.unmodifiable(excluded),
  );
}

/// One Contact's persisted recipient choice. This is shared by the
/// eligible-only selection universe and the final stale-data revalidation so
/// the visible list can never use looser rules than the external handoff.
String? contactRecipientFor(
  ContactDetail detail,
  ContactRecipientAction action,
) => switch (action) {
  ContactRecipientAction.text => _selectTextRecipient(detail),
  ContactRecipientAction.email => _selectEmailRecipient(detail),
};

String contactRecipientIdentity(
  String recipient,
  ContactRecipientAction action,
) => switch (action) {
  ContactRecipientAction.text => _phoneIdentity(recipient),
  ContactRecipientAction.email => recipient.trim().toLowerCase(),
};

String? _selectTextRecipient(ContactDetail detail) {
  final methods = detail.methods
      .where(
        (method) =>
            method.type == ContactMethodType.phone &&
            method.receivesTexts == true &&
            _isValidPhone(method.rawValue),
      )
      .toList();
  if (methods.isEmpty) {
    return null;
  }
  final primary = methods.where((method) => method.isPrimary).firstOrNull;
  return (primary ?? methods.first).rawValue.trim();
}

String? _selectEmailRecipient(ContactDetail detail) {
  final methods = detail.methods
      .where(
        (method) =>
            method.type == ContactMethodType.email &&
            _isValidEmail(method.rawValue),
      )
      .toList();
  if (methods.isEmpty) {
    return null;
  }
  final primary = methods.where((method) => method.isPrimary).firstOrNull;
  return (primary ?? methods.first).rawValue.trim();
}

String _textExclusionReason(ContactDetail detail) {
  final phones = detail.methods
      .where((method) => method.type == ContactMethodType.phone)
      .toList();
  if (phones.isEmpty) {
    return 'No phone number';
  }
  if (!phones.any((method) => _isValidPhone(method.rawValue))) {
    return 'Invalid phone number';
  }
  return 'No text-capable phone';
}

String _emailExclusionReason(ContactDetail detail) {
  final emails = detail.methods
      .where((method) => method.type == ContactMethodType.email)
      .toList();
  if (emails.isEmpty) {
    return 'No email address';
  }
  return 'Invalid email address';
}

bool _isValidPhone(String value) => _phoneIdentity(value).length >= 7;

String _phoneIdentity(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

bool _isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

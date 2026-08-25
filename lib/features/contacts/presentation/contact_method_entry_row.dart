import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/contact_reference_style.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

/// One shared progressive entry affordance for Add Contact and the scoped
/// Contact Information editor.  It intentionally owns only presentation;
/// each screen keeps its existing scoped draft/write boundary.
final class ContactMethodEntryRow extends StatelessWidget {
  const ContactMethodEntryRow({
    required this.type,
    required this.hasExistingRows,
    required this.onTap,
    this.includeAddQualifier = false,
    super.key,
  });

  final ContactMethodType type;
  final bool hasExistingRows;
  final VoidCallback onTap;
  final bool includeAddQualifier;

  String get _noun => switch (type) {
    ContactMethodType.phone => 'Phone',
    ContactMethodType.email => 'Email',
    ContactMethodType.social => 'Social Profile',
  };

  Widget _icon(Color action) {
    if (type == ContactMethodType.phone) {
      return SvgPicture.asset(
        'assets/icons/contacts/social/phone-action.svg',
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(action, BlendMode.srcIn),
      );
    }
    return Icon(
      type == ContactMethodType.email
          ? Icons.mail_outline
          : Icons.alternate_email,
      size: 20,
      color: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = ContactReferenceStyle.actionOf(context);
    return TextButton.icon(
      key: Key('contact-method-entry-${type.name}'),
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        alignment: Alignment.centerLeft,
        foregroundColor: action,
        textStyle: AppTypography.button.copyWith(fontSize: 15),
      ),
      icon: _icon(action),
      label: Text(
        includeAddQualifier && hasExistingRows ? '+ Add $_noun' : '+ $_noun',
      ),
    );
  }
}

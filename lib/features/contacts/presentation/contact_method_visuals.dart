import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

/// One canonical, theme-tinted visual source for the Contact method forms.
const List<String> activeSocialProfileLabels = <String>[
  'Facebook',
  'Messenger',
  'WhatsApp',
  'LINE',
  'Skype',
  'KakaoTalk',
  'Instagram',
  'X',
  'Other',
];

String nextSocialProfileLabel(Iterable<String?> existingLabels) {
  final existing = existingLabels.whereType<String>().toSet();
  return activeSocialProfileLabels.firstWhere(
    (label) => !existing.contains(label),
    orElse: () => 'Other',
  );
}

Widget contactMethodVisual({
  required ContactMethodType type,
  required String label,
  required Color color,
  double size = 22,
}) {
  final asset = switch (type) {
    ContactMethodType.phone => switch (label) {
      'Mobile' => 'assets/icons/contacts/social/phone-action.svg',
      'Home' => 'assets/icons/contacts/social/phone-home.svg',
      'Work' => 'assets/icons/contacts/social/phone-work.svg',
      _ => null,
    },
    ContactMethodType.social => switch (label) {
      'Facebook' => 'assets/icons/contacts/social/facebook.svg',
      'Messenger' => 'assets/icons/contacts/social/messenger.svg',
      'WhatsApp' => 'assets/icons/contacts/social/whatsapp.svg',
      'LINE' => 'assets/icons/contacts/social/line.svg',
      'Skype' => 'assets/icons/contacts/social/skype.svg',
      'KakaoTalk' => 'assets/icons/contacts/social/kakaotalk.svg',
      'Instagram' => 'assets/icons/contacts/social/instagram.svg',
      _ => null,
    },
    ContactMethodType.email => null,
  };
  if (asset != null) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
  if (type == ContactMethodType.social && label == 'X') {
    return Text(
      '𝕏',
      style: TextStyle(
        color: color,
        fontSize: size + 1,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
  return Icon(
    type == ContactMethodType.email ? Icons.mail_outline : Icons.more_horiz,
    color: color,
    size: size,
  );
}

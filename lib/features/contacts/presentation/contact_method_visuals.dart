import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

/// One canonical, theme-tinted visual source for the Contact method forms.
const List<String> activeSocialProfileLabels = <String>[
  'Facebook',
  'Facebook Messenger',
  'WhatsApp',
  'LINE',
  'Skype',
  'KakaoTalk',
  'Instagram',
  'X',
];

/// Display-only compatibility for the former active Messenger label.  Existing
/// rows retain their stored label until a deliberate method edit saves them.
String socialProfileDisplayLabel(String? label) {
  return switch (label?.trim().toLowerCase()) {
    'messenger' || 'facebook messenger' => 'Facebook Messenger',
    _ => label?.trim().isNotEmpty == true ? label!.trim() : 'Social Profile',
  };
}

/// Canonical key shared by Social visuals and truthful external destinations.
/// Legacy Messenger remains readable as Facebook Messenger; inactive legacy
/// labels intentionally have no active key.
String? canonicalSocialProfileKey(String? label) {
  return switch (label?.trim().toLowerCase()) {
    'facebook' => 'facebook',
    'messenger' || 'facebook messenger' => 'facebook-messenger',
    'whatsapp' => 'whatsapp',
    'line' => 'line',
    'skype' => 'skype',
    'kakaotalk' => 'kakaotalk',
    'instagram' => 'instagram',
    'x' => 'x',
    _ => null,
  };
}

String nextSocialProfileLabel(Iterable<String?> existingLabels) {
  // Defaults advance by row creation, not by unused platform type. This keeps
  // saved duplicate platform rows valid and cycles Facebook after X.
  final rowCount = existingLabels.length;
  return activeSocialProfileLabels[rowCount % activeSocialProfileLabels.length];
}

/// The active Social SVGs do not share the same painted bounds inside their
/// view boxes. These values normalize their *visible* marks to the accepted
/// 22 dp Phone/Email optical scale, rather than uniformly enlarging every
/// Social asset. Values are expressed at a nominal 22 dp method visual.
const Map<String, double> _socialVisualSizeAt22Dp = <String, double>{
  'facebook': 22,
  'facebook-messenger': 18,
  'whatsapp': 19,
  'line': 28,
  'skype': 20,
  'kakaotalk': 24,
  'instagram': 18,
  'x': 26,
};

/// Resolves a platform's optical drawing size while preserving the caller's
/// nominal scale in compact form controls and the Profile's 22 dp action row.
double socialProfileVisualSizeFor(String? label, {double nominalSize = 22}) {
  final referenceSize =
      _socialVisualSizeAt22Dp[canonicalSocialProfileKey(label)];
  if (referenceSize == null) {
    return nominalSize;
  }
  return nominalSize * referenceSize / 22;
}

Widget contactMethodVisual({
  required ContactMethodType type,
  required String label,
  required Color color,
  double size = 22,
  bool normalizeSocialOptics = false,
}) {
  final socialKey = canonicalSocialProfileKey(label);
  final visualSize = type == ContactMethodType.social && normalizeSocialOptics
      ? socialProfileVisualSizeFor(label, nominalSize: size)
      : size;
  final asset = switch (type) {
    ContactMethodType.phone => switch (label) {
      'Mobile' => 'assets/icons/contacts/social/phone-action.svg',
      'Home' => 'assets/icons/contacts/social/phone-home.svg',
      'Work' => 'assets/icons/contacts/social/phone-work.svg',
      _ => null,
    },
    ContactMethodType.social => switch (socialKey) {
      'facebook' => 'assets/icons/contacts/social/facebook.svg',
      'facebook-messenger' => 'assets/icons/contacts/social/messenger.svg',
      'whatsapp' => 'assets/icons/contacts/social/whatsapp.svg',
      'line' => 'assets/icons/contacts/social/line.svg',
      'skype' => 'assets/icons/contacts/social/skype.svg',
      'kakaotalk' => 'assets/icons/contacts/social/kakaotalk.svg',
      'instagram' => 'assets/icons/contacts/social/instagram.svg',
      _ => null,
    },
    ContactMethodType.email => null,
  };
  if (asset != null) {
    return SvgPicture.asset(
      asset,
      width: visualSize,
      height: visualSize,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
  if (type == ContactMethodType.social && socialKey == 'x') {
    // Keep the approved text treatment, but give its font metrics a stable
    // visual box so it remains optically centered like SVG-based platforms.
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text(
          '𝕏',
          style: TextStyle(
            color: color,
            fontSize: visualSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
  return Icon(
    type == ContactMethodType.email
        ? contactEmailTypeIcon(label)
        : Icons.more_horiz,
    color: color,
    size: size,
  );
}

/// The one approved email-type mapping shared by Add Contact, scoped Contact
/// Information, and any Profile method presentation that exposes its type.
IconData contactEmailTypeIcon(String label) {
  return switch (label.trim().toLowerCase()) {
    'personal' || 'home' => Icons.person_outline,
    'work' => Icons.business_outlined,
    'family' => Icons.groups_3_outlined,
    _ => Icons.more_horiz,
  };
}

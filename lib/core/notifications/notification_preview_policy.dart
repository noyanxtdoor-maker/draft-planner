import 'package:rmplanner/features/privacy/domain/privacy_settings.dart';

enum EffectiveNotificationPreviewMode { generic, detailed }

EffectiveNotificationPreviewMode resolveNotificationPreviewMode({
  required PrivacySettings settings,
  required bool privacyProtectionRequired,
}) {
  if (privacyProtectionRequired) {
    return EffectiveNotificationPreviewMode.generic;
  }
  return settings.notificationPreviewMode == NotificationPreviewMode.showContent
      ? EffectiveNotificationPreviewMode.detailed
      : EffectiveNotificationPreviewMode.generic;
}

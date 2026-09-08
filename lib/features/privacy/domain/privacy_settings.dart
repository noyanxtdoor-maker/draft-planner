enum NotificationPreviewMode { hidden, showContent }

final class PrivacySettings {
  const PrivacySettings({
    required this.lockEnabled,
    required this.notificationPreviewMode,
  });

  const PrivacySettings.defaults()
    : lockEnabled = false,
      notificationPreviewMode = NotificationPreviewMode.hidden;

  final bool lockEnabled;
  final NotificationPreviewMode notificationPreviewMode;
}

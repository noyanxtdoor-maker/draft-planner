import 'package:rmplanner/core/security/privacy_gate.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/privacy/domain/privacy_settings.dart';

abstract interface class PrivacyRepository
    implements PrivacyLockConfigurationReader {
  Future<PrivacySettings> readSettings();

  Future<PrivacySettings> setLockEnabled(bool enabled);

  Future<PrivacySettings> setNotificationPreviewMode(
    NotificationPreviewMode mode,
  );

  Future<PermissionAudit> readPermissionAudit(OptionalPermission permission);

  Future<void> recordPermissionGranted(OptionalPermission permission);

  Future<void> recordPermissionRequested(OptionalPermission permission);
}

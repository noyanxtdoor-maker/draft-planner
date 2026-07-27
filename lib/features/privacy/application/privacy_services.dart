import 'package:rmplanner/features/privacy/domain/permission_summary.dart';

enum DeviceAuthenticationAvailability { available, unavailable }

enum DeviceAuthenticationResult {
  authenticated,
  canceled,
  failed,
  temporarilyLocked,
  unavailable,
}

abstract interface class DeviceAuthenticator {
  Future<DeviceAuthenticationAvailability> availability();

  Future<DeviceAuthenticationResult> authenticate();
}

abstract interface class PermissionGateway {
  Future<OperatingSystemPermissionState> status(OptionalPermission permission);

  Future<bool> openSystemSettings();
}

import 'package:permission_handler/permission_handler.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';

final class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  @override
  Future<bool> openSystemSettings() => openAppSettings();

  @override
  Future<OperatingSystemPermissionState> status(
    OptionalPermission permission,
  ) async {
    return _map(await _platformPermission(permission).status);
  }

  @override
  Future<OperatingSystemPermissionState> request(
    OptionalPermission permission,
  ) async {
    return _map(await _platformPermission(permission).request());
  }

  OperatingSystemPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return OperatingSystemPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return OperatingSystemPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) {
      return OperatingSystemPermissionState.restricted;
    }
    if (status.isDenied) {
      return OperatingSystemPermissionState.denied;
    }
    return OperatingSystemPermissionState.unavailable;
  }

  Permission _platformPermission(OptionalPermission permission) {
    return switch (permission) {
      OptionalPermission.contacts => Permission.contacts,
      OptionalPermission.notifications => Permission.notification,
      OptionalPermission.foregroundLocation => Permission.locationWhenInUse,
      OptionalPermission.calendar => Permission.calendarFullAccess,
    };
  }
}

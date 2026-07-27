import 'package:local_auth/local_auth.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';

final class LocalAuthDeviceAuthenticator implements DeviceAuthenticator {
  LocalAuthDeviceAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<DeviceAuthenticationResult> authenticate() async {
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: 'Unlock your private Next Transfer planner',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? DeviceAuthenticationResult.authenticated
          : DeviceAuthenticationResult.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => DeviceAuthenticationResult.canceled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          DeviceAuthenticationResult.temporarilyLocked,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware =>
          DeviceAuthenticationResult.unavailable,
        _ => DeviceAuthenticationResult.failed,
      };
    } on Object {
      return DeviceAuthenticationResult.failed;
    }
  }

  @override
  Future<DeviceAuthenticationAvailability> availability() async {
    try {
      return await _authentication.isDeviceSupported()
          ? DeviceAuthenticationAvailability.available
          : DeviceAuthenticationAvailability.unavailable;
    } on Object {
      return DeviceAuthenticationAvailability.unavailable;
    }
  }
}

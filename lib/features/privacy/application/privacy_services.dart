import 'dart:async';

import 'package:rmplanner/features/privacy/domain/permission_summary.dart';

const Duration privacyRelockThreshold = Duration(minutes: 5);

/// Monotonic elapsed-time source used for Privacy Lock background sessions.
/// Wall-clock changes must not shorten or extend the security window.
abstract interface class MonotonicClock {
  Duration get elapsed;
}

final class StopwatchMonotonicClock implements MonotonicClock {
  StopwatchMonotonicClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;
}

/// One-shot background session. Repeated lifecycle notifications do not reset
/// the original monotonic start, and the timer is never periodic.
final class PrivacyBackgroundSession {
  PrivacyBackgroundSession({
    MonotonicClock? clock,
    this.threshold = privacyRelockThreshold,
  }) : _clock = clock ?? StopwatchMonotonicClock();

  final MonotonicClock _clock;
  final Duration threshold;
  Timer? _timer;
  Duration? _startedAt;
  bool _thresholdReached = false;

  bool get isActive => _startedAt != null;

  void enterBackground(void Function() onThreshold) {
    if (isActive) {
      return;
    }
    _startedAt = _clock.elapsed;
    _thresholdReached = false;
    _timer = Timer(threshold, () {
      _thresholdReached = true;
      onThreshold();
    });
  }

  bool resume() {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return false;
    }
    final reached =
        _thresholdReached || _clock.elapsed - startedAt >= threshold;
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _thresholdReached = false;
    return reached;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _thresholdReached = false;
  }
}

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

abstract interface class PrivacyGate {
  Future<bool> isUnlockRequired();

  void markLocked();

  void markUnlocked();
}

final class UnconfiguredPrivacyGate implements PrivacyGate {
  const UnconfiguredPrivacyGate();

  @override
  Future<bool> isUnlockRequired() async => false;

  @override
  void markLocked() {}

  @override
  void markUnlocked() {}
}

abstract interface class PrivacyLockConfigurationReader {
  Future<bool> isPrivacyLockEnabled();
}

final class SessionPrivacyGate implements PrivacyGate {
  SessionPrivacyGate({required this.settingsReader});

  final PrivacyLockConfigurationReader settingsReader;
  bool _unlocked = false;

  @override
  Future<bool> isUnlockRequired() async {
    final enabled = await settingsReader.isPrivacyLockEnabled();
    return enabled && !_unlocked;
  }

  @override
  void markLocked() {
    _unlocked = false;
  }

  @override
  void markUnlocked() {
    _unlocked = true;
  }
}

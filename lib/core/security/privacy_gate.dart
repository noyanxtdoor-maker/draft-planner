abstract interface class PrivacyGate {
  Future<bool> isUnlockRequired();
}

final class UnconfiguredPrivacyGate implements PrivacyGate {
  const UnconfiguredPrivacyGate();

  @override
  Future<bool> isUnlockRequired() async => false;
}

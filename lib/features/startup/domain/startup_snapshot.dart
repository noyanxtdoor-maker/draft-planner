import 'package:rmplanner/features/startup/domain/local_profile.dart';
import 'package:rmplanner/features/startup/domain/onboarding_checkpoint.dart';

enum AccountSessionState { localOnly, signedIn, expired }

enum LocalSyncState { notConfigured, idle }

final class StartupSnapshot {
  const StartupSnapshot({
    required this.accountSessionState,
    required this.syncState,
    required this.unlockRequired,
    this.profile,
    this.onboardingCheckpoint,
  });

  final LocalProfile? profile;
  final OnboardingCheckpoint? onboardingCheckpoint;
  final AccountSessionState accountSessionState;
  final LocalSyncState syncState;
  final bool unlockRequired;
}

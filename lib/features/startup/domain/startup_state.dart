import 'package:rmplanner/features/startup/domain/local_profile.dart';
import 'package:rmplanner/features/startup/domain/onboarding_checkpoint.dart';
import 'package:rmplanner/features/startup/domain/startup_snapshot.dart';

sealed class StartupState {
  const StartupState();
}

final class StartupOpening extends StartupState {
  const StartupOpening();
}

final class StartupWelcome extends StartupState {
  const StartupWelcome();
}

final class StartupOnboarding extends StartupState {
  const StartupOnboarding(this.checkpoint);

  final OnboardingCheckpoint checkpoint;
}

final class StartupReady extends StartupState {
  const StartupReady({
    required this.profile,
    required this.accountSessionState,
    required this.syncState,
  });

  final LocalProfile profile;
  final AccountSessionState accountSessionState;
  final LocalSyncState syncState;
}

final class StartupProtected extends StartupState {
  const StartupProtected();
}

final class StartupRecovery extends StartupState {
  const StartupRecovery({required this.reasonCode});

  final String reasonCode;
}

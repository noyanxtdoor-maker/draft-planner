import 'package:rmplanner/features/startup/domain/local_profile.dart';
import 'package:rmplanner/features/startup/domain/onboarding_checkpoint.dart';
import 'package:rmplanner/features/startup/domain/startup_snapshot.dart';

abstract interface class StartupRepository {
  Future<StartupSnapshot> resolveStartup();

  Future<OnboardingCheckpoint> beginOrResumeOnboarding();

  Future<OnboardingCheckpoint> saveOnboardingDraft(String? displayName);

  Future<LocalProfile> completeOnboarding();

  Future<LocalProfile> updateDisplayName(String? displayName);
}

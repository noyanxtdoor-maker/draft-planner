enum OnboardingStage { profileDraft, completed }

final class OnboardingCheckpoint {
  const OnboardingCheckpoint({
    required this.pendingProfileId,
    required this.stage,
    required this.updatedAtUtc,
    this.draftDisplayName,
  });

  final String pendingProfileId;
  final OnboardingStage stage;
  final String? draftDisplayName;
  final DateTime updatedAtUtc;
}

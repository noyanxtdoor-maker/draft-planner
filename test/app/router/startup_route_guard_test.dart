import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/router/startup_route_guard.dart';
import 'package:rmplanner/features/startup/domain/local_profile.dart';
import 'package:rmplanner/features/startup/domain/onboarding_checkpoint.dart';
import 'package:rmplanner/features/startup/domain/startup_snapshot.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

void main() {
  final profile = LocalProfile(
    id: 'profile',
    localName: 'Local Profile',
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
  );

  test('AC-A-003,004,017: startup guard prioritizes local lifecycle state', () {
    expect(
      StartupRouteGuard.redirect(
        state: const StartupOpening(),
        currentLocation: RoutePaths.home,
      ),
      RoutePaths.startup,
    );
    expect(
      StartupRouteGuard.redirect(
        state: const StartupWelcome(),
        currentLocation: RoutePaths.home,
      ),
      RoutePaths.onboarding,
    );
    expect(
      StartupRouteGuard.redirect(
        state: const StartupRecovery(reasonCode: 'test'),
        currentLocation: RoutePaths.home,
      ),
      RoutePaths.recovery,
    );
    expect(
      StartupRouteGuard.redirect(
        state: const StartupProtected(),
        currentLocation: RoutePaths.home,
      ),
      RoutePaths.protectedContent,
    );
    expect(
      StartupRouteGuard.redirect(
        state: StartupReady(
          profile: profile,
          accountSessionState: AccountSessionState.expired,
          syncState: LocalSyncState.notConfigured,
        ),
        currentLocation: RoutePaths.startup,
      ),
      RoutePaths.home,
    );
    expect(
      StartupRouteGuard.redirect(
        state: StartupReady(
          profile: profile,
          accountSessionState: AccountSessionState.expired,
          syncState: LocalSyncState.notConfigured,
        ),
        currentLocation: '/valid-local-feature',
      ),
      isNull,
    );
  });

  test(
    'AC-A-011: onboarding checkpoint remains at the onboarding boundary',
    () {
      expect(
        StartupRouteGuard.redirect(
          state: StartupOnboarding(
            OnboardingCheckpoint(
              pendingProfileId: 'pending',
              stage: OnboardingStage.profileDraft,
              updatedAtUtc: DateTime.utc(2026),
            ),
          ),
          currentLocation: RoutePaths.home,
        ),
        RoutePaths.onboarding,
      );
    },
  );
}

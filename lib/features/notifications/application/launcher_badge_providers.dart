import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/notifications/launcher_badge_gateway.dart';
import 'package:rmplanner/features/notifications/application/launcher_badge_coordinator.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final launcherBadgeGatewayProvider = Provider<LauncherBadgeGateway>((ref) {
  throw StateError('LauncherBadgeGateway must be overridden at the app root');
});

typedef LauncherBadgeRefresh = Future<void> Function();

final launcherBadgeRefreshProvider = Provider<LauncherBadgeRefresh>((ref) {
  return () async {
    try {
      final startup = ref.read(startupControllerProvider);
      final calendar = ref.read(calendarEventRepositoryProvider);
      final planner = ref.read(plannerRepositoryProvider);
      if (startup is! StartupReady ||
          calendar is! CalendarEventRangeSource ||
          planner is! PlannerBadgeTaskSource) {
        return;
      }
      await LauncherBadgeCoordinator(
        calendarSource: calendar as CalendarEventRangeSource,
        taskSource: planner as PlannerBadgeTaskSource,
        gateway: ref.read(launcherBadgeGatewayProvider),
      ).refresh(
        profileId: startup.profile.id,
        today: ref.read(plannerDateSourceProvider).today(),
        nowUtc: DateTime.now().toUtc(),
      );
    } on Object {
      // Badge rendering is a best-effort platform projection. Canonical Event
      // and Task persistence has already committed and must never roll back.
    }
  };
});

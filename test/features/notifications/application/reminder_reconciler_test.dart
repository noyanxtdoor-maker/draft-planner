import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/background/background_work_request.dart';
import 'package:rmplanner/core/notifications/notification_gateway.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/features/notifications/application/reminder_reconciler.dart';
import 'package:rmplanner/features/notifications/data/drift_notification_foundation_repository.dart';
import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:rmplanner/features/notifications/domain/reminder_policy.dart';

import '../../../support/test_dependencies.dart';

void main() {
  for (final kind in ReminderSourceKind.values) {
    test(
      'OFF overtaking a platform schedule cancels it and ON recreates it: ${kind.name}',
      () async {
        final database = openMemoryDatabase();
        addTearDown(database.close);
        final clock = FixedClock(DateTime.utc(2026, 9, 8, 10));
        final repository = DriftNotificationFoundationRepository(
          database: database,
          clock: clock,
        );
        final profile = await buildTestRepository(
          database: database,
        ).completeOnboarding();
        final enabled = const NotificationPreferences.defaults().copyWith(
          systemNotificationsEnabled: true,
          eventRemindersEnabled: true,
          taskRemindersEnabled: true,
          weeklyReviewRemindersEnabled: true,
          awaitingReportRemindersEnabled: true,
        );
        await repository.savePreferences(
          profileId: profile.id,
          preferences: enabled,
        );
        final gateway = _RacingGateway();
        final reconciler = ReminderReconciler(
          repository: repository,
          gateway: gateway,
          clock: clock,
        );
        Future<void> reconcile() => reconciler.reconcile(
          sourceKind: kind,
          profileId: profile.id,
          sourceId: 'race-source',
          occurrenceId: 'race-occurrence',
          startsAtUtc: DateTime.utc(2026, 9, 8, 11),
          globalOffsetMinutes: 5,
          categoryEnabled: true,
          systemEnabled: true,
          sourceActive: true,
          genericTitle: 'Reminder',
          genericBody: 'Due soon',
        );
        gateway.onSchedule = () async {
          await repository.savePreferences(
            profileId: profile.id,
            preferences: enabled.copyWith(systemNotificationsEnabled: false),
          );
        };
        await reconcile();
        final key = ReminderReconciler.stableKey(
          sourceKind: kind,
          profileId: profile.id,
          occurrenceId: 'race-occurrence',
        );
        expect(gateway.pendingIds, isEmpty);
        expect(
          (await repository.readWorkRequest(key))?.state,
          BackgroundWorkState.cancelledObsolete,
        );
        // Stale caller booleans cannot recreate notifications while durable OFF.
        gateway.onSchedule = null;
        await reconcile();
        expect(gateway.pendingIds, isEmpty);
        await repository.savePreferences(
          profileId: profile.id,
          preferences: enabled,
        );
        await reconcile();
        expect(gateway.pendingIds, hasLength(1));
        expect(
          (await repository.readWorkRequest(key))?.state,
          BackgroundWorkState.scheduled,
        );
      },
    );
  }

  test(
    'M2/M3 reconciler schedules exactly one future eligible reminder and cancels it when inactive',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final clock = FixedClock(DateTime.utc(2026, 9, 6, 10));
      final gateway = FakeNotificationGateway();
      final reconciler = ReminderReconciler(
        repository: DriftNotificationFoundationRepository(
          database: database,
          clock: clock,
        ),
        gateway: gateway,
        clock: clock,
      );
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await reconciler.repository.savePreferences(
        profileId: profile.id,
        preferences: const NotificationPreferences.defaults().copyWith(
          systemNotificationsEnabled: true,
          eventRemindersEnabled: true,
          taskRemindersEnabled: true,
        ),
      );
      await reconciler.reconcile(
        sourceKind: ReminderSourceKind.calendarEvent,
        profileId: profile.id,
        sourceId: 'event-1',
        occurrenceId: 'occurrence-1',
        startsAtUtc: DateTime.utc(2026, 9, 6, 11),
        globalOffsetMinutes: 15,
        categoryEnabled: true,
        systemEnabled: true,
        sourceActive: true,
        genericTitle: 'Upcoming event',
        genericBody: 'Your event starts soon.',
      );
      expect(gateway.scheduleCount, 1);
      await reconciler.reconcile(
        sourceKind: ReminderSourceKind.calendarEvent,
        profileId: profile.id,
        sourceId: 'event-1',
        occurrenceId: 'occurrence-1',
        startsAtUtc: DateTime.utc(2026, 9, 6, 11),
        globalOffsetMinutes: 15,
        categoryEnabled: true,
        systemEnabled: true,
        sourceActive: true,
        genericTitle: 'Upcoming event',
        genericBody: 'Your event starts soon.',
      );
      expect(gateway.scheduleCount, 1, reason: 'same state is idempotent');
      await reconciler.reconcile(
        sourceKind: ReminderSourceKind.calendarEvent,
        profileId: profile.id,
        sourceId: 'event-1',
        occurrenceId: 'occurrence-1',
        startsAtUtc: DateTime.utc(2026, 9, 6, 11),
        globalOffsetMinutes: 15,
        categoryEnabled: true,
        systemEnabled: true,
        sourceActive: false,
        genericTitle: 'Upcoming event',
        genericBody: 'Your event starts soon.',
      );
      expect(gateway.scheduleCount, 1);
    },
  );

  for (final sourceKind in ReminderSourceKind.values) {
    test(
      '${sourceKind.name} preview content refresh reuses identity and is idempotent',
      () async {
        final database = openMemoryDatabase();
        addTearDown(database.close);
        final clock = FixedClock(DateTime.utc(2026, 9, 6, 10));
        final gateway = FakeNotificationGateway();
        final repository = DriftNotificationFoundationRepository(
          database: database,
          clock: clock,
        );
        final reconciler = ReminderReconciler(
          repository: repository,
          gateway: gateway,
          clock: clock,
        );
        final profile = await buildTestRepository(
          database: database,
        ).completeOnboarding();
        await repository.savePreferences(
          profileId: profile.id,
          preferences: const NotificationPreferences.defaults().copyWith(
            systemNotificationsEnabled: true,
            eventRemindersEnabled: true,
            taskRemindersEnabled: true,
            weeklyReviewRemindersEnabled: true,
            awaitingReportRemindersEnabled: true,
          ),
        );
        final sourceId = '${sourceKind.name}-source';
        final occurrenceId = '${sourceKind.name}-occurrence';

        Future<void> reconcile({
          required bool showDetails,
          required String revision,
        }) {
          return reconciler.reconcile(
            sourceKind: sourceKind,
            profileId: profile.id,
            sourceId: sourceId,
            occurrenceId: occurrenceId,
            startsAtUtc: DateTime.utc(2026, 9, 6, 12),
            globalOffsetMinutes: 15,
            categoryEnabled: true,
            systemEnabled: true,
            sourceActive: true,
            genericTitle: 'Generic title',
            genericBody: 'Generic body',
            detailedTitle: 'Private title',
            detailedBody: 'Private description',
            showDetails: showDetails,
            refreshContent: true,
            renderRevision: revision,
          );
        }

        await reconcile(showDetails: false, revision: 'generic');
        final key = ReminderReconciler.stableKey(
          sourceKind: sourceKind,
          profileId: profile.id,
          occurrenceId: occurrenceId,
        );
        final initial = await repository.readWorkRequest(key);
        expect(gateway.scheduledRequests.single.title, 'Generic title');

        await reconcile(showDetails: true, revision: 'detailed_1');
        expect(gateway.scheduledRequests.last.title, 'Private title');
        expect(gateway.scheduledRequests.last.body, 'Private description');
        expect(
          (await repository.readWorkRequest(key))?.platformNotificationId,
          initial?.platformNotificationId,
        );

        await reconcile(showDetails: true, revision: 'detailed_1');
        expect(gateway.scheduleCount, 2, reason: 'same render is idempotent');

        await reconcile(showDetails: false, revision: 'generic');
        expect(gateway.scheduleCount, 3);
        expect(gateway.scheduledRequests.last.title, 'Generic title');
        final rows = await database
            .select(database.backgroundWorkRequests)
            .get();
        expect(rows, hasLength(1));
        expect(
          rows.single.platformNotificationId,
          initial?.platformNotificationId,
        );
        expect(rows.single.sourceRevision, 'generic');
        expect(rows.single.toJson().values, isNot(contains('Private title')));
        expect(
          rows.single.toJson().values,
          isNot(contains('Private description')),
        );
      },
    );
  }
}

final class _RacingGateway implements NotificationGateway {
  Future<void> Function()? onSchedule;
  final Set<int> pendingIds = {};
  @override
  Stream<NotificationResponseIntent> get responses => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    await onSchedule?.call();
    pendingIds.add(request.platformId);
  }

  @override
  Future<void> cancel(int platformId) async {
    pendingIds.remove(platformId);
  }

  @override
  Future<List<PendingLocalNotification>> pending() async =>
      pendingIds.map((id) => PendingLocalNotification(platformId: id)).toList();
  @override
  NotificationResponseIntent? takeInitialResponse() => null;
}

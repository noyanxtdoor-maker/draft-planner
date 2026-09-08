import 'package:rmplanner/core/background/background_work_request.dart';
import 'package:rmplanner/core/notifications/canonical_reminder_delivery_gateway.dart';
import 'package:rmplanner/core/notifications/notification_gateway.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/notifications/application/notification_foundation_repository.dart';
import 'package:rmplanner/features/notifications/application/reminder_quiet_hours.dart';
import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:rmplanner/features/notifications/domain/reminder_policy.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

/// M2/M3's source-driven one-shot reminder boundary.  It owns neither Event
/// nor Task persistence: callers invoke it only after their canonical source
/// write has committed successfully.
final class ReminderReconciler {
  const ReminderReconciler({
    required this.repository,
    required this.gateway,
    required this.clock,
    this.deliveryKey,
    this.deliveryScheduledAtUtc,
    this.snoozeIntent,
    this.actionAtUtc,
    this.deviceLocation,
  });

  final NotificationFoundationRepository repository;
  final NotificationGateway gateway;
  final AppClock clock;
  final String? deliveryKey;
  final DateTime? deliveryScheduledAtUtc;
  final NotificationResponseIntent? snoozeIntent;
  final DateTime? actionAtUtc;

  /// Canonical device zone for Quiet Hours arithmetic.  The device default
  /// local zone is only correct inside the main isolate binding; a headless
  /// WorkManager isolate may resolve a different zone, which silently moved
  /// delayed targets onto the wrong wall clock.
  final tz.Location? deviceLocation;

  static bool _sameInstant(DateTime? a, DateTime? b) =>
      a == null ? b == null : b != null && a.isAtSameMomentAs(b);

  static String stableKey({
    required ReminderSourceKind sourceKind,
    required String profileId,
    required String occurrenceId,
  }) => switch (sourceKind) {
    ReminderSourceKind.weeklyReview =>
      'planning:weekly-review:$profileId:$occurrenceId',
    ReminderSourceKind.awaitingReport =>
      'planning:awaiting-report:$profileId:$occurrenceId',
    _ => 'reminder:${sourceKind.name}:$profileId:$occurrenceId:base',
  };

  static String planningStableKey({
    required ReminderSourceKind sourceKind,
    required String profileId,
    required String occurrenceId,
  }) => stableKey(
    sourceKind: sourceKind,
    profileId: profileId,
    occurrenceId: occurrenceId,
  );

  Future<ReminderPolicy> savePolicy({
    required String profileId,
    required ReminderSourceKind sourceKind,
    required String sourceId,
    required String occurrenceId,
    required ReminderPolicyMode mode,
    int? offsetMinutes,
  }) async {
    final now = clock.nowUtc();
    final existing = (await repository.readPolicies(
      profileId: profileId,
      sourceKind: sourceKind,
      sourceId: sourceId,
    )).where((policy) => policy.occurrenceId == occurrenceId).firstOrNull;
    return repository.upsertPolicy(
      ReminderPolicy(
        id: existing?.id ?? const Uuid().v4(),
        profileId: profileId,
        sourceKind: sourceKind,
        sourceId: sourceId,
        occurrenceId: occurrenceId,
        mode: mode,
        offsetMinutes: mode == ReminderPolicyMode.offset ? offsetMinutes : null,
        createdAtUtc: existing?.createdAtUtc ?? now,
        updatedAtUtc: now,
      ),
    );
  }

  Future<void> cancel({
    required ReminderSourceKind sourceKind,
    required String profileId,
    required String occurrenceId,
  }) async {
    final key = planningStableKey(
      sourceKind: sourceKind,
      profileId: profileId,
      occurrenceId: occurrenceId,
    );
    final existing = await repository.readWorkRequest(key);
    if (existing?.platformNotificationId case final platformId?) {
      await gateway.cancel(platformId);
    }
    if (existing != null) {
      await repository.upsertWorkRequest(
        existing.copyWith(
          state: BackgroundWorkState.cancelledObsolete,
          updatedAtUtc: clock.nowUtc(),
        ),
      );
    }
  }

  Future<void> reconcile({
    required ReminderSourceKind sourceKind,
    required String profileId,
    required String sourceId,
    required String occurrenceId,
    required DateTime? startsAtUtc,
    DateTime? scheduledAtUtc,
    required int? globalOffsetMinutes,
    required bool categoryEnabled,
    required bool systemEnabled,
    required bool sourceActive,
    required String genericTitle,
    required String genericBody,
    String? detailedTitle,
    String? detailedBody,
    bool showDetails = false,
    bool refreshContent = false,
    String? renderRevision,
    int? sourceVersion,
  }) async {
    final key = planningStableKey(
      sourceKind: sourceKind,
      profileId: profileId,
      occurrenceId: occurrenceId,
    );
    final existing = await repository.readWorkRequest(key);
    final policies = await repository.readPolicies(
      profileId: profileId,
      sourceKind: sourceKind,
      sourceId: sourceId,
    );
    final policy =
        policies.where((p) => p.occurrenceId == occurrenceId).firstOrNull ??
        policies
            .where((p) => p.occurrenceId == ReminderPolicy.seriesOccurrenceId)
            .firstOrNull;
    final offset = switch (policy?.mode) {
      ReminderPolicyMode.offset => policy!.offsetMinutes,
      ReminderPolicyMode.off => null,
      _ => globalOffsetMinutes,
    };
    final baseFireAt =
        scheduledAtUtc ??
        (startsAtUtc == null || offset == null
            ? null
            : startsAtUtc.subtract(Duration(minutes: offset)));
    // Only identity, source/policy timestamps and rendering mode enter this token.
    final identity = sourceVersion == null
        ? null
        : 'm4_${sourceVersion}_${startsAtUtc?.microsecondsSinceEpoch ?? 0}_${offset ?? -1}_${policy?.updatedAtUtc.microsecondsSinceEpoch ?? 0}';
    final revision = identity == null
        ? renderRevision
        : '$identity.${renderRevision ?? 'generic'}';
    final sameSource = identity == null
        ? existing?.sourceRevision == revision
        : existing?.sourceRevision?.split('.').first == identity;
    final now = clock.nowUtc();
    final action = snoozeIntent;
    final requestedSnooze =
        action != null &&
        action.action == NotificationResponseAction.snooze &&
        action.profileId == profileId &&
        action.sourceId == sourceId &&
        action.occurrenceId == occurrenceId &&
        action.sourceKind.name == sourceKind.name;
    final acceptsSnooze =
        requestedSnooze &&
        existing != null &&
        sameSource &&
        existing.snoozeCount == action.generation &&
        (existing.state == BackgroundWorkState.completed ||
            (existing.state == BackgroundWorkState.scheduled &&
                existing.scheduledForUtc != null &&
                !existing.scheduledForUtc!.isAfter(now)));
    final priorSnooze =
        sameSource &&
            existing != null &&
            existing.snoozeCount > 0 &&
            (existing.state == BackgroundWorkState.scheduled ||
                existing.state == BackgroundWorkState.queued)
        ? existing.nextEligibleAtUtc
        : null;
    final preferences = await repository.readPreferences(profileId: profileId);
    final snoozedUntil = acceptsSnooze
        ? DateTime.fromMillisecondsSinceEpoch(
            (actionAtUtc ?? now).millisecondsSinceEpoch ~/ 1000 * 1000,
            isUtc: true,
          ).add(Duration(minutes: preferences.snoozeDurationMinutes))
        : priorSnooze;
    final proposed = snoozedUntil ?? baseFireAt;
    var fireAt = proposed == null
        ? null
        : ReminderQuietHours.delayUntilEnd(
            targetUtc: proposed,
            settings: preferences.quietHours,
            location: deviceLocation,
          );
    final delivery =
        deliveryKey == key &&
        existing != null &&
        sameSource &&
        existing.state == BackgroundWorkState.scheduled &&
        _sameInstant(existing.scheduledForUtc, deliveryScheduledAtUtc) &&
        _sameInstant(fireAt, existing.scheduledForUtc) &&
        fireAt != null &&
        !fireAt.isAfter(now);
    if (delivery) {
      // Inexact execution can reach a different quiet interval from its target.
      final allowed = ReminderQuietHours.delayUntilEnd(
        targetUtc: now,
        settings: preferences.quietHours,
        location: deviceLocation,
      );
      if (allowed.isAfter(now)) fireAt = allowed;
    }
    final eventObsolete =
        sourceKind == ReminderSourceKind.calendarEvent &&
        startsAtUtc != null &&
        ((delivery && !startsAtUtc.isAfter(now)) ||
            (fireAt != null &&
                fireAt != baseFireAt &&
                !startsAtUtc.isAfter(fireAt)));
    final eligible =
        preferences.systemNotificationsEnabled &&
        _categoryEnabled(preferences, sourceKind) &&
        systemEnabled &&
        categoryEnabled &&
        sourceActive &&
        baseFireAt != null &&
        fireAt != null &&
        !eventObsolete;
    if (!eligible || (!fireAt.isAfter(now) && !delivery)) {
      // Keep an already displayed valid reminder actionable; a source/preference
      // change still cancels it. Recovery never turns an expired target into now.
      if (eligible &&
          sameSource &&
          existing?.state == BackgroundWorkState.completed) {
        return;
      }
      // Native inexact alarms do not call the Dart delivery worker. A past
      // target can therefore still be pending or already visible while its
      // durable state remains scheduled. Recovery (including another reminder's
      // Snooze pass) must not cancel that valid notification before its action.
      final platform = gateway;
      if (eligible &&
          sameSource &&
          existing?.state == BackgroundWorkState.scheduled &&
          existing?.platformNotificationId != null &&
          _sameInstant(existing?.scheduledForUtc, fireAt) &&
          (sourceKind != ReminderSourceKind.calendarEvent ||
              startsAtUtc!.isAfter(now)) &&
          platform is CanonicalReminderDeliveryGateway) {
        final native = platform as CanonicalReminderDeliveryGateway;
        final platformId = existing!.platformNotificationId!;
        if (await native.hasPendingReminder(platformId, fireAt)) return;
        if (await native.hasDisplayedReminder(platformId)) {
          await repository.upsertWorkRequest(
            existing.copyWith(
              state: BackgroundWorkState.completed,
              completedAtUtc: now,
              updatedAtUtc: now,
            ),
          );
          return;
        }
      }
      await cancel(
        sourceKind: sourceKind,
        profileId: profileId,
        occurrenceId: occurrenceId,
      );
      return;
    }
    final generation = acceptsSnooze
        ? existing.snoozeCount + 1
        : snoozedUntil != null
        ? existing!.snoozeCount
        : 0;
    var durable = BackgroundWorkRequest(
      stableKey: key,
      profileId: profileId,
      category: BackgroundWorkCategory.reminderRecovery,
      ownerKind: switch (sourceKind) {
        ReminderSourceKind.calendarEvent => BackgroundWorkOwnerKind.occurrence,
        ReminderSourceKind.task => BackgroundWorkOwnerKind.task,
        ReminderSourceKind.weeklyReview ||
        ReminderSourceKind.awaitingReport => BackgroundWorkOwnerKind.planning,
      },
      ownerId: sourceId,
      occurrenceId: occurrenceId,
      sourceRevision: revision,
      scheduledForUtc: fireAt,
      state: BackgroundWorkState.queued,
      platformNotificationId: existing?.platformNotificationId,
      attemptCount: existing?.attemptCount ?? 0,
      snoozeCount: generation,
      nextEligibleAtUtc: snoozedUntil,
      createdAtUtc: existing?.createdAtUtc ?? now,
      updatedAtUtc: now,
    );
    final platform = gateway;
    if (!delivery &&
        !acceptsSnooze &&
        existing?.state == BackgroundWorkState.scheduled &&
        _sameInstant(existing?.scheduledForUtc, fireAt) &&
        existing?.sourceRevision == revision &&
        (platform is! CanonicalReminderDeliveryGateway ||
            await (platform as CanonicalReminderDeliveryGateway)
                .hasPendingReminder(
                  existing!.platformNotificationId!,
                  fireAt,
                ))) {
      return;
    }
    if (existing?.platformNotificationId != null &&
        !_sameInstant(existing?.scheduledForUtc, fireAt)) {
      await gateway.cancel(existing!.platformNotificationId!);
    }
    durable = await repository.upsertWorkRequest(durable);
    final platformId =
        durable.platformNotificationId ??
        await repository.allocatePlatformNotificationId(key);
    final intent = NotificationResponseIntent(
      profileId: profileId,
      sourceKind: switch (sourceKind) {
        ReminderSourceKind.calendarEvent =>
          NotificationSourceKind.calendarEvent,
        ReminderSourceKind.task => NotificationSourceKind.task,
        ReminderSourceKind.weeklyReview => NotificationSourceKind.weeklyReview,
        ReminderSourceKind.awaitingReport =>
          NotificationSourceKind.awaitingReport,
      },
      sourceId: sourceId,
      occurrenceId: occurrenceId,
      action: NotificationResponseAction.open,
      generation: generation,
    );
    final request = LocalNotificationRequest(
      platformId: platformId,
      stableKey: key,
      channel: switch (sourceKind) {
        ReminderSourceKind.weeklyReview ||
        ReminderSourceKind.awaitingReport => NotificationChannelKind.planning,
        _ => NotificationChannelKind.reminders,
      },
      scheduledAtUtc: fireAt,
      title: showDetails && detailedTitle != null
          ? detailedTitle
          : genericTitle,
      body: showDetails && detailedBody != null ? detailedBody : genericBody,
      responseIntent: intent,
    );
    Future<bool> stillEnabled() async {
      final latest = await repository.readPreferences(profileId: profileId);
      return latest.systemNotificationsEnabled &&
          _categoryEnabled(latest, sourceKind);
    }

    Future<void> cancelDisabled() async {
      await gateway.cancel(platformId);
      await repository.upsertWorkRequest(
        durable.copyWith(
          state: BackgroundWorkState.cancelledObsolete,
          platformNotificationId: platformId,
          updatedAtUtc: clock.nowUtc(),
        ),
      );
    }

    // An OFF write can overtake an already-running horizon or platform call.
    if (!await stillEnabled()) {
      await cancelDisabled();
      return;
    }
    final deliverNow = delivery && !fireAt.isAfter(now);
    if (deliverNow && platform is CanonicalReminderDeliveryGateway) {
      await (platform as CanonicalReminderDeliveryGateway)
          .showCanonicalReminder(request);
    } else {
      await gateway.schedule(request);
    }
    if (!await stillEnabled()) {
      await cancelDisabled();
      return;
    }
    await repository.upsertWorkRequest(
      durable.copyWith(
        state: deliverNow
            ? BackgroundWorkState.completed
            : BackgroundWorkState.scheduled,
        platformNotificationId: platformId,
        updatedAtUtc: clock.nowUtc(),
        completedAtUtc: deliverNow ? clock.nowUtc() : null,
      ),
    );
  }

  static bool _categoryEnabled(
    NotificationPreferences preferences,
    ReminderSourceKind sourceKind,
  ) => switch (sourceKind) {
    ReminderSourceKind.calendarEvent => preferences.eventRemindersEnabled,
    ReminderSourceKind.task => preferences.taskRemindersEnabled,
    ReminderSourceKind.weeklyReview => preferences.weeklyReviewRemindersEnabled,
    ReminderSourceKind.awaitingReport =>
      preferences.awaitingReportRemindersEnabled,
  };
}

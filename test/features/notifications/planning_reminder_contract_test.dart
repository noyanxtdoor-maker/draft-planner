import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/features/notifications/application/reminder_reconciler.dart';
import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:rmplanner/features/notifications/domain/reminder_policy.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

void main() {
  test('planning categories default off and remain gated by system truth', () {
    const defaults = NotificationPreferences.defaults();
    expect(defaults.weeklyReviewRemindersEnabled, isFalse);
    expect(defaults.awaitingReportRemindersEnabled, isFalse);
    expect(
      defaults.effectiveWeeklyReviewEnabled(androidPermissionGranted: true),
      isFalse,
    );
    expect(
      defaults
          .copyWith(
            systemNotificationsEnabled: true,
            weeklyReviewRemindersEnabled: true,
            awaitingReportRemindersEnabled: true,
          )
          .effectiveAwaitingReportEnabled(androidPermissionGranted: false),
      isFalse,
    );
  });

  test('planning stable keys are family-specific and ID-only', () {
    expect(
      ReminderReconciler.planningStableKey(
        sourceKind: ReminderSourceKind.weeklyReview,
        profileId: 'profile-1',
        occurrenceId: 'weekly-plan-1',
      ),
      'planning:weekly-review:profile-1:weekly-plan-1',
    );
    expect(
      ReminderReconciler.planningStableKey(
        sourceKind: ReminderSourceKind.awaitingReport,
        profileId: 'profile-1',
        occurrenceId: 'occurrence-1',
      ),
      'planning:awaiting-report:profile-1:occurrence-1',
    );
  });

  test(
    'weekly review due state remains distinct from canonical completion',
    () {
      final period = WeeklyPeriod(
        start: const PlannerDate(year: 2026, month: 9, day: 1),
        end: const PlannerDate(year: 2026, month: 9, day: 7),
      );
      final due = WeeklyPlan(
        id: 'weekly-plan-1',
        profileId: 'profile-1',
        period: period,
        timeZoneId: 'Etc/UTC',
        storedState: WeeklyPlanState.active,
        indicators: const <WeeklyIndicatorReview>[],
        createdAtUtc: DateTime.utc(2026, 9, 1),
        updatedAtUtc: DateTime.utc(2026, 9, 1),
      );
      expect(
        due.effectiveState(const PlannerDate(year: 2026, month: 9, day: 8)),
        WeeklyPlanState.reviewDue,
      );
      final reviewed = WeeklyPlan(
        id: due.id,
        profileId: due.profileId,
        period: due.period,
        timeZoneId: due.timeZoneId,
        storedState: WeeklyPlanState.reviewed,
        indicators: due.indicators,
        createdAtUtc: due.createdAtUtc,
        updatedAtUtc: DateTime.utc(2026, 9, 8),
        reviewCompletedAtUtc: DateTime.utc(2026, 9, 8),
      );
      expect(
        reviewed.effectiveState(
          const PlannerDate(year: 2026, month: 9, day: 9),
        ),
        WeeklyPlanState.reviewed,
      );
      expect(reviewed.reviewCompletedAtUtc, isNotNull);
    },
  );

  test('awaiting report remains canonical occurrence eligibility', () {
    final occurrence = CalendarEventOccurrence(
      id: 'occurrence-1',
      eventId: 'event-1',
      profileId: 'profile-1',
      title: 'Sensitive title is never part of the key',
      timing: CalendarEventTiming.timed,
      originalDate: const PlannerDate(year: 2026, month: 9, day: 8),
      displayDate: const PlannerDate(year: 2026, month: 9, day: 8),
      status: CalendarEventStatus.scheduled,
      requiresReport: true,
      recurrence: const CalendarRecurrenceRule(),
      endUtc: DateTime.utc(2026, 9, 8, 10),
    );
    expect(
      occurrence.isAwaitingReport(
        nowUtc: DateTime.utc(2026, 9, 8, 10, 1),
        displayToday: const PlannerDate(year: 2026, month: 9, day: 8),
      ),
      isTrue,
    );
  });

  test('planning tap payload remains a body-open ID-only intent', () {
    const intent = NotificationResponseIntent(
      profileId: 'profile-1',
      sourceKind: NotificationSourceKind.weeklyReview,
      sourceId: 'weekly-plan-1',
      action: NotificationResponseAction.open,
    );
    expect(
      NotificationPayloadCodec.tryDecode(
        NotificationPayloadCodec.encode(intent),
      ),
      intent,
    );
  });
}

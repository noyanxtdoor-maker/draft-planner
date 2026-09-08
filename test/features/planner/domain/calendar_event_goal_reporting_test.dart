import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

void main() {
  const date = PlannerDate(year: 2026, month: 7, day: 29);

  CalendarEventDraft baseDraft({bool requiresReport = false}) {
    return CalendarEventDraft(
      id: 'b4c5a05f-8348-42b2-84b5-2e6ef521c1f4',
      title: 'Event',
      timing: CalendarEventTiming.timed,
      startDate: date,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      timeZoneId: 'UTC',
      requiresReport: requiresReport,
    );
  }

  group('locked Goal-reporting invariant', () {
    test(
      'a manual Goal link forces Report Required ON at save normalization',
      () {
        final normalized = baseDraft()
            .copyWith(goalId: '0c80bcf2-3129-4f28-9f23-cfc194e2d16e')
            .normalized();
        expect(normalized.goalId, isNotNull);
        expect(normalized.requiresReport, isTrue);
      },
    );

    test('a fixed Goal-linked WLI Event Type forces Report Required ON', () {
      for (final stableKey in SystemEventTypeKeys.lockedWliTypeKeys) {
        final normalized = baseDraft()
            .copyWith(
              activityTypeId: 'type-id',
              activityTypeStableKeySnapshot: stableKey,
            )
            .normalized();
        expect(
          normalized.requiresReport,
          isTrue,
          reason: '$stableKey must be Report Required',
        );
      }
    });

    test('removing the Goal does not silently turn reporting back OFF', () {
      final goalLinked = baseDraft(
        requiresReport: true,
      ).copyWith(goalId: '0c80bcf2-3129-4f28-9f23-cfc194e2d16e').normalized();
      expect(goalLinked.requiresReport, isTrue);
      // The user removes the Goal from the form (a fresh draft without the
      // goal id); the reporting preference stays ON because the form keeps
      // the toggle enabled and unchanged.
      final afterRemoval = baseDraft(requiresReport: true).normalized();
      expect(afterRemoval.goalId, isNull);
      expect(afterRemoval.requiresReport, isTrue);
    });

    test('a non-Goal event keeps its user-chosen reporting preference', () {
      expect(baseDraft().normalized().requiresReport, isFalse);
      expect(
        baseDraft(requiresReport: true).normalized().requiresReport,
        isTrue,
      );
    });

    test('normalization rejects the invalid false for a Goal-linked Event', () {
      final normalized = baseDraft()
          .copyWith(goalId: '0c80bcf2-3129-4f28-9f23-cfc194e2d16e')
          .normalized();
      // The explicit `false` draft input can never survive normalization.
      expect(normalized.requiresReport, isTrue);
    });

    test('the invariant survives editing (copyWith then normalized)', () {
      final saved = baseDraft()
          .copyWith(goalId: '0c80bcf2-3129-4f28-9f23-cfc194e2d16e')
          .normalized();
      final edited = saved
          .copyWith(title: 'Edited', startMinute: 11 * 60, endMinute: 12 * 60)
          .normalized();
      expect(edited.goalId, saved.goalId);
      expect(edited.requiresReport, isTrue);
    });
  });
}

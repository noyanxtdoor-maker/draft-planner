import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/goals/domain/assigned_event_type_draft.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';

void main() {
  const originalColor = EventColorPreference(
    accentArgb: 0xFF26A69A,
    surfaceArgb: 0xFF3C4A48,
  );
  const changedColor = EventColorPreference(
    accentArgb: 0xFF7986CB,
    surfaceArgb: 0xFF3E4356,
  );

  AssignedEventTypeDraft draft({
    int expectedSlotIndex = 3,
    AssignedEventTypeNameMode originalNameMode = AssignedEventTypeNameMode.auto,
    String? originalNameOverride,
    AssignedEventTypeNameMode currentNameMode =
        AssignedEventTypeNameMode.auto,
    String? currentNameOverride,
    bool nameDirty = false,
    EventColorPreference? changedColor,
    bool colorDirty = false,
  }) {
    return AssignedEventTypeDraft(
      expectedSlotIndex: expectedSlotIndex,
      expectedEventTypeId: 'e4e41e9e-c028-5c73-b2a9-9d08ff3ca092',
      expectedStableKey: 'exercise',
      originalNameMode: originalNameMode,
      originalNameOverride: originalNameOverride,
      currentNameMode: currentNameMode,
      currentNameOverride: currentNameOverride,
      nameDirty: nameDirty,
      originalColor: originalColor,
      changedColor: changedColor,
      colorDirty: colorDirty,
    );
  }

  group('AssignedEventTypeDraft state machine', () {
    test('AUTO effective name is the trimmed Goal title', () {
      expect(
        draft().effectiveName(goalTitle: '  Swim  '),
        'Swim',
      );
    });

    test('MANUAL effective name is the trimmed override, never the title', () {
      final manual = draft(
        originalNameMode: AssignedEventTypeNameMode.manual,
        originalNameOverride: 'Pool training',
        currentNameMode: AssignedEventTypeNameMode.manual,
        currentNameOverride: 'Pool training ',
        nameDirty: true,
      );
      expect(manual.effectiveName(goalTitle: 'Swim'), 'Pool training');
    });

    test('blank Goal title in AUTO is not silently renamed', () {
      expect(draft().effectiveName(goalTitle: '   '), '');
    });

    test('identity is invalid when the stable key does not match the slot', () {
      expect(
        AssignedEventTypeDraft(
          expectedSlotIndex: 3,
          expectedEventTypeId: 'e4e41e9e-c028-5c73-b2a9-9d08ff3ca092',
          expectedStableKey: 'budget_review',
          originalNameMode: AssignedEventTypeNameMode.auto,
          currentNameMode: AssignedEventTypeNameMode.auto,
          currentNameOverride: null,
          nameDirty: false,
          originalColor: originalColor,
          changedColor: null,
          colorDirty: false,
        ).hasValidIdentity,
        isFalse,
      );
    });

    test('valid identity matches the canonical slot triple', () {
      expect(draft().hasValidIdentity, isTrue);
    });
  });

  group('AssignedEventTypeDraftResult applied merge', () {
    test('merely applying (no edit) preserves name mode and override', () {
      final result = AssignedEventTypeDraftResult.applied(
        nameEdited: false,
        nameText: 'Whatever was in the field',
      );
      final merged = result.applyTo(draft());
      expect(merged.currentNameMode, AssignedEventTypeNameMode.auto);
      expect(merged.currentNameOverride, isNull);
      expect(merged.nameDirty, isFalse);
      expect(merged.hasChanges, isFalse);
    });

    test('merely applying in MANUAL preserves the manual override', () {
      final result = AssignedEventTypeDraftResult.applied(
        nameEdited: false,
        nameText: 'Unused',
      );
      final merged = result.applyTo(
        draft(
          originalNameMode: AssignedEventTypeNameMode.manual,
          originalNameOverride: 'Pool training',
          currentNameMode: AssignedEventTypeNameMode.manual,
          currentNameOverride: 'Pool training',
        ),
      );
      expect(merged.currentNameMode, AssignedEventTypeNameMode.manual);
      expect(merged.currentNameOverride, 'Pool training');
      expect(merged.nameDirty, isFalse);
    });

    test(
      'an applied user edit sets MANUAL even when text equals the Goal title',
      () {
        final result = AssignedEventTypeDraftResult.applied(
          nameEdited: true,
          nameText: '  Swim  ',
        );
        final merged = result.applyTo(draft());
        expect(merged.currentNameMode, AssignedEventTypeNameMode.manual);
        expect(merged.currentNameOverride, 'Swim');
        expect(merged.nameDirty, isTrue);
      },
    );

    test('an applied user edit replaces a previous MANUAL override', () {
      final result = AssignedEventTypeDraftResult.applied(
        nameEdited: true,
        nameText: 'Renamed training',
      );
      final merged = result.applyTo(
        draft(
          originalNameMode: AssignedEventTypeNameMode.manual,
          originalNameOverride: 'Pool training',
          currentNameMode: AssignedEventTypeNameMode.manual,
          currentNameOverride: 'Pool training',
        ),
      );
      expect(merged.currentNameMode, AssignedEventTypeNameMode.manual);
      expect(merged.currentNameOverride, 'Renamed training');
      expect(merged.nameDirty, isTrue);
      // Original observed value is retained for the save-transaction
      // concurrency guard.
      expect(merged.originalNameOverride, 'Pool training');
    });
  });

  group('AssignedEventTypeDraftResult useGoalName merge', () {
    test('Use Goal name clears the override and records AUTO intent', () {
      final result = AssignedEventTypeDraftResult.useGoalName();
      final merged = result.applyTo(
        draft(
          originalNameMode: AssignedEventTypeNameMode.manual,
          originalNameOverride: 'Pool training',
          currentNameMode: AssignedEventTypeNameMode.manual,
          currentNameOverride: 'Pool training',
        ),
      );
      expect(merged.currentNameMode, AssignedEventTypeNameMode.auto);
      expect(merged.currentNameOverride, isNull);
      expect(merged.nameDirty, isTrue);
    });

    test('Use Goal name in AUTO is still an explicit user selection', () {
      final merged = AssignedEventTypeDraftResult.useGoalName().applyTo(
        draft(),
      );
      expect(merged.currentNameMode, AssignedEventTypeNameMode.auto);
      expect(merged.nameDirty, isTrue);
    });
  });

  group('color merge', () {
    test('a changed color travels with a name-only no-op', () {
      final result = AssignedEventTypeDraftResult.applied(
        nameEdited: false,
        nameText: null,
        changedColor: changedColor,
      );
      final merged = result.applyTo(draft());
      expect(merged.nameDirty, isFalse);
      expect(merged.colorDirty, isTrue);
      expect(merged.changedColor, changedColor);
      expect(merged.hasChanges, isTrue);
    });

    test('returning the ORIGINAL color normalizes to a clean unchanged state',
        () {
      final result = AssignedEventTypeDraftResult.applied(
        nameEdited: false,
        changedColor: originalColor,
      );
      final merged = result.applyTo(draft());
      expect(merged.colorDirty, isFalse);
      expect(merged.changedColor, isNull);
      expect(merged.hasChanges, isFalse);
    });

    test('a color-only edit never sets MANUAL', () {
      final result = AssignedEventTypeDraftResult.applied(
        nameEdited: false,
        changedColor: changedColor,
      );
      final merged = result.applyTo(draft());
      expect(merged.currentNameMode, AssignedEventTypeNameMode.auto);
      expect(merged.nameDirty, isFalse);
      expect(merged.colorDirty, isTrue);
    });

    test('a rename-only edit never materializes a color override', () {
      final result = AssignedEventTypeDraftResult.applied(
        nameEdited: true,
        nameText: 'Pool training',
      );
      final merged = result.applyTo(draft());
      expect(merged.colorDirty, isFalse);
      expect(merged.changedColor, isNull);
      expect(merged.nameDirty, isTrue);
    });

    test('Use Goal name can carry a color change alongside', () {
      final merged = AssignedEventTypeDraftResult.useGoalName(
        changedColor: changedColor,
      ).applyTo(draft());
      expect(merged.currentNameMode, AssignedEventTypeNameMode.auto);
      expect(merged.nameDirty, isTrue);
      expect(merged.colorDirty, isTrue);
      expect(merged.changedColor, changedColor);
    });
  });
}

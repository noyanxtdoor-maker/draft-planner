import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

/// Name persistence mode for one Goal's assigned Event Type presentation.
///
/// AUTO means no override entry exists for this Goal: the effective display
/// name is the current trimmed Goal title. MANUAL means a valid nonblank
/// override entry exists for this exact Goal and canonical Event Type stable
/// key; the effective display name is the override name.
enum AssignedEventTypeNameMode { auto, manual }

/// Immutable, typed draft of the Assigned Event Type (name + color) for one
/// Goal, owned by the parent Goal screen and returned value-only by the child
/// editor through [Navigator.pop].
///
/// The draft never writes anything itself. The parent commits name override
/// and changed slot color together with the Goal save inside one AppDatabase
/// transaction.
final class AssignedEventTypeDraft {
  const AssignedEventTypeDraft({
    required this.expectedSlotIndex,
    required this.expectedEventTypeId,
    required this.expectedStableKey,
    required this.originalNameMode,
    required this.currentNameMode,
    required this.currentNameOverride,
    required this.nameDirty,
    required this.originalColor,
    required this.changedColor,
    required this.colorDirty,
    this.originalNameOverride,
    this.expectedGoalUpdatedAtUtc,
  });

  /// Canonical slot the draft was resolved against. Create: the allocator's
  /// preview slot. Edit: the Goal's current active slot.
  final int expectedSlotIndex;

  /// Exact canonical Event Type ID ([SystemEventTypeIds]) the draft was
  /// resolved against. Re-validated inside the save transaction.
  final String expectedEventTypeId;

  /// Canonical Event Type stable key for [expectedSlotIndex].
  final String expectedStableKey;

  /// Name mode as last loaded/persisted for this Goal.
  final AssignedEventTypeNameMode originalNameMode;

  /// Original override NAME entry as last loaded/persisted (null in AUTO).
  /// Carried so Edit can detect a concurrent metadata change against the
  /// stored value inside the save transaction.
  final String? originalNameOverride;
  final AssignedEventTypeNameMode currentNameMode;

  /// Current MANUAL override name, null in AUTO mode.
  final String? currentNameOverride;

  /// True when the user explicitly edited the name (including applying a
  /// value equal to the Goal title) — manual intent, not string inequality.
  final bool nameDirty;

  /// Effective accent/surface pair as last loaded/persisted for the slot.
  final EventColorPreference originalColor;

  /// Edit only: the Goal row's updatedAtUtc when the draft was loaded.
  /// Checked inside the save transaction to reject concurrent Goal edits.
  final DateTime? expectedGoalUpdatedAtUtc;

  /// User-changed pair; null when unchanged. A missing patch means preserve.
  final EventColorPreference? changedColor;

  final bool colorDirty;

  /// Effective display name the parent previews: MANUAL override, otherwise
  /// the trimmed current Goal title. A raw canonical label is never a
  /// fallback for a valid Goal's prospective presentation.
  String effectiveName({required String goalTitle}) {
    if (currentNameMode == AssignedEventTypeNameMode.manual) {
      return currentNameOverride!.trim();
    }
    return goalTitle.trim();
  }

  bool get hasChanges => nameDirty || colorDirty;

  /// True when the draft's expected slot/type/key triple is coherent for its
  /// canonical slot. Parents gate Save on this so a half-resolved draft can
  /// never reach the repository.
  bool get hasValidIdentity {
    final CanonicalGoalSlot slot;
    try {
      slot = CanonicalGoalSlot.bySlot(expectedSlotIndex);
    } on StateError {
      return false;
    }
    return slot.eventTypeStableKey == expectedStableKey &&
        slot.eventTypeId == expectedEventTypeId;
  }

  AssignedEventTypeDraft copyWith({
    int? expectedSlotIndex,
    String? expectedEventTypeId,
    String? expectedStableKey,
    AssignedEventTypeNameMode? originalNameMode,
    String? originalNameOverride,
    bool clearOriginalNameOverride = false,
    AssignedEventTypeNameMode? currentNameMode,
    String? currentNameOverride,
    bool clearNameOverride = false,
    bool? nameDirty,
    EventColorPreference? changedColor,
    bool clearChangedColor = false,
    bool? colorDirty,
    DateTime? expectedGoalUpdatedAtUtc,
  }) {
    return AssignedEventTypeDraft(
      expectedSlotIndex: expectedSlotIndex ?? this.expectedSlotIndex,
      expectedEventTypeId: expectedEventTypeId ?? this.expectedEventTypeId,
      expectedStableKey: expectedStableKey ?? this.expectedStableKey,
      originalNameMode: originalNameMode ?? this.originalNameMode,
      originalNameOverride: clearOriginalNameOverride
          ? null
          : (originalNameOverride ?? this.originalNameOverride),
      currentNameMode: currentNameMode ?? this.currentNameMode,
      currentNameOverride: clearNameOverride
          ? null
          : (currentNameOverride ?? this.currentNameOverride),
      nameDirty: nameDirty ?? this.nameDirty,
      originalColor: originalColor,
      changedColor: clearChangedColor ? null : (changedColor ?? this.changedColor),
      colorDirty: colorDirty ?? this.colorDirty,
      expectedGoalUpdatedAtUtc:
          expectedGoalUpdatedAtUtc ?? this.expectedGoalUpdatedAtUtc,
    );
  }
}

/// Value-only child editor result. The child NEVER saves; it pops this value
/// through Navigator.pop and the parent merges it into its own draft.
///
/// - [AssignedEventTypeDraftActionResult.applied] carries the final name text
///   plus whether the user actually EDITED the name during the child session.
///   An edit sets MANUAL even when the final string equals the Goal title
///   (explicit manual intent); merely opening and Applying without an edit
///   preserves the parent's current name mode and override. A changed color
///   travels alongside a name-only no-op.
/// - [AssignedEventTypeDraftActionResult.useGoalName] is the explicit AUTO
///   return: the override is cleared and the parent preview shows the
///   current Goal title.
/// - Cancel, system back, or dismissal returns null — child changes are
///   discarded and no repository write ever happens.
enum AssignedEventTypeDraftActionResult { applied, useGoalName }

final class AssignedEventTypeDraftResult {
  const AssignedEventTypeDraftResult.applied({
    required this.nameEdited,
    this.nameText,
    this.changedColor,
  }) : action = AssignedEventTypeDraftActionResult.applied;

  const AssignedEventTypeDraftResult.useGoalName({this.changedColor})
    : action = AssignedEventTypeDraftActionResult.useGoalName,
      nameEdited = true,
      nameText = null;

  final AssignedEventTypeDraftActionResult action;

  /// Whether the user edited the Name field during the child session. True
  /// for useGoalName (an explicit mode selection is user intent).
  final bool nameEdited;

  /// Final Name field text for applied results; null otherwise.
  final String? nameText;

  /// Changed color pair, or null when color was not edited.
  final EventColorPreference? changedColor;

  /// Merges this result into [draft]. Color dirtiness is derived from the
  /// ORIGINAL persisted pair, so returning the original color is a no-op.
  AssignedEventTypeDraft applyTo(AssignedEventTypeDraft draft) {
    final effectiveColor = changedColor ?? draft.changedColor;
    final colorDirty = effectiveColor != null &&
        effectiveColor != draft.originalColor;
    if (action == AssignedEventTypeDraftActionResult.useGoalName) {
      // Explicit AUTO: clear the override; nameDirty records the intent so
      // the parent Save removes the stored entry atomically.
      return draft.copyWith(
        currentNameMode: AssignedEventTypeNameMode.auto,
        currentNameOverride: null,
        clearNameOverride: true,
        nameDirty: true,
        changedColor: colorDirty ? effectiveColor : null,
        clearChangedColor: !colorDirty,
        colorDirty: colorDirty,
      );
    }
    if (!nameEdited) {
      // Merely opening/Applying: name mode and override are preserved
      // exactly; only a color change can travel.
      return draft.copyWith(
        changedColor: colorDirty ? effectiveColor : null,
        clearChangedColor: !colorDirty,
        colorDirty: colorDirty,
      );
    }
    final trimmed = (nameText ?? '').trim();
    // A user edit that is applied ALWAYS sets MANUAL, even when the final
    // string equals the Goal title. Blank names are rejected by the form
    // validator; defensively fall back to AUTO-equivalent state.
    return draft.copyWith(
      currentNameMode: trimmed.isEmpty
          ? AssignedEventTypeNameMode.auto
          : AssignedEventTypeNameMode.manual,
      currentNameOverride: trimmed.isEmpty ? null : trimmed,
      clearNameOverride: trimmed.isEmpty,
      nameDirty: true,
      changedColor: colorDirty ? effectiveColor : null,
      clearChangedColor: !colorDirty,
      colorDirty: colorDirty,
    );
  }
}

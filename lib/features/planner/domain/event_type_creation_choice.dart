import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal_event_type_policy.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/event_type_presentation.dart';

/// One creation-time choice (contract D.6): the raw [EventType] preserved
/// untouched plus the optional live Goal binding eligible right now.
///
/// This is NOT an EventType subclass and never overwrites the raw label:
/// history, settings, and the raw controller keep the canonical label. The
/// alias only exists as [displayLabel] and only when the type's canonical
/// slot has a live eligible Goal occupant.
final class EventTypeCreationChoice {
  const EventTypeCreationChoice({required this.type, this.binding});

  final EventType type;

  /// The live Goal aliasing this canonical type for NEW selections, or null
  /// when the slot is empty/ineligible or the type is not canonical.
  final LiveGoalEventTypeBinding? binding;

  /// Live binding's effective display name (MANUAL override, otherwise the
  /// trimmed Goal title) when live-bound. Otherwise the raw type label —
  /// with the pure prospective alias for the exact untouched Study row
  /// ("Study or Plan" presents as "Study & Planning"). Custom and renamed
  /// rows keep their raw labels verbatim everywhere.
  String get displayLabel => binding?.displayLabel ?? EventTypePresentation.prospectiveLabel(type);

  /// Canonical slot for this type, or null for non-canonical types.
  CanonicalGoalSlot? get canonicalSlot =>
      CanonicalGoalSlot.tryByEventTypeKey(type.stableKey);

  @override
  bool operator ==(Object other) =>
      other is EventTypeCreationChoice &&
      other.type == type &&
      other.binding == binding;

  @override
  int get hashCode => Object.hash(type, binding);

  @override
  String toString() =>
      'EventTypeCreationChoice(${type.stableKey}, label: $displayLabel)';

  /// Pure projection builder (contract C): keeps the raw type only when it
  /// is creation-visible, and attaches a binding only when the binding's
  /// slot identity exactly matches this type (same canonical key, system
  /// row, and matching slot/ID law via [CanonicalGoalSlot]). Retired
  /// `goal:` types and archived/legacy system rows keep their raw
  /// visibility law but can never receive a binding. A binding whose slot
  /// is empty or whose occupant failed validation is simply absent — no
  /// stale or all-six fallback is ever synthesized here.
  static List<EventTypeCreationChoice> buildChoices({
    required Iterable<EventType> types,
    required Map<int, LiveGoalEventTypeBinding> bindings,
  }) {
    final choices = <EventTypeCreationChoice>[];
    for (final type in types) {
      if (!type.isCreationVisible) {
        continue;
      }
      LiveGoalEventTypeBinding? binding;
      if (type.isSystem && !type.isArchived) {
        final slot = CanonicalGoalSlot.tryByEventTypeKey(type.stableKey);
        if (slot != null) {
          final candidate = bindings[slot.slotIndex];
          if (candidate == null ||
              slot.eventTypeId != type.id ||
              type.exactIndicatorKey != slot.indicatorKey) {
            // Canonical Goal-linked types are creation choices only while
            // their exact slot has one eligible live occupant. Keep the raw
            // EventType in EventTypeState for history; omit it only from this
            // prospective selection projection.
            continue;
          }
          binding = candidate;
        }
      }
      choices.add(EventTypeCreationChoice(type: type, binding: binding));
    }
    return choices;
  }

  /// Choice-order helper for the full picker (contract E): the previous
  /// `_orderedPickerTypes` law applied to choices — filter BEFORE
  /// recommendation, preserve allowedStableKeys, approved order, custom
  /// trailing order, Task last (Task is not part of this list). A hidden
  /// (no longer eligible) recommended type is never promoted: a hidden type
  /// is not in the list at all.
  static List<EventTypeCreationChoice> orderedForPicker(
    List<EventTypeCreationChoice> choices, {
    String? recommendedEventTypeId,
    Set<String>? allowedStableKeys,
  }) {
    final mappedOrder = <String, int>{
      for (
        var index = 0;
        index < SystemEventTypeKeys.approvedCreationOrder.length;
        index += 1
      )
        SystemEventTypeKeys.approvedCreationOrder[index]: index,
    };
    final filtered =
        choices
            .where(
              (choice) =>
                  (allowedStableKeys == null ||
                      allowedStableKeys.contains(choice.type.stableKey)),
            )
            .toList()
          ..sort((left, right) {
            final recommendedLeft =
                recommendedEventTypeId != null &&
                left.type.id == recommendedEventTypeId;
            final recommendedRight =
                recommendedEventTypeId != null &&
                right.type.id == recommendedEventTypeId;
            if (recommendedLeft && !recommendedRight) {
              return -1;
            }
            if (recommendedRight && !recommendedLeft) {
              return 1;
            }
            final leftMapped = mappedOrder[left.type.stableKey];
            final rightMapped = mappedOrder[right.type.stableKey];
            if (leftMapped != null || rightMapped != null) {
              if (leftMapped == null) {
                return 1;
              }
              if (rightMapped == null) {
                return -1;
              }
              return leftMapped.compareTo(rightMapped);
            }
            final position = left.type.position.compareTo(right.type.position);
            return position == 0
                ? left.type.label.compareTo(right.type.label)
                : position;
          });
    return filtered;
  }

  /// Dropdown order: approved order then customs; no recommendation promo.
  static List<EventTypeCreationChoice> orderedForDropdown(
    List<EventTypeCreationChoice> choices,
  ) {
    return orderedForPicker(choices, recommendedEventTypeId: null);
  }
}

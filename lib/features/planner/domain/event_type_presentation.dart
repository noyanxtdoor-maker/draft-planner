import 'package:rmplanner/features/planner/domain/event_type.dart';

/// Prospective presentation aliases for canonical Event Types.
///
/// A pure prospective alias — never a row rename. Raw labels, stable keys,
/// IDs, positions, mappings, and historical snapshots stay byte-for-byte
/// unchanged. Only FRESH prospective surfaces (picker, settings, new-selection
/// snapshots) may show the alias for the exact untouched system row.
abstract final class EventTypePresentation {
  /// The exact legacy system Study row ("Study or Plan") presents as
  /// "Study & Planning" on fresh prospective surfaces only.
  ///
  /// Matches: system row, exact canonical ID, exact stable key, and the raw
  /// label exactly "Study or Plan". Any other row — custom rows, renamed rows
  /// (for example "My Study"), legacy non-creation rows — presents its raw
  /// label verbatim. A user setting exactly the old built-in label is not
  /// distinguishable from untouched storage; the same exact rule applies and
  /// no data is overwritten.
  static String prospectiveLabel(EventType type) {
    const legacyStudyId = SystemEventTypeIds.studyOrPlan;
    const legacyStudyKey = SystemEventTypeKeys.studyOrPlan;
    const legacyStudyLabel = 'Study or Plan';
    const alias = 'Study & Planning';
    if (type.isSystem &&
        type.id == legacyStudyId &&
        type.stableKey == legacyStudyKey &&
        type.label == legacyStudyLabel) {
      return alias;
    }
    return type.label;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

void main() {
  EventType type({
    required String label,
    EventTypeIcon icon = EventTypeIcon.calendar,
  }) {
    return EventType(
      id: label,
      stableKey: 'custom:$label',
      label: label,
      icon: icon,
      colorValue: 0xFFE91E63,
      isSystem: false,
      isArchived: false,
      reportRequiredDefault: false,
      defaultDurationMinutes: 60,
      position: 0,
      mappingVersion: 1,
      indicatorKeys: const <String>{},
    );
  }

  test('PMG label defaults preserve the exact approved pairs', () {
    expect(
      PlannerEventColorDefaults.forEventType(type(label: 'Teaching')),
      const EventColorPreference(
        accentArgb: 0xFFEBC766,
        surfaceArgb: 0xFF4C4942,
      ),
    );
    expect(
      PlannerEventColorDefaults.forEventType(type(label: 'Study or Plan')),
      PlannerEventColorDefaults.studyOrPlan,
    );
    expect(
      PlannerEventColorDefaults.forEventType(type(label: 'Sacrament')),
      const EventColorPreference(
        accentArgb: 0xFFEAA15D,
        surfaceArgb: 0xFF474141,
      ),
    );
  });

  test('system types resolve the exact locked Accent + Surface pairs', () {
    EventType systemType(String stableKey) {
      return EventType(
        id: stableKey,
        stableKey: stableKey,
        label: stableKey,
        icon: EventTypeIcon.calendar,
        colorValue: 0xFFE91E63,
        isSystem: true,
        isArchived: false,
        reportRequiredDefault: false,
        defaultDurationMinutes: 60,
        position: 0,
        mappingVersion: 1,
        indicatorKeys: const <String>{},
      );
    }

    const expected = <String, EventColorPreference>{
      SystemEventTypeKeys.jobApplication: EventColorPreference(
        accentArgb: 0xFFEBC766,
        surfaceArgb: 0xFF4C4942,
      ),
      SystemEventTypeKeys.scriptureStudy: EventColorPreference(
        accentArgb: 0xFFDE9EDA,
        surfaceArgb: 0xFF4C464A,
      ),
      SystemEventTypeKeys.exercise: EventColorPreference(
        accentArgb: 0xFFEAA15D,
        surfaceArgb: 0xFF474141,
      ),
      SystemEventTypeKeys.templeVisit: EventColorPreference(
        accentArgb: 0xFF98CED8,
        surfaceArgb: 0xFF454B4B,
      ),
      SystemEventTypeKeys.contact: EventColorPreference(
        accentArgb: 0xFF76B181,
        surfaceArgb: 0xFF494E48,
      ),
      SystemEventTypeKeys.meeting: EventColorPreference(
        accentArgb: 0xFFE27386,
        surfaceArgb: 0xFF463D40,
      ),
      SystemEventTypeKeys.studyOrPlan: EventColorPreference(
        accentArgb: 0xFFA272C8,
        surfaceArgb: 0xFF47444B,
      ),
      SystemEventTypeKeys.service: EventColorPreference(
        accentArgb: 0xFFDEEDF2,
        surfaceArgb: 0xFF404447,
      ),
      // P-01D: Work is separated from Service into a muted steel/slate-blue
      // family; Service keeps its approved icy pair unchanged.
      SystemEventTypeKeys.work: EventColorPreference(
        accentArgb: 0xFFA9BEC9,
        surfaceArgb: 0xFF43494D,
      ),
      SystemEventTypeKeys.travel: EventColorPreference(
        accentArgb: 0xFFECC7D8,
        surfaceArgb: 0xFF4F4D4E,
      ),
      SystemEventTypeKeys.meal: EventColorPreference(
        accentArgb: 0xFFE1CFB9,
        surfaceArgb: 0xFF4B4744,
      ),
      SystemEventTypeKeys.other: EventColorPreference(
        accentArgb: 0xFF868A8D,
        surfaceArgb: 0xFF494949,
      ),
    };
    for (final entry in expected.entries) {
      expect(
        PlannerEventColorDefaults.forEventType(systemType(entry.key)),
        entry.value,
        reason: '${entry.key} must resolve the exact locked pair',
      );
    }
    // Ministering Visit and Budget Review are NOT remapped by this delta.
    expect(
      PlannerEventColorDefaults.forEventType(
        systemType(SystemEventTypeKeys.meaningfulConnection),
      ),
      PlannerEventColorDefaults.lockedMinisteringVisit,
    );
    expect(
      PlannerEventColorDefaults.forEventType(
        systemType(SystemEventTypeKeys.budgetReview),
      ),
      PlannerEventColorDefaults.lockedBudgetReview,
    );
  });

  test('current system types receive the approved deterministic pairs', () {
    expect(
      PlannerEventColorDefaults.forEventType(
        type(label: 'Exercise', icon: EventTypeIcon.exercise),
      ),
      PlannerEventColorDefaults.exercise,
    );
    expect(
      PlannerEventColorDefaults.forEventType(
        type(label: 'General', icon: EventTypeIcon.calendar),
      ),
      PlannerEventColorDefaults.other,
    );
    for (final preference in <EventColorPreference>[
      PlannerEventColorDefaults.other,
      PlannerEventColorDefaults.service,
      PlannerEventColorDefaults.meeting,
    ]) {
      expect(preference.surfaceArgb, isNot(0xFFE91E63));
    }
  });

  test('preference codec round-trips and ignores malformed values', () {
    const preference = EventColorPreference(
      accentArgb: 0xFF010203,
      surfaceArgb: 0xFF040506,
    );
    final encoded = EventColorPreferenceCodec.encode(
      <String, EventColorPreference>{'exercise': preference},
    );
    expect(
      EventColorPreferenceCodec.decode(encoded),
      <String, EventColorPreference>{'exercise': preference},
    );
    expect(
      EventColorPreferenceCodec.decode('{"exercise":{"accent":-1}}'),
      isEmpty,
    );
    expect(EventColorPreferenceCodec.decode('not-json'), isEmpty);
  });

  test('document codec preserves independent Event and Group colors', () {
    const preference = EventColorPreference(
      accentArgb: 0xFF112233,
      surfaceArgb: 0xFF445566,
    );
    final encoded = EventColorPreferenceCodec.encodeDocument(
      events: <String, EventColorPreference>{'work': preference},
      groups: const <String, int>{'family': 0xFFEBC766},
    );
    final decoded = EventColorPreferenceCodec.decodeDocument(encoded);
    expect(decoded.events['work'], preference);
    expect(decoded.groups['family'], 0xFFEBC766);
  });

  test(
    'built-in Contact Group colors use stable IDs independent of labels',
    () {
      expect(
        ContactGroupDefaults.ordered.map((group) => group.id).toList(),
        <String>['family', 'friends', 'avoid', 'other'],
      );
      expect(
        ContactGroupDefaults.ordered.map((group) => group.label).toList(),
        <String>['Family', 'Friends', 'Avoid', 'Other'],
      );
      expect(ContactGroupDefaults.byId('family').label, 'Family');
      expect(ContactGroupDefaults.byId('not-a-label').id, 'other');
    },
  );
}

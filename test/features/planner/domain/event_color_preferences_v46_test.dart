import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/colors/vs11_color_system.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';

void main() {
  /// Contract section 4 (V46 persistence format): envelope decode/encode law.
  ///
  /// Format:
  /// {
  ///   "events": {"exercise": {"accent": 428..., "surface": 428...}},
  ///   "groups": {...},
  ///   "goalEventTypeNames": {
  ///     "<actual Goal UUID>": {
  ///       "eventTypeStableKey": "exercise",
  ///       "name": "Pool training"
  ///     }
  ///   }
  /// }
  /// Missing metadata = AUTO. Old decoders must never see name metadata as a
  /// fake color-map entry.
  group('EventColorPreferenceCodec V46 document format', () {
    const education = EventColorPreference(
      accentArgb: 0xFF64B1E6,
      surfaceArgb: 0xFF484F56,
    );

    test('decode null/blank falls back to empty document', () {
      final nullDocument = EventColorPreferenceCodec.decodeDocument(null);
      expect(nullDocument.events, isEmpty);
      expect(nullDocument.groups, isEmpty);
      expect(nullDocument.goalEventTypeNames, isEmpty);
      final blank = EventColorPreferenceCodec.decodeDocument('   ');
      expect(blank.events, isEmpty);
      expect(blank.goalEventTypeNames, isEmpty);
    });

    test('legacy flat colors decode as events only', () {
      final document = EventColorPreferenceCodec.decodeDocument(
        jsonEncode(<String, Object>{
          'exercise': <String, Object>{'accent': 0xFF26A69A, 'surface': 0xFF3C4A48},
        }),
      );
      expect(document.events['exercise']?.accentArgb, 0xFF26A69A);
      expect(document.goalEventTypeNames, isEmpty);
    });

    test('current events/groups envelope decodes without metadata', () {
      final document = EventColorPreferenceCodec.decodeDocument(
        EventColorPreferenceCodec.encodeDocument(
          events: const <String, EventColorPreference>{'education': education},
          groups: const <String, int>{'family': 0xFFEBC766},
        ),
      );
      expect(document.events['education'], education);
      expect(document.groups['family'], 0xFFEBC766);
      expect(document.goalEventTypeNames, isEmpty);
    });

    test('new envelope with goalEventTypeNames decodes validated entries', () {
      const goalId = 'g0000000-0000-4000-8000-000000000001';
      final encoded = EventColorPreferenceCodec.encodeDocument(
        events: const <String, EventColorPreference>{'education': education},
        groups: const <String, int>{},
        goalEventTypeNames: const <String, GoalEventTypeNameOverride>{
          goalId: GoalEventTypeNameOverride(
            eventTypeStableKey: 'education',
            name: 'Classes',
          ),
        },
      );
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final names = decoded['goalEventTypeNames'] as Map<String, Object?>;
      final entry = names[goalId] as Map<String, Object?>;
      // Exact field names per contract.
      expect(entry['eventTypeStableKey'], 'education');
      expect(entry['name'], 'Classes');

      final document = EventColorPreferenceCodec.decodeDocument(encoded);
      expect(document.events['education'], education);
      expect(document.goalEventTypeNames[goalId]?.name, 'Classes');
      expect(
        document.goalEventTypeNames[goalId]?.eventTypeStableKey,
        'education',
      );
    });

    test(
      'envelope is recognized when goalEventTypeNames exists with empty '
      'events/groups',
      () {
        const goalId = 'g0000000-0000-4000-8000-000000000002';
        final raw = jsonEncode(<String, Object?>{
          'goalEventTypeNames': <String, Object?>{
            goalId: <String, Object?>{
              'eventTypeStableKey': 'exercise',
              'name': 'Pool training',
            },
          },
        });
        final document = EventColorPreferenceCodec.decodeDocument(raw);
        expect(document.events, isEmpty);
        expect(document.goalEventTypeNames[goalId]?.name, 'Pool training');
      },
    );

    test('invalid metadata entry does not create an override', () {
      const goalId = 'g0000000-0000-4000-8000-000000000003';
      final raw = jsonEncode(<String, Object?>{
        'goalEventTypeNames': <String, Object?>{
          goalId: <String, Object?>{'eventTypeStableKey': 'exercise'},
          'not-even-a-map': 'oops',
        },
      });
      final document = EventColorPreferenceCodec.decodeDocument(raw);
      expect(document.goalEventTypeNames.containsKey(goalId), isFalse);
      expect(document.goalEventTypeNames.containsKey('not-even-a-map'),
          isFalse);
    });

    test('metadata is never inserted as a fake color-map entry', () {
      const goalId = 'g0000000-0000-4000-8000-000000000004';
      final encoded = EventColorPreferenceCodec.encodeDocument(
        events: const <String, EventColorPreference>{},
        groups: const <String, int>{},
        goalEventTypeNames: const <String, GoalEventTypeNameOverride>{
          goalId: GoalEventTypeNameOverride(
            eventTypeStableKey: 'exercise',
            name: 'Pool training',
          ),
        },
      );
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      // Names live ONLY under goalEventTypeNames.
      expect(decoded.containsKey(goalId), isFalse);
      expect(decoded['events'], isA<Map<dynamic, dynamic>>());
      expect((decoded['events'] as Map).isEmpty, isTrue);
      final document = EventColorPreferenceCodec.decodeDocument(encoded);
      expect(document.events.containsKey(goalId), isFalse);
      // Old events-only decode sees nothing fake.
      expect(
        EventColorPreferenceCodec.decode(encoded).containsKey(goalId),
        isFalse,
      );
    });

    test('Education default pair is the approved P22 Gray Blue pair', () {
      expect(PlannerEventColorDefaults.education.accentArgb, 0xFF64B1E6);
      expect(PlannerEventColorDefaults.education.surfaceArgb, 0xFF484F56);
      expect(
        PlannerEventColorDefaults.education.accentArgb,
        Vs11ColorSystem.p22SteelBlue,
      );
    });

    test('P24 pair token remains untouched and distinct', () {
      expect(
        PlannerEventColorDefaults.education.accentArgb,
        isNot(Vs11ColorSystem.p24DeepBlue),
      );
    });
  });
}

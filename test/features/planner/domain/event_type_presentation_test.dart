import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/event_type_presentation.dart';

void main() {
  EventType type({
    String? id,
    String? stableKey,
    String label = 'Study or Plan',
    bool isSystem = true,
  }) {
    return EventType(
      id: id ?? SystemEventTypeIds.studyOrPlan,
      stableKey: stableKey ?? SystemEventTypeKeys.studyOrPlan,
      label: label,
      icon: EventTypeIcon.scripture,
      colorValue: 0xFF8E6FC8,
      isSystem: isSystem,
      isArchived: false,
      reportRequiredDefault: false,
      defaultDurationMinutes: 60,
      position: 8,
      mappingVersion: 1,
      indicatorKeys: const <String>{},
    );
  }

  group('EventTypePresentation.prospectiveLabel', () {
    test(
      'exact untouched legacy system Study row presents as Study & Planning',
      () {
        final presented = EventTypePresentation.prospectiveLabel(type());
        expect(presented, 'Study & Planning');
      },
    );

    test('raw row label is never modified by the alias', () {
      final row = type();
      EventTypePresentation.prospectiveLabel(row);
      expect(row.label, 'Study or Plan');
    });

    test('customized label keeps its verbatim raw label', () {
      expect(
        EventTypePresentation.prospectiveLabel(type(label: 'My Study')),
        'My Study',
      );
      expect(
        EventTypePresentation.prospectiveLabel(type(label: 'study or plan')),
        'study or plan',
      );
      expect(
        EventTypePresentation.prospectiveLabel(type(label: 'Study or Plan ')),
        'Study or Plan ',
      );
    });

    test('a custom (non-system) row is never aliased', () {
      expect(
        EventTypePresentation.prospectiveLabel(type(isSystem: false)),
        'Study or Plan',
      );
    });

    test('a different stable key with the legacy label is never aliased', () {
      expect(
        EventTypePresentation.prospectiveLabel(
          type(stableKey: 'scripture_study'),
        ),
        'Study or Plan',
      );
    });

    test('a different ID with the legacy label is never aliased', () {
      expect(
        EventTypePresentation.prospectiveLabel(
          type(id: '0010a93e-6bbf-52e8-97d8-79b527cfef30'),
        ),
        'Study or Plan',
      );
    });

    test('Education and other rows present their raw labels', () {
      expect(
        EventTypePresentation.prospectiveLabel(
          type(
            id: SystemEventTypeIds.education,
            stableKey: SystemEventTypeKeys.education,
            label: 'Education',
          ),
        ),
        'Education',
      );
      expect(
        EventTypePresentation.prospectiveLabel(
          type(
            id: SystemEventTypeIds.exercise,
            stableKey: SystemEventTypeKeys.exercise,
            label: 'Exercise',
          ),
        ),
        'Exercise',
      );
    });
  });
}

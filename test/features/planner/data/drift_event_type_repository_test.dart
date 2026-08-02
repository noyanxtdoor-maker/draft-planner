import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;
  late DriftEventTypeRepository repository;
  late String profileId;

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    repository = DriftEventTypeRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 29, 12)),
    );
  });

  tearDown(() => database.close());

  test(
    'six system Event Types have exact deterministic indicator mappings',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);

      expect(types, hasLength(10));
      expect({
        for (final type in types)
          if (type.exactIndicatorKey != null)
            type.stableKey: type.exactIndicatorKey,
      }, systemEventTypeIndicatorKeys);
      for (final entry in systemEventTypeIndicatorKeys.entries) {
        final type = await repository.readExactTypeForIndicator(
          profileId: profileId,
          indicatorKey: entry.value,
        );
        expect(type?.stableKey, entry.key);
      }
    },
  );

  test('custom mapping is explicit and never inferred from title', () async {
    final none = await repository.saveCustomType(
      profileId: profileId,
      draft: const EventTypeDraft(
        id: '11111111-1111-4111-8111-111111111111',
        label: 'Temple Visit',
        icon: EventTypeIcon.calendar,
        colorValue: 0xFFE91E63,
        reportRequiredDefault: false,
        defaultDurationMinutes: 60,
        indicatorKeys: <String>{},
      ),
    );
    expect(none.indicatorKeys, isEmpty);

    final one = await repository.saveCustomType(
      profileId: profileId,
      draft: const EventTypeDraft(
        id: '11111111-1111-4111-8111-111111111111',
        label: 'Custom wellbeing',
        icon: EventTypeIcon.personal,
        colorValue: 0xFFFFA726,
        reportRequiredDefault: true,
        defaultDurationMinutes: 45,
        indicatorKeys: <String>{'exercise'},
      ),
    );
    expect(one.indicatorKeys, <String>{'exercise'});

    final many = await repository.saveCustomType(
      profileId: profileId,
      draft: const EventTypeDraft(
        id: '11111111-1111-4111-8111-111111111111',
        label: 'Explicit combined activity',
        icon: EventTypeIcon.personal,
        colorValue: 0xFFFFA726,
        reportRequiredDefault: true,
        defaultDurationMinutes: 45,
        indicatorKeys: <String>{'exercise', 'meaningful_connections'},
      ),
    );
    expect(many.indicatorKeys, <String>{'exercise', 'meaningful_connections'});
    expect(many.mappingVersion, 3);
    final mappingRows = await database
        .select(database.activityTypeIndicatorMappings)
        .get();
    final customRows = mappingRows
        .where((row) => row.activityTypeId == many.id)
        .toList(growable: false);
    expect(
      customRows.map((row) => row.mappingVersion).toSet(),
      <int>{2, 3},
      reason: 'Prior mapping revisions remain available for provenance.',
    );
    expect(
      customRows
          .where((row) => row.mappingVersion == 2)
          .map((row) => row.indicatorKey),
      <String>['exercise'],
    );
  });

  test(
    'archiving a custom type preserves existing Calendar Events and history',
    () async {
      const typeId = '22222222-2222-4222-8222-222222222222';
      final type = await repository.saveCustomType(
        profileId: profileId,
        draft: const EventTypeDraft(
          id: typeId,
          label: 'Community service',
          icon: EventTypeIcon.connection,
          colorValue: 0xFF26A69A,
          reportRequiredDefault: true,
          defaultDurationMinutes: 90,
          indicatorKeys: <String>{},
        ),
      );
      await database
          .into(database.calendarEvents)
          .insert(
            CalendarEventsCompanion.insert(
              id: '33333333-3333-4333-8333-333333333333',
              profileId: profileId,
              title: 'Historical event',
              timing: 'timed',
              startDate: '2026-07-29',
              startMinute: const Value<int>(600),
              endMinute: const Value<int>(660),
              timeZoneId: const Value<String>('Asia/Manila'),
              activityTypeId: const Value<String>(typeId),
              activityTypeMappingVersion: Value<int>(type.mappingVersion),
              createdAtUtc: DateTime.utc(2026, 7, 29),
              updatedAtUtc: DateTime.utc(2026, 7, 29),
            ),
          );

      await repository.setCustomTypeArchived(
        profileId: profileId,
        eventTypeId: typeId,
        archived: true,
      );

      final event = await database.select(database.calendarEvents).getSingle();
      final archived = await repository.readEventType(
        profileId: profileId,
        eventTypeId: typeId,
      );
      expect(event.activityTypeId, typeId);
      expect(archived?.isArchived, isTrue);
      expect(
        await database.select(database.activityLedgerEntries).get(),
        isEmpty,
      );
    },
  );

  test(
    'Planner settings remain local and validate timeline boundaries',
    () async {
      const settings = PlannerSettings(
        defaultEventTypeId: SystemEventTypeIds.exercise,
        defaultDurationMinutes: 45,
        defaultReminderMinutes: 15,
        visibleStartHour: 5,
        visibleEndHour: 23,
        use24HourTime: true,
        snapMinutes: 15,
        showCurrentTime: false,
        initialScrollBehavior: PlannerInitialScrollBehavior.visibleStart,
        creationPresentation: EventCreationPresentation.fullScreen,
        quickEditEnabled: true,
        showCompletedItems: false,
        showCancelledItems: true,
        weekStartDay: DateTime.monday,
        preferredPresentation: PlannerPresentation.day,
        contentFilters: PlannerContentFilters.defaults(),
        timelineHourHeight: PlannerZoomPolicy.normalHourHeight,
      );

      await repository.savePlannerSettings(
        profileId: profileId,
        settings: settings,
      );
      final restored = await repository.readPlannerSettings(
        profileId: profileId,
      );
      expect(restored.defaultEventTypeId, SystemEventTypeIds.exercise);
      expect(restored.visibleStartHour, 5);
      expect(restored.visibleEndHour, 23);
      expect(restored.use24HourTime, isTrue);
      expect(restored.showCompletedItems, isFalse);
      expect(
        () => settings.copyWith(visibleEndHour: 4).validate(),
        throwsArgumentError,
      );
    },
  );

  test(
    'Event color pairs persist in Planner Preferences without touching Events',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);
      final exercise = types.singleWhere(
        (type) => type.stableKey == SystemEventTypeKeys.exercise,
      );
      const custom = EventColorPreference(
        accentArgb: 0xFF123456,
        surfaceArgb: 0xFF654321,
      );

      expect(
        await repository.readEventColorPreferences(profileId: profileId),
        isEmpty,
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: exercise.stableKey,
        preference: custom,
      );

      final restored = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(restored[exercise.stableKey], custom);

      final eventRowsBefore = await database
          .select(database.calendarEvents)
          .get();
      await repository.savePlannerSettings(
        profileId: profileId,
        settings: const PlannerSettings.defaults(),
      );
      expect(
        (await repository.readEventColorPreferences(
          profileId: profileId,
        ))[exercise.stableKey],
        custom,
      );
      expect(
        await database.select(database.calendarEvents).get(),
        eventRowsBefore,
      );

      await repository.restoreEventColorDefaults(profileId: profileId);
      expect(
        await repository.readEventColorPreferences(profileId: profileId),
        isEmpty,
      );
    },
  );
}

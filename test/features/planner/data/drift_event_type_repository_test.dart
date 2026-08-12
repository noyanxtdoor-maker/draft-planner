import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_math.dart';
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
    'system Event Types preserve exact mappings and target catalog identities',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);

      expect(types, hasLength(19));
      expect(
        types.map((type) => type.stableKey).toSet(),
        containsAll(<String>[
          SystemEventTypeKeys.meaningfulConnection,
          SystemEventTypeKeys.teaching,
          SystemEventTypeKeys.finding,
          SystemEventTypeKeys.meeting,
          SystemEventTypeKeys.studyOrPlan,
          SystemEventTypeKeys.service,
          SystemEventTypeKeys.work,
          SystemEventTypeKeys.templeVisit,
          SystemEventTypeKeys.travel,
          SystemEventTypeKeys.meal,
          SystemEventTypeKeys.other,
        ]),
      );
      expect(
        types.where((type) => type.stableKey == SystemEventTypeKeys.contact),
        hasLength(1),
      );
      expect(
        types
            .singleWhere(
              (type) =>
                  type.stableKey == SystemEventTypeKeys.meaningfulConnection,
            )
            .label,
        'Ministering Visit',
      );
      expect(types.where((type) => type.label == 'Service'), hasLength(1));
      expect(types.where((type) => type.label == 'Work'), hasLength(1));
      expect(
        types
            .where((type) => type.isCreationVisible)
            .map((type) => type.stableKey),
        <String>[...SystemEventTypeKeys.approvedCreationOrder],
      );
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
        label: 'Temple Visit custom',
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
      // The surface is always derived from the accent (Part 14 lock), so a
      // persisted pair round-trips unchanged only when it is already
      // derivation-consistent.
      final custom = EventColorPreference(
        accentArgb: 0xFF123456,
        surfaceArgb: EventColorMath.lightMutedSurfaceArgb(0xFF123456),
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

  test(
    'six locked Goal-linked types seed with the exact PMG defaults',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);
      const expected = <String, int>{
        SystemEventTypeKeys.jobApplication: 0xFFEBC766,
        SystemEventTypeKeys.scriptureStudy: 0xFFDE9EDA,
        SystemEventTypeKeys.exercise: 0xFFEAA15D,
        SystemEventTypeKeys.budgetReview: 0xFFBFA384,
        SystemEventTypeKeys.meaningfulConnection: 0xFFB0A971,
        SystemEventTypeKeys.templeVisit: 0xFF98CED8,
      };
      for (final entry in expected.entries) {
        final type = types.singleWhere((type) => type.stableKey == entry.key);
        expect(
          type.colorValue,
          entry.value,
          reason: '${entry.key} must seed with the exact PMG default',
        );
      }
    },
  );

  test(
    'untouched locked seed colors migrate to the faded PMG defaults',
    () async {
      // Simulate an install that still carries the previous approved default
      // (dark-muted Slate Blue family).
      const oldDefaults = <String, int>{
        SystemEventTypeKeys.jobApplication: 0xFF676DA2,
        SystemEventTypeKeys.scriptureStudy: 0xFF5946B9,
        SystemEventTypeKeys.exercise: 0xFF86CC7B,
        SystemEventTypeKeys.budgetReview: 0xFFA5975F,
        SystemEventTypeKeys.meaningfulConnection: 0xFFBB7772,
        SystemEventTypeKeys.templeVisit: 0xFF66C7B3,
      };
      for (final entry in oldDefaults.entries) {
        final type = (await repository.readEventTypes(
          profileId: profileId,
        )).singleWhere((type) => type.stableKey == entry.key);
        await (database.update(database.activityTypes)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(type.id),
            ))
            .write(ActivityTypesCompanion(colorValue: Value<int>(entry.value)));
      }
      // Any public entry point re-runs the reconciliation.
      final migrated = await repository.readEventTypes(profileId: profileId);
      const expected = <String, int>{
        SystemEventTypeKeys.jobApplication: 0xFFEBC766,
        SystemEventTypeKeys.scriptureStudy: 0xFFDE9EDA,
        SystemEventTypeKeys.exercise: 0xFFEAA15D,
        SystemEventTypeKeys.budgetReview: 0xFFBFA384,
        SystemEventTypeKeys.meaningfulConnection: 0xFFB0A971,
        SystemEventTypeKeys.templeVisit: 0xFF98CED8,
      };
      for (final entry in expected.entries) {
        final type = migrated.singleWhere(
          (type) => type.stableKey == entry.key,
        );
        expect(type.colorValue, entry.value, reason: entry.key);
      }
    },
  );

  test(
    'light-muted era and device-era defaults migrate to faded PMG',
    () async {
      // The previous light-muted recommended mapping plus the device-era
      // light-muted Contact-through-Task values observed on the Infinix must
      // converge to the final faded family without touching custom colors.
      const deviceEra = <String, int>{
        SystemEventTypeKeys.jobApplication: 0xFFC98BA7,
        SystemEventTypeKeys.exercise: 0xFF9CCB8F,
        SystemEventTypeKeys.templeVisit: 0xFF82C8BE,
        SystemEventTypeKeys.contact: 0xFF7BB37D,
        SystemEventTypeKeys.meeting: 0xFFE57A88,
        SystemEventTypeKeys.work: 0xFFD5E7EE,
        SystemEventTypeKeys.other: 0xFF8C8C8C,
      };
      for (final entry in deviceEra.entries) {
        final type = (await repository.readEventTypes(
          profileId: profileId,
        )).singleWhere((type) => type.stableKey == entry.key);
        await (database.update(database.activityTypes)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(type.id),
            ))
            .write(ActivityTypesCompanion(colorValue: Value<int>(entry.value)));
      }
      final migrated = await repository.readEventTypes(profileId: profileId);
      final byKey = <String, int>{
        for (final type in migrated) type.stableKey: type.colorValue,
      };
      expect(byKey[SystemEventTypeKeys.jobApplication], 0xFFEBC766);
      expect(byKey[SystemEventTypeKeys.exercise], 0xFFEAA15D);
      expect(byKey[SystemEventTypeKeys.templeVisit], 0xFF98CED8);
      expect(byKey[SystemEventTypeKeys.contact], 0xFF76B181);
      expect(byKey[SystemEventTypeKeys.meeting], 0xFFE27386);
      // P-01D: untouched Work rows converge off the shared icy Service
      // family onto the muted steel pair; Service keeps 0xFFDEEDF2.
      expect(byKey[SystemEventTypeKeys.work], 0xFFA9BEC9);
      expect(byKey[SystemEventTypeKeys.other], 0xFF868A8D);
    },
  );

  test(
    'customized locked colors are preserved and migration is idempotent',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);
      final exercise = types.singleWhere(
        (type) => type.stableKey == SystemEventTypeKeys.exercise,
      );
      const custom = 0xFF8A5CF6;
      await (database.update(database.activityTypes)..where(
            (table) =>
                table.profileId.equals(profileId) &
                table.id.equals(exercise.id),
          ))
          .write(ActivityTypesCompanion(colorValue: Value<int>(custom)));
      final after = await repository.readEventTypes(profileId: profileId);
      expect(
        after
            .singleWhere(
              (type) => type.stableKey == SystemEventTypeKeys.exercise,
            )
            .colorValue,
        custom,
        reason: 'a customized color must never be overwritten by the migration',
      );
      // Running reconciliation again leaves the customized color untouched.
      final again = await repository.readEventTypes(profileId: profileId);
      expect(
        again
            .singleWhere(
              (type) => type.stableKey == SystemEventTypeKeys.exercise,
            )
            .colorValue,
        custom,
      );
    },
  );

  test(
    'mapped Contact-through-Task types seed the exact PMG defaults',
    () async {
      const expected = <String, int>{
        SystemEventTypeKeys.contact: 0xFF76B181,
        SystemEventTypeKeys.meeting: 0xFFE27386,
        SystemEventTypeKeys.studyOrPlan: 0xFFA272C8,
        SystemEventTypeKeys.service: 0xFFDEEDF2,
        // P-01D: fresh installs seed Work with the muted steel pair, distinct
        // from Service.
        SystemEventTypeKeys.work: 0xFFA9BEC9,
        SystemEventTypeKeys.travel: 0xFFECC7D8,
        SystemEventTypeKeys.meal: 0xFFE1CFB9,
        SystemEventTypeKeys.other: 0xFF868A8D,
      };
      final types = await repository.readEventTypes(profileId: profileId);
      for (final entry in expected.entries) {
        final type = types.singleWhere((type) => type.stableKey == entry.key);
        expect(
          type.colorValue,
          entry.value,
          reason: '${entry.key} must seed the exact PMG accent',
        );
      }
    },
  );

  test(
    'legacy dark surfaces self-heal to the light-muted derivation on read',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);
      final ministering = types.singleWhere(
        (type) => type.stableKey == SystemEventTypeKeys.meaningfulConnection,
      );
      // Simulate a pair persisted by the old dark-blend pipeline: the saved
      // accent is kept, but its surface is the stale legacy blend.
      const legacy = EventColorPreference(
        accentArgb: 0xFFA5975F,
        surfaceArgb: 0xFF4C3E3D,
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: ministering.stableKey,
        preference: legacy,
      );

      final healed = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      final expectedSurfaceArgb = EventColorMath.lightMutedSurfaceArgb(
        legacy.accentArgb,
      );
      expect(
        healed[ministering.stableKey]?.accentArgb,
        legacy.accentArgb,
        reason: 'the saved accent must never be changed by the repair',
      );
      expect(healed[ministering.stableKey]?.surfaceArgb, expectedSurfaceArgb);
      expect(
        expectedSurfaceArgb,
        isNot(legacy.surfaceArgb),
        reason: 'the old dark blend must not survive the repair',
      );

      // The repair is persisted, so a second read is stable (idempotent) and
      // the stored document now carries the healed pair.
      final again = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(again[ministering.stableKey], healed[ministering.stableKey]);
      final row = await (database.select(
        database.plannerPreferences,
      )..where((table) => table.profileId.equals(profileId))).getSingle();
      expect(
        EventColorPreferenceCodec.decode(
          row.eventColorPreferencesJson,
        )[ministering.stableKey],
        healed[ministering.stableKey],
      );
      // A further read must not rewrite the already-healed document.
      final persisted = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(persisted[ministering.stableKey], healed[ministering.stableKey]);
      final rowAgain = await (database.select(
        database.plannerPreferences,
      )..where((table) => table.profileId.equals(profileId))).getSingle();
      expect(
        rowAgain.eventColorPreferencesJson,
        row.eventColorPreferencesJson,
        reason: 'a second read must not rewrite the healed document',
      );
    },
  );

  test(
    'legacy saved accents converge to the PMG palette while custom stays',
    () async {
      // An older pipeline persisted the pre-PMG accent (dark-muted Slate Blue
      // family) into the preference document; the presentation resolver would
      // otherwise keep rendering pre-PMG colors forever.
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.budgetReview,
        preference: const EventColorPreference(
          accentArgb: 0xFFA5975F,
          surfaceArgb: 0xFF736F61,
        ),
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.meaningfulConnection,
        preference: const EventColorPreference(
          accentArgb: 0xFFBB7772,
          surfaceArgb: 0xFF836C6B,
        ),
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.jobApplication,
        preference: const EventColorPreference(
          accentArgb: 0xFFA15E79,
          surfaceArgb: 0xFF716067,
        ),
      );
      // A genuinely custom accent that matches no legacy default stays (its
      // surface is already the derivation, so the surface repair leaves the
      // pair untouched).
      final custom = EventColorPreference(
        accentArgb: 0xFF8A5CF6,
        surfaceArgb: EventColorMath.lightMutedSurfaceArgb(0xFF8A5CF6),
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.scriptureStudy,
        preference: custom,
      );

      final healed = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(healed[SystemEventTypeKeys.budgetReview]?.accentArgb, 0xFFBFA384);
      expect(
        healed[SystemEventTypeKeys.budgetReview]?.surfaceArgb,
        EventColorMath.lightMutedSurfaceArgb(0xFFBFA384),
      );
      expect(
        healed[SystemEventTypeKeys.meaningfulConnection]?.accentArgb,
        0xFFB0A971,
      );
      // Job converges to the exact locked pair (accent AND explicit surface).
      expect(
        healed[SystemEventTypeKeys.jobApplication],
        const EventColorPreference(
          accentArgb: 0xFFEBC766,
          surfaceArgb: 0xFF4C4942,
        ),
      );
      expect(healed[SystemEventTypeKeys.scriptureStudy], custom);

      // The remap is persisted and idempotent.
      final again = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(
        again[SystemEventTypeKeys.budgetReview],
        healed[SystemEventTypeKeys.budgetReview],
      );
    },
  );

  test(
    'surface repair keeps custom accents, group colors, and light pairs',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);
      final job = types.singleWhere(
        (type) => type.stableKey == SystemEventTypeKeys.jobApplication,
      );
      // A custom accent that matches no recognized legacy default: the
      // surface repair must lift only its stale dark surface while leaving
      // the accent itself untouched.
      final customDark = EventColorPreference(
        accentArgb: 0xFF123456,
        surfaceArgb: 0xFF1A1A1A,
      );
      final alreadyLight = EventColorPreference(
        accentArgb: 0xFF8A5CF6,
        surfaceArgb: EventColorMath.lightMutedSurfaceArgb(0xFF8A5CF6),
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: job.stableKey,
        preference: customDark,
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.scriptureStudy,
        preference: alreadyLight,
      );
      await repository.saveContactGroupColor(
        profileId: profileId,
        groupId: 'family',
        colorArgb: 0xFFEBC766,
      );

      final healed = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(
        healed[job.stableKey],
        EventColorPreference(
          accentArgb: customDark.accentArgb,
          surfaceArgb: EventColorMath.lightMutedSurfaceArgb(
            customDark.accentArgb,
          ),
        ),
        reason:
            'a custom accent is never remapped; only its stale surface '
            'is lifted to the derivation',
      );
      expect(
        healed[SystemEventTypeKeys.scriptureStudy],
        alreadyLight,
        reason: 'a pair that already matches the derivation is untouched',
      );
      expect(
        await repository.readContactGroupColors(profileId: profileId),
        <String, int>{'family': 0xFFEBC766},
        reason: 'group colors are never touched by the surface repair',
      );
    },
  );

  test(
    'saved pre-delta default pairs converge to the exact locked pairs',
    () async {
      const preDelta = <String, EventColorPreference>{
        SystemEventTypeKeys.jobApplication: EventColorPreference(
          accentArgb: 0xFFB98CA8,
          surfaceArgb: 0xFF877580,
        ),
        SystemEventTypeKeys.scriptureStudy: EventColorPreference(
          accentArgb: 0xFFC27E6E,
          surfaceArgb: 0xFF866F69,
        ),
        SystemEventTypeKeys.exercise: EventColorPreference(
          accentArgb: 0xFF90AE79,
          surfaceArgb: 0xFF747E6C,
        ),
        SystemEventTypeKeys.templeVisit: EventColorPreference(
          accentArgb: 0xFF77ADA9,
          surfaceArgb: 0xFF6B7D7B,
        ),
        SystemEventTypeKeys.contact: EventColorPreference(
          accentArgb: 0xFF74C385,
          surfaceArgb: 0xFF6C8871,
        ),
        SystemEventTypeKeys.meeting: EventColorPreference(
          accentArgb: 0xFFF07175,
          surfaceArgb: 0xFF9E6264,
        ),
        SystemEventTypeKeys.studyOrPlan: EventColorPreference(
          accentArgb: 0xFFA474DC,
          surfaceArgb: 0xFF7E6996,
        ),
        SystemEventTypeKeys.service: EventColorPreference(
          accentArgb: 0xFFD3EEF8,
          surfaceArgb: 0xFF648C9B,
        ),
        // P-01D: the previous approved Work default (shared icy Service
        // pair) is the exact value the new hop migrates in a single read.
        SystemEventTypeKeys.work: EventColorPreference(
          accentArgb: 0xFFDEEDF2,
          surfaceArgb: 0xFF404447,
        ),
        SystemEventTypeKeys.travel: EventColorPreference(
          accentArgb: 0xFFECAEC6,
          surfaceArgb: 0xFF97687B,
        ),
        SystemEventTypeKeys.meal: EventColorPreference(
          accentArgb: 0xFFEAD5B8,
          surfaceArgb: 0xFF94836B,
        ),
        SystemEventTypeKeys.other: EventColorPreference(
          accentArgb: 0xFF8E9599,
          surfaceArgb: 0xFF70777A,
        ),
      };
      const locked = <String, EventColorPreference>{
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
      for (final entry in preDelta.entries) {
        await repository.saveEventColorPreference(
          profileId: profileId,
          eventTypeStableKey: entry.key,
          preference: entry.value,
        );
      }
      final converged = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      for (final entry in locked.entries) {
        expect(
          converged[entry.key],
          entry.value,
          reason: '${entry.key} must converge to the exact locked pair',
        );
      }
      // The exact locked surfaces must survive a further read untouched.
      final again = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(again, converged);
    },
  );

  test(
    'explicit PMG surfaces are preserved verbatim and never re-derived',
    () async {
      const lockedJob = EventColorPreference(
        accentArgb: 0xFFEBC766,
        surfaceArgb: 0xFF4C4942,
      );
      const lockedService = EventColorPreference(
        accentArgb: 0xFFDEEDF2,
        surfaceArgb: 0xFF404447,
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.jobApplication,
        preference: lockedJob,
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.service,
        preference: lockedService,
      );

      final first = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(first[SystemEventTypeKeys.jobApplication], lockedJob);
      expect(first[SystemEventTypeKeys.service], lockedService);
      final rowAfterFirst = await (database.select(
        database.plannerPreferences,
      )..where((table) => table.profileId.equals(profileId))).getSingle();
      final second = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(second, first);
      final rowAfterSecond = await (database.select(
        database.plannerPreferences,
      )..where((table) => table.profileId.equals(profileId))).getSingle();
      expect(
        rowAfterSecond.eventColorPreferencesJson,
        rowAfterFirst.eventColorPreferencesJson,
        reason: 'a second read must never rewrite the locked pairs',
      );
    },
  );

  test(
    'Ministering Visit and Budget Review defaults remain unchanged',
    () async {
      final types = await repository.readEventTypes(profileId: profileId);
      final ministering = types.singleWhere(
        (type) => type.stableKey == SystemEventTypeKeys.meaningfulConnection,
      );
      final budget = types.singleWhere(
        (type) => type.stableKey == SystemEventTypeKeys.budgetReview,
      );
      expect(ministering.colorValue, 0xFFB0A971);
      expect(budget.colorValue, 0xFFBFA384);
      // Simulate the untouched default saved in the preference document:
      // neither pair may be remapped by the migration.
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.meaningfulConnection,
        preference: PlannerEventColorDefaults.lockedMinisteringVisit,
      );
      await repository.saveEventColorPreference(
        profileId: profileId,
        eventTypeStableKey: SystemEventTypeKeys.budgetReview,
        preference: PlannerEventColorDefaults.lockedBudgetReview,
      );
      final healed = await repository.readEventColorPreferences(
        profileId: profileId,
      );
      expect(
        healed[SystemEventTypeKeys.meaningfulConnection],
        PlannerEventColorDefaults.lockedMinisteringVisit,
        reason: 'Ministering Visit must keep its prior default pair',
      );
      expect(
        healed[SystemEventTypeKeys.budgetReview],
        PlannerEventColorDefaults.lockedBudgetReview,
        reason: 'Budget Review must keep its prior default pair',
      );
    },
  );
}

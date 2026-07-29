import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/planner/application/event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';

final class DriftEventTypeRepository implements EventTypeRepository {
  const DriftEventTypeRepository({required this.database, required this.clock});

  final AppDatabase database;
  final AppClock clock;

  @override
  Future<List<EventType>> readEventTypes({
    required String profileId,
    bool includeArchived = false,
  }) async {
    await _ensureSystemTypes(profileId);
    final rows =
        await (database.select(database.activityTypes)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    (includeArchived
                        ? const Constant(true)
                        : table.isArchived.equals(false)),
              )
              ..orderBy(<OrderingTerm Function(ActivityTypes)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.label),
              ]))
            .get();
    final mappings = await _readMappings(profileId);
    return rows
        .map(
          (row) => _map(
            row,
            mappings[_mappingRevisionKey(row.id, row.mappingVersion)] ??
                const <String>{},
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<EventType?> readEventType({
    required String profileId,
    required String eventTypeId,
  }) async {
    await _ensureSystemTypes(profileId);
    final row =
        await (database.select(database.activityTypes)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.id.equals(eventTypeId),
            ))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    final mappings = await _readMappings(profileId);
    return _map(
      row,
      mappings[_mappingRevisionKey(row.id, row.mappingVersion)] ??
          const <String>{},
    );
  }

  @override
  Future<EventType?> readExactTypeForIndicator({
    required String profileId,
    required String indicatorKey,
  }) async {
    final types = await readEventTypes(profileId: profileId);
    final matches = types
        .where(
          (type) =>
              type.isSystem &&
              type.indicatorKeys.length == 1 &&
              type.indicatorKeys.single == indicatorKey,
        )
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  @override
  Future<EventType> saveCustomType({
    required String profileId,
    required EventTypeDraft draft,
  }) async {
    final label = draft.label.trim();
    if (label.isEmpty) {
      throw ArgumentError.value(draft.label, 'label', 'Label is required.');
    }
    if (draft.defaultDurationMinutes < 15 ||
        draft.defaultDurationMinutes > 24 * 60) {
      throw ArgumentError.value(
        draft.defaultDurationMinutes,
        'defaultDurationMinutes',
      );
    }
    await _ensureSystemTypes(profileId);
    return database.transaction(() async {
      final existing =
          await (database.select(database.activityTypes)..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(draft.id),
              ))
              .getSingleOrNull();
      if (existing?.isSystem ?? false) {
        throw StateError('System Event Type identity is protected.');
      }
      final now = clock.nowUtc();
      final nextPosition =
          existing?.position ??
          ((await (database.select(
                    database.activityTypes,
                  )..where((table) => table.profileId.equals(profileId))).get())
                  .map((row) => row.position)
                  .fold<int>(
                    -1,
                    (value, position) => position > value ? position : value,
                  ) +
              1);
      final mappingVersion = (existing?.mappingVersion ?? 0) + 1;
      await database
          .into(database.activityTypes)
          .insertOnConflictUpdate(
            ActivityTypesCompanion.insert(
              id: draft.id,
              profileId: profileId,
              stableKey: existing?.stableKey ?? 'custom:${draft.id}',
              label: label,
              iconKey: draft.icon.name,
              colorValue: draft.colorValue,
              isSystem: false,
              isArchived: const Value<bool>(false),
              reportRequiredDefault: Value<bool>(draft.reportRequiredDefault),
              defaultDurationMinutes: Value<int>(draft.defaultDurationMinutes),
              defaultReminderMinutes: Value<int?>(draft.defaultReminderMinutes),
              position: nextPosition,
              mappingVersion: Value<int>(mappingVersion),
              createdAtUtc: existing?.createdAtUtc ?? now,
              updatedAtUtc: now,
            ),
          );
      for (final indicatorKey in draft.indicatorKeys) {
        await database
            .into(database.activityTypeIndicatorMappings)
            .insert(
              ActivityTypeIndicatorMappingsCompanion.insert(
                id: '${draft.id}:$mappingVersion:$indicatorKey',
                profileId: profileId,
                activityTypeId: draft.id,
                indicatorKey: indicatorKey,
                mappingVersion: Value<int>(mappingVersion),
                createdAtUtc: now,
              ),
            );
      }
      return (await readEventType(
        profileId: profileId,
        eventTypeId: draft.id,
      ))!;
    });
  }

  @override
  Future<void> setCustomTypeArchived({
    required String profileId,
    required String eventTypeId,
    required bool archived,
  }) async {
    final type = await readEventType(
      profileId: profileId,
      eventTypeId: eventTypeId,
    );
    if (type == null) {
      throw StateError('Event Type not found.');
    }
    if (type.isSystem) {
      throw StateError('System Event Types cannot be archived.');
    }
    await (database.update(database.activityTypes)..where(
          (table) =>
              table.profileId.equals(profileId) & table.id.equals(eventTypeId),
        ))
        .write(
          ActivityTypesCompanion(
            isArchived: Value<bool>(archived),
            updatedAtUtc: Value<DateTime>(clock.nowUtc()),
          ),
        );
  }

  @override
  Future<void> restoreSystemDefaults({required String profileId}) async {
    await database.transaction(() async {
      await (database.delete(database.activityTypeIndicatorMappings)..where(
            (table) =>
                table.profileId.equals(profileId) &
                table.activityTypeId.isIn(
                  _systemSeeds.map((seed) => seed.id).toList(growable: false),
                ),
          ))
          .go();
      await (database.delete(database.activityTypes)..where(
            (table) =>
                table.profileId.equals(profileId) & table.isSystem.equals(true),
          ))
          .go();
      await _insertSystemTypes(profileId);
    });
  }

  @override
  Future<PlannerSettings> readPlannerSettings({
    required String profileId,
  }) async {
    await _ensureSystemTypes(profileId);
    final row = await (database.select(
      database.plannerPreferences,
    )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
    if (row == null) {
      return const PlannerSettings.defaults();
    }
    return PlannerSettings(
      defaultEventTypeId: row.defaultActivityTypeId,
      defaultDurationMinutes: row.defaultDurationMinutes,
      defaultReminderMinutes: row.defaultReminderMinutes,
      visibleStartHour: row.visibleStartHour,
      visibleEndHour: row.visibleEndHour,
      use24HourTime: row.use24HourTime,
      snapMinutes: row.snapMinutes,
      showCurrentTime: row.showCurrentTime,
      initialScrollBehavior: PlannerInitialScrollBehavior.values.byName(
        row.initialScrollBehavior,
      ),
      creationPresentation: EventCreationPresentation.values.byName(
        row.creationPresentation,
      ),
      quickEditEnabled: row.quickEditEnabled,
      showCompletedItems: row.showCompletedItems,
      showCancelledItems: row.showCancelledItems,
      weekStartDay: row.weekStartDay,
    );
  }

  @override
  Future<PlannerSettings> savePlannerSettings({
    required String profileId,
    required PlannerSettings settings,
  }) async {
    settings.validate();
    final defaultTypeId = settings.defaultEventTypeId;
    if (defaultTypeId != null) {
      final type = await readEventType(
        profileId: profileId,
        eventTypeId: defaultTypeId,
      );
      if (type == null || type.isArchived) {
        throw StateError('Default Event Type must be active.');
      }
    }
    await database
        .into(database.plannerPreferences)
        .insertOnConflictUpdate(
          PlannerPreferencesCompanion.insert(
            profileId: profileId,
            defaultActivityTypeId: Value<String?>(defaultTypeId),
            defaultDurationMinutes: Value<int>(settings.defaultDurationMinutes),
            defaultReminderMinutes: Value<int?>(
              settings.defaultReminderMinutes,
            ),
            visibleStartHour: Value<int>(settings.visibleStartHour),
            visibleEndHour: Value<int>(settings.visibleEndHour),
            use24HourTime: Value<bool>(settings.use24HourTime),
            snapMinutes: Value<int>(settings.snapMinutes),
            showCurrentTime: Value<bool>(settings.showCurrentTime),
            initialScrollBehavior: Value<String>(
              settings.initialScrollBehavior.name,
            ),
            creationPresentation: Value<String>(
              settings.creationPresentation.name,
            ),
            quickEditEnabled: Value<bool>(settings.quickEditEnabled),
            showCompletedItems: Value<bool>(settings.showCompletedItems),
            showCancelledItems: Value<bool>(settings.showCancelledItems),
            weekStartDay: Value<int>(settings.weekStartDay),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
    return settings;
  }

  Future<void> _ensureSystemTypes(String profileId) async {
    final existing =
        await (database.select(database.activityTypes)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.isSystem.equals(true),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await database.transaction(() => _insertSystemTypes(profileId));
    }
  }

  Future<void> _insertSystemTypes(String profileId) async {
    final now = clock.nowUtc();
    for (final seed in _systemSeeds) {
      await database
          .into(database.activityTypes)
          .insert(
            ActivityTypesCompanion.insert(
              id: seed.id,
              profileId: profileId,
              stableKey: seed.key,
              label: seed.label,
              iconKey: seed.icon.name,
              colorValue: seed.colorValue,
              isSystem: true,
              reportRequiredDefault: Value<bool>(seed.reportRequired),
              defaultDurationMinutes: Value<int>(seed.durationMinutes),
              position: seed.position,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final indicatorKey = seed.indicatorKey;
      if (indicatorKey != null) {
        await database
            .into(database.activityTypeIndicatorMappings)
            .insert(
              ActivityTypeIndicatorMappingsCompanion.insert(
                id: '${seed.id}:1:$indicatorKey',
                profileId: profileId,
                activityTypeId: seed.id,
                indicatorKey: indicatorKey,
                createdAtUtc: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }
  }

  Future<Map<String, Set<String>>> _readMappings(String profileId) async {
    final rows = await (database.select(
      database.activityTypeIndicatorMappings,
    )..where((table) => table.profileId.equals(profileId))).get();
    final result = <String, Set<String>>{};
    for (final row in rows) {
      result
          .putIfAbsent(
            _mappingRevisionKey(row.activityTypeId, row.mappingVersion),
            () => <String>{},
          )
          .add(row.indicatorKey);
    }
    return result;
  }

  static String _mappingRevisionKey(String eventTypeId, int mappingVersion) =>
      '$eventTypeId:$mappingVersion';

  EventType _map(ActivityTypeRow row, Set<String> indicatorKeys) {
    return EventType(
      id: row.id,
      stableKey: row.stableKey,
      label: row.label,
      icon: EventTypeIcon.values.byName(row.iconKey),
      colorValue: row.colorValue,
      isSystem: row.isSystem,
      isArchived: row.isArchived,
      reportRequiredDefault: row.reportRequiredDefault,
      defaultDurationMinutes: row.defaultDurationMinutes,
      defaultReminderMinutes: row.defaultReminderMinutes,
      position: row.position,
      mappingVersion: row.mappingVersion,
      indicatorKeys: Set<String>.unmodifiable(indicatorKeys),
    );
  }
}

final class _SystemEventTypeSeed {
  const _SystemEventTypeSeed({
    required this.id,
    required this.key,
    required this.label,
    required this.icon,
    required this.colorValue,
    required this.position,
    this.indicatorKey,
    this.reportRequired = false,
    this.durationMinutes = 60,
  });

  final String id;
  final String key;
  final String label;
  final EventTypeIcon icon;
  final int colorValue;
  final int position;
  final String? indicatorKey;
  final bool reportRequired;
  final int durationMinutes;
}

const _systemSeeds = <_SystemEventTypeSeed>[
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.general,
    key: SystemEventTypeKeys.general,
    label: 'General',
    icon: EventTypeIcon.calendar,
    colorValue: 0xFFE91E63,
    position: 0,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.templeVisit,
    key: SystemEventTypeKeys.templeVisit,
    label: 'Temple Visit',
    icon: EventTypeIcon.temple,
    colorValue: 0xFFB39DDB,
    position: 1,
    indicatorKey: 'temple_visit',
    reportRequired: true,
    durationMinutes: 120,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.scriptureStudy,
    key: SystemEventTypeKeys.scriptureStudy,
    label: 'Scripture Study',
    icon: EventTypeIcon.scripture,
    colorValue: 0xFF7CB342,
    position: 2,
    indicatorKey: 'scripture_study',
    reportRequired: true,
    durationMinutes: 30,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.exercise,
    key: SystemEventTypeKeys.exercise,
    label: 'Exercise',
    icon: EventTypeIcon.exercise,
    colorValue: 0xFFFF7043,
    position: 3,
    indicatorKey: 'exercise',
    reportRequired: true,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.budgetReview,
    key: SystemEventTypeKeys.budgetReview,
    label: 'Budget Review',
    icon: EventTypeIcon.budget,
    colorValue: 0xFF42A5F5,
    position: 4,
    indicatorKey: 'budget_review',
    reportRequired: true,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.jobApplication,
    key: SystemEventTypeKeys.jobApplication,
    label: 'Job Application',
    icon: EventTypeIcon.job,
    colorValue: 0xFFAB47BC,
    position: 5,
    indicatorKey: 'job_applications',
    reportRequired: true,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.meaningfulConnection,
    key: SystemEventTypeKeys.meaningfulConnection,
    label: 'Meaningful Connection',
    icon: EventTypeIcon.connection,
    colorValue: 0xFFEC407A,
    position: 6,
    indicatorKey: 'meaningful_connections',
    reportRequired: true,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.appointment,
    key: SystemEventTypeKeys.appointment,
    label: 'Appointment',
    icon: EventTypeIcon.appointment,
    colorValue: 0xFF26A69A,
    position: 7,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.work,
    key: SystemEventTypeKeys.work,
    label: 'Work',
    icon: EventTypeIcon.work,
    colorValue: 0xFF78909C,
    position: 8,
  ),
  _SystemEventTypeSeed(
    id: SystemEventTypeIds.personal,
    key: SystemEventTypeKeys.personal,
    label: 'Personal',
    icon: EventTypeIcon.personal,
    colorValue: 0xFFFFA726,
    position: 9,
  ),
];

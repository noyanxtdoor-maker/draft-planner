// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('LocalProfileRow')
class LocalProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get slot =>
      text().withDefault(const Constant('primary')).unique()();
  TextColumn get localName => text()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('OnboardingCheckpointRow')
class OnboardingCheckpoints extends Table {
  TextColumn get key => text().withDefault(const Constant('primary'))();
  TextColumn get pendingProfileId => text()();
  TextColumn get stage => text()();
  TextColumn get draftDisplayName => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@TableIndex(
  name: 'life_indicator_profile_key_unique',
  columns: <Symbol>{#profileId, #indicatorKey},
  unique: true,
)
@DataClassName('LifeIndicatorDefinitionRow')
class LifeIndicatorDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get indicatorKey => text()();
  TextColumn get label => text()();
  TextColumn get unit => text()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('PrivacyPreferenceRow')
class PrivacyPreferences extends Table {
  TextColumn get key => text().withDefault(const Constant('primary'))();
  BoolColumn get lockEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get notificationPreviewMode =>
      text().withDefault(const Constant('hidden'))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DataClassName('PermissionAuditRow')
class PermissionAudits extends Table {
  TextColumn get permissionKey => text()();
  BoolColumn get requestedByApp =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get everGranted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{permissionKey};
}

@TableIndex(
  name: 'planner_task_profile_due_date',
  columns: <Symbol>{#profileId, #dueDate},
)
@DataClassName('PlannerTaskRow')
class PlannerTasks extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get dueDate => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('incomplete'))();
  BoolColumn get requiresReport =>
      boolean().withDefault(const Constant(false))();
  TextColumn get contributionRuleKey => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'task_status_change_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@TableIndex(
  name: 'task_status_change_task_time',
  columns: <Symbol>{#taskId, #changedAtUtc},
)
@DataClassName('TaskStatusChangeRow')
class TaskStatusChanges extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get taskId =>
      text().references(PlannerTasks, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get fromStatus => text()();
  TextColumn get toStatus => text()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get changedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'calendar_event_profile_start_date',
  columns: <Symbol>{#profileId, #startDate},
)
@DataClassName('CalendarEventRow')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get timing => text()();
  TextColumn get startDate => text()();
  IntColumn get startMinute => integer().nullable()();
  IntColumn get endMinute => integer().nullable()();
  TextColumn get timeZoneId => text().nullable()();
  TextColumn get locationText => text().nullable()();
  BoolColumn get requiresReport =>
      boolean().withDefault(const Constant(false))();
  TextColumn get contributionRuleKey => text().nullable()();
  TextColumn get recurrenceFrequency =>
      text().withDefault(const Constant('none'))();
  TextColumn get recurrenceEndMode =>
      text().withDefault(const Constant('never'))();
  TextColumn get recurrenceEndDate => text().nullable()();
  IntColumn get recurrenceCount => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  TextColumn get parentEventId => text().nullable()();
  TextColumn get replacementEventId => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'calendar_event_exception_occurrence_time',
  columns: <Symbol>{#eventId, #occurrenceId, #createdAtUtc},
)
@DataClassName('CalendarEventExceptionRow')
class CalendarEventExceptions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get eventId =>
      text().references(CalendarEvents, #id, onDelete: KeyAction.restrict)();
  TextColumn get occurrenceId => text()();
  TextColumn get originalDate => text()();
  TextColumn get effectiveDate => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get timing => text()();
  IntColumn get startMinute => integer().nullable()();
  IntColumn get endMinute => integer().nullable()();
  TextColumn get timeZoneId => text().nullable()();
  TextColumn get locationText => text().nullable()();
  BoolColumn get requiresReport =>
      boolean().withDefault(const Constant(false))();
  TextColumn get contributionRuleKey => text().nullable()();
  TextColumn get status => text()();
  TextColumn get replacementEventId => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('CalendarEventOperationRow')
class CalendarEventOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get eventId => text()();
  TextColumn get occurrenceId => text().nullable()();
  TextColumn get command => text()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{operationId};
}

@TableIndex(
  name: 'task_event_link_equivalent_unique',
  columns: <Symbol>{#profileId, #taskId, #eventId, #targetKey},
  unique: true,
)
@TableIndex(
  name: 'task_event_link_task_status',
  columns: <Symbol>{#taskId, #status},
)
@TableIndex(
  name: 'task_event_link_event_status',
  columns: <Symbol>{#eventId, #status},
)
@DataClassName('TaskEventLinkRow')
class TaskEventLinks extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get taskId => text()();
  TextColumn get eventId => text()();
  TextColumn get scope => text()();
  TextColumn get targetKey => text()();
  TextColumn get occurrenceId => text().nullable()();
  TextColumn get originalDate => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get canonicalSource => text()();
  TextColumn get transferredFromLinkId => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'task_event_link_history_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@TableIndex(
  name: 'task_event_link_history_link_time',
  columns: <Symbol>{#linkId, #createdAtUtc},
)
@DataClassName('TaskEventLinkHistoryRow')
class TaskEventLinkHistory extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get linkId => text()();
  TextColumn get operationId => text()();
  TextColumn get action => text()();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text()();
  TextColumn get relatedLinkId => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(
  tables: <Type>[
    LocalProfiles,
    OnboardingCheckpoints,
    LifeIndicatorDefinitions,
    PrivacyPreferences,
    PermissionAudits,
    PlannerTasks,
    TaskStatusChanges,
    CalendarEvents,
    CalendarEventExceptions,
    CalendarEventOperations,
    TaskEventLinks,
    TaskEventLinkHistory,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase.defaults()
    : _schemaVersionOverride = null,
      _injectMigrationFailure = false,
      _injectTaskMigrationFailure = false,
      _injectCalendarEventMigrationFailure = false,
      _injectTaskEventLinkMigrationFailure = false,
      super(driftDatabase(name: 'next_transfer'));

  AppDatabase.forTesting(
    super.executor, {
    int? schemaVersionOverride,
    bool injectMigrationFailure = false,
    bool injectTaskMigrationFailure = false,
    bool injectCalendarEventMigrationFailure = false,
    bool injectTaskEventLinkMigrationFailure = false,
  }) : _schemaVersionOverride = schemaVersionOverride,
       _injectMigrationFailure = injectMigrationFailure,
       _injectTaskMigrationFailure = injectTaskMigrationFailure,
       _injectCalendarEventMigrationFailure =
           injectCalendarEventMigrationFailure,
       _injectTaskEventLinkMigrationFailure =
           injectTaskEventLinkMigrationFailure;

  final int? _schemaVersionOverride;
  final bool _injectMigrationFailure;
  final bool _injectTaskMigrationFailure;
  final bool _injectCalendarEventMigrationFailure;
  final bool _injectTaskEventLinkMigrationFailure;

  @override
  int get schemaVersion => _schemaVersionOverride ?? 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createTable(localProfiles);
        await migrator.createTable(onboardingCheckpoints);
        await migrator.createTable(lifeIndicatorDefinitions);
        if (schemaVersion >= 2) {
          await migrator.createTable(privacyPreferences);
          await migrator.createTable(permissionAudits);
        }
        if (schemaVersion >= 3) {
          await migrator.createTable(plannerTasks);
          await migrator.createTable(taskStatusChanges);
        }
        if (schemaVersion >= 4) {
          await migrator.createTable(calendarEvents);
          await migrator.createTable(calendarEventExceptions);
          await migrator.createTable(calendarEventOperations);
        }
        if (schemaVersion >= 5) {
          await migrator.createTable(taskEventLinks);
          await migrator.createTable(taskEventLinkHistory);
        }
      },
      onUpgrade: (migrator, from, to) async {
        await transaction(() async {
          if (from < 2 && to >= 2) {
            await migrator.createTable(privacyPreferences);
            await migrator.createTable(permissionAudits);
            if (_injectMigrationFailure) {
              throw StateError('Injected migration failure');
            }
          }
          if (from < 3 && to >= 3) {
            await migrator.createTable(plannerTasks);
            await migrator.createTable(taskStatusChanges);
            if (_injectTaskMigrationFailure) {
              throw StateError('Injected task migration failure');
            }
          }
          if (from < 4 && to >= 4) {
            await migrator.createTable(calendarEvents);
            await migrator.createTable(calendarEventExceptions);
            await migrator.createTable(calendarEventOperations);
            if (_injectCalendarEventMigrationFailure) {
              throw StateError('Injected Calendar Event migration failure');
            }
          }
          if (from < 5 && to >= 5) {
            await migrator.createTable(taskEventLinks);
            await migrator.createTable(taskEventLinkHistory);
            if (_injectTaskEventLinkMigrationFailure) {
              throw StateError('Injected Task-Event link migration failure');
            }
          }
        });
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

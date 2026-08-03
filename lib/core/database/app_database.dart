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
  TextColumn get timeZoneId => text().nullable()();
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

/// The canonical lifecycle record for a user-facing goal.
///
/// `role` and `activeSlotIndex` are intentionally stored as stable values
/// rather than inferred from the current WLI label.  This lets a renamed or
/// archived goal keep its identity, history, and relationships intact.
@TableIndex(
  name: 'goal_profile_active_slot_unique',
  columns: <Symbol>{#profileId, #activeSlotIndex},
  unique: true,
)
@TableIndex(
  name: 'goal_profile_status_slot',
  columns: <Symbol>{#profileId, #status, #activeSlotIndex},
)
@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get indicatorKey => text().nullable()();
  TextColumn get role => text()();
  IntColumn get activeSlotIndex => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get iconId => text().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();
  DateTimeColumn get archivedAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'goal_activity_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@TableIndex(
  name: 'goal_activity_goal_time',
  columns: <Symbol>{#goalId, #occurredAtUtc},
)
@DataClassName('GoalActivityRow')
class GoalActivities extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get goalId =>
      text().references(Goals, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get action => text()();
  TextColumn get previousValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  DateTimeColumn get occurredAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Local, idempotent outbox entries for Goal lifecycle mutations.  The app is
/// currently offline-first; keeping the operation payload by stable Goal ID
/// makes later sync/backup integration additive instead of requiring a second
/// Goal architecture.
@DataClassName('GoalOutboxOperationRow')
class GoalOutboxOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{operationId};
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
  IntColumn get dueMinute => integer().nullable()();
  TextColumn get recurrenceFrequency =>
      text().withDefault(const Constant('none'))();
  TextColumn get peopleJson => text().withDefault(const Constant('[]'))();
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
  TextColumn get activityTypeId => text().nullable()();
  IntColumn get activityTypeMappingVersion => integer().nullable()();
  TextColumn get contributionRuleKey => text().nullable()();
  BoolColumn get isBackupAppointment =>
      boolean().withDefault(const Constant(false))();
  TextColumn get backupForEventId => text().nullable()();
  TextColumn get backupRelationshipProvenance => text().nullable()();
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
  TextColumn get activityTypeId => text().nullable()();
  IntColumn get activityTypeMappingVersion => integer().nullable()();
  TextColumn get contributionRuleKey => text().nullable()();
  BoolColumn get isBackupAppointment =>
      boolean().withDefault(const Constant(false))();
  TextColumn get backupForEventId => text().nullable()();
  TextColumn get backupRelationshipProvenance => text().nullable()();
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

@TableIndex(
  name: 'outcome_report_effective_slot_unique',
  columns: <Symbol>{#effectiveSlotKey},
  unique: true,
)
@TableIndex(
  name: 'outcome_report_draft_slot_unique',
  columns: <Symbol>{#draftSlotKey},
  unique: true,
)
@TableIndex(
  name: 'outcome_report_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@TableIndex(
  name: 'outcome_report_profile_activity_date',
  columns: <Symbol>{#profileId, #activityDate},
)
@DataClassName('OutcomeReportRow')
class OutcomeReports extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  TextColumn get sourceLabel => text()();
  TextColumn get sourceSlotKey => text()();
  TextColumn get eventId => text().nullable()();
  TextColumn get occurrenceId => text().nullable()();
  TextColumn get originalDate => text().nullable()();
  TextColumn get draftSlotKey => text().nullable()();
  TextColumn get effectiveSlotKey => text().nullable()();
  TextColumn get status => text()();
  TextColumn get outcome => text().nullable()();
  TextColumn get activityDate => text()();
  IntColumn get factualValueScaled => integer().nullable()();
  IntColumn get factualValueScale => integer().withDefault(const Constant(0))();
  TextColumn get factualValueUnit => text().nullable()();
  TextColumn get privateNotes => text().nullable()();
  TextColumn get correctsReportId => text().nullable()();
  TextColumn get correctionReason => text().nullable()();
  TextColumn get operationId => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();
  DateTimeColumn get submittedAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('OutcomeReportContributionDraftRow')
class OutcomeReportContributionDrafts extends Table {
  TextColumn get reportId =>
      text().references(OutcomeReports, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleKey => text()();
  TextColumn get indicatorKey => text()();
  IntColumn get valueScaled => integer()();
  IntColumn get valueScale => integer()();
  TextColumn get unit => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{reportId, ruleKey};
}

@TableIndex(
  name: 'ledger_entry_idempotency_unique',
  columns: <Symbol>{#idempotencyKey},
  unique: true,
)
@TableIndex(
  name: 'ledger_entry_reversal_unique',
  columns: <Symbol>{#reversalOfEntryId},
  unique: true,
)
@TableIndex(
  name: 'ledger_entry_indicator_period',
  columns: <Symbol>{#profileId, #indicatorKey, #activityDate},
)
@TableIndex(
  name: 'ledger_entry_report_rule',
  columns: <Symbol>{#sourceReportId, #ruleKey},
)
@DataClassName('ActivityLedgerEntryRow')
class ActivityLedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get sourceReportId =>
      text().references(OutcomeReports, #id, onDelete: KeyAction.restrict)();
  TextColumn get entryType => text()();
  TextColumn get indicatorKey => text()();
  IntColumn get valueScaled => integer()();
  IntColumn get valueScale => integer()();
  TextColumn get unit => text()();
  TextColumn get activityDate => text()();
  TextColumn get ruleKey => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get reversalOfEntryId => text().nullable()();
  TextColumn get replacesEntryId => text().nullable()();
  DateTimeColumn get recordedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'weekly_indicator_target_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@TableIndex(
  name: 'weekly_indicator_target_period_history',
  columns: <Symbol>{#profileId, #indicatorKey, #periodStartDate, #createdAtUtc},
)
@DataClassName('WeeklyIndicatorTargetRevisionRow')
class WeeklyIndicatorTargetRevisions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get indicatorKey => text()();
  TextColumn get goalId => text().nullable()();
  TextColumn get periodStartDate => text()();
  TextColumn get state => text()();
  IntColumn get valueScaled => integer().nullable()();
  IntColumn get valueScale => integer()();
  TextColumn get unit => text()();
  TextColumn get supersedesRevisionId => text().nullable()();
  TextColumn get operationId => text()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Goal revisions whose period is not necessarily weekly.  Weekly targets
/// remain in [WeeklyIndicatorTargetRevisions] for backwards compatibility;
/// this table carries the daily and monthly slots and gives every period type
/// the same idempotent, append-only semantics.
@TableIndex(
  name: 'indicator_goal_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@TableIndex(
  name: 'indicator_goal_period_history',
  columns: <Symbol>{
    #profileId,
    #indicatorKey,
    #periodType,
    #periodStartDate,
    #createdAtUtc,
  },
)
@DataClassName('IndicatorGoalRevisionRow')
class IndicatorGoalRevisions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get goalId => text().nullable()();
  TextColumn get indicatorKey => text()();
  TextColumn get periodType => text()();
  TextColumn get periodStartDate => text()();
  TextColumn get periodEndDate => text()();
  TextColumn get state => text()();
  IntColumn get valueScaled => integer().nullable()();
  IntColumn get valueScale => integer()();
  TextColumn get unit => text()();
  TextColumn get supersedesRevisionId => text().nullable()();
  TextColumn get operationId => text()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'weekly_plan_profile_period_unique',
  columns: <Symbol>{#profileId, #periodStartDate},
  unique: true,
)
@DataClassName('WeeklyPlanRow')
class WeeklyPlans extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get periodStartDate => text()();
  TextColumn get periodEndDate => text()();
  TextColumn get timeZoneId => text()();
  TextColumn get state => text()();
  DateTimeColumn get reviewCompletedAtUtc => dateTime().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'activity_type_profile_key_unique',
  columns: <Symbol>{#profileId, #stableKey},
  unique: true,
)
@TableIndex(
  name: 'activity_type_profile_position',
  columns: <Symbol>{#profileId, #position},
)
@DataClassName('ActivityTypeRow')
class ActivityTypes extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get stableKey => text()();
  TextColumn get label => text()();
  TextColumn get iconKey => text()();
  IntColumn get colorValue => integer()();
  BoolColumn get isSystem => boolean()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get reportRequiredDefault =>
      boolean().withDefault(const Constant(false))();
  IntColumn get defaultDurationMinutes =>
      integer().withDefault(const Constant(60))();
  IntColumn get defaultReminderMinutes => integer().nullable()();
  IntColumn get position => integer()();
  IntColumn get mappingVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'activity_type_indicator_mapping_unique',
  columns: <Symbol>{#activityTypeId, #mappingVersion, #indicatorKey},
  unique: true,
)
@DataClassName('ActivityTypeIndicatorMappingRow')
class ActivityTypeIndicatorMappings extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get activityTypeId =>
      text().references(ActivityTypes, #id, onDelete: KeyAction.restrict)();
  TextColumn get indicatorKey => text()();
  IntColumn get mappingVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('PlannerPreferenceRow')
class PlannerPreferences extends Table {
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get defaultActivityTypeId => text().nullable()();
  IntColumn get defaultDurationMinutes =>
      integer().withDefault(const Constant(60))();
  IntColumn get defaultReminderMinutes => integer().nullable()();
  IntColumn get visibleStartHour => integer().withDefault(const Constant(6))();
  IntColumn get visibleEndHour => integer().withDefault(const Constant(22))();
  BoolColumn get use24HourTime =>
      boolean().withDefault(const Constant(false))();
  IntColumn get snapMinutes => integer().withDefault(const Constant(15))();
  BoolColumn get showCurrentTime =>
      boolean().withDefault(const Constant(true))();
  TextColumn get initialScrollBehavior =>
      text().withDefault(const Constant('currentTime'))();
  TextColumn get creationPresentation =>
      text().withDefault(const Constant('sheet'))();
  BoolColumn get quickEditEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showCompletedItems =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showCancelledItems =>
      boolean().withDefault(const Constant(false))();
  IntColumn get weekStartDay =>
      integer().withDefault(const Constant(DateTime.monday))();
  TextColumn get preferredPresentation =>
      text().withDefault(const Constant('day'))();
  BoolColumn get showEvents => boolean().withDefault(const Constant(true))();
  BoolColumn get showBackupEvents =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showTasks => boolean().withDefault(const Constant(true))();
  BoolColumn get showCompletedTasks =>
      boolean().withDefault(const Constant(false))();
  IntColumn get timelineHourHeight =>
      integer().withDefault(const Constant(60))();
  TextColumn get eventColorPreferencesJson => text().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{profileId};
}

@DriftDatabase(
  tables: <Type>[
    LocalProfiles,
    OnboardingCheckpoints,
    LifeIndicatorDefinitions,
    Goals,
    GoalActivities,
    GoalOutboxOperations,
    PrivacyPreferences,
    PermissionAudits,
    PlannerTasks,
    TaskStatusChanges,
    CalendarEvents,
    CalendarEventExceptions,
    CalendarEventOperations,
    TaskEventLinks,
    TaskEventLinkHistory,
    OutcomeReports,
    OutcomeReportContributionDrafts,
    ActivityLedgerEntries,
    WeeklyIndicatorTargetRevisions,
    IndicatorGoalRevisions,
    WeeklyPlans,
    ActivityTypes,
    ActivityTypeIndicatorMappings,
    PlannerPreferences,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase.defaults()
    : _schemaVersionOverride = null,
      _injectMigrationFailure = false,
      _injectTaskMigrationFailure = false,
      _injectCalendarEventMigrationFailure = false,
      _injectTaskEventLinkMigrationFailure = false,
      _injectOutcomeReportingMigrationFailure = false,
      _injectIndicatorMigrationFailure = false,
      _injectWeeklyPlanningMigrationFailure = false,
      _injectPlannerCorrectionMigrationFailure = false,
      _injectPlannerExperienceMigrationFailure = false,
      super(driftDatabase(name: 'next_transfer'));

  AppDatabase.forTesting(
    super.executor, {
    int? schemaVersionOverride,
    bool injectMigrationFailure = false,
    bool injectTaskMigrationFailure = false,
    bool injectCalendarEventMigrationFailure = false,
    bool injectTaskEventLinkMigrationFailure = false,
    bool injectOutcomeReportingMigrationFailure = false,
    bool injectIndicatorMigrationFailure = false,
    bool injectWeeklyPlanningMigrationFailure = false,
    bool injectPlannerCorrectionMigrationFailure = false,
    bool injectPlannerExperienceMigrationFailure = false,
  }) : _schemaVersionOverride = schemaVersionOverride,
       _injectMigrationFailure = injectMigrationFailure,
       _injectTaskMigrationFailure = injectTaskMigrationFailure,
       _injectCalendarEventMigrationFailure =
           injectCalendarEventMigrationFailure,
       _injectTaskEventLinkMigrationFailure =
           injectTaskEventLinkMigrationFailure,
       _injectOutcomeReportingMigrationFailure =
           injectOutcomeReportingMigrationFailure,
       _injectIndicatorMigrationFailure = injectIndicatorMigrationFailure,
       _injectWeeklyPlanningMigrationFailure =
           injectWeeklyPlanningMigrationFailure,
       _injectPlannerCorrectionMigrationFailure =
           injectPlannerCorrectionMigrationFailure,
       _injectPlannerExperienceMigrationFailure =
           injectPlannerExperienceMigrationFailure;

  final int? _schemaVersionOverride;
  final bool _injectMigrationFailure;
  final bool _injectTaskMigrationFailure;
  final bool _injectCalendarEventMigrationFailure;
  final bool _injectTaskEventLinkMigrationFailure;
  final bool _injectOutcomeReportingMigrationFailure;
  final bool _injectIndicatorMigrationFailure;
  final bool _injectWeeklyPlanningMigrationFailure;
  final bool _injectPlannerCorrectionMigrationFailure;
  final bool _injectPlannerExperienceMigrationFailure;

  @override
    int get schemaVersion => _schemaVersionOverride ?? 17;

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
        if (schemaVersion >= 6) {
          await migrator.createTable(outcomeReports);
          await migrator.createTable(outcomeReportContributionDrafts);
          await migrator.createTable(activityLedgerEntries);
        }
        if (schemaVersion >= 7) {
          await migrator.createTable(weeklyIndicatorTargetRevisions);
        }
        if (schemaVersion >= 8) {
          await migrator.createTable(weeklyPlans);
        }
        if (schemaVersion >= 9) {
          await migrator.createTable(activityTypes);
          await migrator.createTable(activityTypeIndicatorMappings);
          await migrator.createTable(plannerPreferences);
        }
        if (schemaVersion >= 17) {
          await migrator.createTable(goals);
          await migrator.createTable(goalActivities);
          await migrator.createTable(goalOutboxOperations);
        }
        if (schemaVersion >= 14) {
          await migrator.createTable(indicatorGoalRevisions);
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
          if (from < 6 && to >= 6) {
            await migrator.createTable(outcomeReports);
            await migrator.createTable(outcomeReportContributionDrafts);
            await migrator.createTable(activityLedgerEntries);
            if (_injectOutcomeReportingMigrationFailure) {
              throw StateError('Injected outcome reporting migration failure');
            }
          }
          if (from < 7 && to >= 7) {
            await migrator.createTable(weeklyIndicatorTargetRevisions);
            if (_injectIndicatorMigrationFailure) {
              throw StateError('Injected indicator migration failure');
            }
          }
          if (from < 8 && to >= 8) {
            if (!await _columnExists('local_profiles', 'time_zone_id')) {
              await migrator.addColumn(localProfiles, localProfiles.timeZoneId);
            }
            await migrator.createTable(weeklyPlans);
            if (_injectWeeklyPlanningMigrationFailure) {
              throw StateError('Injected weekly planning migration failure');
            }
          }
          if (from < 9 && to >= 9) {
            await migrator.createTable(activityTypes);
            await migrator.createTable(activityTypeIndicatorMappings);
            await migrator.createTable(plannerPreferences);
            if (!await _columnExists('calendar_events', 'activity_type_id')) {
              await migrator.addColumn(
                calendarEvents,
                calendarEvents.activityTypeId,
              );
            }
            if (!await _columnExists(
              'calendar_events',
              'activity_type_mapping_version',
            )) {
              await migrator.addColumn(
                calendarEvents,
                calendarEvents.activityTypeMappingVersion,
              );
            }
            if (!await _columnExists(
              'calendar_event_exceptions',
              'activity_type_id',
            )) {
              await migrator.addColumn(
                calendarEventExceptions,
                calendarEventExceptions.activityTypeId,
              );
            }
            if (!await _columnExists(
              'calendar_event_exceptions',
              'activity_type_mapping_version',
            )) {
              await migrator.addColumn(
                calendarEventExceptions,
                calendarEventExceptions.activityTypeMappingVersion,
              );
            }
            if (_injectPlannerCorrectionMigrationFailure) {
              throw StateError('Injected Planner correction migration failure');
            }
          }
          if (from < 10 && to >= 10) {
            if (!await _columnExists(
              'calendar_events',
              'is_backup_appointment',
            )) {
              await migrator.addColumn(
                calendarEvents,
                calendarEvents.isBackupAppointment,
              );
            }
            if (!await _columnExists(
              'calendar_events',
              'backup_for_event_id',
            )) {
              await migrator.addColumn(
                calendarEvents,
                calendarEvents.backupForEventId,
              );
            }
            if (!await _columnExists(
              'calendar_events',
              'backup_relationship_provenance',
            )) {
              await migrator.addColumn(
                calendarEvents,
                calendarEvents.backupRelationshipProvenance,
              );
            }
            if (!await _columnExists(
              'calendar_event_exceptions',
              'is_backup_appointment',
            )) {
              await migrator.addColumn(
                calendarEventExceptions,
                calendarEventExceptions.isBackupAppointment,
              );
            }
            if (!await _columnExists(
              'calendar_event_exceptions',
              'backup_for_event_id',
            )) {
              await migrator.addColumn(
                calendarEventExceptions,
                calendarEventExceptions.backupForEventId,
              );
            }
            if (!await _columnExists(
              'calendar_event_exceptions',
              'backup_relationship_provenance',
            )) {
              await migrator.addColumn(
                calendarEventExceptions,
                calendarEventExceptions.backupRelationshipProvenance,
              );
            }
            if (!await _columnExists(
              'planner_preferences',
              'preferred_presentation',
            )) {
              await migrator.addColumn(
                plannerPreferences,
                plannerPreferences.preferredPresentation,
              );
            }
            if (!await _columnExists('planner_preferences', 'show_events')) {
              await migrator.addColumn(
                plannerPreferences,
                plannerPreferences.showEvents,
              );
            }
            if (!await _columnExists(
              'planner_preferences',
              'show_backup_events',
            )) {
              await migrator.addColumn(
                plannerPreferences,
                plannerPreferences.showBackupEvents,
              );
            }
            if (!await _columnExists('planner_preferences', 'show_tasks')) {
              await migrator.addColumn(
                plannerPreferences,
                plannerPreferences.showTasks,
              );
            }
            if (!await _columnExists(
              'planner_preferences',
              'show_completed_tasks',
            )) {
              await migrator.addColumn(
                plannerPreferences,
                plannerPreferences.showCompletedTasks,
              );
            }
            if (!await _columnExists(
              'planner_preferences',
              'timeline_hour_height',
            )) {
              await migrator.addColumn(
                plannerPreferences,
                plannerPreferences.timelineHourHeight,
              );
            }
            if (_injectPlannerExperienceMigrationFailure) {
              throw StateError('Injected Planner experience migration failure');
            }
          }
          if (from < 11 && to >= 11) {
            if (!await _columnExists(
              'planner_preferences',
              'event_color_preferences_json',
            )) {
              await migrator.addColumn(
                plannerPreferences,
                plannerPreferences.eventColorPreferencesJson,
              );
            }
          }
          if (from < 12 && to >= 12) {
            if (!await _columnExists('planner_tasks', 'due_minute')) {
              await migrator.addColumn(plannerTasks, plannerTasks.dueMinute);
            }
            if (!await _columnExists('planner_tasks', 'recurrence_frequency')) {
              await migrator.addColumn(
                plannerTasks,
                plannerTasks.recurrenceFrequency,
              );
            }
          }
          if (from < 13 && to >= 13) {
            if (!await _columnExists('planner_tasks', 'people_json')) {
              await migrator.addColumn(plannerTasks, plannerTasks.peopleJson);
            }
          }
          if (from < 14 && to >= 14) {
            await migrator.createTable(indicatorGoalRevisions);
          }
          if (from < 15 && to >= 15) {
            // Promote legacy weekly revisions into the canonical goal table.
            // IDs and operation IDs are retained so idempotency and revision
            // chains survive the migration without creating a second write.
            await customStatement('''
              INSERT OR IGNORE INTO indicator_goal_revisions
                (id, profile_id, indicator_key, period_type,
                 period_start_date, period_end_date, state, value_scaled,
                 value_scale, unit, supersedes_revision_id, operation_id,
                 created_at_utc)
              SELECT id, profile_id, indicator_key, 'weekly',
                     period_start_date,
                     date(period_start_date, '+6 days'),
                     state, value_scaled, value_scale, unit,
                     supersedes_revision_id, operation_id, created_at_utc
              FROM weekly_indicator_target_revisions
            ''');
          }
          if (from < 16 && to >= 16) {
            // Prompt A removes the legacy Commitment feature.  These tables
            // contain only links/review/carryover metadata; the canonical
            // Event, Task, report, ledger, and goal tables remain untouched.
            for (final tableName in <String>[
              'indicator_commitment_links',
              'weekly_plan_commitments',
              'weekly_plan_review_indicator_snapshots',
              'weekly_plan_reviews',
              'weekly_plan_task_carryover_decisions',
            ]) {
              await customStatement('DROP TABLE IF EXISTS $tableName');
            }
          }
          if (from < 17 && to >= 17) {
            await migrator.createTable(goals);
            await migrator.createTable(goalActivities);
            await migrator.createTable(goalOutboxOperations);
            if (!await _columnExists(
              'weekly_indicator_target_revisions',
              'goal_id',
            )) {
              await migrator.addColumn(
                weeklyIndicatorTargetRevisions,
                weeklyIndicatorTargetRevisions.goalId,
              );
            }
            if (!await _columnExists('indicator_goal_revisions', 'goal_id')) {
              await migrator.addColumn(
                indicatorGoalRevisions,
                indicatorGoalRevisions.goalId,
              );
            }

            // The six seeded WLI definitions are the only pre-canonical Goal
            // records.  Their IDs are deterministic, so reopening a partially
            // migrated database cannot create duplicate Goals.
            await customStatement('''
              INSERT OR IGNORE INTO goals
                (id, profile_id, indicator_key, role, active_slot_index,
                 title, icon_id, status, created_at_utc, updated_at_utc,
                 archived_at_utc)
              SELECT profile_id || ':goal:' || (position + 1),
                     profile_id,
                     indicator_key,
                     CASE position
                       WHEN 0 THEN 'dailyWeekly'
                       WHEN 5 THEN 'weeklyMonthly'
                       ELSE 'weekly'
                     END,
                     position + 1,
                     CASE
                       WHEN position = 3 AND label = 'Meaningful Connections'
                         THEN 'Ministering Visit'
                       ELSE label
                     END,
                     NULL,
                     'active',
                     created_at_utc,
                     created_at_utc,
                     NULL
                FROM life_indicator_definitions
            ''');
            await customStatement('''
              UPDATE life_indicator_definitions
                 SET label = 'Ministering Visit'
               WHERE indicator_key = 'meaningful_connections'
                 AND position = 3
                 AND label = 'Meaningful Connections'
            ''');
            await customStatement('''
              UPDATE indicator_goal_revisions
                 SET goal_id = (
                   SELECT g.id
                     FROM goals g
                    WHERE g.profile_id = indicator_goal_revisions.profile_id
                      AND g.indicator_key = indicator_goal_revisions.indicator_key
                    LIMIT 1
                 )
               WHERE goal_id IS NULL
            ''');
            await customStatement('''
              UPDATE weekly_indicator_target_revisions
                 SET goal_id = (
                   SELECT g.id
                     FROM goals g
                    WHERE g.profile_id = weekly_indicator_target_revisions.profile_id
                      AND g.indicator_key = weekly_indicator_target_revisions.indicator_key
                    LIMIT 1
                 )
              WHERE goal_id IS NULL
            ''');
            await customStatement('''
              INSERT OR IGNORE INTO goal_activities
                (id, profile_id, goal_id, operation_id, action,
                 previous_value, new_value, occurred_at_utc)
              SELECT profile_id || ':goal:' || (position + 1) || ':created',
                     profile_id,
                     profile_id || ':goal:' || (position + 1),
                     profile_id || ':goal:' || (position + 1) || ':created',
                     'created',
                     NULL,
                     CASE
                       WHEN position = 3 AND label = 'Meaningful Connections'
                         THEN 'Ministering Visit'
                       ELSE label
                     END,
                     created_at_utc
                FROM life_indicator_definitions
            ''');
            await customStatement('''
              INSERT OR IGNORE INTO goal_outbox_operations
                (operation_id, profile_id, entity_type, entity_id, action,
                 payload_json, created_at_utc)
              SELECT profile_id || ':goal:' || (position + 1) || ':created',
                     profile_id,
                     'goal',
                     profile_id || ':goal:' || (position + 1),
                     'created',
                     json_object(
                       'goalId', profile_id || ':goal:' || (position + 1),
                       'role', CASE
                         WHEN position = 0 THEN 'dailyWeekly'
                         WHEN position = 5 THEN 'weeklyMonthly'
                         ELSE 'weekly'
                       END,
                       'slot', position + 1,
                       'title', CASE
                         WHEN position = 3 AND label = 'Meaningful Connections'
                           THEN 'Ministering Visit'
                         ELSE label
                       END,
                       'iconId', NULL
                     ),
                     created_at_utc
                FROM life_indicator_definitions
            ''');
          }
        });
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.any((row) => row.read<String>('name') == columnName);
  }
}

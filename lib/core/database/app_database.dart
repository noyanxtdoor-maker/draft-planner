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
  TextColumn get activityTypeId => text().nullable()();
  IntColumn get activityTypeMappingVersion => integer().nullable()();
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
  TextColumn get activityTypeId => text().nullable()();
  IntColumn get activityTypeMappingVersion => integer().nullable()();
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
  name: 'weekly_plan_commitment_unique',
  columns: <Symbol>{#planId, #commitmentKey},
  unique: true,
)
@DataClassName('WeeklyPlanCommitmentRow')
class WeeklyPlanCommitments extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get planId =>
      text().references(WeeklyPlans, #id, onDelete: KeyAction.restrict)();
  TextColumn get commitmentKey => text()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  TextColumn get occurrenceId => text().nullable()();
  DateTimeColumn get addedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'weekly_plan_review_plan_unique',
  columns: <Symbol>{#planId},
  unique: true,
)
@TableIndex(
  name: 'weekly_plan_review_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@DataClassName('WeeklyPlanReviewRow')
class WeeklyPlanReviews extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get planId =>
      text().references(WeeklyPlans, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get privateReflection => text().nullable()();
  BoolColumn get unresolvedReportsAcknowledged => boolean()();
  DateTimeColumn get completedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'weekly_plan_review_indicator_unique',
  columns: <Symbol>{#reviewId, #indicatorKey},
  unique: true,
)
@DataClassName('WeeklyPlanReviewIndicatorSnapshotRow')
class WeeklyPlanReviewIndicatorSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get reviewId =>
      text().references(WeeklyPlanReviews, #id, onDelete: KeyAction.restrict)();
  TextColumn get indicatorKey => text()();
  IntColumn get actualValueScaled => integer()();
  IntColumn get actualValueScale => integer()();
  TextColumn get actualUnit => text()();
  TextColumn get targetState => text()();
  IntColumn get targetValueScaled => integer().nullable()();
  IntColumn get targetValueScale => integer()();
  TextColumn get targetUnit => text()();
  IntColumn get scheduledValueScaled => integer()();
  IntColumn get scheduledValueScale => integer()();
  TextColumn get scheduledUnit => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'weekly_plan_carryover_operation_unique',
  columns: <Symbol>{#operationId},
  unique: true,
)
@TableIndex(
  name: 'weekly_plan_carryover_task_unique',
  columns: <Symbol>{#fromPlanId, #taskId},
  unique: true,
)
@DataClassName('WeeklyPlanTaskCarryoverDecisionRow')
class WeeklyPlanTaskCarryoverDecisions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  @ReferenceName('carryoverSourcePlan')
  TextColumn get fromPlanId =>
      text().references(WeeklyPlans, #id, onDelete: KeyAction.restrict)();
  TextColumn get taskId =>
      text().references(PlannerTasks, #id, onDelete: KeyAction.restrict)();
  TextColumn get decision => text()();
  @ReferenceName('carryoverDestinationPlan')
  TextColumn get toPlanId => text().nullable().references(
    WeeklyPlans,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get operationId => text()();
  DateTimeColumn get decidedAtUtc => dateTime()();

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
      text().withDefault(const Constant('fullScreen'))();
  BoolColumn get quickEditEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showCompletedItems =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showCancelledItems =>
      boolean().withDefault(const Constant(false))();
  IntColumn get weekStartDay =>
      integer().withDefault(const Constant(DateTime.monday))();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{profileId};
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
    OutcomeReports,
    OutcomeReportContributionDrafts,
    ActivityLedgerEntries,
    WeeklyIndicatorTargetRevisions,
    WeeklyPlans,
    WeeklyPlanCommitments,
    WeeklyPlanReviews,
    WeeklyPlanReviewIndicatorSnapshots,
    WeeklyPlanTaskCarryoverDecisions,
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
           injectPlannerCorrectionMigrationFailure;

  final int? _schemaVersionOverride;
  final bool _injectMigrationFailure;
  final bool _injectTaskMigrationFailure;
  final bool _injectCalendarEventMigrationFailure;
  final bool _injectTaskEventLinkMigrationFailure;
  final bool _injectOutcomeReportingMigrationFailure;
  final bool _injectIndicatorMigrationFailure;
  final bool _injectWeeklyPlanningMigrationFailure;
  final bool _injectPlannerCorrectionMigrationFailure;

  @override
  int get schemaVersion => _schemaVersionOverride ?? 9;

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
          await migrator.createTable(weeklyPlanCommitments);
          await migrator.createTable(weeklyPlanReviews);
          await migrator.createTable(weeklyPlanReviewIndicatorSnapshots);
          await migrator.createTable(weeklyPlanTaskCarryoverDecisions);
        }
        if (schemaVersion >= 9) {
          await migrator.createTable(activityTypes);
          await migrator.createTable(activityTypeIndicatorMappings);
          await migrator.createTable(plannerPreferences);
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
            await migrator.createTable(weeklyPlanCommitments);
            await migrator.createTable(weeklyPlanReviews);
            await migrator.createTable(weeklyPlanReviewIndicatorSnapshots);
            await migrator.createTable(weeklyPlanTaskCarryoverDecisions);
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

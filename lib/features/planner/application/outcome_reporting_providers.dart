import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final outcomeReportingRepositoryProvider = Provider<OutcomeReportingRepository>(
  (ref) {
    throw StateError(
      'OutcomeReportingRepository must be overridden at the app root',
    );
  },
);

final outcomeReportingControllerProvider =
    NotifierProvider<OutcomeReportingController, String?>(
      OutcomeReportingController.new,
    );

final class OutcomeReportingController extends Notifier<String?> {
  OutcomeReportingRepository get _repository =>
      ref.read(outcomeReportingRepositoryProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Outcome reporting requires a ready Local Profile');
    }
    return startup.profile.id;
  }

  @override
  String? build() => null;

  Future<OutcomeReportSource?> readTaskSource(String taskId) {
    return _repository.readTaskSource(profileId: _profileId, taskId: taskId);
  }

  Future<OutcomeReportSource?> readEventSource({
    required String eventId,
    required PlannerDate originalDate,
  }) {
    return _repository.readEventSource(
      profileId: _profileId,
      eventId: eventId,
      originalDate: originalDate,
    );
  }

  Future<List<IndicatorOption>> readIndicatorOptions() {
    return _repository.readIndicatorOptions(_profileId);
  }

  Future<OutcomeReport?> readDraft(String sourceSlotKey) {
    return _repository.readDraftForSlot(
      profileId: _profileId,
      sourceSlotKey: sourceSlotKey,
    );
  }

  Future<OutcomeReport?> readReport(String reportId) {
    return _repository.readReport(profileId: _profileId, reportId: reportId);
  }

  Future<List<OutcomeReport>> readHistory() {
    return _repository.readReportHistory(_profileId);
  }

  Future<List<ActivityLedgerEntry>> readLedgerHistory({
    bool effectiveOnly = true,
  }) {
    return _repository.readLedgerHistory(
      profileId: _profileId,
      effectiveOnly: effectiveOnly,
    );
  }

  Future<OutcomeReport?> saveDraft(OutcomeReportDraft draft) async {
    try {
      final saved = await _repository.saveDraft(
        profileId: _profileId,
        draft: draft,
      );
      state = 'Draft saved locally';
      return saved;
    } on OutcomeReportValidationException catch (error) {
      state = error.message;
      return null;
    } on Object {
      state = 'Draft could not be saved. Your input remains available.';
      return null;
    }
  }

  Future<ReportSubmissionResult?> submit({
    required OutcomeReportDraft draft,
    required String operationId,
  }) async {
    try {
      final result = await _repository.submit(
        profileId: _profileId,
        draft: draft,
        operationId: operationId,
      );
      final planner = ref.read(plannerControllerProvider.notifier);
      await planner.selectDate(
        ref.read(plannerControllerProvider).selectedDate,
      );
      state = result.unchanged
          ? 'This report was already submitted.'
          : 'Report submitted locally';
      return result;
    } on OutcomeReportValidationException catch (error) {
      state = error.message;
      return null;
    } on Object {
      state =
          'Report was not submitted. No partial completion or contribution '
          'was saved.';
      return null;
    }
  }

  /// Persists an Event's selected Current Status without opening a report
  /// form. The repository submission remains the single transactional write
  /// path, so history, ledger contributions, and planner refresh stay coupled
  /// and idempotent.
  Future<ReportSubmissionResult?> submitEventStatus({
    required String eventId,
    required PlannerDate originalDate,
    required OutcomeKind outcome,
    required String operationId,
    String? contributionRuleKey,
  }) async {
    try {
      final source = await readEventSource(
        eventId: eventId,
        originalDate: originalDate,
      );
      if (source == null) {
        state = 'This Calendar Event is no longer available.';
        return null;
      }

      final current = (await readHistory())
          .where(
            (report) =>
                report.status == OutcomeReportStatus.submitted &&
                report.source.slotKey == source.slotKey,
          )
          .firstOrNull;
      if (current?.outcome == outcome) {
        final entries = (await readLedgerHistory(effectiveOnly: false))
            .where((entry) => entry.sourceReportId == current!.id)
            .toList(growable: false);
        state = 'Status already saved locally.';
        return ReportSubmissionResult(
          report: current!,
          entries: entries,
          unchanged: true,
        );
      }

      final draft = await readDraft(source.slotKey);
      final rule = ScheduledPotentialRule.tryParse(contributionRuleKey);
      final contributions = outcome == OutcomeKind.didNotHappen || rule == null
          ? const <ContributionDraft>[]
          : <ContributionDraft>[
              ContributionDraft(
                ruleKey: rule.encode(),
                indicatorKey: rule.indicatorKey,
                value: IndicatorValue(
                  scaledValue: rule.value.scaledValue,
                  scale: rule.value.scale,
                  unit: rule.value.unit,
                ),
              ),
            ];
      final result = await submit(
        draft: OutcomeReportDraft(
          id: draft?.id ?? ref.read(plannerIdentifierSourceProvider).nextUuid(),
          source: source,
          activityDate: source.activityDate,
          outcome: outcome,
          correctsReportId: current?.id,
          correctionReason: current == null
              ? null
              : 'Current Status corrected directly.',
          contributions: contributions,
          allowUnstructuredPartial: true,
        ),
        operationId: operationId,
      );
      if (result != null) {
        state = result.unchanged
            ? 'Status already saved locally.'
            : 'Status saved locally.';
      }
      return result;
    } on OutcomeReportValidationException catch (error) {
      state = error.message;
      return null;
    } on Object {
      state =
          'Status was not saved. No partial completion or contribution '
          'was recorded.';
      return null;
    }
  }

  void clearMessage() {
    state = null;
  }
}

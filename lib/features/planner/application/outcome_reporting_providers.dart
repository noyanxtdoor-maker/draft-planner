import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void clearMessage() {
    state = null;
  }
}

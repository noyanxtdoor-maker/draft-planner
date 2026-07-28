import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  throw StateError('PlannerRepository must be overridden at the app root');
});

final plannerDateSourceProvider = Provider<PlannerDateSource>((ref) {
  return const SystemPlannerDateSource();
});

final plannerIdentifierSourceProvider = Provider<IdentifierSource>((ref) {
  return const UuidIdentifierSource();
});

enum PlannerLoadStatus { loading, ready, failure }

final class PlannerState {
  const PlannerState({
    required this.status,
    required this.selectedDate,
    required this.historicalItemsExpanded,
    this.day,
    this.message,
  });

  final PlannerLoadStatus status;
  final PlannerDate selectedDate;
  final PlannerDay? day;
  final bool historicalItemsExpanded;
  final String? message;

  PlannerState copyWith({
    PlannerLoadStatus? status,
    PlannerDate? selectedDate,
    PlannerDay? day,
    bool? historicalItemsExpanded,
    String? message,
    bool clearMessage = false,
  }) {
    return PlannerState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      day: day ?? this.day,
      historicalItemsExpanded:
          historicalItemsExpanded ?? this.historicalItemsExpanded,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final plannerControllerProvider =
    NotifierProvider<PlannerController, PlannerState>(PlannerController.new);

final class PlannerController extends Notifier<PlannerState> {
  PlannerRepository get _repository => ref.read(plannerRepositoryProvider);
  PlannerDateSource get _dateSource => ref.read(plannerDateSourceProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Planner requires a ready Local Profile');
    }
    return startup.profile.id;
  }

  @override
  PlannerState build() {
    final today = _dateSource.today();
    unawaited(Future<void>.microtask(() => _load(today)));
    return PlannerState(
      status: PlannerLoadStatus.loading,
      selectedDate: today,
      historicalItemsExpanded: true,
    );
  }

  Future<void> selectDate(PlannerDate date) => _load(date);

  Future<void> moveDays(int days) => _load(state.selectedDate.addDays(days));

  void toggleHistoricalItems() {
    state = state.copyWith(
      historicalItemsExpanded: !state.historicalItemsExpanded,
    );
  }

  Future<PlannerTask?> readTask(String taskId) {
    return _repository.readTask(profileId: _profileId, taskId: taskId);
  }

  Future<bool> saveTask(PlannerTaskDraft draft) async {
    try {
      await _repository.saveTask(profileId: _profileId, draft: draft);
      await _load(state.selectedDate);
      return true;
    } on PlannerTaskValidationException catch (error) {
      state = state.copyWith(message: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        message:
            'Task could not be saved. Your input remains available to retry.',
      );
      return false;
    }
  }

  Future<TaskStatusChangeOutcome> changeStatus({
    required String taskId,
    required PlannerTaskStatus target,
    required String operationId,
    String? reason,
  }) async {
    try {
      final outcome = await _repository.changeTaskStatus(
        profileId: _profileId,
        taskId: taskId,
        target: target,
        operationId: operationId,
        reason: reason,
      );
      await _load(state.selectedDate);
      state = state.copyWith(
        message: switch (outcome) {
          TaskStatusChangeOutcome.reportRequired =>
            'This Task stays Incomplete until its required report and '
                'completion can save together.',
          TaskStatusChangeOutcome.correctionRequired =>
            'This status has historical effects and must use a correction.',
          TaskStatusChangeOutcome.changed ||
          TaskStatusChangeOutcome.unchanged => null,
        },
        clearMessage:
            outcome == TaskStatusChangeOutcome.changed ||
            outcome == TaskStatusChangeOutcome.unchanged,
      );
      return outcome;
    } on Object {
      state = state.copyWith(
        message: 'Task status was not changed. You can safely retry.',
      );
      return TaskStatusChangeOutcome.unchanged;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> _load(PlannerDate date) async {
    state = state.copyWith(
      status: PlannerLoadStatus.loading,
      selectedDate: date,
      clearMessage: true,
    );
    try {
      final day = await _repository.readDay(
        profileId: _profileId,
        selectedDate: date,
        today: _dateSource.today(),
      );
      state = state.copyWith(
        status: PlannerLoadStatus.ready,
        selectedDate: date,
        day: day,
        clearMessage: true,
      );
    } on Object {
      state = state.copyWith(
        status: PlannerLoadStatus.failure,
        selectedDate: date,
        message: 'Planner data could not be opened. Retry without data loss.',
      );
    }
  }
}

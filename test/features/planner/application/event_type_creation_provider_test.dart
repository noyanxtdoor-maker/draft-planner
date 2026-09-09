import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/application/goal_repository.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/domain/goal_event_type_policy.dart';
import 'package:rmplanner/features/planner/application/event_type_creation_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/event_type_creation_choice.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/application/startup_repository.dart';
import 'package:rmplanner/features/startup/domain/local_profile.dart';
import 'package:rmplanner/features/startup/domain/onboarding_checkpoint.dart';
import 'package:rmplanner/features/startup/domain/startup_snapshot.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

/// Controlled startup: resolveStartup returns a ready profile snapshot whose
/// id can be switched to emulate a profile A -> B transition.
final class _ControlledStartupRepository implements StartupRepository {
  _ControlledStartupRepository(this.profileId);

  String profileId;
  int resolveCalls = 0;

  LocalProfile _profile(String id) => LocalProfile(
    id: id,
    localName: 'Local Profile',
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
  );

  @override
  Future<StartupSnapshot> resolveStartup() async {
    resolveCalls += 1;
    return StartupSnapshot(
      profile: _profile(profileId),
      accountSessionState: AccountSessionState.localOnly,
      syncState: LocalSyncState.notConfigured,
      unlockRequired: false,
    );
  }

  @override
  Future<OnboardingCheckpoint> beginOrResumeOnboarding() async {
    throw UnimplementedError();
  }

  @override
  Future<OnboardingCheckpoint> saveOnboardingDraft(String? displayName) async {
    throw UnimplementedError();
  }

  @override
  Future<LocalProfile> completeOnboarding() async => _profile(profileId);

  @override
  Future<LocalProfile> updateDisplayName(String? displayName) async =>
      _profile(profileId);
}

/// Controlled Event Type source: readEventTypes can be held open (loading),
/// failed (error), and its list mutated between loads. All historical rows
/// are always retained in the returned raw list.
final class _ControlledEventTypeRepository implements EventTypeRepository {
  final Completer<void> _gate = Completer<void>();

  Object? readError;
  List<EventType> types = <EventType>[];
  int readEventTypesCalls = 0;

  void release() {
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  @override
  Future<List<EventType>> readEventTypes({
    required String profileId,
    bool includeArchived = false,
  }) async {
    readEventTypesCalls += 1;
    final error = readError;
    if (error != null) {
      throw error;
    }
    await _gate.future;
    return List<EventType>.of(types);
  }

  @override
  Future<EventType?> readEventType({
    required String profileId,
    required String eventTypeId,
  }) async => null;

  @override
  Future<EventType?> readExactTypeForIndicator({
    required String profileId,
    required String indicatorKey,
  }) async => null;

  @override
  Future<EventType> saveCustomType({
    required String profileId,
    required EventTypeDraft draft,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> renameSystemType({
    required String profileId,
    required String eventTypeId,
    required String label,
  }) async {}

  @override
  Future<void> setCustomTypeArchived({
    required String profileId,
    required String eventTypeId,
    required bool archived,
  }) async {}

  @override
  Future<void> restoreSystemDefaults({required String profileId}) async {}

  @override
  Future<PlannerSettings> readPlannerSettings({
    required String profileId,
  }) async => PlannerSettings.defaults();

  @override
  Future<PlannerSettings> savePlannerSettings({
    required String profileId,
    required PlannerSettings settings,
  }) async => settings;

  @override
  Future<Map<String, EventColorPreference>> readEventColorPreferences({
    required String profileId,
  }) async => const <String, EventColorPreference>{};

  @override
  Future<Map<String, EventColorPreference>> saveEventColorPreference({
    required String profileId,
    required String eventTypeStableKey,
    required EventColorPreference preference,
  }) async => const <String, EventColorPreference>{};

  @override
  Future<Map<String, EventColorPreference>> restoreEventColorDefaults({
    required String profileId,
  }) async => const <String, EventColorPreference>{};

  @override
  Future<Map<String, int>> readContactGroupColors({
    required String profileId,
  }) async => const <String, int>{};

  @override
  Future<Map<String, int>> saveContactGroupColor({
    required String profileId,
    required String groupId,
    required int colorArgb,
  }) async => const <String, int>{};

  @override
  Future<Map<String, int>> restoreContactGroupColorDefaults({
    required String profileId,
  }) async => const <String, int>{};
}

/// Controlled Goal repository: only watchChanges + readLiveEventTypeBindings
/// are meaningful; the bindings map is mutated by the test between stream
/// generations to emulate create/rename/archive/restore.
final class _ControlledGoalRepository implements GoalRepository {
  _ControlledGoalRepository();

  final StreamController<int> _changes =
      StreamController<int>.broadcast();
  int _generation = 0;
  Map<int, LiveGoalEventTypeBinding> bindings =
      const <int, LiveGoalEventTypeBinding>{};
  int readBindingsCalls = 0;

  /// Replays the last generation to new listeners (mirroring the Drift
  /// tableUpdates behavior the production repository guarantees) so a
  /// provider subscribing "later" still sees the current generation.
  void emitChange() {
    _generation += 1;
    _changes.add(_generation);
  }

  @override
  Stream<int> watchChanges(String profileId) async* {
    yield _generation;
    yield* _changes.stream;
  }

  @override
  Future<Map<int, LiveGoalEventTypeBinding>> readLiveEventTypeBindings(
    String profileId,
  ) async {
    readBindingsCalls += 1;
    return bindings;
  }

  @override
  Future<void> ensureCanonicalGoals(String profileId) async {}

  @override
  Future<List<Goal>> readActiveGoals(String profileId) async =>
      const <Goal>[];

  @override
  Future<Goal?> readGoal({
    required String profileId,
    required String goalId,
  }) async => null;

  @override
  Future<GoalCapacity> readCapacity(String profileId) async =>
      const GoalCapacity(activeByRole: <GoalRole, int>{});

  @override
  Future<int?> nextAvailableSlot({
    required String profileId,
    required GoalRole role,
  }) async => null;

  @override
  Future<Goal> createGoal({
    required String profileId,
    required GoalRole role,
    required String title,
    required GoalTargets targets,
    String? indicatorKey,
    String? iconId,
    String? operationId,
    int? expectedSlotIndex,
    int startDay = DateTime.monday,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Goal> saveGoal({
    required String profileId,
    required String goalId,
    required String title,
    required GoalTargets targets,
    String? iconId,
    String? operationId,
    PlannerDate? today,
    int startDay = DateTime.monday,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> archiveGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  }) async {}

  @override
  Future<Goal> restoreGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  }) async {}

  @override
  Future<List<Goal>> readArchivedGoals({
    required String profileId,
    String? query,
  }) async => const <Goal>[];

  @override
  Future<List<GoalActivityHistoryItem>> readActivityHistory(
    String profileId, {
    String? goalId,
  }) async => const <GoalActivityHistoryItem>[];

  @override
  Future<Map<String, Object?>> exportGoalBackup(String profileId) async =>
      const <String, Object?>{};

  @override
  Future<void> importGoalBackup({
    required String profileId,
    required Map<String, Object?> backup,
  }) async {}

  @override
  Future<Map<String, Object?>> exportBackup(String profileId) async =>
      const <String, Object?>{};

  @override
  Future<void> importBackup({
    required String profileId,
    required Map<String, Object?> backup,
  }) async {}

  @override
  Future<GoalPlanningSnapshot> readPlanning({
    required String profileId,
    required PlannerDate periodStart,
    PlannerDate? today,
    int startDay = DateTime.monday,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GoalProgress?> readProgress({
    required String profileId,
    required String goalId,
    required PlannerDate today,
    int startDay = DateTime.monday,
  }) async => null;
}

EventType _type(
  String stableKey, {
  String? id,
  String? label,
  bool isArchived = false,
  bool isSystem = true,
  String? indicatorKey,
  int position = 0,
}) {
  final slot = CanonicalGoalSlot.tryByEventTypeKey(stableKey);
  return EventType(
    id: id ?? slot?.eventTypeId ?? 'id-$stableKey',
    stableKey: stableKey,
    label: label ?? slot?.defaultTitle ?? stableKey,
    icon: EventTypeIcon.calendar,
    colorValue: 0xFF868A8D,
    isSystem: isSystem,
    isArchived: isArchived,
    reportRequiredDefault: false,
    defaultDurationMinutes: 60,
    position: position,
    mappingVersion: 1,
    indicatorKeys: <String>{?indicatorKey},
  );
}

Future<void> _settleUntil(
  bool Function() condition, {
  required String description,
}) async {
  for (var turn = 0; turn < 100; turn += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out while waiting for $description');
}

Future<void> _bootStartup(ProviderContainer container) async {
  container.read(startupControllerProvider);
  await _settleUntil(
    () => container.read(startupControllerProvider) is StartupReady,
    description: 'StartupReady',
  );
}

Future<void> _settleRawEventTypes(ProviderContainer container) async {
  container.read(eventTypeControllerProvider);
  await _settleUntil(
    () => !container.read(eventTypeControllerProvider).isLoading,
    description: 'the raw Event Type controller',
  );
}

void main() {
  late _ControlledStartupRepository startupRepo;
  late _ControlledEventTypeRepository typeRepo;
  late _ControlledGoalRepository goalRepo;

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        startupRepositoryProvider.overrideWithValue(startupRepo),
        diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
        eventTypeRepositoryProvider.overrideWithValue(typeRepo),
        goalRepositoryProvider.overrideWithValue(goalRepo),
      ],
    );
  }

  setUp(() {
    startupRepo = _ControlledStartupRepository('profile-a');
    typeRepo = _ControlledEventTypeRepository();
    goalRepo = _ControlledGoalRepository();
    typeRepo.types = <EventType>[
      _type('job_application', indicatorKey: 'job_applications', position: 0),
      _type('scripture_study', indicatorKey: 'scripture_study', position: 1),
      _type('exercise', indicatorKey: 'exercise', position: 2),
      _type('budget_review', indicatorKey: 'budget_review', position: 3),
      _type(
        'meaningful_connection',
        indicatorKey: 'meaningful_connections',
        position: 4,
      ),
      _type('temple_visit', indicatorKey: 'temple_visit', position: 5),
      _type('education', label: 'Education', position: 6),
      _type('other', position: 13),
      // Historical rows that must stay in the RAW state but never appear in
      // creation choices: a legacy system row and an archived custom row.
      _type('general', id: 'legacy-general', position: 90),
      _type(
        'custom_archived',
        id: 'custom-archived-1',
        isSystem: false,
        isArchived: true,
        position: 91,
      ),
      _type(
        'goal:legacy-goal-id',
        id: 'goal:legacy-goal-id',
        isSystem: false,
        position: 92,
      ),
    ];
  });

  test('loading inputs keep choices disabled (retry restores them)', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    await _bootStartup(container);
    container.read(eventTypeControllerProvider);
    await container.read(
      liveGoalEventTypeBindingsProvider('profile-a').future,
    );
    final choicesSubscription = container.listen(
      eventTypeCreationChoicesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(choicesSubscription.close);

    // First read: startup is ready but the raw controller is still awaiting
    // the repository gate, so choices fail closed instead of exposing stale
    // or all-six data.
    await _settleUntil(
      () => container.read(eventTypeCreationChoicesProvider).hasError,
      description: 'the fail-closed loading state',
    );
    final loadingState = container.read(eventTypeCreationChoicesProvider);
    expect(loadingState.error, isNot(isA<StateError>()));
    expect(loadingState.error.toString(), contains('still loading'));

    typeRepo.release();
    await _settleRawEventTypes(container);

    // Raw historical retention law: once the gate opens, the raw controller
    // still retains legacy and archived rows outside the creation projection.
    final raw = container.read(eventTypeControllerProvider);
    expect(raw.eventTypes.map((t) => t.stableKey),
        containsAll(<String>['general', 'custom_archived', 'education']));

    // Retry restores data: hidden/eligible projection now resolves.
    goalRepo.bindings = <int, LiveGoalEventTypeBinding>{
      1: const LiveGoalEventTypeBinding(
        profileId: 'profile-a',
        goalId: 'goal-a',
        slotIndex: 1,
        title: 'Alias One',
      ),
    };
    goalRepo.emitChange();
    await _settleUntil(
      () => goalRepo.readBindingsCalls >= 2,
      description: 'choices to refresh after the Goal change',
    );
    final choices = await container.read(eventTypeCreationChoicesProvider.future);
    expect(choices, hasLength(3));
    final job = choices
        .singleWhere((c) => c.type.stableKey == 'job_application');
    expect(job.displayLabel, 'Alias One');
    final education = choices
        .singleWhere((c) => c.type.stableKey == 'education');
    expect(education.displayLabel, 'Education');
    // Raw state untouched by the projection.
    expect(
      container.read(eventTypeControllerProvider).eventTypes,
      hasLength(typeRepo.types.length),
    );
  });

  test('repository error surfaces as a hard failure, never a stale list',
      () async {
    typeRepo.readError = StateError('db closed');
    final container = buildContainer();
    addTearDown(container.dispose);
    await _bootStartup(container);
    await _settleRawEventTypes(container);
    final choicesSubscription = container.listen(
      eventTypeCreationChoicesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(choicesSubscription.close);
    await expectLater(
      container.read(eventTypeCreationChoicesProvider.future),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        'Planner settings could not be opened. Retry without data loss.',
      )),
    );
  });

  test('successive Goal stream generations refresh choices', () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    typeRepo.release();
    await _bootStartup(container);
    await _settleRawEventTypes(container);
    final choicesSubscription = container.listen(
      eventTypeCreationChoicesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(choicesSubscription.close);

    // Establish the provider and its Goal-change subscription while the slot
    // is empty; later generations must refresh this live projection.
    await container.read(eventTypeCreationChoicesProvider.future);

    Future<List<EventTypeCreationChoice>> refreshChoices() async {
      final previousReads = goalRepo.readBindingsCalls;
      goalRepo.emitChange();
      await _settleUntil(
        () => goalRepo.readBindingsCalls > previousReads,
        description: 'the next Goal binding generation',
      );
      return container.read(eventTypeCreationChoicesProvider.future);
    }

    // Generation 1: create (slot 1 bound).
    goalRepo.bindings = <int, LiveGoalEventTypeBinding>{
      1: const LiveGoalEventTypeBinding(
        profileId: 'profile-a',
        goalId: 'goal-a',
        slotIndex: 1,
        title: 'Created Goal',
      ),
    };
    final created = await refreshChoices();
    expect(
      created
          .singleWhere((c) => c.type.stableKey == 'job_application')
          .displayLabel,
      'Created Goal',
    );

    // Generation 2: rename (same slot, new alias).
    goalRepo.bindings = <int, LiveGoalEventTypeBinding>{
      1: const LiveGoalEventTypeBinding(
        profileId: 'profile-a',
        goalId: 'goal-a',
        slotIndex: 1,
        title: 'Renamed Goal',
      ),
    };
    final renamed = await refreshChoices();
    expect(
      renamed
          .singleWhere((c) => c.type.stableKey == 'job_application')
          .displayLabel,
      'Renamed Goal',
    );

    // Generation 3: archive (slot empty, canonical choice disappears).
    goalRepo.bindings = const <int, LiveGoalEventTypeBinding>{};
    final archived = await refreshChoices();
    expect(
      archived.where((c) => c.type.stableKey == 'job_application'),
      isEmpty,
    );

    // Generation 4: restore/reoccupation (alias returns).
    goalRepo.bindings = <int, LiveGoalEventTypeBinding>{
      1: const LiveGoalEventTypeBinding(
        profileId: 'profile-a',
        goalId: 'goal-b',
        slotIndex: 1,
        title: 'Reoccupied Goal',
      ),
    };
    final restored = await refreshChoices();
    expect(
      restored
          .singleWhere((c) => c.type.stableKey == 'job_application')
          .displayLabel,
      'Reoccupied Goal',
    );
    expect(goalRepo.readBindingsCalls, greaterThanOrEqualTo(4),
        reason: 'every stream generation rereads raw bindings');
  });

  test('profile A -> B discards A bindings without stale reuse', () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    typeRepo.release();
    await _bootStartup(container);
    await _settleRawEventTypes(container);
    final choicesSubscription = container.listen(
      eventTypeCreationChoicesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(choicesSubscription.close);
    goalRepo.bindings = <int, LiveGoalEventTypeBinding>{
      1: const LiveGoalEventTypeBinding(
        profileId: 'profile-a',
        goalId: 'goal-a',
        slotIndex: 1,
        title: 'Profile A Goal',
      ),
    };
    goalRepo.emitChange();
    final before = await container.read(eventTypeCreationChoicesProvider.future);
    expect(
      before.singleWhere((c) => c.type.stableKey == 'job_application')
          .displayLabel,
      'Profile A Goal',
    );

    // Switch the ready profile to B: startup controller re-resolves and the
    // choices provider re-evaluates against B (whose bindings differ).
    goalRepo.bindings = <int, LiveGoalEventTypeBinding>{
      2: const LiveGoalEventTypeBinding(
        profileId: 'profile-b',
        goalId: 'goal-b2',
        slotIndex: 2,
        title: 'Profile B Goal',
      ),
    };
    goalRepo.emitChange();
    startupRepo.profileId = 'profile-b';
    await container.read(startupControllerProvider.notifier).completeOnboarding();
    await _settleUntil(
      () => goalRepo.readBindingsCalls >= 2,
      description: 'profile B bindings',
    );
    final after = await container.read(eventTypeCreationChoicesProvider.future);
    expect(
      after.where((c) => c.type.stableKey == 'job_application'),
      isEmpty,
      reason: 'A slot-1 binding must never leak into profile B',
    );
    final scripture = after
        .singleWhere((c) => c.type.stableKey == 'scripture_study');
    expect(scripture.displayLabel, 'Profile B Goal');
  });

  test('projection triggers no notification reconciliation or extra writes',
      () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    typeRepo.release();
    await _bootStartup(container);
    await _settleRawEventTypes(container);
    final choicesSubscription = container.listen(
      eventTypeCreationChoicesProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(choicesSubscription.close);
    // Reading the projection (twice, via cache + invalidate) completes using
    // only the declared inputs: any notification/other-repository dependency
    // would have thrown UnimplementedError inside this container.
    await container.read(eventTypeCreationChoicesProvider.future);
    container.invalidate(eventTypeCreationChoicesProvider);
    await container.read(eventTypeCreationChoicesProvider.future);
    expect(typeRepo.readEventTypesCalls, 1,
        reason: 'the raw historical controller stays cached and unmodified');
    expect(goalRepo.readBindingsCalls, greaterThanOrEqualTo(2));
  });
}

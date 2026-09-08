import 'dart:async';

import 'package:rmplanner/features/planner/application/event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';

/// Delegates to a real Event Type repository while allowing latency tests to
/// hold one persistence/read phase independently from the others.
final class GatedEventTypeRepository implements EventTypeRepository {
  GatedEventTypeRepository(this.delegate);

  final EventTypeRepository delegate;

  bool blockReadEventType = false;
  bool blockGlobalReads = false;
  bool blockCustomSave = false;
  bool blockRename = false;
  bool blockColorSave = false;

  Object? customSaveFailure;
  Object? renameFailure;
  Object? colorSaveFailure;

  int readEventTypeCalls = 0;
  int globalReadCalls = 0;

  final Completer<void> readEventTypeStarted = Completer<void>();
  final Completer<void> customSaveStarted = Completer<void>();
  final Completer<EventType> customWriteCompleted = Completer<EventType>();
  final Completer<void> renameStarted = Completer<void>();
  final Completer<void> renameWriteCompleted = Completer<void>();
  final Completer<void> colorSaveStarted = Completer<void>();
  final Completer<void> colorWriteCompleted = Completer<void>();

  final Completer<void> _readEventTypeRelease = Completer<void>();
  final Completer<void> _globalReadRelease = Completer<void>();
  final Completer<void> _customSaveRelease = Completer<void>();
  final Completer<void> _renameRelease = Completer<void>();
  final Completer<void> _colorSaveRelease = Completer<void>();

  void releaseReadEventType() => _complete(_readEventTypeRelease);

  void releaseGlobalReads() => _complete(_globalReadRelease);

  void releaseCustomSave() => _complete(_customSaveRelease);

  void releaseRename() => _complete(_renameRelease);

  void releaseColorSave() => _complete(_colorSaveRelease);

  void releaseAll() {
    releaseReadEventType();
    releaseGlobalReads();
    releaseCustomSave();
    releaseRename();
    releaseColorSave();
  }

  static void _complete(Completer<void> completer) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _waitForGlobalReadGate() async {
    globalReadCalls += 1;
    if (blockGlobalReads) {
      await _globalReadRelease.future;
    }
  }

  @override
  Future<List<EventType>> readEventTypes({
    required String profileId,
    bool includeArchived = false,
  }) async {
    await _waitForGlobalReadGate();
    return delegate.readEventTypes(
      profileId: profileId,
      includeArchived: includeArchived,
    );
  }

  @override
  Future<EventType?> readEventType({
    required String profileId,
    required String eventTypeId,
  }) async {
    readEventTypeCalls += 1;
    _complete(readEventTypeStarted);
    if (blockReadEventType) {
      await _readEventTypeRelease.future;
    }
    return delegate.readEventType(
      profileId: profileId,
      eventTypeId: eventTypeId,
    );
  }

  @override
  Future<EventType?> readExactTypeForIndicator({
    required String profileId,
    required String indicatorKey,
  }) => delegate.readExactTypeForIndicator(
    profileId: profileId,
    indicatorKey: indicatorKey,
  );

  @override
  Future<EventType> saveCustomType({
    required String profileId,
    required EventTypeDraft draft,
  }) async {
    _complete(customSaveStarted);
    final failure = customSaveFailure;
    if (failure != null) {
      throw failure;
    }
    if (blockCustomSave) {
      await _customSaveRelease.future;
    }
    final saved = await delegate.saveCustomType(
      profileId: profileId,
      draft: draft,
    );
    if (!customWriteCompleted.isCompleted) {
      customWriteCompleted.complete(saved);
    }
    return saved;
  }

  @override
  Future<void> renameSystemType({
    required String profileId,
    required String eventTypeId,
    required String label,
  }) async {
    _complete(renameStarted);
    final failure = renameFailure;
    if (failure != null) {
      throw failure;
    }
    if (blockRename) {
      await _renameRelease.future;
    }
    await delegate.renameSystemType(
      profileId: profileId,
      eventTypeId: eventTypeId,
      label: label,
    );
    _complete(renameWriteCompleted);
  }

  @override
  Future<void> setCustomTypeArchived({
    required String profileId,
    required String eventTypeId,
    required bool archived,
  }) => delegate.setCustomTypeArchived(
    profileId: profileId,
    eventTypeId: eventTypeId,
    archived: archived,
  );

  @override
  Future<void> restoreSystemDefaults({required String profileId}) =>
      delegate.restoreSystemDefaults(profileId: profileId);

  @override
  Future<PlannerSettings> readPlannerSettings({
    required String profileId,
  }) async {
    await _waitForGlobalReadGate();
    return delegate.readPlannerSettings(profileId: profileId);
  }

  @override
  Future<PlannerSettings> savePlannerSettings({
    required String profileId,
    required PlannerSettings settings,
  }) => delegate.savePlannerSettings(profileId: profileId, settings: settings);

  @override
  Future<Map<String, EventColorPreference>> readEventColorPreferences({
    required String profileId,
  }) async {
    await _waitForGlobalReadGate();
    return delegate.readEventColorPreferences(profileId: profileId);
  }

  @override
  Future<Map<String, EventColorPreference>> saveEventColorPreference({
    required String profileId,
    required String eventTypeStableKey,
    required EventColorPreference preference,
  }) async {
    _complete(colorSaveStarted);
    final failure = colorSaveFailure;
    if (failure != null) {
      throw failure;
    }
    if (blockColorSave) {
      await _colorSaveRelease.future;
    }
    final saved = await delegate.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: eventTypeStableKey,
      preference: preference,
    );
    _complete(colorWriteCompleted);
    return saved;
  }

  @override
  Future<Map<String, EventColorPreference>> restoreEventColorDefaults({
    required String profileId,
  }) => delegate.restoreEventColorDefaults(profileId: profileId);

  @override
  Future<Map<String, int>> readContactGroupColors({
    required String profileId,
  }) async {
    await _waitForGlobalReadGate();
    return delegate.readContactGroupColors(profileId: profileId);
  }

  @override
  Future<Map<String, int>> saveContactGroupColor({
    required String profileId,
    required String groupId,
    required int colorArgb,
  }) => delegate.saveContactGroupColor(
    profileId: profileId,
    groupId: groupId,
    colorArgb: colorArgb,
  );

  @override
  Future<Map<String, int>> restoreContactGroupColorDefaults({
    required String profileId,
  }) => delegate.restoreContactGroupColorDefaults(profileId: profileId);
}

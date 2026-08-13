import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final eventTypeRepositoryProvider = Provider<EventTypeRepository>((ref) {
  throw StateError('EventTypeRepository must be overridden at the app root');
});

final class EventTypeState {
  const EventTypeState({
    required this.isLoading,
    required this.eventTypes,
    required this.settings,
    required this.eventColors,
    required this.groupColors,
    this.message,
  });

  const EventTypeState.loading()
    : isLoading = true,
      eventTypes = const <EventType>[],
      settings = const PlannerSettings.defaults(),
      eventColors = const <String, EventColorPreference>{},
      groupColors = const <String, int>{},
      message = null;

  final bool isLoading;
  final List<EventType> eventTypes;
  final PlannerSettings settings;

  /// Explicit user choices keyed by Event Type stable key. Missing entries
  /// resolve through [PlannerEventColorDefaults] at the presentation edge.
  final Map<String, EventColorPreference> eventColors;
  final Map<String, int> groupColors;
  final String? message;

  EventTypeState copyWith({
    bool? isLoading,
    List<EventType>? eventTypes,
    PlannerSettings? settings,
    Map<String, EventColorPreference>? eventColors,
    Map<String, int>? groupColors,
    String? message,
    bool clearMessage = false,
  }) {
    return EventTypeState(
      isLoading: isLoading ?? this.isLoading,
      eventTypes: eventTypes ?? this.eventTypes,
      settings: settings ?? this.settings,
      eventColors: eventColors ?? this.eventColors,
      groupColors: groupColors ?? this.groupColors,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  Map<String, EventColorPreference> get resolvedEventColorsByTypeId {
    return <String, EventColorPreference>{
      for (final type in eventTypes)
        type.id:
            eventColors[type.stableKey] ??
            PlannerEventColorDefaults.forEventType(type),
    };
  }
}

final eventTypeControllerProvider =
    NotifierProvider<EventTypeController, EventTypeState>(
      EventTypeController.new,
    );

final class EventTypeController extends Notifier<EventTypeState> {
  EventTypeRepository get _repository => ref.read(eventTypeRepositoryProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Event Types require a ready Local Profile');
    }
    return startup.profile.id;
  }

  @override
  EventTypeState build() {
    unawaited(Future<void>.microtask(load));
    return const EventTypeState.loading();
  }

  Future<void> load({bool includeArchived = false}) async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repository.readEventTypes(
          profileId: _profileId,
          includeArchived: includeArchived,
        ),
        _repository.readPlannerSettings(profileId: _profileId),
        _repository.readEventColorPreferences(profileId: _profileId),
        _repository.readContactGroupColors(profileId: _profileId),
      ]);
      state = EventTypeState(
        isLoading: false,
        eventTypes: results[0] as List<EventType>,
        settings: results[1] as PlannerSettings,
        eventColors: results[2] as Map<String, EventColorPreference>,
        groupColors: results[3] as Map<String, int>,
      );
    } on Object {
      state = state.copyWith(
        isLoading: false,
        message:
            'Planner settings could not be opened. Retry without data loss.',
      );
    }
  }

  Future<EventType?> exactTypeForIndicator(String indicatorKey) {
    return _repository.readExactTypeForIndicator(
      profileId: _profileId,
      indicatorKey: indicatorKey,
    );
  }

  Future<EventType?> readType(String eventTypeId) {
    return _repository.readEventType(
      profileId: _profileId,
      eventTypeId: eventTypeId,
    );
  }

  Future<bool> saveCustomType(EventTypeDraft draft) async {
    try {
      final saved = await _repository.saveCustomType(
        profileId: _profileId,
        draft: draft,
      );
      _replaceOrAppendType(saved);
      return true;
    } on Object {
      state = state.copyWith(
        message: 'Event Type was not changed. Your input is still available.',
      );
      return false;
    }
  }

  Future<bool> renameSystemType({
    required String eventTypeId,
    required String label,
  }) async {
    try {
      final current = state.eventTypes
          .where((type) => type.id == eventTypeId)
          .firstOrNull;
      await _repository.renameSystemType(
        profileId: _profileId,
        eventTypeId: eventTypeId,
        label: label,
      );
      if (current == null) {
        state = state.copyWith(clearMessage: true);
      } else {
        _replaceOrAppendType(_withLabel(current, label.trim()));
      }
      return true;
    } on Object {
      state = state.copyWith(
        message:
            'Event Type name was not changed. Your input is still available.',
      );
      return false;
    }
  }

  void _replaceOrAppendType(EventType saved) {
    final eventTypes = List<EventType>.of(state.eventTypes);
    final index = eventTypes.indexWhere((type) => type.id == saved.id);
    if (index == -1) {
      eventTypes.add(saved);
    } else {
      eventTypes[index] = saved;
    }
    state = state.copyWith(
      eventTypes: List<EventType>.unmodifiable(eventTypes),
      clearMessage: true,
    );
  }

  static EventType _withLabel(EventType type, String label) => EventType(
    id: type.id,
    stableKey: type.stableKey,
    label: label,
    icon: type.icon,
    colorValue: type.colorValue,
    isSystem: type.isSystem,
    isArchived: type.isArchived,
    reportRequiredDefault: type.reportRequiredDefault,
    defaultDurationMinutes: type.defaultDurationMinutes,
    defaultReminderMinutes: type.defaultReminderMinutes,
    position: type.position,
    mappingVersion: type.mappingVersion,
    indicatorKeys: type.indicatorKeys,
  );

  Future<bool> setArchived(EventType type, bool archived) async {
    try {
      await _repository.setCustomTypeArchived(
        profileId: _profileId,
        eventTypeId: type.id,
        archived: archived,
      );
      await load(includeArchived: true);
      return true;
    } on Object {
      state = state.copyWith(
        message: 'Event Type archive state was not changed.',
      );
      return false;
    }
  }

  Future<bool> restoreSystemDefaults() async {
    try {
      await _repository.restoreSystemDefaults(profileId: _profileId);
      await load(includeArchived: true);
      return true;
    } on Object {
      state = state.copyWith(message: 'System defaults were not changed.');
      return false;
    }
  }

  Future<bool> saveSettings(PlannerSettings settings) async {
    try {
      final saved = await _repository.savePlannerSettings(
        profileId: _profileId,
        settings: settings,
      );
      state = state.copyWith(settings: saved, clearMessage: true);
      return true;
    } on Object {
      state = state.copyWith(
        message: 'Planner settings were not changed. You can safely retry.',
      );
      return false;
    }
  }

  Future<bool> saveEventColor(
    EventType type,
    EventColorPreference preference,
  ) async {
    try {
      final saved = await _repository.saveEventColorPreference(
        profileId: _profileId,
        eventTypeStableKey: type.stableKey,
        preference: preference,
      );
      state = state.copyWith(eventColors: saved, clearMessage: true);
      return true;
    } on Object {
      state = state.copyWith(
        message: 'Event color was not changed. You can safely retry.',
      );
      return false;
    }
  }

  Future<bool> restoreEventColorDefaults() async {
    try {
      final restored = await _repository.restoreEventColorDefaults(
        profileId: _profileId,
      );
      state = state.copyWith(eventColors: restored, clearMessage: true);
      return true;
    } on Object {
      state = state.copyWith(
        message: 'Event colors were not restored. You can safely retry.',
      );
      return false;
    }
  }

  Future<bool> saveContactGroupColor({
    required String groupId,
    required int colorArgb,
  }) async {
    try {
      final saved = await _repository.saveContactGroupColor(
        profileId: _profileId,
        groupId: groupId,
        colorArgb: colorArgb,
      );
      state = state.copyWith(groupColors: saved, clearMessage: true);
      return true;
    } on Object {
      state = state.copyWith(
        message: 'Group color was not changed. You can safely retry.',
      );
      return false;
    }
  }

  Future<bool> restoreContactGroupColorDefaults() async {
    try {
      final restored = await _repository.restoreContactGroupColorDefaults(
        profileId: _profileId,
      );
      state = state.copyWith(groupColors: restored, clearMessage: true);
      return true;
    } on Object {
      state = state.copyWith(
        message: 'Group colors were not restored. You can safely retry.',
      );
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}

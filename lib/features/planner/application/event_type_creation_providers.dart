import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type_creation_choice.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

/// Creation projection (contract D.7): combines the raw Event Type
/// controller state with the live Goal slot bindings into an AsyncValue of
/// creation choices.
///
/// The RAW EventTypeState is never migrated or modified: raw eventTypes,
/// settings, and the resolved color map keep every historical type. Loading
/// and error propagate — callers must disable taps/save instead of falling
/// back to a stale or all-six list. The provider re-evaluates whenever the
/// raw controller or the monotonic goalChangesProvider emits.
final eventTypeCreationChoicesProvider =
    FutureProvider<List<EventTypeCreationChoice>>((ref) async {
      final startup = ref.watch(startupControllerProvider);
      if (startup is! StartupReady) {
        throw StateError('Creation choices require a ready Local Profile');
      }
      final profileId = startup.profile.id;
      // Watching both inputs keeps an open picker reactive (contract C/E).
      final rawState = ref.watch(eventTypeControllerProvider);
      final bindings = await ref.watch(
        liveGoalEventTypeBindingsProvider(profileId).future,
      );
      if (rawState.isLoading) {
        throw const _ChoicesLoading();
      }
      if (rawState.message != null) {
        throw StateError(rawState.message!);
      }
      return EventTypeCreationChoice.buildChoices(
        types: rawState.eventTypes,
        bindings: bindings,
      );
    });

/// Internal sentinel distinguishing "inputs still loading" (a retry-able,
/// transient state) from a hard failure, so pickers can keep the sheet open
/// with controls disabled instead of showing an error.
final class _ChoicesLoading implements Exception {
  const _ChoicesLoading();

  @override
  String toString() => 'Creation choices are still loading';
}

/// Resolves the CURRENT choice by raw Event Type ID from the provider
/// state (form initialization and tap guards). Contract P: the TRANSACTIONAL
/// save guard must instead reread raw bindings in its own DB transaction —
/// this resolver is UI-state only. Throws when inputs are unavailable;
/// never silently falls back. Callers decide stale-source behavior (e.g.
/// eligible Other fallback) per contract E.
Future<EventTypeCreationChoice?> findCreationChoiceById(
  WidgetRef ref,
  String eventTypeId,
) async {
  final choices = await ref.read(eventTypeCreationChoicesProvider.future);
  for (final choice in choices) {
    if (choice.type.id == eventTypeId) {
      return choice;
    }
  }
  return null;
}

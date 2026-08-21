import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/contacts/application/contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  throw StateError('ContactRepository must be overridden at the app root');
});

final contactProfileIdProvider = Provider<String>((ref) {
  final startup = ref.read(startupControllerProvider);
  if (startup is! StartupReady) {
    throw StateError('Contacts require a ready Local Profile');
  }
  return startup.profile.id;
});

final contactChangesProvider = StreamProvider.family<int, String>((
  ref,
  profileId,
) {
  return ref.read(contactRepositoryProvider).watchChanges(profileId);
});

// ---------------------------------------------------------------------------
// Main Contacts list controller
// ---------------------------------------------------------------------------

enum ContactsLoadStatus { loading, ready, failure }

final class ContactsState {
  const ContactsState({
    required this.status,
    required this.criteria,
    required this.viewCriteria,
    required this.sortBy,
    required this.contacts,
    this.appliedFilter,
    this.message,
  });

  final ContactsLoadStatus status;
  final ContactFilterCriteria criteria;
  final ContactFilterCriteria viewCriteria;
  final ContactSortBy sortBy;
  final List<ContactSummary> contacts;
  final SavedContactFilter? appliedFilter;
  final String? message;

  ContactsState copyWith({
    ContactsLoadStatus? status,
    ContactFilterCriteria? criteria,
    ContactFilterCriteria? viewCriteria,
    ContactSortBy? sortBy,
    List<ContactSummary>? contacts,
    SavedContactFilter? appliedFilter,
    String? message,
    bool clearMessage = false,
    bool clearAppliedFilter = false,
    bool replaceViewCriteria = false,
  }) {
    return ContactsState(
      status: status ?? this.status,
      criteria: criteria ?? this.criteria,
      viewCriteria: replaceViewCriteria
          ? viewCriteria ?? this.viewCriteria
          : this.viewCriteria,
      sortBy: sortBy ?? this.sortBy,
      contacts: contacts ?? this.contacts,
      appliedFilter: clearAppliedFilter
          ? null
          : appliedFilter ?? this.appliedFilter,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final contactsControllerProvider =
    NotifierProvider<ContactsController, ContactsState>(ContactsController.new);

final class ContactsController extends Notifier<ContactsState> {
  int _generation = 0;

  ContactRepository get _repository => ref.read(contactRepositoryProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Contacts require a ready Local Profile');
    }
    return startup.profile.id;
  }

  @override
  ContactsState build() {
    ref.onDispose(() => _generation++);
    final profileId = _profileId;
    ref.listen(contactChangesProvider(profileId), (_, _) {
      unawaited(refresh());
    });
    unawaited(Future<void>.microtask(_load));
    return const ContactsState(
      status: ContactsLoadStatus.loading,
      criteria: ContactFilterCriteria(),
      viewCriteria: ContactFilterCriteria(),
      sortBy: ContactSortBy.name,
      contacts: <ContactSummary>[],
    );
  }

  Future<void> _load() async {
    final generation = ++_generation;
    state = state.copyWith(
      status: ContactsLoadStatus.loading,
      clearMessage: true,
    );
    try {
      final contacts = await _repository.readContacts(
        profileId: _profileId,
        criteria: state.criteria,
        sortBy: state.sortBy,
        today: ref.read(plannerDateSourceProvider).today(),
      );
      if (generation != _generation) {
        return;
      }
      state = state.copyWith(
        status: ContactsLoadStatus.ready,
        contacts: contacts,
        clearMessage: true,
      );
    } on Object {
      if (generation != _generation) {
        return;
      }
      state = state.copyWith(
        status: ContactsLoadStatus.failure,
        message: 'Contacts could not be opened. Retry without data loss.',
      );
    }
  }

  Future<void> refresh() => _load();

  void applyFilter(
    ContactFilterCriteria criteria, {
    SavedContactFilter? appliedFilter,
    bool clearAppliedFilter = false,
    bool updateCurrentView = true,
  }) {
    state = state.copyWith(
      criteria: criteria,
      appliedFilter: appliedFilter,
      clearAppliedFilter: clearAppliedFilter,
      viewCriteria: criteria,
      replaceViewCriteria: updateCurrentView,
    );
    unawaited(_load());
  }

  void setSort(ContactSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
    unawaited(_load());
  }

  /// Removes temporary quick-filter changes while retaining the selected
  /// current view and its saved-filter identity.
  void clearAdHocFilters() {
    final baseline = state.viewCriteria;
    state = state.copyWith(criteria: baseline);
    unawaited(_load());
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}

// ---------------------------------------------------------------------------
// Read-only data providers
// ---------------------------------------------------------------------------

final contactGroupsProvider = FutureProvider<List<ContactGroup>>((ref) async {
  final profileId = ref.read(contactProfileIdProvider);
  ref.watch(contactChangesProvider(profileId));
  // C2 canonicalization gate: ensure the four built-in default ContactGroup
  // rows exist with deterministic identity (idempotent and collision-safe)
  // before any consumer reads the group list. This is the single canonical
  // source-of-truth gate shared by Contacts and Settings -> Colors.
  final repository = ref.read(contactRepositoryProvider);
  await repository.ensureBuiltInGroups(profileId);
  // Includes archived groups so the manager can show and restore them;
  // filters hide archived groups everywhere else.
  return repository.readGroups(profileId, includeArchived: true);
});

final contactTagsProvider = FutureProvider<List<ContactTag>>((ref) {
  final profileId = ref.read(contactProfileIdProvider);
  ref.watch(contactChangesProvider(profileId));
  return ref.read(contactRepositoryProvider).readTags(profileId);
});

final savedContactFiltersProvider = FutureProvider<List<SavedContactFilter>>((
  ref,
) {
  final profileId = ref.read(contactProfileIdProvider);
  ref.watch(contactChangesProvider(profileId));
  return ref.read(contactRepositoryProvider).readSavedFilters(profileId);
});

final contactDetailProvider = FutureProvider.family<ContactDetail, String>((
  ref,
  contactId,
) {
  final profileId = ref.read(contactProfileIdProvider);
  ref.watch(contactChangesProvider(profileId));
  return ref
      .read(contactRepositoryProvider)
      .readContactDetail(profileId: profileId, contactId: contactId);
});

final contactTimelineProvider = FutureProvider.family<ContactTimeline, String>((
  ref,
  contactId,
) {
  final profileId = ref.read(contactProfileIdProvider);
  ref.watch(contactChangesProvider(profileId));
  return ref
      .read(contactRepositoryProvider)
      .readTimeline(
        profileId: profileId,
        contactId: contactId,
        today: ref.read(plannerDateSourceProvider).today(),
      );
});

final commonEventPatternsProvider =
    FutureProvider.family<List<CommonEventPattern>, String>((ref, contactId) {
      final profileId = ref.read(contactProfileIdProvider);
      ref.watch(contactChangesProvider(profileId));
      return ref
          .read(contactRepositoryProvider)
          .readCommonEventPatterns(profileId: profileId, contactId: contactId);
    });

final eventPeopleProvider =
    FutureProvider.family<
      List<ContactSummary>,
      ({String eventId, String occurrenceId})
    >((ref, key) {
      final profileId = ref.read(contactProfileIdProvider);
      ref.watch(contactChangesProvider(profileId));
      return ref
          .read(contactRepositoryProvider)
          .readEventPeople(
            profileId: profileId,
            eventId: key.eventId,
            occurrenceId: key.occurrenceId,
            today: ref.read(plannerDateSourceProvider).today(),
          );
    });

final taskContactsProvider =
    FutureProvider.family<List<ContactSummary>, String>((ref, taskId) {
      final profileId = ref.read(contactProfileIdProvider);
      ref.watch(contactChangesProvider(profileId));
      return ref
          .read(contactRepositoryProvider)
          .readTaskContacts(profileId: profileId, taskId: taskId);
    });

final contactUpcomingTasksProvider =
    FutureProvider.family<List<PlannerTask>, String>((ref, contactId) {
      final profileId = ref.read(contactProfileIdProvider);
      ref.watch(contactChangesProvider(profileId));
      return ref
          .read(contactRepositoryProvider)
          .readContactUpcomingTasks(profileId: profileId, contactId: contactId);
    });

final duplicateCandidatesProvider = FutureProvider<List<List<Contact>>>((ref) {
  final profileId = ref.read(contactProfileIdProvider);
  ref.watch(contactChangesProvider(profileId));
  return ref.read(contactRepositoryProvider).readDuplicateCandidates(profileId);
});

/// Summaries for a stable comma-separated contact ID list.  Used by the
/// Event form People section to render the current draft selection without
/// holding repository futures inside widget state.
final contactSummariesByCsvProvider =
    FutureProvider.family<Map<String, ContactSummary>, String>((ref, csv) {
      final ids = csv
          .split(',')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (ids.isEmpty) {
        return Future<Map<String, ContactSummary>>.value(
          const <String, ContactSummary>{},
        );
      }
      final profileId = ref.read(contactProfileIdProvider);
      ref.watch(contactChangesProvider(profileId));
      return ref
          .read(contactRepositoryProvider)
          .readContactsByIds(
            profileId: profileId,
            contactIds: ids,
            today: ref.read(plannerDateSourceProvider).today(),
          );
    });

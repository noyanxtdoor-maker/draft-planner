import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

abstract interface class ContactRepository {
  /// Emits a monotonic counter on every underlying-table change.
  ///
  /// The value is deliberately non-`void`: Riverpod 3 treats consecutive
  /// identical [AsyncData] states as equal and skips notifying listeners, so
  /// a `Stream<void>` would swallow every change after the first and live
  /// refresh would stop after the first emission.
  Stream<int> watchChanges(String profileId);

  // -- Contacts -------------------------------------------------------------
  Future<Contact> createContact({
    required String profileId,
    required ContactDraft draft,
  });

  Future<Contact> updateContact({
    required String profileId,
    required String contactId,
    required ContactDraft draft,
  });

  Future<ContactDetail> readContactDetail({
    required String profileId,
    required String contactId,
  });

  Future<Contact> setFavorite({
    required String profileId,
    required String contactId,
    required bool favorite,
  });

  Future<void> archiveContact({
    required String profileId,
    required String contactId,
  });

  Future<Contact> restoreContact({
    required String profileId,
    required String contactId,
  });

  /// Active list rows for the current view.  Group/tag labels are joined in
  /// a bounded query set and event context is batched for the returned rows,
  /// so hundreds of Contacts render without N+1 reads.
  Future<List<ContactSummary>> readContacts({
    required String profileId,
    required ContactFilterCriteria criteria,
    required ContactSortBy sortBy,
    required PlannerDate today,
    String? query,
  });

  Future<List<ContactSummary>> searchContacts({
    required String profileId,
    required String query,
    required PlannerDate today,
  });

  /// Summaries for an explicit Contact ID list (e.g. an Event People draft
  /// held outside the repository).  Archived and merged rows resolve too so a
  /// saved selection never silently disappears from view.
  Future<Map<String, ContactSummary>> readContactsByIds({
    required String profileId,
    required List<String> contactIds,
    required PlannerDate today,
  });

  // -- Groups ---------------------------------------------------------------
  Future<List<ContactGroup>> readGroups(
    String profileId, {
    bool includeArchived = false,
  });

  Future<ContactGroup> createGroup({
    required String profileId,
    required String name,
    required int colorValue,
  });

  Future<ContactGroup> updateGroup({
    required String profileId,
    required String groupId,
    required String name,
    required int colorValue,
  });

  Future<void> archiveGroup({
    required String profileId,
    required String groupId,
  });

  /// Replaces a Contact's group memberships and enforces a single primary
  /// group within the same transaction.
  Future<void> setContactGroups({
    required String profileId,
    required String contactId,
    required List<String> groupIds,
    String? primaryGroupId,
  });

  // -- Tags -----------------------------------------------------------------
  Future<List<ContactTag>> readTags(String profileId);

  // -- Notes ----------------------------------------------------------------
  Future<ContactNote> addNote({
    required String profileId,
    required String contactId,
    required String text,
  });

  Future<ContactNote> updateNote({
    required String profileId,
    required String noteId,
    required String text,
  });

  Future<void> deleteNote({required String profileId, required String noteId});

  // -- Availability ---------------------------------------------------------
  Future<void> setAvailability({
    required String profileId,
    required String contactId,
    required List<ContactAvailability> windows,
  });

  // -- Saved filters --------------------------------------------------------
  Future<List<SavedContactFilter>> readSavedFilters(String profileId);

  Future<SavedContactFilter> saveSavedFilter({
    required String profileId,
    required SavedContactFilterDraft draft,
  });

  Future<void> deleteSavedFilter({
    required String profileId,
    required String filterId,
  });

  // -- Planner links --------------------------------------------------------
  /// Replaces the people on [eventId] for [occurrenceId] (`series` or a
  /// specific occurrence identity).  Historical occurrences are frozen into
  /// participant snapshots BEFORE any series-level removal, so a future
  /// People edit can never rewrite history.
  Future<void> setEventPeople({
    required String profileId,
    required String eventId,
    required String occurrenceId,
    PlannerDate? originalDate,
    required List<String> contactIds,
  });

  Future<List<ContactSummary>> readEventPeople({
    required String profileId,
    required String eventId,
    required String occurrenceId,
    required PlannerDate today,
  });

  Future<void> setTaskContacts({
    required String profileId,
    required String taskId,
    required List<String> contactIds,
  });

  Future<List<ContactSummary>> readTaskContacts({
    required String profileId,
    required String taskId,
  });

  /// Incomplete Tasks linked to a Contact, for the Profile Upcoming section.
  Future<List<PlannerTask>> readContactUpcomingTasks({
    required String profileId,
    required String contactId,
  });

  // -- Timeline -------------------------------------------------------------
  Future<ContactTimeline> readTimeline({
    required String profileId,
    required String contactId,
    required PlannerDate today,
  });

  Future<List<CommonEventPattern>> readCommonEventPatterns({
    required String profileId,
    required String contactId,
  });

  // -- Merge / duplicates ---------------------------------------------------
  Future<List<List<Contact>>> readDuplicateCandidates(String profileId);

  Future<ContactMergePlan> readMergePlan({
    required String profileId,
    required String survivorId,
    required List<String> absorbedIds,
  });

  Future<Contact> mergeContacts({
    required String profileId,
    required String survivorId,
    required List<String> absorbedIds,
    required ContactMergeChoices choices,
  });

  // -- Device import --------------------------------------------------------
  Future<ContactImportResult> importDeviceContacts({
    required String profileId,
    required List<DeviceContactDraft> drafts,
  });
}

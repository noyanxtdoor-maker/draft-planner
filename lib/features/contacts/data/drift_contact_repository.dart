import 'dart:async';

import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/contacts/application/contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

/// Drift-backed VS-11 Contacts repository.
///
/// Every multi-row operation uses batched queries (no N+1), and every write
/// that could affect history freezes occurrence-level participant snapshots
/// first so recurrence edits can never rewrite the past.
final class DriftContactRepository implements ContactRepository {
  DriftContactRepository({
    required this.database,
    required this.clock,
    required this.identifiers,
  });

  final AppDatabase database;
  final AppClock clock;
  final IdentifierSource identifiers;

  static const String seriesOccurrenceId = 'series';

  // -- Change stream --------------------------------------------------------

  @override
  Stream<int> watchChanges(String profileId) {
    // The same lightweight change stream the Goals repository uses: table
    // update notifications instead of per-table QueryStreams, so widget-test
    // teardown never leaves drift cancel timers pending.  The counter is
    // never `void`: Riverpod 3 skips notifying listeners for consecutive
    // equal AsyncData states, so a void stream would only ever refresh once.
    var generation = 0;
    return database
        .tableUpdates(
          TableUpdateQuery.onAllTables(<ResultSetImplementation>[
            database.contacts,
            database.contactMethods,
            database.contactGroups,
            database.contactGroupMemberships,
            database.contactTags,
            database.contactTagMemberships,
            database.contactNotes,
            database.contactAvailabilities,
            database.eventContactLinks,
            database.eventOccurrenceParticipants,
            database.taskContactLinks,
            database.savedContactFilters,
          ]),
        )
        .map((_) => ++generation);
  }

  // -- Contacts -------------------------------------------------------------

  @override
  Future<Contact> createContact({
    required String profileId,
    required ContactDraft draft,
  }) async {
    final normalized = draft.normalized();
    final now = clock.nowUtc();
    return database.transaction(() async {
      await database
          .into(database.contacts)
          .insert(
            ContactsCompanion.insert(
              id: normalized.id,
              profileId: profileId,
              firstName: Value<String?>(
                normalized.firstName.isEmpty ? null : normalized.firstName,
              ),
              lastName: Value<String?>(
                normalized.lastName.isEmpty ? null : normalized.lastName,
              ),
              displayName: normalized.displayName,
              preferredContactMethod: Value<String>(
                ContactPreferredMethodCodec.encode(
                  normalized.preferredContactMethod,
                ),
              ),
              isFavorite: Value<bool>(normalized.isFavorite),
              lifecycleState: Value<String>(
                ContactLifecycleStateCodec.encode(ContactLifecycleState.active),
              ),
              source: Value<String>(
                ContactSourceCodec.encode(normalized.source),
              ),
              addressText: Value<String?>(normalized.addressText),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      await _replaceMethods(
        profileId,
        contactId: normalized.id,
        methods: normalized.methods,
      );
      await setContactGroups(
        profileId: profileId,
        contactId: normalized.id,
        groupIds: normalized.groupIds,
        primaryGroupId: normalized.primaryGroupId,
      );
      await _replaceTags(
        profileId,
        contactId: normalized.id,
        tagNames: normalized.tagNames,
      );
      await setAvailability(
        profileId: profileId,
        contactId: normalized.id,
        windows: normalized.availability,
      );
      final note = normalized.initialNoteText;
      if (note != null) {
        await database
            .into(database.contactNotes)
            .insert(
              ContactNotesCompanion.insert(
                id: identifiers.nextUuid(),
                contactId: normalized.id,
                noteText: note,
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      }
      final detail = await readContactDetail(
        profileId: profileId,
        contactId: normalized.id,
      );
      return detail.contact;
    });
  }

  @override
  Future<Contact> updateContact({
    required String profileId,
    required String contactId,
    required ContactDraft draft,
  }) async {
    final normalized = draft.normalized();
    final now = clock.nowUtc();
    return database.transaction(() async {
      final updated =
          await (database.update(database.contacts)..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(contactId),
              ))
              .write(
                ContactsCompanion(
                  firstName: Value<String?>(
                    normalized.firstName.isEmpty ? null : normalized.firstName,
                  ),
                  lastName: Value<String?>(
                    normalized.lastName.isEmpty ? null : normalized.lastName,
                  ),
                  displayName: Value<String>(normalized.displayName),
                  preferredContactMethod: Value<String>(
                    ContactPreferredMethodCodec.encode(
                      normalized.preferredContactMethod,
                    ),
                  ),
                  isFavorite: Value<bool>(normalized.isFavorite),
                  addressText: Value<String?>(normalized.addressText),
                  updatedAtUtc: Value<DateTime>(now),
                ),
              );
      if (updated == 0) {
        throw const ContactValidationException('Contact not found.');
      }
      await _replaceMethods(
        profileId,
        contactId: contactId,
        methods: normalized.methods,
      );
      await setContactGroups(
        profileId: profileId,
        contactId: contactId,
        groupIds: normalized.groupIds,
        primaryGroupId: normalized.primaryGroupId,
      );
      await _replaceTags(
        profileId,
        contactId: contactId,
        tagNames: normalized.tagNames,
      );
      await setAvailability(
        profileId: profileId,
        contactId: contactId,
        windows: normalized.availability,
      );
      final detail = await readContactDetail(
        profileId: profileId,
        contactId: contactId,
      );
      return detail.contact;
    });
  }

  @override
  Future<ContactDetail> readContactDetail({
    required String profileId,
    required String contactId,
  }) async {
    final row =
        await (database.select(database.contacts)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(contactId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      throw const ContactValidationException('Contact not found.');
    }
    final contact = _contactFromRow(row);
    final methods = await (database.select(
      database.contactMethods,
    )..where((table) => table.contactId.equals(contactId))).get();
    final membershipRows =
        await (database.select(database.contactGroupMemberships).join([
              innerJoin(
                database.contactGroups,
                database.contactGroups.id.equalsExp(
                  database.contactGroupMemberships.groupId,
                ),
              ),
            ])..where(
              database.contactGroupMemberships.contactId.equals(contactId),
            ))
            .get();
    final groups = <ContactGroup>[];
    String? primaryGroupId;
    for (final row2 in membershipRows) {
      final group = row2.readTable(database.contactGroups);
      groups.add(_groupFromRow(group));
      if (row2.readTable(database.contactGroupMemberships).isPrimary) {
        primaryGroupId = group.id;
      }
    }
    final tags = await (database.select(database.contactTags).join(
      [
        innerJoin(
          database.contactTagMemberships,
          database.contactTagMemberships.tagId.equalsExp(
            database.contactTags.id,
          ),
        ),
      ],
    )..where(database.contactTagMemberships.contactId.equals(contactId))).get();
    final tagRows =
        tags.map((row) => row.readTable(database.contactTags)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final notes =
        await (database.select(
          database.contactNotes,
        )..where((table) => table.contactId.equals(contactId))).get().then(
          (rows) =>
              rows.toList()
                ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc)),
        );
    final availability =
        await (database.select(database.contactAvailabilities)
              ..where((table) => table.contactId.equals(contactId))
              ..orderBy([(table) => OrderingTerm.asc(table.weekday)]))
            .get();
    return ContactDetail(
      contact: contact,
      methods: methods.map(_methodFromRow).toList(growable: false),
      groups: groups,
      primaryGroupId: primaryGroupId,
      tags: tagRows.map(_tagFromRow).toList(growable: false),
      notes: notes.map(_noteFromRow).toList(growable: false),
      availability: availability
          .map(_availabilityFromRow)
          .toList(growable: false),
    );
  }

  @override
  Future<Contact> setFavorite({
    required String profileId,
    required String contactId,
    required bool favorite,
  }) async {
    await (database.update(database.contacts)..where(
          (table) =>
              table.profileId.equals(profileId) & table.id.equals(contactId),
        ))
        .write(
          ContactsCompanion(
            isFavorite: Value<bool>(favorite),
            updatedAtUtc: Value<DateTime>(clock.nowUtc()),
          ),
        );
    final detail = await readContactDetail(
      profileId: profileId,
      contactId: contactId,
    );
    return detail.contact;
  }

  @override
  Future<void> archiveContact({
    required String profileId,
    required String contactId,
  }) async {
    await (database.update(database.contacts)..where(
          (table) =>
              table.profileId.equals(profileId) & table.id.equals(contactId),
        ))
        .write(
          ContactsCompanion(
            lifecycleState: Value<String>(ContactLifecycleState.archived.name),
            archivedAtUtc: Value<DateTime?>(clock.nowUtc()),
            updatedAtUtc: Value<DateTime>(clock.nowUtc()),
          ),
        );
  }

  @override
  Future<Contact> restoreContact({
    required String profileId,
    required String contactId,
  }) async {
    final updated =
        await (database.update(database.contacts)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.id.equals(contactId) &
                  table.lifecycleState.equals(
                    ContactLifecycleState.archived.name,
                  ),
            ))
            .write(
              ContactsCompanion(
                lifecycleState: Value<String>(
                  ContactLifecycleState.active.name,
                ),
                archivedAtUtc: const Value<DateTime?>(null),
                updatedAtUtc: Value<DateTime>(clock.nowUtc()),
              ),
            );
    if (updated == 0) {
      throw const ContactValidationException('Contact not found.');
    }
    final detail = await readContactDetail(
      profileId: profileId,
      contactId: contactId,
    );
    return detail.contact;
  }

  @override
  Future<List<ContactSummary>> readContacts({
    required String profileId,
    required ContactFilterCriteria criteria,
    required ContactSortBy sortBy,
    required PlannerDate today,
    String? query,
  }) async {
    final baseQuery = database.select(database.contacts);
    var where =
        database.contacts.profileId.equals(profileId) &
        database.contacts.lifecycleState.isNotValue(
          ContactLifecycleState.merged.name,
        );
    if (!criteria.includeArchived) {
      where =
          where &
          database.contacts.lifecycleState.equals(
            ContactLifecycleState.active.name,
          );
    }
    if (criteria.favoritesOnly) {
      where = where & database.contacts.isFavorite.equals(true);
    }
    final normalizedQuery = query?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      where =
          where &
          database.contacts.displayName.lower().contains(
            normalizedQuery.toLowerCase(),
          );
    }
    if (criteria.source != null) {
      where =
          where &
          database.contacts.source.equals(
            ContactSourceCodec.encode(criteria.source!),
          );
    }
    if (criteria.hasAddress) {
      where = where & database.contacts.addressText.isNotNull();
    }
    baseQuery.where((table) => where);
    if (sortBy == ContactSortBy.name) {
      baseQuery.orderBy([(table) => OrderingTerm.asc(table.displayName)]);
    } else {
      baseQuery.orderBy([(table) => OrderingTerm.desc(table.createdAtUtc)]);
    }
    final rows = await baseQuery.get();
    if (rows.isEmpty) {
      return const <ContactSummary>[];
    }
    final ids = rows.map((row) => row.id).toList(growable: false);
    return _buildSummaries(
      profileId: profileId,
      contactRows: rows,
      ids: ids,
      criteria: criteria,
      today: today,
    );
  }

  /// Batches methods, memberships, tags, and event context for [ids] and
  /// applies the criteria that cannot be expressed cheaply in SQL
  /// (methods, tags, availability, event-based filters).
  Future<List<ContactSummary>> _buildSummaries({
    required String profileId,
    required List<ContactRow> contactRows,
    required List<String> ids,
    required ContactFilterCriteria criteria,
    required PlannerDate today,
  }) async {
    final methods = await (database.select(
      database.contactMethods,
    )..where((table) => table.contactId.isIn(ids))).get();
    final methodsByContact = <String, List<ContactMethodRow>>{};
    for (final method in methods) {
      methodsByContact
          .putIfAbsent(method.contactId, () => <ContactMethodRow>[])
          .add(method);
    }
    final membershipRows =
        await (database.select(database.contactGroupMemberships).join([
          innerJoin(
            database.contactGroups,
            database.contactGroups.id.equalsExp(
              database.contactGroupMemberships.groupId,
            ),
          ),
        ])..where(database.contactGroupMemberships.contactId.isIn(ids))).get();
    final primaryGroupByContact = <String, ContactGroupRow>{};
    final groupNamesByContact = <String, List<String>>{};
    final groupIdsByContact = <String, Set<String>>{};
    for (final row in membershipRows) {
      final membership = row.readTable(database.contactGroupMemberships);
      final group = row.readTable(database.contactGroups);
      if (group.isArchived) {
        continue;
      }
      groupIdsByContact
          .putIfAbsent(membership.contactId, () => <String>{})
          .add(group.id);
      if (membership.isPrimary) {
        primaryGroupByContact[membership.contactId] = group;
      } else {
        groupNamesByContact
            .putIfAbsent(membership.contactId, () => <String>[])
            .add(group.name);
      }
    }
    final tagRows = await (database.select(database.contactTags).join([
      innerJoin(
        database.contactTagMemberships,
        database.contactTagMemberships.tagId.equalsExp(database.contactTags.id),
      ),
    ])..where(database.contactTagMemberships.contactId.isIn(ids))).get();
    final tagNamesByContact = <String, List<String>>{};
    final tagIdsByContact = <String, Set<String>>{};
    for (final row in tagRows) {
      final membership = row.readTable(database.contactTagMemberships);
      final tag = row.readTable(database.contactTags);
      tagNamesByContact
          .putIfAbsent(membership.contactId, () => <String>[])
          .add(tag.name);
      tagIdsByContact
          .putIfAbsent(membership.contactId, () => <String>{})
          .add(tag.id);
    }
    final availabilityRows = await (database.select(
      database.contactAvailabilities,
    )..where((table) => table.contactId.isIn(ids))).get();
    final weekdaysByContact = <String, Set<int>>{};
    for (final row in availabilityRows) {
      weekdaysByContact
          .putIfAbsent(row.contactId, () => <int>{})
          .add(row.weekday);
    }

    final eventContext = await _eventContextForContacts(ids, today);
    final filtered = <ContactRow>[];
    for (final row in contactRows) {
      final contactId = row.id;
      if (criteria.hasPhone &&
          !(methodsByContact[contactId]?.any((m) => m.type == 'phone') ??
              false)) {
        continue;
      }
      if (criteria.hasEmail &&
          !(methodsByContact[contactId]?.any((m) => m.type == 'email') ??
              false)) {
        continue;
      }
      final groupIds = groupIdsByContact[contactId] ?? const <String>{};
      if (criteria.groupIds.isNotEmpty &&
          !criteria.groupIds.any(groupIds.contains)) {
        continue;
      }
      final tagIds = tagIdsByContact[contactId] ?? const <String>{};
      if (criteria.tagIds.isNotEmpty && !criteria.tagIds.any(tagIds.contains)) {
        continue;
      }
      final weekdays = weekdaysByContact[contactId] ?? const <int>{};
      if (criteria.availabilityWeekdays.isNotEmpty &&
          !criteria.availabilityWeekdays.any(weekdays.contains)) {
        continue;
      }
      final context = eventContext[contactId] ?? const ContactListContext();
      if (criteria.withEventsToday &&
          !(context.nextEventDate == today || context.lastEventDate == today)) {
        continue;
      }
      if (criteria.withFutureEvents && context.nextEventDate == null) {
        continue;
      }
      if (criteria.withoutFutureEvents && context.nextEventDate != null) {
        continue;
      }
      if (criteria.noInteractionYet &&
          context.nextEventDate != null &&
          context.lastEventDate != null) {
        continue;
      }
      if (criteria.eventHistoryAny && context.lastEventDate == null) {
        continue;
      }
      filtered.add(row);
    }
    return filtered
        .map((row) {
          final primary = primaryGroupByContact[row.id];
          return ContactSummary(
            contact: _contactFromRow(row),
            primaryGroup: primary == null ? null : _groupFromRow(primary),
            groupNames: List<String>.unmodifiable(
              groupNamesByContact[row.id] ?? const <String>[],
            ),
            tagNames: List<String>.unmodifiable(
              tagNamesByContact[row.id] ?? const <String>[],
            ),
            context: eventContext[row.id] ?? const ContactListContext(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<ContactSummary>> searchContacts({
    required String profileId,
    required String query,
    required PlannerDate today,
  }) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return const <ContactSummary>[];
    }
    final rows =
        await (database.select(database.contacts)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.lifecycleState.equals(
                    ContactLifecycleState.active.name,
                  ),
            ))
            .get();
    final ids = rows.map((row) => row.id).toList(growable: false);
    if (ids.isEmpty) {
      return const <ContactSummary>[];
    }
    final methods = await (database.select(
      database.contactMethods,
    )..where((table) => table.contactId.isIn(ids))).get();
    final methodsByContact = <String, List<ContactMethodRow>>{};
    for (final method in methods) {
      methodsByContact
          .putIfAbsent(method.contactId, () => <ContactMethodRow>[])
          .add(method);
    }
    final membershipRows =
        await (database.select(database.contactGroupMemberships).join([
          innerJoin(
            database.contactGroups,
            database.contactGroups.id.equalsExp(
              database.contactGroupMemberships.groupId,
            ),
          ),
        ])..where(database.contactGroupMemberships.contactId.isIn(ids))).get();
    final groupNamesByContact = <String, List<String>>{};
    final primaryGroupByContact = <String, ContactGroupRow>{};
    for (final row in membershipRows) {
      final membership = row.readTable(database.contactGroupMemberships);
      final group = row.readTable(database.contactGroups);
      if (group.isArchived) {
        continue;
      }
      if (membership.isPrimary) {
        primaryGroupByContact[membership.contactId] = group;
      }
      // Search covers every group name — primary or secondary.
      groupNamesByContact
          .putIfAbsent(membership.contactId, () => <String>[])
          .add(group.name);
    }
    final tagRows = await (database.select(database.contactTags).join([
      innerJoin(
        database.contactTagMemberships,
        database.contactTagMemberships.tagId.equalsExp(database.contactTags.id),
      ),
    ])..where(database.contactTagMemberships.contactId.isIn(ids))).get();
    final tagNamesByContact = <String, List<String>>{};
    for (final row in tagRows) {
      final membership = row.readTable(database.contactTagMemberships);
      tagNamesByContact
          .putIfAbsent(membership.contactId, () => <String>[])
          .add(row.readTable(database.contactTags).name);
    }
    final matches = <ContactRow>[];
    for (final row in rows) {
      if (row.displayName.toLowerCase().contains(needle) ||
          (row.firstName ?? '').toLowerCase().contains(needle) ||
          (row.lastName ?? '').toLowerCase().contains(needle) ||
          (row.addressText ?? '').toLowerCase().contains(needle)) {
        matches.add(row);
        continue;
      }
      final methodValues =
          (methodsByContact[row.id] ?? const <ContactMethodRow>[])
              .map((m) => '${m.rawValue} ${m.normalizedValue} ${m.label ?? ''}')
              .join(' ')
              .toLowerCase();
      if (methodValues.contains(needle)) {
        matches.add(row);
        continue;
      }
      if ((groupNamesByContact[row.id] ?? const <String>[]).any(
        (name) => name.toLowerCase().contains(needle),
      )) {
        matches.add(row);
        continue;
      }
      if ((tagNamesByContact[row.id] ?? const <String>[]).any(
        (name) => name.toLowerCase().contains(needle),
      )) {
        matches.add(row);
      }
    }
    if (matches.isEmpty) {
      return const <ContactSummary>[];
    }
    final matchIds = matches.map((row) => row.id).toList(growable: false);
    final eventContext = await _eventContextForContacts(matchIds, today);
    return matches
        .map((row) {
          final primary = primaryGroupByContact[row.id];
          return ContactSummary(
            contact: _contactFromRow(row),
            primaryGroup: primary == null ? null : _groupFromRow(primary),
            groupNames: List<String>.unmodifiable(
              groupNamesByContact[row.id] ?? const <String>[],
            ),
            tagNames: List<String>.unmodifiable(
              tagNamesByContact[row.id] ?? const <String>[],
            ),
            context: eventContext[row.id] ?? const ContactListContext(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Map<String, ContactSummary>> readContactsByIds({
    required String profileId,
    required List<String> contactIds,
    required PlannerDate today,
  }) async {
    final ids = contactIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return const <String, ContactSummary>{};
    }
    final rows = await (database.select(
      database.contacts,
    )..where((table) => table.id.isIn(ids))).get();
    if (rows.isEmpty) {
      return const <String, ContactSummary>{};
    }
    final summaries = await _summariesForContactRows(
      profileId: profileId,
      rows: rows,
      today: today,
    );
    return <String, ContactSummary>{
      for (final summary in summaries) summary.contact.id: summary,
    };
  }

  // -- Groups ---------------------------------------------------------------

  @override
  Future<List<ContactGroup>> readGroups(
    String profileId, {
    bool includeArchived = false,
  }) async {
    final query = database.select(database.contactGroups);
    var where = database.contactGroups.profileId.equals(profileId);
    if (!includeArchived) {
      where = where & database.contactGroups.isArchived.equals(false);
    }
    query
      ..where((table) => where)
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.name),
      ]);
    final rows = await query.get();
    return rows.map(_groupFromRow).toList(growable: false);
  }

  @override
  Future<ContactGroup> createGroup({
    required String profileId,
    required String name,
    required int colorValue,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const ContactValidationException('Group name cannot be blank.');
    }
    final now = clock.nowUtc();
    final id = identifiers.nextUuid();
    await database
        .into(database.contactGroups)
        .insert(
          ContactGroupsCompanion.insert(
            id: id,
            profileId: profileId,
            name: normalized,
            colorValue: colorValue,
            isArchived: const Value<bool>(false),
            sortOrder: const Value<int>(0),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final row =
        await (database.select(database.contactGroups)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) & table.id.equals(id),
              )
              ..limit(1))
            .getSingle();
    return _groupFromRow(row);
  }

  @override
  Future<ContactGroup> updateGroup({
    required String profileId,
    required String groupId,
    required String name,
    required int colorValue,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const ContactValidationException('Group name cannot be blank.');
    }
    final updated =
        await (database.update(database.contactGroups)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(groupId),
            ))
            .write(
              ContactGroupsCompanion(
                name: Value<String>(normalized),
                colorValue: Value<int>(colorValue),
                updatedAtUtc: Value<DateTime>(clock.nowUtc()),
              ),
            );
    if (updated == 0) {
      throw const ContactValidationException('Group not found.');
    }
    final row =
        await (database.select(database.contactGroups)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(groupId),
              )
              ..limit(1))
            .getSingle();
    return _groupFromRow(row);
  }

  @override
  Future<void> archiveGroup({
    required String profileId,
    required String groupId,
  }) async {
    await (database.update(database.contactGroups)..where(
          (table) =>
              table.profileId.equals(profileId) & table.id.equals(groupId),
        ))
        .write(
          ContactGroupsCompanion(
            isArchived: const Value<bool>(true),
            updatedAtUtc: Value<DateTime>(clock.nowUtc()),
          ),
        );
    // An archived group can no longer be anyone's primary group.
    await (database.update(database.contactGroupMemberships)..where(
          (table) =>
              table.groupId.equals(groupId) & table.isPrimary.equals(true),
        ))
        .write(
          const ContactGroupMembershipsCompanion(isPrimary: Value<bool>(false)),
        );
  }

  @override
  Future<void> setContactGroups({
    required String profileId,
    required String contactId,
    required List<String> groupIds,
    String? primaryGroupId,
  }) async {
    final normalizedIds = groupIds.toSet().toList(growable: false);
    final primary = normalizedIds.contains(primaryGroupId)
        ? primaryGroupId
        : null;
    await database.transaction(() async {
      await (database.delete(
        database.contactGroupMemberships,
      )..where((table) => table.contactId.equals(contactId))).go();
      await database.batch((batch) {
        for (final groupId in normalizedIds) {
          batch.insert(
            database.contactGroupMemberships,
            ContactGroupMembershipsCompanion.insert(
              contactId: contactId,
              groupId: groupId,
              isPrimary: Value<bool>(groupId == primary),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
      if (primary != null) {
        await (database.update(database.contactGroupMemberships)..where(
              (table) =>
                  table.contactId.equals(contactId) &
                  table.groupId.equals(primary),
            ))
            .write(
              const ContactGroupMembershipsCompanion(
                isPrimary: Value<bool>(true),
              ),
            );
        await (database.update(database.contactGroupMemberships)..where(
              (table) =>
                  table.contactId.equals(contactId) &
                  table.groupId.isNotValue(primary) &
                  table.isPrimary.equals(true),
            ))
            .write(
              const ContactGroupMembershipsCompanion(
                isPrimary: Value<bool>(false),
              ),
            );
      }
    });
  }

  // -- Tags -----------------------------------------------------------------

  @override
  Future<List<ContactTag>> readTags(String profileId) async {
    final rows =
        await (database.select(database.contactTags)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy([(table) => OrderingTerm.asc(table.name)]))
            .get();
    return rows.map(_tagFromRow).toList(growable: false);
  }

  Future<void> _replaceTags(
    String profileId, {
    required String contactId,
    required List<String> tagNames,
  }) async {
    final tagIds = <String>[];
    for (final rawName in tagNames) {
      final name = rawName.trim();
      if (name.isEmpty) {
        continue;
      }
      var row =
          await (database.select(database.contactTags)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.name.equals(name),
                )
                ..limit(1))
              .getSingleOrNull();
      if (row == null) {
        final id = identifiers.nextUuid();
        await database
            .into(database.contactTags)
            .insert(
              ContactTagsCompanion.insert(
                id: id,
                profileId: profileId,
                name: name,
                createdAtUtc: clock.nowUtc(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        row =
            await (database.select(database.contactTags)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.name.equals(name),
                  )
                  ..limit(1))
                .getSingle();
      }
      tagIds.add(row.id);
    }
    await (database.delete(
      database.contactTagMemberships,
    )..where((table) => table.contactId.equals(contactId))).go();
    await database.batch((batch) {
      for (final tagId in tagIds) {
        batch.insert(
          database.contactTagMemberships,
          ContactTagMembershipsCompanion.insert(
            contactId: contactId,
            tagId: tagId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  // -- Notes ----------------------------------------------------------------

  @override
  Future<ContactNote> addNote({
    required String profileId,
    required String contactId,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw const ContactValidationException('Note cannot be blank.');
    }
    final now = clock.nowUtc();
    final id = identifiers.nextUuid();
    await database
        .into(database.contactNotes)
        .insert(
          ContactNotesCompanion.insert(
            id: id,
            contactId: contactId,
            noteText: normalized,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    final row =
        await (database.select(database.contactNotes)
              ..where((table) => table.id.equals(id))
              ..limit(1))
            .getSingle();
    return _noteFromRow(row);
  }

  Future<String> _ownedNoteContactId(String noteId, String profileId) async {
    final note =
        await (database.select(database.contactNotes)
              ..where((table) => table.id.equals(noteId))
              ..limit(1))
            .getSingleOrNull();
    if (note == null) {
      return '';
    }
    final contact =
        await (database.select(database.contacts)
              ..where((table) => table.id.equals(note.contactId))
              ..limit(1))
            .getSingleOrNull();
    if (contact == null || contact.profileId != profileId) {
      return '';
    }
    return note.contactId;
  }

  @override
  Future<ContactNote> updateNote({
    required String profileId,
    required String noteId,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw const ContactValidationException('Note cannot be blank.');
    }
    if (await _ownedNoteContactId(noteId, profileId) == '') {
      throw const ContactValidationException('Note not found.');
    }
    await (database.update(
      database.contactNotes,
    )..where((table) => table.id.equals(noteId))).write(
      ContactNotesCompanion(
        noteText: Value<String>(normalized),
        updatedAtUtc: Value<DateTime>(clock.nowUtc()),
      ),
    );
    final row =
        await (database.select(database.contactNotes)
              ..where((table) => table.id.equals(noteId))
              ..limit(1))
            .getSingle();
    return _noteFromRow(row);
  }

  @override
  Future<void> deleteNote({
    required String profileId,
    required String noteId,
  }) async {
    if (await _ownedNoteContactId(noteId, profileId) == '') {
      return;
    }
    await (database.delete(
      database.contactNotes,
    )..where((table) => table.id.equals(noteId))).go();
  }

  // -- Availability ---------------------------------------------------------

  @override
  Future<void> setAvailability({
    required String profileId,
    required String contactId,
    required List<ContactAvailability> windows,
  }) async {
    final valid = <ContactAvailability>[];
    for (final window in windows) {
      try {
        valid.add(window.normalized());
      } on ContactValidationException {
        // Ignore invalid windows on save; the form validates first.
      }
    }
    await database.transaction(() async {
      await (database.delete(
        database.contactAvailabilities,
      )..where((table) => table.contactId.equals(contactId))).go();
      if (valid.isEmpty) {
        return;
      }
      await database.batch((batch) {
        for (final window in valid) {
          batch.insert(
            database.contactAvailabilities,
            ContactAvailabilitiesCompanion.insert(
              id: identifiers.nextUuid(),
              contactId: contactId,
              weekday: window.weekday,
              startMinute: window.startMinute,
              endMinute: window.endMinute,
              createdAtUtc: clock.nowUtc(),
            ),
          );
        }
      });
    });
  }

  // -- Saved filters --------------------------------------------------------

  @override
  Future<List<SavedContactFilter>> readSavedFilters(String profileId) async {
    final rows =
        await (database.select(database.savedContactFilters)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAtUtc)]))
            .get();
    return rows.map(_filterFromRow).toList(growable: false);
  }

  @override
  Future<SavedContactFilter> saveSavedFilter({
    required String profileId,
    required SavedContactFilterDraft draft,
  }) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const ContactValidationException('Filter name cannot be blank.');
    }
    final now = clock.nowUtc();
    final id = identifiers.nextUuid();
    await database
        .into(database.savedContactFilters)
        .insert(
          SavedContactFiltersCompanion.insert(
            id: id,
            profileId: profileId,
            name: name,
            isSystem: Value<bool>(draft.isSystem),
            criteriaJson: draft.criteria.encode(),
            sortBy: Value<String>(draft.sortBy.name),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    final row =
        await (database.select(database.savedContactFilters)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) & table.id.equals(id),
              )
              ..limit(1))
            .getSingle();
    return _filterFromRow(row);
  }

  @override
  Future<void> deleteSavedFilter({
    required String profileId,
    required String filterId,
  }) async {
    final row =
        await (database.select(database.savedContactFilters)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(filterId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return;
    }
    if (row.isSystem) {
      throw const ContactValidationException(
        'System filters cannot be deleted.',
      );
    }
    await (database.delete(database.savedContactFilters)..where(
          (table) =>
              table.profileId.equals(profileId) & table.id.equals(filterId),
        ))
        .go();
  }

  // -- Planner links --------------------------------------------------------

  @override
  Future<void> setEventPeople({
    required String profileId,
    required String eventId,
    required String occurrenceId,
    PlannerDate? originalDate,
    required List<String> contactIds,
  }) async {
    final normalizedIds = contactIds.toSet().toList(growable: false);
    await database.transaction(() async {
      final existing =
          await (database.select(database.eventContactLinks)..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.eventId.equals(eventId) &
                    table.occurrenceId.equals(occurrenceId) &
                    table.status.equals('active'),
              ))
              .get();
      final existingIds = existing.map((row) => row.contactId).toSet();
      final removedIds = existingIds.difference(normalizedIds.toSet());
      // Freeze every past occurrence that a removed series-level participant
      // was on BEFORE removing the link, so history can never be erased.
      if (removedIds.isNotEmpty) {
        await _freezeRemovedParticipants(
          profileId: profileId,
          eventId: eventId,
          removedIds: removedIds.toList(growable: false),
          occurrenceId: occurrenceId,
          originalDate: originalDate,
        );
      }
      await (database.delete(database.eventContactLinks)..where(
            (table) =>
                table.profileId.equals(profileId) &
                table.eventId.equals(eventId) &
                table.occurrenceId.equals(occurrenceId),
          ))
          .go();
      final now = clock.nowUtc();
      await database.batch((batch) {
        for (final contactId in normalizedIds) {
          batch.insert(
            database.eventContactLinks,
            EventContactLinksCompanion.insert(
              id: identifiers.nextUuid(),
              profileId: profileId,
              eventId: eventId,
              occurrenceId: Value<String>(occurrenceId),
              originalDate: Value<String?>(
                occurrenceId == seriesOccurrenceId
                    ? null
                    : originalDate?.iso8601,
              ),
              contactId: contactId,
              status: const Value<String>('active'),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    });
  }

  Future<void> _freezeRemovedParticipants({
    required String profileId,
    required String eventId,
    required List<String> removedIds,
    required String occurrenceId,
    required PlannerDate? originalDate,
  }) async {
    final event =
        await (database.select(database.calendarEvents)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(eventId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (event == null) {
      return;
    }
    final today = PlannerDate.fromDateTime(clock.nowUtc().toLocal());
    final dates = occurrenceId == seriesOccurrenceId
        ? _seriesDates(event, today, nextLimit: 0, pastLimit: 500)
        : <PlannerDate>[?originalDate];
    final contacts = await (database.select(
      database.contacts,
    )..where((table) => table.id.isIn(removedIds))).get();
    final contactsById = {for (final row in contacts) row.id: row};
    final memberships =
        await (database.select(database.contactGroupMemberships).join([
              innerJoin(
                database.contactGroups,
                database.contactGroups.id.equalsExp(
                  database.contactGroupMemberships.groupId,
                ),
              ),
            ])..where(
              database.contactGroupMemberships.contactId.isIn(removedIds) &
                  database.contactGroupMemberships.isPrimary.equals(true),
            ))
            .get();
    final colorByContact = <String, int?>{
      for (final row in memberships)
        row.readTable(database.contactGroupMemberships).contactId: row
            .readTable(database.contactGroups)
            .colorValue,
    };
    final now = clock.nowUtc();
    await database.batch((batch) {
      for (final date in dates) {
        if (date.compareTo(today) >= 0) {
          continue;
        }
        final occurrenceIdForDate = CalendarEventOccurrenceIdentity.forDate(
          eventId: eventId,
          originalDate: date,
        );
        for (final contactId in removedIds) {
          final contact = contactsById[contactId];
          batch.insert(
            database.eventOccurrenceParticipants,
            EventOccurrenceParticipantsCompanion.insert(
              id: identifiers.nextUuid(),
              profileId: profileId,
              eventId: eventId,
              occurrenceId: occurrenceIdForDate,
              originalDate: date.iso8601,
              contactId: contactId,
              displayNameSnapshot: contact?.displayName ?? 'Contact',
              groupColorValueSnapshot: Value<int?>(colorByContact[contactId]),
              createdAtUtc: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }

  @override
  Future<List<ContactSummary>> readEventPeople({
    required String profileId,
    required String eventId,
    required String occurrenceId,
    required PlannerDate today,
  }) async {
    final links =
        await (database.select(database.eventContactLinks)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.eventId.equals(eventId) &
                  table.occurrenceId.equals(occurrenceId) &
                  table.status.equals('active'),
            ))
            .get();
    if (links.isEmpty) {
      // Historical participation is owned by occurrence-level snapshots:
      // a series edit that removed people must not empty a past occurrence.
      if (occurrenceId == seriesOccurrenceId) {
        return const <ContactSummary>[];
      }
      final snapshotRows =
          await (database.select(database.eventOccurrenceParticipants)..where(
                (table) =>
                    table.eventId.equals(eventId) &
                    table.occurrenceId.equals(occurrenceId),
              ))
              .get();
      if (snapshotRows.isEmpty) {
        return const <ContactSummary>[];
      }
      final snapshotIds = snapshotRows
          .map((row) => row.contactId)
          .toSet()
          .toList();
      final snapshotContactRows = await (database.select(
        database.contacts,
      )..where((table) => table.id.isIn(snapshotIds))).get();
      if (snapshotContactRows.isEmpty) {
        return const <ContactSummary>[];
      }
      return _summariesForContactRows(
        profileId: profileId,
        rows: snapshotContactRows,
        today: today,
      );
    }
    final ids = links.map((link) => link.contactId).toList(growable: false);
    final rows = await (database.select(
      database.contacts,
    )..where((table) => table.id.isIn(ids))).get();
    if (rows.isEmpty) {
      return const <ContactSummary>[];
    }
    return _summariesForContactRows(
      profileId: profileId,
      rows: rows,
      today: today,
    );
  }

  @override
  Future<void> setTaskContacts({
    required String profileId,
    required String taskId,
    required List<String> contactIds,
  }) async {
    final normalizedIds = contactIds.toSet().toList(growable: false);
    await database.transaction(() async {
      await (database.delete(
        database.taskContactLinks,
      )..where((table) => table.taskId.equals(taskId))).go();
      final now = clock.nowUtc();
      await database.batch((batch) {
        for (final contactId in normalizedIds) {
          batch.insert(
            database.taskContactLinks,
            TaskContactLinksCompanion.insert(
              id: identifiers.nextUuid(),
              profileId: profileId,
              taskId: taskId,
              contactId: contactId,
              createdAtUtc: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    });
  }

  @override
  Future<List<PlannerTask>> readContactUpcomingTasks({
    required String profileId,
    required String contactId,
  }) async {
    final links = await (database.select(
      database.taskContactLinks,
    )..where((table) => table.contactId.equals(contactId))).get();
    if (links.isEmpty) {
      return const <PlannerTask>[];
    }
    final taskIds = links.map((link) => link.taskId).toSet();
    final rows =
        await (database.select(database.plannerTasks)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.isIn(taskIds) &
                    table.status.equals(PlannerTaskStatus.incomplete.name),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.dueDate)]))
            .get();
    return rows
        .map(
          (row) => PlannerTask(
            id: row.id,
            profileId: row.profileId,
            title: row.title,
            notes: row.notes,
            dueDate: row.dueDate == null
                ? null
                : PlannerDate.parse(row.dueDate!),
            dueMinute: row.dueMinute,
            recurrence:
                PlannerTaskRecurrence.values
                    .asNameMap()[row.recurrenceFrequency] ??
                PlannerTaskRecurrence.none,
            status:
                PlannerTaskStatus.values.asNameMap()[row.status] ??
                PlannerTaskStatus.incomplete,
            requiresReport: row.requiresReport,
            people: const <String>[],
            createdAtUtc: row.createdAtUtc,
            updatedAtUtc: row.updatedAtUtc,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ContactSummary>> readTaskContacts({
    required String profileId,
    required String taskId,
  }) async {
    final links = await (database.select(
      database.taskContactLinks,
    )..where((table) => table.taskId.equals(taskId))).get();
    if (links.isEmpty) {
      return const <ContactSummary>[];
    }
    final ids = links.map((link) => link.contactId).toList(growable: false);
    final rows = await (database.select(
      database.contacts,
    )..where((table) => table.id.isIn(ids))).get();
    return _summariesForContactRows(
      profileId: profileId,
      rows: rows,
      today: PlannerDate.fromDateTime(clock.nowUtc().toLocal()),
    );
  }

  // -- Timeline -------------------------------------------------------------

  @override
  Future<ContactTimeline> readTimeline({
    required String profileId,
    required String contactId,
    required PlannerDate today,
  }) async {
    final detail = await readContactDetail(
      profileId: profileId,
      contactId: contactId,
    );
    final links =
        await (database.select(database.eventContactLinks)..where(
              (table) =>
                  table.contactId.equals(contactId) &
                  table.status.equals('active'),
            ))
            .get();
    // Immutable occurrence-level participant snapshots are the canonical
    // historical record: a series People edit that removed this Contact must
    // never erase their past participation.
    final snapshots = await (database.select(
      database.eventOccurrenceParticipants,
    )..where((table) => table.contactId.equals(contactId))).get();
    final eventIds = <String>{
      for (final link in links) link.eventId,
      for (final snapshot in snapshots) snapshot.eventId,
    };
    final events = eventIds.isEmpty
        ? const <CalendarEventRow>[]
        : await (database.select(database.calendarEvents)..where(
                (table) =>
                    table.profileId.equals(profileId) & table.id.isIn(eventIds),
              ))
              .get();
    final eventsById = {for (final event in events) event.id: event};
    final exceptions = eventIds.isEmpty
        ? const <CalendarEventExceptionRow>[]
        : await (database.select(database.calendarEventExceptions)..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.eventId.isIn(eventIds),
              ))
              .get();
    final exceptionsByKey = <String, CalendarEventExceptionRow>{
      for (final row in exceptions) '${row.eventId}:${row.occurrenceId}': row,
    };

    final upcoming = <ContactTimelineEntry>[];
    final history = <ContactTimelineEntry>[];
    final freezeTargets = <(String, PlannerDate)>[];

    for (final link in links) {
      final event = eventsById[link.eventId];
      if (event == null) {
        continue;
      }
      final dates = link.occurrenceId == seriesOccurrenceId
          ? _seriesDates(event, today, nextLimit: 30, pastLimit: 500)
          : <PlannerDate>[
              if (link.originalDate != null)
                PlannerDate.parse(link.originalDate!),
            ];
      for (final date in dates) {
        final occurrenceIdForDate = CalendarEventOccurrenceIdentity.forDate(
          eventId: event.id,
          originalDate: date,
        );
        final exception = exceptionsByKey['${event.id}:$occurrenceIdForDate'];
        final effectiveDate = exception == null
            ? date
            : PlannerDate.parse(exception.effectiveDate);
        final status = exception == null
            ? _statusFromRow(event.status)
            : _statusFromRow(exception.status);
        final isCancelled = status == CalendarEventStatus.cancelled;
        final isUpcoming = effectiveDate.compareTo(today) >= 0 && !isCancelled;
        final entry = ContactTimelineEntry(
          kind: ContactTimelineKind.eventOccurrence,
          date: effectiveDate,
          title: _eventDisplayTitle(event, exception),
          subtitle: _occurrenceTimeLabel(event, exception),
          status: status,
          statusLabel: _timelineStatusLabel(
            status,
            isPast: effectiveDate.compareTo(today) < 0,
            requiresReport: exception?.requiresReport ?? event.requiresReport,
          ),
          eventId: event.id,
          originalDate: date,
          occurrenceId: occurrenceIdForDate,
          isUpcoming: isUpcoming,
        );
        if (isUpcoming) {
          upcoming.add(entry);
        } else {
          history.add(entry);
          freezeTargets.add((event.id, date));
        }
      }
    }

    // Freeze historical participation so later series edits cannot erase it.
    final primaryColor = await _primaryGroupColor(profileId, contactId);
    for (final target in freezeTargets) {
      await _freezeSingleParticipant(
        profileId: profileId,
        eventId: target.$1,
        date: target.$2,
        contact: detail.contact,
        primaryColor: primaryColor,
      );
    }

    // Merge frozen snapshots into history, deduped against series-derived
    // entries so a still-linked past occurrence never appears twice.
    final seenKeys = <String>{
      for (final entry in history) '${entry.eventId}:${entry.originalDate}',
    };
    for (final snapshot in snapshots) {
      final event = eventsById[snapshot.eventId];
      if (event == null) {
        continue;
      }
      final key = '${snapshot.eventId}:${snapshot.originalDate}';
      if (seenKeys.contains(key)) {
        continue;
      }
      seenKeys.add(key);
      final date = PlannerDate.parse(snapshot.originalDate);
      final exception = exceptionsByKey['${event.id}:${snapshot.occurrenceId}'];
      final effectiveDate = exception == null
          ? date
          : PlannerDate.parse(exception.effectiveDate);
      final status = exception == null
          ? _statusFromRow(event.status)
          : _statusFromRow(exception.status);
      history.add(
        ContactTimelineEntry(
          kind: ContactTimelineKind.eventOccurrence,
          date: effectiveDate,
          title: _eventDisplayTitle(event, exception),
          subtitle: _occurrenceTimeLabel(event, exception),
          status: status,
          statusLabel: _timelineStatusLabel(
            status,
            isPast: effectiveDate.compareTo(today) < 0,
            requiresReport: exception?.requiresReport ?? event.requiresReport,
          ),
          eventId: event.id,
          originalDate: date,
          occurrenceId: snapshot.occurrenceId,
          isUpcoming: false,
        ),
      );
    }

    final createdLocal = detail.contact.createdAtUtc.toLocal();
    history.add(
      ContactTimelineEntry(
        kind: ContactTimelineKind.recordCreated,
        date: PlannerDate.fromDateTime(createdLocal),
        title: 'Record Created',
        subtitle: 'Contact was added',
      ),
    );

    upcoming.sort((a, b) => a.date.compareTo(b.date));
    history.sort((a, b) => b.date.compareTo(a.date));
    return ContactTimeline(upcoming: upcoming, history: history);
  }

  @override
  Future<List<CommonEventPattern>> readCommonEventPatterns({
    required String profileId,
    required String contactId,
  }) async {
    final participations = await (database.select(
      database.eventOccurrenceParticipants,
    )..where((table) => table.contactId.equals(contactId))).get();
    if (participations.isEmpty) {
      return const <CommonEventPattern>[];
    }
    final eventIds = participations.map((row) => row.eventId).toSet();
    final events =
        await (database.select(database.calendarEvents)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.isIn(eventIds),
            ))
            .get();
    final eventsById = {for (final event in events) event.id: event};
    final exceptions =
        await (database.select(database.calendarEventExceptions)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.eventId.isIn(eventIds),
            ))
            .get();
    final exceptionsByKey = <String, CalendarEventExceptionRow>{
      for (final row in exceptions) '${row.eventId}:${row.occurrenceId}': row,
    };
    final counts = <String, int>{};
    for (final participation in participations) {
      final event = eventsById[participation.eventId];
      if (event == null) {
        continue;
      }
      final exception =
          exceptionsByKey['${participation.eventId}:${participation.occurrenceId}'];
      final status = exception == null
          ? _statusFromRow(event.status)
          : _statusFromRow(exception.status);
      if (status != CalendarEventStatus.completedHappened) {
        continue;
      }
      final date = PlannerDate.parse(participation.originalDate);
      final startMinute = exception?.startMinute ?? event.startMinute;
      final key = '${participation.eventId}:${date.weekday}:$startMinute';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final patterns = <CommonEventPattern>[];
    for (final entry in counts.entries) {
      final count = entry.value;
      if (count < 2) {
        continue;
      }
      final parts = entry.key.split(':');
      final eventId = parts[0];
      final weekday = int.parse(parts[1]);
      final startMinute = parts[2] == 'null' ? null : int.tryParse(parts[2]);
      final event = eventsById[eventId];
      if (event == null) {
        continue;
      }
      patterns.add(
        CommonEventPattern(
          eventId: eventId,
          title: _eventDisplayTitle(event, null),
          weekdayLabel: _weekdayShort(weekday),
          startMinuteLabel: startMinute == null
              ? 'All day'
              : _formatMinute(startMinute),
          count: count,
        ),
      );
    }
    patterns.sort((a, b) => b.count.compareTo(a.count));
    return patterns;
  }

  // -- Merge / duplicates ---------------------------------------------------

  @override
  Future<List<List<Contact>>> readDuplicateCandidates(String profileId) async {
    final contacts =
        await (database.select(database.contacts)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.lifecycleState.equals(
                    ContactLifecycleState.active.name,
                  ),
            ))
            .get();
    if (contacts.length < 2) {
      return const <List<Contact>>[];
    }
    final methods =
        await (database.select(database.contactMethods)..where(
              (table) =>
                  table.contactId.isIn(contacts.map((row) => row.id).toList()),
            ))
            .get();
    final contactsById = {for (final row in contacts) row.id: row};
    final byNormalized = <String, Set<String>>{};
    for (final method in methods) {
      if (method.type != 'phone' && method.type != 'email') {
        continue;
      }
      final normalized = method.normalizedValue.trim().toLowerCase();
      if (normalized.isEmpty) {
        continue;
      }
      byNormalized
          .putIfAbsent(normalized, () => <String>{})
          .add(method.contactId);
    }
    final groups = <List<Contact>>[];
    final seen = <String>{};
    for (final ids in byNormalized.values) {
      if (ids.length < 2) {
        continue;
      }
      final sorted = ids.toList()..sort();
      final key = sorted.join('|');
      if (!seen.add(key)) {
        continue;
      }
      final members = <Contact>[
        for (final id in sorted)
          if (contactsById[id] != null) _contactFromRow(contactsById[id]!),
      ];
      if (members.length >= 2) {
        groups.add(members);
      }
    }
    groups.sort((a, b) => a.length.compareTo(b.length));
    return groups;
  }

  @override
  Future<ContactMergePlan> readMergePlan({
    required String profileId,
    required String survivorId,
    required List<String> absorbedIds,
  }) async {
    final survivor = await readContactDetail(
      profileId: profileId,
      contactId: survivorId,
    );
    final absorbed = <Contact>[];
    var absorbedLinks = 0;
    var absorbedNotes = 0;
    for (final id in absorbedIds) {
      final detail = await readContactDetail(
        profileId: profileId,
        contactId: id,
      );
      absorbed.add(detail.contact);
      absorbedLinks +=
          await (database.select(database.eventContactLinks)
                ..where((table) => table.contactId.equals(id)))
              .get()
              .then((rows) => rows.length);
      absorbedNotes += detail.notes.length;
    }
    final survivorLinks = (await (database.select(
      database.eventContactLinks,
    )..where((table) => table.contactId.equals(survivorId))).get()).length;
    return ContactMergePlan(
      survivor: survivor.contact,
      absorbed: absorbed,
      survivorLinkCount: survivorLinks,
      absorbedLinkCount: absorbedLinks,
      absorbedNoteCount: absorbedNotes,
    );
  }

  @override
  Future<Contact> mergeContacts({
    required String profileId,
    required String survivorId,
    required List<String> absorbedIds,
    required ContactMergeChoices choices,
  }) async {
    if (absorbedIds.contains(survivorId)) {
      throw const ContactMergeException(
        'Survivor cannot be an absorbed Contact.',
      );
    }
    final now = clock.nowUtc();
    return database.transaction(() async {
      final survivorRow =
          await (database.select(database.contacts)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.id.equals(survivorId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (survivorRow == null) {
        throw const ContactMergeException('Survivor Contact not found.');
      }
      final survivor = _contactFromRow(survivorRow);
      final survivorMethods = await (database.select(
        database.contactMethods,
      )..where((table) => table.contactId.equals(survivorId))).get();
      final survivorMethodKeys = survivorMethods
          .map((m) => '${m.type}:${m.normalizedValue.toLowerCase()}')
          .toSet();
      final survivorMemberships = await (database.select(
        database.contactGroupMemberships,
      )..where((table) => table.contactId.equals(survivorId))).get();
      final survivorGroupIds = survivorMemberships
          .map((row) => row.groupId)
          .toSet();
      final survivorTags = await (database.select(
        database.contactTagMemberships,
      )..where((table) => table.contactId.equals(survivorId))).get();
      final survivorTagIds = survivorTags.map((row) => row.tagId).toSet();
      final survivorEventLinks = await (database.select(
        database.eventContactLinks,
      )..where((table) => table.contactId.equals(survivorId))).get();
      final survivorEventLinkKeys = survivorEventLinks
          .map((row) => '${row.eventId}:${row.occurrenceId}')
          .toSet();
      final survivorParticipantKeys =
          (await (database.select(
                database.eventOccurrenceParticipants,
              )..where((table) => table.contactId.equals(survivorId))).get())
              .map((row) => '${row.eventId}:${row.occurrenceId}')
              .toSet();
      final survivorTaskLinks = await (database.select(
        database.taskContactLinks,
      )..where((table) => table.contactId.equals(survivorId))).get();
      final survivorTaskLinkKeys = survivorTaskLinks
          .map((row) => row.taskId)
          .toSet();

      for (final absorbedId in absorbedIds) {
        final absorbedRow =
            await (database.select(database.contacts)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.id.equals(absorbedId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (absorbedRow == null) {
          continue;
        }
        // Methods: keep survivor's; add absorbed ones that do not collide.
        final absorbedMethods = await (database.select(
          database.contactMethods,
        )..where((table) => table.contactId.equals(absorbedId))).get();
        for (final method in absorbedMethods) {
          final key = '${method.type}:${method.normalizedValue.toLowerCase()}';
          if (survivorMethodKeys.contains(key)) {
            await (database.delete(
              database.contactMethods,
            )..where((table) => table.id.equals(method.id))).go();
            continue;
          }
          survivorMethodKeys.add(key);
          await (database.update(
            database.contactMethods,
          )..where((table) => table.id.equals(method.id))).write(
            ContactMethodsCompanion(
              contactId: Value<String>(survivorId),
              isPrimary: const Value<bool>(false),
            ),
          );
        }
        // Groups: add missing memberships.
        final absorbedMemberships = await (database.select(
          database.contactGroupMemberships,
        )..where((table) => table.contactId.equals(absorbedId))).get();
        for (final membership in absorbedMemberships) {
          if (survivorGroupIds.add(membership.groupId)) {
            await database
                .into(database.contactGroupMemberships)
                .insert(
                  ContactGroupMembershipsCompanion.insert(
                    contactId: survivorId,
                    groupId: membership.groupId,
                    isPrimary: const Value<bool>(false),
                  ),
                );
          }
        }
        await (database.delete(
          database.contactGroupMemberships,
        )..where((table) => table.contactId.equals(absorbedId))).go();
        // Tags: add missing.
        final absorbedTags = await (database.select(
          database.contactTagMemberships,
        )..where((table) => table.contactId.equals(absorbedId))).get();
        for (final membership in absorbedTags) {
          if (survivorTagIds.add(membership.tagId)) {
            await database
                .into(database.contactTagMemberships)
                .insert(
                  ContactTagMembershipsCompanion.insert(
                    contactId: survivorId,
                    tagId: membership.tagId,
                  ),
                );
          }
        }
        await (database.delete(
          database.contactTagMemberships,
        )..where((table) => table.contactId.equals(absorbedId))).go();
        // Notes move to the survivor (same IDs, new owner).
        await (database.update(database.contactNotes)
              ..where((table) => table.contactId.equals(absorbedId)))
            .write(ContactNotesCompanion(contactId: Value<String>(survivorId)));
        // Availability moves to the survivor.
        await (database.update(
          database.contactAvailabilities,
        )..where((table) => table.contactId.equals(absorbedId))).write(
          ContactAvailabilitiesCompanion(contactId: Value<String>(survivorId)),
        );
        // Event links: dedupe then re-own.
        final absorbedLinks = await (database.select(
          database.eventContactLinks,
        )..where((table) => table.contactId.equals(absorbedId))).get();
        for (final link in absorbedLinks) {
          final key = '${link.eventId}:${link.occurrenceId}';
          if (!survivorEventLinkKeys.add(key)) {
            await (database.delete(
              database.eventContactLinks,
            )..where((table) => table.id.equals(link.id))).go();
            continue;
          }
          await (database.update(
            database.eventContactLinks,
          )..where((table) => table.id.equals(link.id))).write(
            EventContactLinksCompanion(contactId: Value<String>(survivorId)),
          );
        }
        // Participant snapshots: dedupe then re-own.
        final absorbedParticipants = await (database.select(
          database.eventOccurrenceParticipants,
        )..where((table) => table.contactId.equals(absorbedId))).get();
        for (final participant in absorbedParticipants) {
          final key = '${participant.eventId}:${participant.occurrenceId}';
          if (!survivorParticipantKeys.add(key)) {
            await (database.delete(
              database.eventOccurrenceParticipants,
            )..where((table) => table.id.equals(participant.id))).go();
            continue;
          }
          await (database.update(
            database.eventOccurrenceParticipants,
          )..where((table) => table.id.equals(participant.id))).write(
            EventOccurrenceParticipantsCompanion(
              contactId: Value<String>(survivorId),
            ),
          );
        }
        // Task links: dedupe then re-own.
        final absorbedTaskLinks = await (database.select(
          database.taskContactLinks,
        )..where((table) => table.contactId.equals(absorbedId))).get();
        for (final link in absorbedTaskLinks) {
          if (!survivorTaskLinkKeys.add(link.taskId)) {
            await (database.delete(
              database.taskContactLinks,
            )..where((table) => table.id.equals(link.id))).go();
            continue;
          }
          await (database.update(
            database.taskContactLinks,
          )..where((table) => table.id.equals(link.id))).write(
            TaskContactLinksCompanion(contactId: Value<String>(survivorId)),
          );
        }
        // Absorb the row into a traceable tombstone.
        await (database.update(
          database.contacts,
        )..where((table) => table.id.equals(absorbedId))).write(
          ContactsCompanion(
            lifecycleState: Value<String>(ContactLifecycleState.merged.name),
            mergedIntoContactId: Value<String?>(survivorId),
            updatedAtUtc: Value<DateTime>(now),
          ),
        );
      }

      // Apply field-level choices to the survivor.  The absorbed rows are
      // loaded up front so per-field value choices can resolve by ID.
      final absorbedRowsCache = <String, Contact>{};
      for (final id in absorbedIds) {
        final detail = await readContactDetail(
          profileId: profileId,
          contactId: id,
        );
        absorbedRowsCache[id] = detail.contact;
      }

      String? sourceFor(String field) {
        return choices.valueFor(field, fallbackContactId: survivorId);
      }

      Contact? resolveChosen(String? contactId) {
        if (contactId == null) {
          return null;
        }
        if (contactId == survivorId) {
          return survivor;
        }
        return absorbedRowsCache[contactId];
      }

      final displaySource = resolveChosen(sourceFor('displayName'));
      final addressSource = resolveChosen(sourceFor('addressText'));
      final methodSource = resolveChosen(sourceFor('preferredContactMethod'));
      final mergedDisplay = displaySource?.displayName ?? survivor.displayName;
      final mergedAddress = addressSource?.addressText ?? survivor.addressText;
      final mergedMethod =
          methodSource?.preferredContactMethod ??
          survivor.preferredContactMethod;

      await (database.update(
        database.contacts,
      )..where((table) => table.id.equals(survivorId))).write(
        ContactsCompanion(
          firstName: Value<String?>(_splitNames(mergedDisplay).$1),
          lastName: Value<String?>(_splitNames(mergedDisplay).$2),
          displayName: Value<String>(mergedDisplay),
          addressText: Value<String?>(mergedAddress),
          preferredContactMethod: Value<String>(
            ContactPreferredMethodCodec.encode(mergedMethod),
          ),
          isFavorite: Value<bool>(
            survivor.isFavorite ||
                absorbedRowsCache.values.any((contact) => contact.isFavorite),
          ),
          updatedAtUtc: Value<DateTime>(now),
        ),
      );
      final detail = await readContactDetail(
        profileId: profileId,
        contactId: survivorId,
      );
      return detail.contact;
    });
  }

  // -- Device import --------------------------------------------------------

  @override
  Future<ContactImportResult> importDeviceContacts({
    required String profileId,
    required List<DeviceContactDraft> drafts,
  }) async {
    if (drafts.isEmpty) {
      return const ContactImportResult(
        createdCount: 0,
        skippedCount: 0,
        duplicateContactIds: <String>[],
      );
    }
    final existingContacts =
        await (database.select(database.contacts)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.lifecycleState.equals(
                    ContactLifecycleState.active.name,
                  ),
            ))
            .get();
    final existingIds = existingContacts
        .map((row) => row.id)
        .toList(growable: false);
    final existingMethods = existingIds.isEmpty
        ? const <ContactMethodRow>[]
        : await (database.select(
            database.contactMethods,
          )..where((table) => table.contactId.isIn(existingIds))).get();
    final existingNormalized = <String>{
      for (final method in existingMethods)
        if (method.normalizedValue.trim().isNotEmpty)
          '${method.type}:${method.normalizedValue.trim().toLowerCase()}',
    };
    final duplicateContactIds = <String>[];
    var created = 0;
    var skipped = 0;
    for (final draft in drafts) {
      final displayName = draft.displayName.trim();
      if (displayName.isEmpty) {
        skipped++;
        continue;
      }
      final phones = draft.phones
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      final emails = draft.emails
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toList();
      final normalizedPhone = phones.isEmpty
          ? null
          : normalizePhone(phones.first);
      final normalizedEmail = emails.isEmpty
          ? null
          : emails.first.toLowerCase();
      final phoneKey = normalizedPhone == null || normalizedPhone.isEmpty
          ? null
          : 'phone:$normalizedPhone';
      final emailKey = normalizedEmail == null || normalizedEmail.isEmpty
          ? null
          : 'email:$normalizedEmail';
      final matchedExisting = <String>[];
      if (phoneKey != null && existingNormalized.contains(phoneKey)) {
        matchedExisting.add(phoneKey);
      }
      if (emailKey != null && existingNormalized.contains(emailKey)) {
        matchedExisting.add(emailKey);
      }
      if (matchedExisting.isNotEmpty) {
        // A normalized phone/email match is advisory — we never merge and
        // never silently rewrite history.  The record is simply skipped and
        // reported so the user can decide what to do with it.
        duplicateContactIds.add(displayName);
        existingNormalized.addAll([?phoneKey, ?emailKey]);
        skipped++;
        continue;
      }
      final contactDraft = ContactDraft(
        id: identifiers.nextUuid(),
        firstName: draft.firstName ?? '',
        lastName: draft.lastName ?? '',
        displayName: displayName,
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
        source: ContactSource.deviceImport,
        methods: <ContactMethodDraft>[
          for (final phone in phones)
            ContactMethodDraft(type: ContactMethodType.phone, value: phone),
          for (final email in emails)
            ContactMethodDraft(type: ContactMethodType.email, value: email),
        ],
      );
      await createContact(profileId: profileId, draft: contactDraft);
      created++;
    }
    return ContactImportResult(
      createdCount: created,
      skippedCount: skipped,
      duplicateContactIds: duplicateContactIds,
    );
  }

  // -- Shared helpers -------------------------------------------------------

  Future<List<ContactSummary>> _summariesForContactRows({
    required String profileId,
    required List<ContactRow> rows,
    required PlannerDate today,
  }) async {
    final ids = rows.map((row) => row.id).toList(growable: false);
    final eventContext = await _eventContextForContacts(ids, today);
    final memberships =
        await (database.select(database.contactGroupMemberships).join([
          innerJoin(
            database.contactGroups,
            database.contactGroups.id.equalsExp(
              database.contactGroupMemberships.groupId,
            ),
          ),
        ])..where(database.contactGroupMemberships.contactId.isIn(ids))).get();
    final primaryGroupByContact = <String, ContactGroupRow>{};
    final secondaryByContact = <String, List<String>>{};
    for (final row in memberships) {
      final membership = row.readTable(database.contactGroupMemberships);
      final group = row.readTable(database.contactGroups);
      if (group.isArchived) {
        continue;
      }
      if (membership.isPrimary) {
        primaryGroupByContact[membership.contactId] = group;
      } else {
        secondaryByContact
            .putIfAbsent(membership.contactId, () => <String>[])
            .add(group.name);
      }
    }
    return rows
        .map((row) {
          final primary = primaryGroupByContact[row.id];
          return ContactSummary(
            contact: _contactFromRow(row),
            primaryGroup: primary == null ? null : _groupFromRow(primary),
            groupNames: List<String>.unmodifiable(
              secondaryByContact[row.id] ?? const <String>[],
            ),
            context: eventContext[row.id] ?? const ContactListContext(),
          );
        })
        .toList(growable: false);
  }

  /// Bounded, batched next/last occurrence computation for a set of
  /// Contacts.  Uses the exact same recurrence semantics as the Planner
  /// (`occurrenceIndexOn` / `occurrenceAt`), so Timeline and list rows can
  /// never disagree about a date.
  Future<Map<String, ContactListContext>> _eventContextForContacts(
    List<String> contactIds,
    PlannerDate today,
  ) async {
    if (contactIds.isEmpty) {
      return const <String, ContactListContext>{};
    }
    final links =
        await (database.select(database.eventContactLinks)..where(
              (table) =>
                  table.contactId.isIn(contactIds) &
                  table.status.equals('active'),
            ))
            .get();
    if (links.isEmpty) {
      return const <String, ContactListContext>{};
    }
    final eventIds = links.map((link) => link.eventId).toSet();
    final events = await (database.select(
      database.calendarEvents,
    )..where((table) => table.id.isIn(eventIds))).get();
    final eventsById = {for (final event in events) event.id: event};
    final exceptions = await (database.select(
      database.calendarEventExceptions,
    )..where((table) => table.eventId.isIn(eventIds))).get();
    final exceptionsByKey = <String, CalendarEventExceptionRow>{
      for (final row in exceptions) '${row.eventId}:${row.occurrenceId}': row,
    };
    final byContact = <String, List<EventContactLinkRow>>{};
    for (final link in links) {
      byContact
          .putIfAbsent(link.contactId, () => <EventContactLinkRow>[])
          .add(link);
    }
    final result = <String, ContactListContext>{};
    for (final entry in byContact.entries) {
      PlannerDate? nextDate;
      String? nextTitle;
      PlannerDate? lastDate;
      for (final link in entry.value) {
        final event = eventsById[link.eventId];
        if (event == null) {
          continue;
        }
        final dates = link.occurrenceId == seriesOccurrenceId
            ? _seriesDates(event, today, nextLimit: 20, pastLimit: 60)
            : <PlannerDate>[
                if (link.originalDate != null)
                  PlannerDate.parse(link.originalDate!),
              ];
        for (final date in dates) {
          final occurrenceIdForDate = CalendarEventOccurrenceIdentity.forDate(
            eventId: event.id,
            originalDate: date,
          );
          final exception = exceptionsByKey['${event.id}:$occurrenceIdForDate'];
          if (exception?.status == CalendarEventStatus.cancelled.name) {
            continue;
          }
          if (date.compareTo(today) >= 0) {
            if (nextDate == null || date.compareTo(nextDate) < 0) {
              nextDate = date;
              nextTitle = _eventDisplayTitle(event, exception);
            }
          } else if (lastDate == null || date.compareTo(lastDate) > 0) {
            lastDate = date;
          }
        }
      }
      result[entry.key] = ContactListContext(
        nextEventTitle: nextTitle,
        nextEventDate: nextDate,
        lastEventDate: lastDate,
      );
    }
    return result;
  }

  Future<void> _freezeSingleParticipant({
    required String profileId,
    required String eventId,
    required PlannerDate date,
    required Contact contact,
    required int? primaryColor,
  }) async {
    final now = clock.nowUtc();
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: date,
    );
    await database
        .into(database.eventOccurrenceParticipants)
        .insert(
          EventOccurrenceParticipantsCompanion.insert(
            id: identifiers.nextUuid(),
            profileId: profileId,
            eventId: eventId,
            occurrenceId: occurrenceId,
            originalDate: date.iso8601,
            contactId: contact.id,
            displayNameSnapshot: contact.displayName,
            groupColorValueSnapshot: Value<int?>(primaryColor),
            createdAtUtc: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<int?> _primaryGroupColor(String profileId, String contactId) async {
    final row =
        await (database.select(database.contactGroupMemberships).join([
                innerJoin(
                  database.contactGroups,
                  database.contactGroups.id.equalsExp(
                    database.contactGroupMemberships.groupId,
                  ),
                ),
              ])
              ..where(
                database.contactGroupMemberships.contactId.equals(contactId) &
                    database.contactGroupMemberships.isPrimary.equals(true),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.readTable(database.contactGroups).colorValue;
  }

  Future<void> _replaceMethods(
    String profileId, {
    required String contactId,
    required List<ContactMethodDraft> methods,
  }) async {
    await database.transaction(() async {
      await (database.delete(
        database.contactMethods,
      )..where((table) => table.contactId.equals(contactId))).go();
      if (methods.isEmpty) {
        return;
      }
      await database.batch((batch) {
        for (final method in methods) {
          final normalized = switch (method.type) {
            ContactMethodType.phone => normalizePhone(method.value),
            ContactMethodType.email => method.value.toLowerCase().trim(),
            ContactMethodType.social => method.value.trim(),
          };
          if (normalized.isEmpty) {
            continue;
          }
          batch.insert(
            database.contactMethods,
            ContactMethodsCompanion.insert(
              id: identifiers.nextUuid(),
              contactId: contactId,
              type: method.type.name,
              label: Value<String?>(
                method.label?.trim().isEmpty ?? true
                    ? null
                    : method.label!.trim(),
              ),
              rawValue: method.value.trim(),
              normalizedValue: normalized,
              isPrimary: Value<bool>(method.isPrimary),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    });
  }

  // -- Occurrence math ------------------------------------------------------

  CalendarRecurrenceRule _ruleFromRow(CalendarEventRow row) {
    return calendarRecurrenceRuleFromStorage(
      frequencyName: row.recurrenceFrequency,
      endModeName: row.recurrenceEndMode,
      endDateIso: row.recurrenceEndDate,
      occurrenceCount: row.recurrenceCount,
      patternJson: row.recurrencePatternJson,
    );
  }

  static int _approximateIndex(
    CalendarRecurrenceRule rule,
    PlannerDate start,
    PlannerDate target,
  ) {
    if (target.compareTo(start) <= 0) {
      return 0;
    }
    return rule.occurrenceIndexAtOrBefore(startDate: start, targetDate: target);
  }

  /// Enumerates occurrence dates for [event], bounded for list/timeline use.
  /// Only dates that satisfy `occurrenceIndexOn` are included, so monthly
  /// clamped dates behave exactly like the Planner.
  List<PlannerDate> _seriesDates(
    CalendarEventRow event,
    PlannerDate today, {
    required int nextLimit,
    required int pastLimit,
  }) {
    final rule = _ruleFromRow(event);
    final start = PlannerDate.parse(event.startDate);
    if (!rule.isRecurring) {
      return <PlannerDate>[start];
    }
    final approx = _approximateIndex(rule, start, today);
    final result = <PlannerDate>[];
    final pastBudget = pastLimit * 4 + 10;
    var index = approx - 1;
    var pastWalked = 0;
    while (index >= 0 && pastWalked < pastBudget) {
      final date = rule.occurrenceAt(startDate: start, index: index);
      if (rule.occurrenceIndexOn(startDate: start, targetDate: date) == index) {
        result.add(date);
        pastWalked++;
        if (pastWalked >= pastLimit) {
          break;
        }
      }
      index--;
      if (pastWalked == 0 && index < approx - 100) {
        // The approximation is off (e.g. clamped month); bail defensively.
        break;
      }
    }
    final upcomingBudget = nextLimit * 4 + 10;
    index = approx;
    var upcomingWalked = 0;
    while (upcomingWalked < upcomingBudget) {
      final date = rule.occurrenceAt(startDate: start, index: index);
      final verified = rule.occurrenceIndexOn(
        startDate: start,
        targetDate: date,
      );
      if (verified == index) {
        result.add(date);
        upcomingWalked++;
        if (result.where((d) => d.compareTo(today) >= 0).length >= nextLimit) {
          break;
        }
      }
      index++;
      if (upcomingWalked == 0 && index > approx + 100) {
        break;
      }
    }
    return result;
  }

  // -- Row mapping ----------------------------------------------------------

  Contact _contactFromRow(ContactRow row) {
    return Contact(
      id: row.id,
      profileId: row.profileId,
      firstName: row.firstName,
      lastName: row.lastName,
      displayName: row.displayName,
      preferredContactMethod: ContactPreferredMethodCodec.decode(
        row.preferredContactMethod,
      ),
      isFavorite: row.isFavorite,
      lifecycleState: ContactLifecycleStateCodec.decode(row.lifecycleState),
      source: ContactSourceCodec.decode(row.source),
      addressText: row.addressText,
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
      archivedAtUtc: row.archivedAtUtc,
      mergedIntoContactId: row.mergedIntoContactId,
    );
  }

  ContactMethod _methodFromRow(ContactMethodRow row) {
    return ContactMethod(
      id: row.id,
      contactId: row.contactId,
      type:
          ContactMethodType.values.asNameMap()[row.type] ??
          ContactMethodType.phone,
      label: row.label,
      rawValue: row.rawValue,
      normalizedValue: row.normalizedValue,
      isPrimary: row.isPrimary,
    );
  }

  ContactGroup _groupFromRow(ContactGroupRow row) {
    return ContactGroup(
      id: row.id,
      profileId: row.profileId,
      name: row.name,
      colorValue: row.colorValue,
      isArchived: row.isArchived,
      sortOrder: row.sortOrder,
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
    );
  }

  ContactTag _tagFromRow(ContactTagRow row) {
    return ContactTag(id: row.id, profileId: row.profileId, name: row.name);
  }

  ContactNote _noteFromRow(ContactNoteRow row) {
    return ContactNote(
      id: row.id,
      contactId: row.contactId,
      noteText: row.noteText,
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
    );
  }

  ContactAvailability _availabilityFromRow(ContactAvailabilityRow row) {
    return ContactAvailability(
      weekday: row.weekday,
      startMinute: row.startMinute,
      endMinute: row.endMinute,
    );
  }

  SavedContactFilter _filterFromRow(SavedContactFilterRow row) {
    return SavedContactFilter(
      id: row.id,
      profileId: row.profileId,
      name: row.name,
      isSystem: row.isSystem,
      criteria: ContactFilterCriteria.decode(row.criteriaJson),
      sortBy:
          ContactSortBy.values.asNameMap()[row.sortBy] ?? ContactSortBy.name,
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
    );
  }

  CalendarEventStatus _statusFromRow(String value) {
    return CalendarEventStatus.values.asNameMap()[value] ??
        CalendarEventStatus.scheduled;
  }

  static String _eventDisplayTitle(
    CalendarEventRow event,
    CalendarEventExceptionRow? exception,
  ) {
    final storedTitle = (exception?.title ?? event.title).trim();
    if (storedTitle.isNotEmpty) {
      return storedTitle;
    }
    final label =
        (exception?.activityTypeLabelSnapshot ??
                event.activityTypeLabelSnapshot)
            ?.trim();
    return label == null || label.isEmpty ? 'Calendar Event' : label;
  }

  static String _occurrenceTimeLabel(
    CalendarEventRow event,
    CalendarEventExceptionRow? exception,
  ) {
    final timing = exception?.timing ?? event.timing;
    if (timing == 'allDay') {
      return 'All day';
    }
    final start = exception?.startMinute ?? event.startMinute;
    final end = exception?.endMinute ?? event.endMinute;
    if (start == null) {
      return '';
    }
    return end == null
        ? _formatMinute(start)
        : '${_formatMinute(start)} – ${_formatMinute(end)}';
  }

  static String _timelineStatusLabel(
    CalendarEventStatus status, {
    required bool isPast,
    required bool requiresReport,
  }) {
    if (status == CalendarEventStatus.scheduled) {
      if (isPast && requiresReport) {
        return 'Report Required';
      }
      return 'Scheduled';
    }
    return calendarEventStatusLabel(status);
  }

  static String _formatMinute(int minute) {
    final hour24 = minute ~/ 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minuteText = (minute % 60).toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minuteText $period';
  }

  static String _weekdayShort(int weekday) {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }

  static (String, String) _splitNames(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return ('', '');
    }
    if (parts.length == 1) {
      return (parts.first, '');
    }
    return (parts.first, parts.sublist(1).join(' '));
  }
}

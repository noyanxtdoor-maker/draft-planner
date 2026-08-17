# VS-11 Contacts & Follow-Ups — Completion Handoff

Status: implementation complete, analyzer clean, full suite green (616 tests),
debug APK built. Physical-device verification is the one remaining gate (no
Android device or AVD exists in this environment).

## What shipped

- **Schema v22** (from v21): contacts, contact_methods, contact_groups,
  contact_group_memberships, contact_tags, contact_tag_memberships,
  contact_notes, contact_availabilities, event_contact_links,
  event_occurrence_participants (immutable occurrence snapshots),
  task_contact_links, saved_contact_filters. Migrations for v22 are additive
  and idempotent (`_columnExists` guarded).
- **Domain** (`lib/features/contacts/domain/contact.dart`): Contact lifecycle
  (active/archived/merged), methods with normalization, groups (primary color),
  tags, notes, availability, saved filters, timeline projection types,
  merge plan/choices, device-import drafts.
- **One canonical repository** (`DriftContactRepository`) behind one interface
  (`ContactRepository`) with one providers file. No duplicate ownership paths
  (verified by search: single writer for each link table, single
  `normalizePhone`, single `searchContacts`).
- **Screens**: Contacts Main (sections, favorites, group dots, saved-filter
  selector, FAB), dedicated Search, progressive Add/Edit Contact, Groups
  manager, Filter Builder (discard confirm), Saved Filters, Contact Detail
  (Profile + Timeline tabs only, no Progress), Timeline (UPCOMING/HISTORY,
  year/date column, Common Events panel, tap-through to occurrence),
  Add People (inline New Contact keeps the Event draft), multi-select with
  mass-SMS handoff, Merge (advisory candidates → survivor + field choices),
  Device Import (just-in-time READ_CONTACTS, selected-only, denied/failed
  fallbacks).
- **Planner integration**: Event form People section (chips + Add People,
  links saved after the Event persists, keyed to `_draftId` so
  `thisAndFuture` edits keep the same id); `?contacts=` pre-link on
  Event/Task create routes; Task form Contacts section (distinct from legacy
  free-text people).
- **External handoff** (`external_handoff.dart`): call/SMS/email/mass-SMS via
  url_launcher. Returning creates NO outcome; only an explicit user-typed
  note is offered.
- **Release-blocking behavior**: historical participation is frozen into
  occurrence snapshots; removing a Contact from a future series keeps their
  past Timeline entries (test-verified).

## Verification

- `flutter analyze` — no issues.
- `flutter test` — 616 tests pass (includes 7 new contacts repository tests,
  the RELEASE-BLOCKING occurrence-snapshot stability test, and a Contacts
  journey smoke test). Schema-bump regressions in migration tests and
  root-back-policy tests were fixed.
- `flutter build apk --debug` — built `build/app/outputs/flutter-apk/app-debug.apk`.

## Deferred / known items

- **Physical-device verification** (install, screenshots, video, PMG visual
  comparison) — no Android device or AVD available here.
- Single-occurrence People edits currently rewrite the series link set
  (freeze-protected, so no history loss); occurrence-scoped People editing is
  a future refinement.
- `flutter_contacts` reads names/phone/email only; photos, call-log, and
  message permissions are intentionally absent.

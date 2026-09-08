# Planner Edit-Save Fixes — Completion Handoff

**Date:** 2026-08-08
**Scope:** Owner-reported defects after Delta 3:
1. "Editing a normal Event into a repeating Event does not save as repeat."
2. "Editing a normal Event into a Backup Appointment reverts to normal when moved."
3. Same-class defects found while tracing the canonical ownership path.

**Status:** Implemented, analyzer-clean, tests green, built, safely installed, physically
verified on the live Infinix X6731. Owner acceptance remains the owner's call.

---

## 1. ROOT CAUSE (one defect, two symptoms)

The detail Edit screen (and the timeline move/resize gestures) edit a **non-recurring**
Event with `CalendarEventEditScope.occurrence`. In `DriftCalendarEventRepository.editEvent`
the occurrence path wrote only a **`calendar_event_exceptions` row** and never touched the
master row. Consequences:

- **Recurrence never persisted.** The `calendar_event_exceptions` table has **no recurrence
  columns**, so an edit that turned a normal Event into a repeating Event wrote the
  recurrence into a table that cannot store it — the master row stayed `none`. (Bug 1.)
- **Backup lived only on the exception.** A Backup state set via edit landed on the
  exception while the master row stayed normal. The timeline move/resize path
  (`planner_screen.dart::_persistTimelineEdit`) drafts from `readEventDraft` — the
  **master row only** — so the next move silently reverted the Event to normal. (Bug 2.)

The exception mechanism exists to override a **single occurrence of a recurring series**.
A non-recurring Event has exactly one occurrence, so "this event only" and "the whole
event" are the same record — the **master row is the canonical owner** of its schedule,
recurrence, and Backup identity.

## 2. FIXES

### 2a. `lib/features/planner/data/drift_calendar_event_repository.dart` — canonical fix

`editEvent`, `CalendarEventEditScope.occurrence` case, now branches on the source rule:

- **Non-recurring source → `_writeEvent` on the master row** (`startDate` forced to the
  original occurrence date, mirroring the existing occurrence convention). Recurrence and
  Backup now persist on the master row, where the form, detail, and move/resize paths all
  read them.
- Then `_clearFieldOverrideExceptions` removes stale **scheduled** (field-override)
  exceptions for that occurrence so a pre-fix override (e.g. old times) can no longer mask
  the fresh master state. **Cancelled/rescheduled lifecycle exceptions are preserved.**
- Recurring sources keep the existing exception path unchanged (Delta 2 occurrence
  overrides).

### 2b. `lib/features/planner/presentation/planner_screen.dart` — same-class move/resize fix

`_persistTimelineEdit` occurrence-scope draft now carries the **rendered occurrence's**
`title`, `isBackupAppointment`, and `backupForEventId` (merged from any exception override)
instead of the raw master draft values. A Backup toggled via "This event only" on a
**recurring** Event — or a pre-fix exception Backup — survives a subsequent move/resize.

### 2c. `lib/features/planner/presentation/calendar_event_form_screen.dart` — form prefill

`_loadExisting` now prefills `_isBackupAppointment` / `_backupForEventId` /
`_backupRelationshipProvenance` from the **effective occurrence** (exception-merged) before
falling back to the master draft. Reopening the edit form of an Event whose Backup lives on
an occurrence override shows ON instead of silently dropping it on the next save.

## 3. TESTS

Added to `test/features/planner/data/drift_calendar_event_repository_test.dart`:

1. **Edit normal → Daily**: master row `recurrence_frequency == daily`, occurrence
   `isRecurring`, next-day occurrence generated, **zero exception rows**.
2. **Edit normal → Backup → move/resize edit**: master row `isBackupAppointment` true,
   Backup survives the second occurrence-scoped edit with new times.
3. **Stale scheduled override cleanup**: a seeded pre-fix scheduled exception is removed by
   the master edit and no longer masks the new master time.

Updated to the corrected canonical behavior (non-recurring move/resize = master-row update,
no exception row): `planner_issue5_6_test.dart` (6 resize assertions + header) and
`planner_horizontal_day_swipe_test.dart` TEST 8.

Added widget test `planner_issue5_6_test.dart` — "Owner fix: edit-save canonical ownership"
— which seeds a pre-fix scheduled exception carrying Backup=true over a normal master row,
then drives a real long-press move; it asserts the moved Event stays Backup on the master
row (10:00 start) with the stale override exception removed. This locks in the
`_persistTimelineEdit` draft fix (the piece only reachable through the widget move gesture).

### Results (run one file at a time; kill leftover `flutter_tester`/`dart` + clear
`build/native_assets` + the Flutter `bin/cache/lockfile` before each run):

| Suite | Result |
|---|---|
| `drift_calendar_event_repository_test.dart` | 16/16 pass (incl. 3 new) |
| `calendar_event_journey_test.dart` | pass |
| `calendar_event_current_status_journey_test.dart` | pass |
| `planner_issue5_6_test.dart` | 18/18 pass (incl. new move-path widget test) |
| `planner_horizontal_day_swipe_test.dart` | pass |
| `planner_correction_pack_test.dart` | pass |
| `planner_interactive_day_pager_safety_test.dart` | pass |
| `planner_interactive_day_pager_domain_safety_test.dart` | pass |
| `planner_pinch_zoom_test.dart` | pass |
| `planner_physical_pinch_responsiveness_test.dart` | pass |
| `planner_journey_test.dart` | pass |
| `planner_current_time_indicator_test.dart` | pass |

`flutter analyze` on all changed files: **No issues found.**
`dart format` applied to all changed files.

## 4. BUILD / INSTALL

- `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` (success).
- `adb install -r` (safe update, app data preserved): **Success**.
- No uninstall, no data clear. Existing events (including the moved daily Study or Plan
  from the Delta-2 verification) intact after relaunch.

## 5. PHYSICAL VERIFICATION (live Infinix X6731, 1080×2400)

### Bug 1 — edit normal → Repeat = Daily
1. Created a fresh non-recurring "Fix Verify Meeting" (10:45–11:45 AM, Aug 8).
2. Edit → Repeat = Daily → Save.
3. Detail shows **`Repeats | Daily`** (uiautomator: `ownerfix_repeats_daily_detail.xml`).
4. DB master row `4c357259…`: `recurrence_frequency='daily'`, `recurrence_end_mode='never'`,
   **zero exception rows**.
5. Aug 9 shows "Fix Verify Meeting, 10:45 AM – 11:45 AM" (`ownerfix_future_occurrence_aug9.png`).
6. Survives app restart.

### Bug 2 — edit normal → Backup → move
1. Created a fresh non-recurring "Fix Verify Backup" (2:00–3:00 PM, Aug 7).
2. Edit → Backup Appointment ON → Save.
3. Detail badge "Backup Appointment" appears; DB master row `10cf49c3…`:
   `is_backup_appointment=1`, `backup_relationship_provenance='user-classified'`,
   **zero exception rows**.
4. Dragged the card down to 4:00–5:00 PM (long-press move; no scope dialog — non-recurring).
5. Moved card still reads **"4:00 PM – 5:00 PM, Backup Appointment, Unreported"**
   (`ownerfix_backup_after_move_4pm.png`); DB master: `start_minute=960, end_minute=1020,
   is_backup_appointment=1` — the move was a canonical master-row update.
6. Survives app restart (`ownerfix_restart_aug7_backup.png`).

### Same-class check
A pre-fix Event whose Backup lived only on an exception is repaired on its next move
(the draft now inherits the occurrence's Backup state, and the master write persists it).

## 6. EVIDENCE ARCHIVED

`docs/handoffs/planner-edit-save-fixes/`:

- `ownerfix_repeats_daily_detail.xml` — detail "Repeats | Daily".
- `ownerfix_future_occurrence_aug9.png` — future daily occurrence.
- `ownerfix_db_daily_verified.sqlite` — master row daily, no exceptions.
- `ownerfix_backup_badge_before_move.xml` — Backup badge on detail.
- `ownerfix_backup_after_move_4pm.png` — moved card still Backup.
- `ownerfix_restart_aug7_backup.png` + `.xml` — Backup survives restart.
- `ownerfix_db_backup_moved.sqlite` — master row backup=1 after move.

## 7. FILES CHANGED

- `lib/features/planner/data/drift_calendar_event_repository.dart` — canonical fix
  (non-recurring occurrence edits write the master row; `_clearFieldOverrideExceptions`).
- `lib/features/planner/presentation/planner_screen.dart` — move/resize draft inherits the
  occurrence's Backup state + title.
- `lib/features/planner/presentation/calendar_event_form_screen.dart` — edit form prefills
  Backup from the effective occurrence.
- `test/features/planner/data/drift_calendar_event_repository_test.dart` — 3 new tests.
- `test/features/planner/presentation/planner_issue5_6_test.dart` — resize assertions now
  target the canonical master row.
- `test/features/planner/presentation/planner_horizontal_day_swipe_test.dart` — TEST 8
  asserts master-row persistence.

## 8. REPOSITORY SAFETY

- No schema changes, no migrations, no data rewriting.
- Recurring-series occurrence semantics (Delta 2) untouched.
- All previous planner polish (dominant-right lanes, Backup lanes, Did Not Attempt
  persistence, Work/Service colors, portrait lock, report statuses, Life Goal naming)
  regression-checked by the suites above.

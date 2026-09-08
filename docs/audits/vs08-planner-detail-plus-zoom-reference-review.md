# VS-08 Planner Detail, Top Bar, Plus, and Zoom Reference Review

**Reviewed:** 2026-07-29

**Branch:** `codex/vs-08-weekly-planning-lifecycle`

**Starting commit:** `201f2a35ebafcbea1ad277fd43c0b81050bec63d`

**Authority:** approved Phase 3 baseline first, approved Next Transfer PNG
second, Stitch HTML third, PMG interaction references fourth,
BetterCalendar fifth, and DayFlow mechanics only when source is locally
available.

## 1. Current implementation status

Before this refinement, the Planner already had picker-first Event creation,
one-tap empty-grid creation, event movement and bottom resize previews, a
60-pixel hour grid, local settings, deterministic Event Type mappings, and
confirmed-source progress protection. The Event form and detail view were
full-screen routes. Planner displayed permanent Task, Overdue Task, Awaiting
Report, and Changes sections below the timeline. Awaiting Report events were
removed from the normal timed/all-day lists, which conflicts with the new
locked visibility rule.

## 2. Complete PMG media inventory

| File | Duration | Size | Primary observation |
| --- | ---: | ---: | --- |
| `Images/pmg-select-event-type-first-reference.jpg` | still | 922×2048 | picker-first composition |
| `pmg-another-workflow.mp4` | 393.835 s | 720×1600 | broad Planner/detail workflow |
| `pmg-event-picker-first.mp4` | 75.760 s | 1080×2400 | type picker before detail |
| `pmg-select-event-type-first-workflow.mp4` | 17.607 s | 720×1600 | empty-time picker-first creation |
| `pmg-settings-workflow.mp4` | 108.990 s | 1080×2400 | calendar/settings controls |
| `pmg-weekly-planning-workflow.mp4` | 142.243 s | 720×1600 | weekly planning |
| `pm-whole-review-workflow.mp4` | 519.175 s | 720×1600 | broad navigation and Planner |
| `Reference 01/0359e10d-0fec-4d11-8c31-fbdf7c48f265.mp4` | 14.952 s | 576×1280 | timeline scale and vertical navigation |
| `Reference 01/1d802829-4334-42b5-980b-b759c39f7da6.mp4` | 29.607 s | 576×1280 | picker-first compact detail form |
| `Reference 01/48e84e30-e137-4902-87db-fd5797148e9d.mp4` | 28.620 s | 576×1280 | contextual plus, person, contact, and map patterns |
| `Reference 01/5e06e813-4bf6-4ee4-a586-b8e9b84ff365.mp4` | 28.268 s | 576×1280 | existing-event detail/edit and movement |
| `Reference 01/65637a37-bc15-4fd3-ba68-5eac7fb7a1fd.mp4` | 60.793 s | 576×1280 | detail sheet, location, people, backup, and schedule-from-calendar |
| `Reference 01/9c7ef975-494b-4f17-9c5b-67b702102dd8.mp4` | 53.389 s | 576×1280 | date, filters, selection/delete, overflow, Schedule/Day/Week/Tasks/Search |
| `Reference 01/b9f6ff48-b69a-4f32-96d8-635b5f2f143e.mp4` | 74.690 s | 576×1280 | indicator-to-event flow and report-required behavior |
| `Reference 01/ff05bd5c-c119-4214-a8e4-0ca7c21596da.mp4` | 30.302 s | 576×1280 | backup classification and live event movement |
| `pmg-planner-topbar-filter-and-view-workflow.mp4` | 53.389 s | 576×1280 | descriptive byte-identical copy of the top-bar recording |

The descriptive copy has SHA-256
`62226A44FB84841CF7574015C2DD1494B1A0A938A012BF2EEA4EB24542D26CC8`,
matching its UUID-named source.

## 3. BetterCalendar inventory

| File | Duration | Size | Primary observation |
| --- | ---: | ---: | --- |
| `Bettercalendar-backup-json.mp4` | 17.640 s | 720×1600 | backup representation/export reference |
| `bettercalendar-preview-workflow.mp4` | 289.285 s | 720×1600 | calendar creation, move/resize, map, tasks, contacts, and settings |

## 4. New recording review method

All eight `Reference 01` recordings were inspected from beginning to end.
Evenly sampled frames spanning each complete duration were generated under
ignored `build/reference-audit/vs08-reference-01/` and visually reviewed.
The original media remains the evidence authority.

## 5. Bottom-sheet and detail-form findings

PMG opens the detailed editor from the bottom, keeps the Planner visible
behind a dim barrier, uses a small handle, and allows a nearly full-height
scrolling surface. Fields are compact and grouped: identity, title/notes,
date/time, recurrence, backup, address/location, people, and save. Next
Transfer should adopt the sheet motion and density while retaining its own
Event Types, Life Indicator mapping, reporting explanation, charcoal/pink
tokens, and Android safe areas.

The form should reject Members Participating, companionship, missionary role,
finding method, teaching record, baptism, referral, area, lesson commitment,
key-indicator, and missionary-only status fields.

## 6. Backup Appointment findings

The recording exposes a Backup Appointment toggle in scheduling details and
shows a dark treatment on the timeline. Next Transfer should store a boolean
classification and optional primary-event identity/provenance. The timeline
retains the Event Type color while adding a black stripe and accessible Backup
label. A linked backup is excluded from duplicate Scheduled Potential; only a
qualifying report from the activity that occurred can contribute Actual.

## 7. Movement and resize findings

An existing event opens details on tap. A deliberate long press lifts the
event, then vertical movement updates the displayed start/end time before one
final commit on release. Resize updates the end and block height continuously.
Next Transfer already has single-write persistence and rollback behavior but
must make preview times visibly use transient values and keep ordinary taps,
scroll, and two-finger zoom distinct.

## 8. Pinch-to-zoom findings

The Planner scale changes continuously while time labels, grid lines, event
positions, and event heights remain aligned. Practical Next Transfer limits
are 44 px/hour minimum, 60 px/hour normal, and 88 px/hour maximum. These values
preserve a compact overview, the approved 60 px reference default, and a
larger accessible manipulation scale on the Infinix viewport. The selected
height is device-local and clamped. Compact/Normal/Expanded settings provide
an accessible non-gesture alternative.

## 9. Contextual creation findings

PMG uses one expanding floating action system with distinct actions and
screen-specific emphasis. Next Transfer may adopt its position, animation,
outside/back dismissal, and explicit labels. It must not merge `+ Person`
with interaction `Contact`. Only Home and Planner currently have authorized
production screens. Later-destination context is deferred rather than
fabricated.

## 10. Top bar, date, filters, and selection

The top-bar recording shows a compact date label/calendar picker, filter
checkbox menu, checklist selection mode, delete confirmation, and overflow.
The useful order is Search, Schedule, Day, Week, Tasks. Filters are independent
checkboxes for Events, Backup Events, Tasks, and Completed Tasks. Selection is
temporary and displays checked records plus a count. Next Transfer must
preserve linked-record independence and use cancel/archive semantics where
history prevents destructive deletion.

## 11. Planner presentations

- **Schedule:** chronological existing records grouped by date; no new model.
- **Day:** selected-day time grid and all existing gesture contracts.
- **Week:** responsive seven-day summary preserving time, backup, and report
  status without merging Tasks into Events.
- **Tasks:** Incomplete and Completed; Overdue remains an Incomplete state.
- **Awaiting Reports:** only ended, report-required, unreported, non-cancelled
  Event occurrences.
- **Search:** local, private-safe matching; PMG server/sync behavior is rejected.

## 12. Report visibility and Awaiting Report

Report Required is not a visibility filter. Every scheduled internal Event is
shown in its date/time position. An ended report-required occurrence without a
qualifying report receives a derived Awaiting Report badge while remaining an
Event. A completed report clears that derived status. Derivation, filtering,
navigation, and elapsed time never write Activity Ledger rows.

## 13. Location and future map boundary

Typed location remains available without permission. VS-08 may define a
`CalendarEventLocationSelection` value and adapter boundary for place name,
formatted address, latitude, longitude, and external identifier, but no map,
dependency, permission, external URL, or broken control is introduced. The
control remains hidden until the authorized map slice.

## 14. Proposed data and presentation changes

- additive Calendar Event and exception snapshots:
  `isBackupAppointment`, `backupForEventId`, and backup provenance;
- additive Planner preferences: preferred presentation, four filters, and
  clamped timeline hour height;
- report status remains derived from existing report snapshots;
- reusable detail sheet, contextual FAB, filter surface, selection state,
  Schedule/Week/Tasks/Awaiting presentations, and gesture coordinator;
- More → Settings becomes the only Planner entry to Planner/Calendar and
  Privacy/Data settings.

## 15. Gesture architecture

Gesture interpretation remains transient. One pointer tap on empty space
creates; one pointer tap on an Event opens details; long press on an Event
moves; the lower handle resizes; two-pointer scale zooms. Only valid move or
resize release writes once. Zoom writes only the preference. Cancellation and
failure restore the prior visual state.

## 16. Migration, accessibility, performance, and rollback

Schema v10 is additive and transactionally adds nullable/defaulted columns.
Existing UUIDs and rows remain unchanged. Migration tests must cover v9→v10
preservation and injected rollback. Semantics identify Backup and Awaiting
Report states; top-bar controls use tooltips and 48 dp targets; text scaling
and narrow Android widths remain tested. Layout work stays O(n log n) through
the existing overlap arranger. Pinch updates are clamped and event writes
never occur per frame.

Rollback is a code rollback while retaining readable schema-v10 columns.
Database downgrade, deletion, and destructive recreation are forbidden.

## 17. Risks and mitigations

- **Gesture collision:** pointer-count coordination and separate event handles.
- **Duplicate potential:** exclude a linked backup from a second planning
  contribution.
- **History mutation:** existing reported-occurrence edit guard remains active.
- **Narrow week columns:** responsive summary cards rather than tiny editors.
- **Accidental bulk mutation:** explicit selection, count, confirmation, and
  one guarded mutation per record.
- **Later-slice leakage:** disabled/deferred Contact/Pathway actions and no new
  repository or map client.

## 18. Exact authority identifiers

- ADR-003–006, ADR-009–013, ADR-021–023
- FR-B-001–020, FR-C-001–020, FR-D-001–020, FR-E-001–024,
  FR-G-001–020, FR-H-001–020, FR-I-001–020
- BR-B-001–010, BR-C-001–010, BR-D-001–010, BR-E-001–012,
  BR-I-001–010
- AC-B-001–020, AC-C-001–020, AC-D-001–020, AC-E-001–024,
  AC-I-001–020
- OPD-1-005–020 and OPD-2-010–012
- active slice: VS-08
- deferred: standalone Pathways, Contacts, maps, notifications, sync, and
  backup-service work in VS-09 and later owning slices

No contradiction, technical impossibility, security vulnerability, or
data-loss risk requires stopping the authorized VS-08 implementation.

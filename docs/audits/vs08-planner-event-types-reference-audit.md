# VS-08 Planner and Event Types Reference Audit

**Audit date:** 2026-07-29
**Branch:** `codex/vs-08-weekly-planning-lifecycle`
**Starting checkpoint:** `af3c6b1ddbedecb0cb441eef4f19f20bb0a9b459`

## 1. Current VS-08 summary

The checkpoint implements the approved Weekly Planning lifecycle with one
effective Monday–Sunday plan per Local Profile and period, explicit Task
carryover, immutable review snapshots, unresolved-report acknowledgement, and
offline local persistence. The correction stays on VS-08 and does not authorize
VS-09.

## 2. Current Planner architecture

Before correction, `PlannerScreen` was a single 877-line presentation file. It
used a selected-date controller backed by `DriftPlannerRepository`, read
Calendar Event occurrences through `DriftCalendarEventRepository`, rendered a
fixed 06:00–22:00 60-pixel-per-hour stack, and listed Tasks, overdue Tasks,
Awaiting Report, and Changes below it. Calendar Event create/edit used a
separate full-screen form. Events had no first-class Activity/Event Type
identity.

## 3. Current visual and workflow defects

- Events occupied the full timeline width, so overlaps obscured one another.
- The timeline used one generic event color and a full border instead of a slim
  type-colored leading accent.
- Visible hours, time format, snapping, current-time line, initial position,
  completed/cancelled visibility, and quick edit were not configurable.
- The timeline had no native long-press creation, move, or resize interaction.
- Event creation began with the title rather than a deliberate Event Type.
- Life Indicator planning context relied only on an optional encoded
  contribution string; there was no explicit bidirectional type mapping.
- Planner settings had no clear destination.

## 4. PNG-versus-current differences

The approved Planner PNG uses a black/charcoal canvas, compact top bar and
seven-day strip, approximately 60 pixels per hour, a narrow time gutter, subtle
hour dividers, proportionally positioned/heighted event blocks, muted
type-colored fills, a slim colored leading border, compact text hierarchy, a
pink rounded-square floating action button, and persistent five-destination
bottom navigation. The checkpoint had the correct broad composition but used
larger framed sections, a generic event treatment, no overlap columns, and no
current-time line. The correction retains real Android safe areas and does not
copy fake system chrome.

## 5. Stitch measurements and tokens

`UI Preferences/stitch_next_transfer/planner_recreated/code.html` supplies the
secondary measurements: black `#000000` background, charcoal `#1c1c1e`
surface, pink `#e91e63` accent, secondary `#8e8e93`, border `#2c2c2e`,
60-pixel hour slots, approximately 64-pixel time gutter, 16-pixel right inset,
4-pixel event leading border, 4-pixel event radius, 8-pixel event padding, and
a 64-pixel rounded FAB. Shared Home, Pathways, Contacts, and More references
confirm compact rows, 1-pixel borders, 24-pixel navigation icons, and the same
dark/pink hierarchy. HTML, Tailwind, CDN assets, sample data, and fake iOS chrome
are not production dependencies.

## 6. PMG Planner findings

The PMG recordings show a compact day timeline, deliberate date navigation,
clear event blocks, direct detail access, and visible interaction feedback.
Useful mechanics are the dense time grid, explicit save, and reversible
timeline editing. PMG branding, proprietary assets, sample names, and
mission-specific records are not copied.

## 7. PMG Event Type creation findings

The PMG flow makes type selection deliberate, exposes type name/color/icon, and
keeps type management separate from individual event content. Next Transfer
uses this only as workflow evidence. Its Event Type implementation is the
approved Activity Type concept with stable IDs, explicit Life Indicator
mappings, protected system types, and independently stored Calendar Events.

## 8. PMG Settings findings

The recordings group notification, default type, duration, clock format,
visible start/end hours, creation presentation, quick edit, and colors. The
applicable local Planner settings are adopted. Notification permission,
scheduling, and quiet-hour behavior remain deferred to VS-16 under the owner
amendment.

## 9. BetterCalendar interaction findings

BetterCalendar demonstrates long-form event creation, type/color selection,
all-day and recurrence controls, start/end hour, hour-height/zoom, default
duration, 24-hour format, week start, and separate notification settings. The
useful findings are explicit configuration, compact timeline interaction, and
local event save independent from notification success. Import behavior remains
owned by VS-17 and no BetterCalendar data/code is copied.

## 10. Current Next Transfer findings

`3dec88dd-f092-4e56-861f-a7b523b8f1f0.mp4` confirms the checkpoint’s sparse
single-column timeline, pink header, date strip, separate Task/report sections,
and permanent navigation. It is the before-state evidence for this correction.

## 11. Relevant DayFlow mechanics

The MIT-licensed DayFlow repository was inspected at commit
`a224ed974a41d903508dd711239bda5a8bcc08d3`. Useful independent mechanics are:

- configurable first/last hour, hour height, minimum duration, and time gutter;
- y-coordinate to time conversion with clamping and 15-minute snapping;
- current-time line placement and minute updates;
- long-press activation with cancellation on competing scroll/touch movement;
- strict overlap grouping, lowest-free-column placement, and readable
  side-by-side widths;
- separate all-day and timed regions;
- preview state separated from persistence, with cleanup on cancel/failure;
- drag auto-scroll concepts and `touchcancel`/pointer-cancel cleanup;
- vertical intent separated from horizontal navigation intent.

Files studied include:

- `packages/core/src/types/config.ts`
- `packages/core/src/components/weekView/TimeGrid.tsx`
- `packages/core/src/views/WeekView.tsx`
- `packages/core/src/views/DayView.tsx`
- `packages/core/src/views/utils/dragCreate.ts`
- `packages/core/src/hooks/useWeekViewSwipe.ts`
- `packages/core/src/utils/eventLayout/grouping.ts`
- `packages/core/src/utils/eventLayout/layout.ts`
- `packages/core/src/utils/eventLayout/rebalance.ts`
- `packages/core/src/utils/eventLayout/utils.ts`
- `packages/plugins/drag/src/hooks/useDragState.ts`
- `packages/plugins/drag/src/hooks/useDragManager.ts`
- `packages/plugins/drag/src/hooks/useDragHandlers.ts`
- `packages/plugins/drag/src/hooks/useDragCommon.ts`
- `packages/plugins/drag/src/hooks/useWeekDayDrag.ts`
- `packages/plugins/drag/src/hooks/utils/dragInteraction.ts`
- `packages/plugins/drag/src/hooks/utils/weekDay/drag.ts`
- `packages/plugins/drag/src/hooks/utils/weekDay/completion.ts`
- `packages/plugins/drag/src/hooks/utils/weekDay/preview.ts`

The Flutter implementation is independent and copies no DayFlow source.

## 12. DayFlow mechanics not to copy

Do not copy its Preact/DOM architecture, CSS, document-level listener model,
web drawer behavior, CalDAV/provider model, JavaScript event schema, synthetic
mouse events, runtime packages, or source text. Flutter gesture arenas,
Semantics, native scrolling, Drift transactions, and Next Transfer domain
objects remain authoritative.

## 13. Domain constraints

Tasks and Calendar Events remain separate. Scheduling, moving, resizing, time
passing, or Task completion never creates Actual. Actual remains derived only
from confirmed canonical source records through reports and append-only ledger
entries. Reported history is immutable except through reversal/replacement
correction. Event title alone never determines classification. Spiritual
quality and universal percentage scoring are prohibited.

## 14. Event Type and Life Indicator mapping design

The approved Activity Type entity is implemented and presented as Event Type;
no duplicate Event Category or Calendar Type concept is created. System types
have stable UUIDs and stable keys. Mapping rows use stable indicator keys and a
mapping version. Six exact mappings are seeded:

| Event Type | Life Indicator |
| --- | --- |
| Temple Visit | `temple_visit` |
| Scripture Study | `scripture_study` |
| Exercise | `exercise` |
| Budget Review | `budget_review` |
| Job Application | `job_applications` |
| Meaningful Connection | `meaningful_connections` |

General, Appointment, Work, and Personal are useful non-indicator system types.
Custom types explicitly map to None, one, or multiple indicators. Exact reverse
lookup is allowed only when one active system type matches one indicator.
Calendar Events snapshot the selected type ID and mapping version.

## 15. Settings design

`PlannerPreferences` is Local Profile scoped and device-local. It stores the
default type/duration/reminder value, visible start/end hours, 12/24-hour
format, snapping, current-time line, initial scroll preference, creation
presentation preference, quick edit, completed/cancelled visibility, and week
start. The correction UI implements settings that affect the current Planner.
Notification platform behavior and unimplemented external-feature preferences
remain explicitly deferred.

## 16. Screenshot and security-code inventory

The repository search found one active blocker:
`MainActivity.kt` called `window.addFlags(FLAG_SECURE)`. Claims also existed in
README, Privacy Center, implementation notes, VS-02 traceability, and the
authority verifier. No secure-screen plugin, capture platform channel, lifecycle
reapply path, theme flag, or second Android activity was found. The owner
amendment requires removal of the flag and all prevention claims while
retaining the other privacy controls.

## 17. Proposed Flutter architecture

- Drift schema v9: Activity Types, type mappings, Planner preferences, nullable
  type/mapping-version snapshots on event and occurrence-exception rows.
- `EventTypeRepository`: idempotent system seeding, custom management, explicit
  mappings, archive/restore, and settings persistence.
- Event form: Event Type first, visible deterministic mapping, type defaults,
  and no Actual write.
- Indicator detail: Schedule Activity reverse route with exact type preselection.
- Planner timeline: pure overlap/snap domain utility plus native Flutter
  long-press create/move/resize preview and transactional persistence.
- Settings routes: Planner and Calendar, Event Types, and custom type form.

## 18. Files expected to change

Database schema/generated source, Planner/Event Type domain/application/data
and presentation files, router/route names, app/test dependency composition,
Android `MainActivity`, Privacy Center, authority verifier, migration/domain/
repository/widget tests, README, implementation notes, VS-02 and VS-08
traceability, and this audit/amendment evidence.

## 19. Database and migration impact

The v8-to-v9 migration creates three tables and adds four nullable columns.
Existing rows remain valid with null type snapshots. No table is dropped, reset,
or rewritten. Migration occurs inside the existing transaction and has an
injected-failure rollback test. Archived types remain referenced and are never
deleted by normal management. Restoring system defaults does not touch events,
reports, links, ledger rows, or weekly planning history.

## 20. Test impact

Required coverage includes migration preservation/rollback; seed idempotency;
six exact mappings; custom None/one/multi mappings; title non-inference;
archive/history preservation; settings validation/persistence; type
preselection; scheduling-no-Actual; timeline placement, height, overlap,
snapping, create/move/resize/cancel/failure behavior; current-time display;
capture-code absence; and retained existing test suites.

## 21. Risks and rollback

Primary risks are event-time conversion during gesture edits, gesture/scroll
competition, narrow overlap columns, stale mapping display, migration partial
failure, and accidental historical reclassification. Mitigations are
long-press activation, snapped/clamped previews, failure reset, reported-event
edit guards, nullable additive columns, version snapshots, idempotent seeding,
transactional migration, and preservation tests. Rollback is code rollback plus
continued schema-v9 compatibility; user data must never be downgraded by
destructive reset.

## 22. Material source conflicts

The correction’s capture override directly contradicted FR-W-006, AC-W-006,
BR-W-005, and OPD-5-012. Work stopped before changing that behavior. The owner
approved `OWNER-AMENDMENT-001`, which replaces only those clauses. The request
also included reverse flows and QA for later-slice screens; implementing those
now would violate the VS-08 boundary, so the owner explicitly deferred them to
their owning slices. No other direct contradiction, technical impossibility,
security vulnerability, or data-loss risk was found.

## 23. Exact authority and traceability IDs

- ADR-004, ADR-005, ADR-006, ADR-009, ADR-010, ADR-011, ADR-012, ADR-013,
  ADR-021, ADR-022, ADR-023
- FR-A-005; FR-B-001–020; FR-C-001–020; FR-D-001–020; FR-E-001–024;
  FR-F-001–020; FR-G-001–020; FR-H-001–020; FR-I-001–020
- BR-B-001–010; BR-C-001–010; BR-D-001–010; BR-E-001–012; BR-I-001–010
- AC-B-001–020; AC-C-001–020; AC-D-001–020; AC-E-001–024; AC-I-001–020
- OPD-1-005–020; OPD-2-010–012
- replaced only by amendment: FR-W-006/FR-W-006A, AC-W-006/AC-W-006A,
  BR-W-005/BR-W-005A, OPD-5-012/OPD-5-012A
- current authorized slice: VS-08
- deferred owning slices: VS-09, VS-10, VS-11, VS-12, VS-14, VS-16, VS-17,
  VS-19, and VS-20

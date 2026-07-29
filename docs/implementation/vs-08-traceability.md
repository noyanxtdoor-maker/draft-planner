# VS-08 Traceability — Weekly Planning Lifecycle

**Authorized:** 2026-07-28

**Scope boundary:** VS-08 plus the explicitly approved Planner/Event Type and
screen-capture correction only; VS-09 and later remain unauthorized.

**Dependencies:** VS-03, VS-04, VS-06, and VS-07; all satisfied.

## Exit gate

One effective Weekly Plan exists per Local Profile and Monday-start period.
Exact Monday-Sunday dates are computed in a persisted profile IANA timezone and
snapshotted on the plan. Planning never writes Actual. Review completion
preserves factual indicator snapshots, unresolved-report acknowledgement, and
an optional local-only reflection. Late valid ledger changes are disclosed
without rewriting the snapshot. Incomplete Tasks carry only by explicit choice;
Calendar Events never carry automatically. Prior plans remain accessible and
read-only after review/archive.

## Functional requirements

| Requirement | Implementation and evidence |
| --- | --- |
| FR-I-001 | unique `weekly_plan_profile_period_unique` index and idempotent `openOrCreate` |
| FR-I-002 | `WeeklyPeriod` enforces a Monday start and exact Sunday end |
| FR-I-003 | all lifecycle writes use local Drift transactions; rollback and Android smoke fixtures |
| FR-I-004 | existing append-only weekly target editor is linked from the plan |
| FR-I-005 | target domain and review snapshot preserve Not set separately from explicit zero |
| FR-I-006 | `WeeklyIndicatorTargetRevisions` remains append-only and supersession-linked |
| FR-I-007 | plan/review UI and models keep Actual, Target, and Scheduled Potential separate |
| FR-I-008 | incomplete Task candidates can be explicitly selected as commitments |
| FR-I-009 | concrete Calendar Event occurrences can be selected; native create route is available |
| FR-I-010 | Draft/Active plans derive Review Due only after the stored Sunday in profile timezone |
| FR-I-011 | review shows factual outcomes and every unresolved required report |
| FR-I-012 | indicator detail remains the immutable contribution-history route |
| FR-I-013 | optional trimmed private reflection is local-only and non-contributory |
| FR-I-014 | review completion is transactional and retry-idempotent by operation ID |
| FR-I-015 | ledger rows recorded after review completion are disclosed as post-review factual changes |
| FR-I-016 | reviewed plan offers explicit next-week creation |
| FR-I-017 | every incomplete committed Task requires Carry or Do not carry |
| FR-I-018 | next-week creation copies no Calendar Event commitment |
| FR-I-019 | history lists prior weeks; Reviewed/Historical plans are read-only |
| FR-I-020 | repository, widget, and Android journeys have no network dependency |

All 20 functional requirements, FR-I-001 through FR-I-020, are mapped.

## Business rules

| Rule | Enforced by |
| --- | --- |
| BR-I-001 | unique profile/period database index and idempotent open |
| BR-I-002 | user-controlled target revisions; no target is inferred or applied |
| BR-I-003 | `IndicatorTarget.notSet` versus explicit scaled zero |
| BR-I-004 | append-only target revisions and immutable review snapshots |
| BR-I-005 | separate Actual, Target, and Scheduled fields/models/labels |
| BR-I-006 | profile-zone date comparison derives Review Due without a reminder write |
| BR-I-007 | immutable review snapshots plus post-review ledger disclosure |
| BR-I-008 | persisted per-Task Carry / Do not carry decision |
| BR-I-009 | carryover loop handles Tasks only and never copies Events |
| BR-I-010 | Reviewed/Historical edit guard and prior-week history route |

All ten business rules, BR-I-001 through BR-I-010, are mapped.

## Acceptance criteria

| Acceptance criterion | Evidence |
| --- | --- |
| AC-I-001 | repository and migration tests prove one effective profile/week plan |
| AC-I-002 | domain/repository/widget assertions verify exact Monday-Sunday identity |
| AC-I-003 | in-memory/offline creation and injected transaction rollback tests |
| AC-I-004 | widget route opens the existing weekly target editor |
| AC-I-005 | repository fixture proves target zero remains distinct from Not set |
| AC-I-006 | retained target revision repository tests and review snapshot mapping |
| AC-I-007 | repository/widget tests assert independent Actual/Target/Scheduled values |
| AC-I-008 | widget and Android journeys explicitly select an existing Task |
| AC-I-009 | widget journey explicitly selects a weekly Event occurrence |
| AC-I-010 | profile-zone repository test derives Review Due after Sunday |
| AC-I-011 | review widget/repository expose outcomes and unresolved report list |
| AC-I-012 | existing indicator contribution-history journey remains green |
| AC-I-013 | review widget/repository store trimmed local private reflection |
| AC-I-014 | review transaction and retry operation return the same review |
| AC-I-015 | late ledger fixture preserves snapshot and exposes disclosure |
| AC-I-016 | reviewed widget exposes Start next week |
| AC-I-017 | repository rejects missing incomplete-Task decisions and copies explicit Carry |
| AC-I-018 | repository asserts next week contains no copied Event |
| AC-I-019 | v7-to-v8 migration, history, and read-only reopening tests |
| AC-I-020 | local repository, widget, rollback, relaunch-compatible schema, and Android smoke coverage |

All 20 acceptance criteria, AC-I-001 through AC-I-020, are mapped.

Release blockers are AC-I-001 through AC-I-008, AC-I-013, AC-I-015,
AC-I-018, and AC-I-020.

## Locked decisions

| Decision | VS-08 application |
| --- | --- |
| ADR-005 | Actual remains factual, ledger-derived, explainable, and read-only |
| ADR-006 | the full lifecycle is available from local authoritative state |
| ADR-009 | stable source and occurrence identities are retained in commitments |
| ADR-010 | Local Profile timezone defines the Monday-Sunday week |
| ADR-011 | unresolved required reports need explicit acknowledgement before review completion |
| ADR-012 | signed Activity Ledger entries remain the Actual authority |
| OPD-2-010 | the stored IANA profile timezone controls the week boundary |
| OPD-2-011 | unresolved reports require explicit acknowledgement |
| OPD-2-012 | final target is shown by default while revision history remains available |
| OPD-1-005 | targets begin Not set and suggestions are never silently applied |

## Timezone migration decision

Schema v8 adds nullable `LocalProfiles.timeZoneId`. Existing rows are not
silently labeled UTC during migration. On first Weekly Planning use, the
already-approved device IANA adapter resolves a valid zone (truthfully falling
back to `Etc/UTC` only if platform resolution fails), persists it once, and
copies it into the plan. This preserves week identity after travel or later
device-zone changes without destructive backfill.

## Visual and accessibility evidence

Weekly Planning, Weekly Review, and Prior Weeks are supporting routes rather
than one of the five permanent destinations with a dedicated PNG/HTML pair.
They reuse the approved native charcoal/pink theme, compact cards, border
treatment, Android safe areas, and permanent shell navigation. No HTML,
WebView, sample data, fake OS chrome, percentage, composite score, or
gamification is used. Widget coverage includes the 941 by 1672 reference
viewport and explicit 200% text scaling.

## Approved correction overlay

The correction is governed by
`docs/decisions/OWNER-AMENDMENT-001-screen-capture-and-vs08-scope.md` and the
original reference audit at
`docs/audits/vs08-planner-event-types-reference-audit.md`. The authoritative
event-creation interaction correction is audited at
`docs/audits/vs08-pmg-bettercalendar-reference-review.md`.

| Correction requirement | Implementation and evidence |
| --- | --- |
| Native Planner geometry | 60 px/hour time grid, duration height, overlap columns, compact 56 px time gutter, Event Type fill/accent, all-day separation |
| Safe interaction | one empty-grid tap, deliberate long-press event move and resize handle, configured snapping, live preview labels, preview cancellation, failed-save restoration |
| Initial navigation | week strip, Today/date picker, configured visible hours, current-time line, initial scroll to current time or first relevant event |
| First-class Event Type | stable UUID/key, system/custom and archive flags, color/icon, defaults, mapping version, protected system identities |
| Deterministic mapping | exactly six system mappings; no title inference; explicit custom zero/one/many mappings |
| Historical provenance | Calendar Event and exception snapshot type ID/version; custom mapping revisions are append-only |
| Mandatory type-first creation | immutable temporary context opens `Select Event Type` before any form or persisted draft from the timeline, Planner `+`, Weekly Planning, Life Indicator, Task, and direct create route |
| Context and defaults | selected date, snapped time, and compatible Life Indicator context survive the picker; selection then applies the chosen type duration and deterministic mapping |
| Recommendation | an exact Life Indicator mapping is ordered first and visibly marked `Recommended`; the user can choose another type or cancel |
| Cancellation | dismissing the picker restores the calling screen and creates no Calendar Event, operation, report, notification, or Activity Ledger row |
| Reverse flow | existing Life Indicator detail Schedule Activity opens the type picker with its exact system type recommended |
| No Actual from scheduling | mapping affects planning/report context only; no ledger write exists in Event Type or timeline mutation paths |
| Local settings | default type/duration, visible hours, time format, snapping, current line, initial scroll, quick edit, status visibility, and week start persist in Drift |
| Existing-event detail | tapping an existing Event opens the native bottom detail sheet; long press remains reserved for move and the resize handle |
| Top-bar workflow | date/calendar, Filter, Select/Delete, and overflow Search/Schedule/Day/Week/Tasks replace permanent footer sections |
| Visibility/report overlay | Report Required never controls Event visibility; ended required/unreported Events remain in their normal position with `Awaiting Report` |
| Filters | Events, Backup Events, Tasks, and Completed Tasks persist locally with true/true/true/false defaults |
| Global plus | Home, Planner, and More use the reusable four-action Event/Task/Person/Contact menu; unavailable owning-slice actions remain truthful and non-persistent |
| Pinch zoom | two-pointer scale updates timeline geometry live and persists the clamped hour height locally |
| Settings relocation | More -> Settings exposes Planner and Calendar plus Privacy and Data |
| Backup Appointment | additive Event/exception metadata, black-stripe/badge presentation, preserved link provenance, and linked-primary Scheduled Potential de-duplication |
| Capture override | `MainActivity` has no secure flag; repository test/verifier reject `FLAG_SECURE`; Privacy Center uses approved wording |

Notification behavior is deferred to VS-16. Pathways and Contacts scheduling
entry points do not yet exist; the reusable creation coordinator is ready for
their owning slices, but no VS-09/later route or test is claimed here. Flows
that require unauthorized Pathways/Covenant Path, Contacts, Employment,
Documents, or Backups screens remain deferred. These deferrals are explicit
scope controls, not claims of completed VS-08 QA.

## Schema v9 correction migration

The v8-to-v9 transaction adds Activity Types, append-only mapping revisions,
Planner preferences, and nullable Event Type snapshots to Calendar Events and
occurrence exceptions. Migration fixtures prove prior weekly plans, events,
links, reports, and ledger rows survive. An injected migration failure proves
the transaction rolls back rather than leaving a partial schema.

## Schema v10 Planner-experience migration

The additive v9-to-v10 transaction adds Backup Appointment identity,
linked-primary/provenance fields to Event series and exceptions, plus preferred
Planner view, the four local content filters, and clamped timeline hour height
to Planner preferences. The migration uses safe defaults, preserves existing
records, and has an injected-failure rollback fixture. Ordinary Event edits
retain Backup linkage/provenance; changing an Event to non-backup clears the
relationship deterministically.

## Quality-gate record

| Gate | VS-08 status |
| --- | --- |
| Q0 Authority and traceability | Passed locally: immutable hashes, Android identity, schema v10, owner overlay, reference audit, dependency/slice boundaries |
| Q1 Static and build | Formatting, analysis, byte-clean code generation, production-defined debug assembly, and QA-signed release assembly pass. Release remains fail-closed without all four signing environment values; the incomplete local SDK still requires the documented `--no-tree-shake-icons` fallback |
| Q2 Domain/database/migration | Targeted lifecycle, v7-to-v8, v8-to-v9, v9-to-v10, failed-migration rollback, mapping provenance, Backup-link preservation/clearing, and injected write rollback tests pass |
| Q3 Offline/privacy/idempotency | Local pass; no new package, permission, remote client, direct Actual write, or non-transactional mutation |
| Q4 UI/accessibility | All 112 Flutter tests pass, including picker-first creation, Event detail sheet, exact filter defaults/persistence, selection safety, two-finger timeline zoom persistence, global create menu, More Settings, approved viewport, 200% text, Planner geometry, overlap, scrolling, and mapping regressions |
| Q5 Android platform | The final-refinement debug and QA-signed release APKs assemble and install over the existing app on Infinix X6731 Android 14 with data preserved. Current live debug evidence proves the top-bar layout, normal visibility of ended Events with `Awaiting Report`, absence of the old footer, picker-first creation and recommendation, exact filter defaults, existing-Event detail sheet, selection mode, global create order, and More Settings without saving or deleting. The release independently passes one-tap picker-first smoke and verifies with one v2 signer. Unchecked manual scenarios remain pending. Earlier corrected run `30433029259` passed all 18 API 24/API 36 emulator jobs |
| Q6 Remote security | Not applicable; no remote client or provider identity introduced |
| Q7 Slice evidence | Local authority/format/analyze/byte-clean-codegen/112-test/debug-build/QA-release gates pass; protected quality and Android CI for the final owner-refinement commit remain pending. Earlier protected quality run `30433009563` and Android run `30433029259` passed on `dea0aa2` |

VS-09 Pathways, remote sync, provider Calendar integration, notifications,
maps, contacts, and all later-slice work are not implemented.

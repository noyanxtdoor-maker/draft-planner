# VS-04 Traceability — Calendar Events

**Authorized:** 2026-07-28

**Scope boundary:** VS-04 only; VS-05 and later remain unauthorized.

**Dependencies:** VS-01 through VS-03.

## Exit gate

Calendar Event recurrence is deterministic offline; all-day values never shift
through time-zone conversion; occurrence edits preserve stable series identity,
replacement links, and reported history.

## Functional requirements

| Requirement IDs | Implementation and evidence |
| --- | --- |
| FR-E-001, FR-E-002, FR-E-003, FR-E-004 | Native create form and Drift repository save one-time, all-day, and timed Events immediately offline; widget and repository journeys |
| FR-E-005, FR-E-006 | Explicit Scheduled and factual report outcome enums; elapsed time derives only Awaiting Report; domain/repository tests |
| FR-E-007, FR-E-008 | Daily, weekly, monthly, and yearly recurrence engine with final-valid-day and Feb 29 rules; recurrence tests |
| FR-E-009, FR-E-010 | No-end, end-date, and occurrence-count rules; deterministic domain tests |
| FR-E-011, FR-E-012 | Original IANA zone and UTC instants retained; current-zone display conversion and date-only all-day storage; repository tests |
| FR-E-013, FR-E-014 | Stable series and occurrence UUIDs; recurring detail exposes explicit mutation scope; domain/widget tests |
| FR-E-015, FR-E-016 | Occurrence, this-and-future, and entire-series edit/cancel/reschedule transactions; repository tests |
| FR-E-017, FR-E-018 | Report-required attention and three factual report outcome read states; no inferred result; domain/repository tests |
| FR-E-019 | Stable UUID validation, operation rows, and retry-idempotent mutation boundary; repository tests |
| FR-E-020 | Typed local location without runtime location or Calendar permission; repository/manifest verifier |
| FR-E-021 | Linked Task IDs are read through a separate typed port and never merge status; repository test |
| FR-E-022 | Reschedule creates a new stable Event and preserves the original-to-replacement link; repository/widget detail |
| FR-E-023 | Existing report snapshots override elapsed attention and reported occurrences reject destructive edits; repository test |
| FR-E-024 | Drift transactions, migration rollback, injected write failure, and retry-safe operation records; migration/repository tests |

All 24 VS-04 functional requirements, FR-E-001 through FR-E-024, are mapped.

## Business rules

| Rule IDs | Enforced by |
| --- | --- |
| BR-E-001, BR-E-002 | Task and Event domain/repository types remain separate; no title-based classification |
| BR-E-003 | All-day values persist as `PlannerDate` strings with no zone or UTC instant |
| BR-E-004 | Timed values retain original IANA identity and UTC instants |
| BR-E-005 | Recurrence engine implements the locked month-end and leap-day outcomes |
| BR-E-006 | Mutations require one of the three locked scopes |
| BR-E-007 | Cancellation/rescheduling preserve historical original occurrences and links |
| BR-E-008 | Elapsed time creates Awaiting Report only; factual outcome comes from report snapshots |
| BR-E-009 | Reported occurrences are immutable under Event edits |
| BR-E-010 | Local writes are transactional, profile-scoped, UUID-backed, and retry-idempotent |

All 10 VS-04 business rules, BR-E-001 through BR-E-010, are mapped.

## Acceptance criteria

| Acceptance criteria | Evidence |
| --- | --- |
| AC-E-001 through AC-E-006 | Native offline create/detail journey, repository persistence, and explicit status/attention tests |
| AC-E-007 through AC-E-010 | Daily/weekly/monthly/yearly and date/count recurrence domain tests |
| AC-E-011, AC-E-012 | IANA retention, UTC conversion, and all-day date-only repository tests |
| AC-E-013 through AC-E-016 | Scope selection, stable occurrence identity, cancellation, split/edit, and replacement repository/widget coverage |
| AC-E-017, AC-E-018 | Report-required and factual outcome read-source tests |
| AC-E-019 | UUID and idempotent retry assertions plus schema operation identity |
| AC-E-020 | Typed local location and authority verifier proving no new manifest permission |
| AC-E-021 | Typed Task-link read context remains status-independent |
| AC-E-022 | Original/replacement link persistence test |
| AC-E-023 | Reported historical occurrence rejects destructive edit |
| AC-E-024 | v3-to-v4 upgrade, rollback injection, repository rollback, and generated-schema checks |

All 24 VS-04 acceptance criteria, AC-E-001 through AC-E-024, are mapped.
Release blockers are AC-E-001 through AC-E-008, AC-E-010, AC-E-014,
AC-E-017, AC-E-019 through AC-E-024.

## Locked decisions

| Decision | VS-04 application |
| --- | --- |
| ADR-011, ADR-005, ADR-012 | Explicit report-required state and factual outcome read boundary; no Actual or Activity Ledger write |
| ADR-006 | Drift is authoritative immediately and needs no remote connection |
| ADR-009 | Task links and report snapshots are separately typed read sources |
| ADR-021, ADR-022 | No new Android permission; local typed location and privacy-safe failure behavior |
| ADR-001, ADR-023 | Schema v4 migration, injected rollback, local failure recovery, and layered tests |
| ADR-016 | Stable UUIDs and idempotent operation effects |
| OPD-1-016 | Monthly recurrence uses the final valid day |
| OPD-1-017 | Feb 29 yearly recurrence uses Feb 28 in non-leap years |
| OPD-1-018 | Mutation scopes are occurrence, this-and-future, and series |
| OPD-1-019 | Recurrence ends are none, date, or count |
| OPD-1-020 | Timed events retain original IANA zone and show converted local time; all-day dates never shift |

## Visual-reference evidence and deviations

VS-04 changes the approved permanent Planner destination and therefore reuses
the already inspected `UI Preferences/planner-approved-reference.png` and
`UI Preferences/stitch_next_transfer/planner_recreated/code.html`. The native
Flutter Planner retains the locked dark surfaces, compact week strip, timeline,
FAB, section geometry, and bottom navigation. Event create and detail are
supporting routes, not new permanent destinations.

| Affected area | Reason | Result |
| --- | --- | --- |
| Planner Calendar Event action | VS-04 is now authorized | The former truthful unavailable handoff is replaced by native offline create/detail routes |
| Event forms and details | The approved references do not define these supporting routes | Native dark-theme Flutter controls follow Android safe areas, accessibility, and existing design tokens |
| Map action | Maps belong to a later slice and no location permission is authorized | Typed location is stored and displayed; no fake map integration or permission request |
| Report button | VS-06 owns report and Activity Ledger writes | VS-04 displays factual supported outcomes and a truthful boundary message without writing a report |

## Quality-gate record

| Gate | VS-04 status |
| --- | --- |
| Q0 Authority and traceability | Pass locally when `tool/verify_authority.dart` validates source hashes, Android identity, schema v4, dependency boundary, and permission lock |
| Q1 Static and build | Pass locally — strict format, analyzer, byte-identical codegen, and direct production-defined debug APK assembly |
| Q2 Domain/database/migration | Pass locally for recurrence, repository, v3-to-v4 upgrade, and rollback fixtures |
| Q3 Offline/privacy/idempotency | Pass locally for transaction rollback, stable UUIDs, retry idempotency, no-permission location, and report immutability |
| Q4 UI/accessibility | Pass locally — native create/detail journey at the approved 431 by 912 logical viewport and existing 200% Planner text-scale test |
| Q5 Android platform | Pending API 24/API 36 Calendar Event smoke matrix |
| Q6 Remote security | Not applicable; no remote client or provider identifier introduced |
| Q7 Slice evidence | Pending final protected quality and Android workflow evidence |

VS-05 Task-Event linking writes, VS-06 report/Activity Ledger writes, remote
sync, provider Calendar integration, notifications, maps, and later slice work
are not implemented.

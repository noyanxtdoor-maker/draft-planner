# VS-05 Traceability — Task-Event Linking

**Authorized:** 2026-07-28

**Scope boundary:** VS-05 only; VS-06 and later remain unauthorized.

**Dependencies:** VS-01 through VS-04.

## Exit gate

Task-Event relationships are explicit, reversible, profile-scoped, and usable
offline. A Task mutation never silently completes, deletes, or overwrites its
Calendar Event, and the reverse is equally true. Missing references remain
visible and repairable.

## Functional requirements

| Requirement IDs | Implementation and evidence |
| --- | --- |
| FR-F-001 through FR-F-004 | Dedicated native link routes from Task and Event details; candidates come only from persisted UUID-backed records |
| FR-F-005 through FR-F-008 | Bidirectional repository read ports, multiple links, and status independence; repository tests |
| FR-F-009 through FR-F-011 | Explicit unlink confirmation, retained source records, reactivation, and append-only history |
| FR-F-012 through FR-F-014 | Series links, occurrence overrides, and reschedule transfer inside the Event transaction |
| FR-F-015 | Explicit Task-or-Event canonical planning source with a truthful no-progress explanation |
| FR-F-016, FR-F-017 | Missing-side detection, visible broken-reference state, and explicit repair by stable identity rather than title |
| FR-F-018 | Drift schema v5, UUID/idempotent operations, migration rollback, and injected atomic-write failure |

All 18 VS-05 functional requirements, FR-F-001 through FR-F-018, are mapped.

## Business rules

| Rule IDs | Enforced by |
| --- | --- |
| BR-F-001 through BR-F-003 | Separate Task, Event, and link domain records; no status propagation or title inference |
| BR-F-004 | Event creation plus link creation share one Drift transaction |
| BR-F-005, BR-F-006 | Link removal changes only relationship state and is reversible |
| BR-F-007 | Event rescheduling transfers effective link context in the same transaction |
| BR-F-008 | Link count never affects progress or Actual |
| BR-F-009 | One explicit canonical source is stored per relationship |
| BR-F-010 | Profile scope, stable UUIDs, retry identity, append-only history, and rollback guards |

All 10 VS-05 business rules, BR-F-001 through BR-F-010, are mapped.

## Acceptance criteria

| Acceptance criteria | Evidence |
| --- | --- |
| AC-F-001 through AC-F-008 | Native link flows and repository tests for two-way visibility, multiplicity, and independent statuses |
| AC-F-009 through AC-F-013 | Explicit unlink UI, non-deletion assertions, retry-idempotence, and reversible reactivation history |
| AC-F-014 | Series and occurrence-override repository test plus reschedule transfer test |
| AC-F-015 | Persisted canonical source and Scheduled Potential explanation assertions |
| AC-F-016, AC-F-017 | Broken-reference read and stable-ID repair tests; no title matching |
| AC-F-018 | v4-to-v5 upgrade, failed-migration rollback, generated schema, and injected coordinator rollback |

All 18 VS-05 acceptance criteria, AC-F-001 through AC-F-018, are mapped.
Release blockers are AC-F-001 through AC-F-008, AC-F-010 through AC-F-013,
AC-F-015, AC-F-016, and AC-F-018.

## Locked decisions

| Decision | VS-05 application |
| --- | --- |
| ADR-005, ADR-009 | Task, Event, and relationship records remain separate and factual |
| ADR-006, ADR-016 | Links save immediately offline with stable UUID and operation identity |
| ADR-001, ADR-023 | Schema v5 migrations and coordinated writes are transactional and rollback-tested |
| OPD-2-001 | Multiple Tasks per Event and Events per Task are permitted; link count never means progress |
| OPD-2-002 | Series links apply to future occurrences; occurrence rows provide explicit overrides |
| OPD-2-003 | Every active relationship records one explicit canonical planning source |

## Visual-reference evidence and deviations

VS-05 re-opened `UI Preferences/planner-approved-reference.png` and inspected
`UI Preferences/stitch_next_transfer/planner_recreated/code.html`. The
permanent Planner composition is unchanged. Link management and create-from-
Task are native supporting routes using the existing compact dark theme,
Android safe areas, Flutter accessibility, and responsive controls.

No HTML is embedded and no sample reference content is product data. The
references do not define these supporting routes, so native controls are the
documented visual deviation required by the approved VS-05 behavior.

## Quality-gate record

| Gate | VS-05 status |
| --- | --- |
| Q0 Authority and traceability | Pass locally — approved hashes, identity, permission boundary, schema v5, and all FR/BR/AC mappings verified |
| Q1 Static and build | Pass locally — strict format, analyzer, byte-clean codegen, and direct Gradle debug assembly |
| Q2 Domain/database/migration | Pass locally — repository, v4-to-v5 upgrade, failed-migration rollback, and injected coordinator rollback |
| Q3 Offline/privacy/idempotency | Pass locally — offline link/unlink/relink, operation retry, reschedule transfer, and no new permission or dependency |
| Q4 UI/accessibility | Pass locally — matching-viewport native link journey plus retained 200% Planner coverage |
| Q5 Android platform | Pending protected API 24/API 36 emulator evidence |
| Q6 Remote security | Not applicable; no remote client or provider identity introduced |
| Q7 Slice evidence | Local evidence complete; protected CI evidence pending |

VS-06 report and Activity Ledger writes, remote sync, provider Calendar
integration, notifications, maps, and later slice work are not implemented.

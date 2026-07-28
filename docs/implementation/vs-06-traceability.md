# VS-06 Traceability — Outcome Reporting and Activity Ledger

**Authorized:** 2026-07-28

**Scope boundary:** VS-06 only; VS-07 and later remain unauthorized.

**Dependencies:** VS-01 through VS-05.

## Exit gate

Task, Calendar Event occurrence, and structured manual Activity Reports save
offline with stable identities. A required Task completion and its report
commit atomically. Retry cannot duplicate a report or contribution. Actual is
read-only and derived only from effective Activity Ledger entries. Corrections
preserve the original report and append reversals and replacements.

## Functional requirements

| Requirement IDs | Implementation and evidence |
| --- | --- |
| FR-G-001 through FR-G-005 | Native Task/Event/manual report routes, three factual outcomes, activity date, structured partial value, and local Draft state |
| FR-G-006 through FR-G-010 | Required-Task transaction, stable Event occurrence source, explicit private notes, autosave, and retry-idempotent submission |
| FR-G-011 through FR-G-015 | Effective report uniqueness, correction route, preserved superseded report, required correction reason when Actual changes, and failure rollback |
| FR-G-016 through FR-G-020 | Offline operation, factual source validation, no elapsed-time inference, effective-first report history, and structured manual Activity Report |
| FR-H-001 through FR-H-005 | Append-only contribution and reversal entries, explicit indicator/rule selection, integer-scaled values, and no title classification |
| FR-H-006 through FR-H-010 | Ledger-derived Actual, read-only projection API, deterministic entry identity, one contribution per report rule, and unit validation |
| FR-H-011 through FR-H-015 | Correction reversal/replacement links, retained audit history, effective filtering, source-history survival, and rebuild support |
| FR-H-016 through FR-H-020 | Projection audit, profile/date/indicator scope, private-note exclusion, manual report boundary, and transactional rollback |

All 40 VS-06 functional requirements, FR-G-001 through FR-G-020 and FR-H-001
through FR-H-020, are mapped.

## Business rules

| Rule IDs | Enforced by |
| --- | --- |
| BR-G-001 through BR-G-003 | Reports remain separate factual records; outcomes are explicit; report-required Task completion cannot be bypassed |
| BR-G-004 through BR-G-006 | Draft labeling/autosave, stable source identities, and one effective report per source slot |
| BR-G-007 through BR-G-010 | Transactional submission, idempotent retry, preserved corrections, and private non-contributory notes |
| BR-H-001 through BR-H-003 | Append-only ledger, explicit qualifying selection, and Actual derived only from effective entries |
| BR-H-004 through BR-H-006 | Fixed-decimal integer storage, approved unit/precision validation, and no binary floating-point values |
| BR-H-007 through BR-H-010 | Reversal plus replacement corrections, immutable audit links, rebuild/audit behavior, and no raw-ledger UI |

All 20 VS-06 business rules, BR-G-001 through BR-G-010 and BR-H-001 through
BR-H-010, are mapped.

## Acceptance criteria

| Acceptance criteria | Evidence |
| --- | --- |
| AC-G-001 through AC-G-005 | Widget journey and repository tests for source routes, Drafts, factual outcomes, activity dates, and partial values |
| AC-G-006 through AC-G-010 | Atomic required-Task completion, Event occurrence identity, private notes, autosave, and idempotent retry tests |
| AC-G-011 through AC-G-015 | Effective uniqueness, correction/supersession history, correction-reason enforcement, and rollback tests |
| AC-G-016 through AC-G-020 | v5-to-v6 migration/rollback, offline persistence, no inference, effective-first history, and manual Activity Report tests |
| AC-H-001 through AC-H-005 | Contribution/reversal row assertions, explicit selections, scaled integer values, and no classifier path |
| AC-H-006 through AC-H-010 | Actual summation, no writable Actual field, deterministic retry identity, rule uniqueness, and unit rejection tests |
| AC-H-011 through AC-H-015 | Correction links, reversed audit detail, effective filtering, archived-source survival, and rebuild tests |
| AC-H-016 through AC-H-020 | Projection audit, profile/period filters, private-note isolation, structured manual entry, and injected rollback |

All 40 VS-06 acceptance criteria, AC-G-001 through AC-G-020 and AC-H-001
through AC-H-020, are mapped.

Release blockers are AC-G-001 through AC-G-008, AC-G-013, AC-G-015 through
AC-G-019, AC-H-001 through AC-H-009, AC-H-012, and AC-H-017 through AC-H-020.

## Locked decisions

| Decision | VS-06 application |
| --- | --- |
| ADR-005, ADR-006 | Factual offline-first reports with stable identities |
| ADR-008, ADR-010, ADR-011 | Explicit structured outcomes; no title, time, or spiritual-worth inference |
| ADR-012 | Append-only Activity Ledger is the sole Actual authority |
| ADR-023 | Report, required-Task status, reversals, and replacements share one transaction |
| OPD-2-004 | Local autosave remains clearly labeled Draft |
| OPD-2-005 | Correction reason is required when prior effective contributions changed Actual |
| OPD-2-006 | Private notes are optional, non-contributory, and absent from diagnostics/previews |
| OPD-2-007 | Manual entry uses a structured Activity Report; no raw-ledger editor exists |
| OPD-2-008 | Values use integer scaling with unit-specific precision and no binary float |
| OPD-2-009 | Effective contributions appear first; reversed history remains in correction detail |

## Visual-reference evidence and deviations

VS-06 opened `UI Preferences/planner-approved-reference.png` and inspected
`UI Preferences/stitch_next_transfer/planner_recreated/code.html` before
changing the permanent Planner destination. The approved dark charcoal
surfaces, pink accent, compact top bar, week strip, timeline, section order,
bottom navigation, and FAB composition remain intact.

Activity Report and Activity History are native Android-first supporting
routes because the reference does not define those required behaviors. The
Planner top bar adds a compact history action and the existing create sheet
adds Activity Report. This documented deviation is required for approved
reporting/history access, uses responsive scrolling and Android safe areas, and
does not embed HTML or reference sample content.

## Quality-gate record

| Gate | VS-06 status |
| --- | --- |
| Q0 Authority and traceability | Pass locally — approved hashes, permanent Android identity, permission boundary, schema v6, and all FR/BR/AC mappings |
| Q1 Static and build | Pass locally — strict format, analyzer, byte-clean codegen, and direct Gradle debug assembly |
| Q2 Domain/database/migration | Pass locally — repository tests, v5-to-v6 migration, failed-migration rollback, and injected transactional failure |
| Q3 Offline/privacy/idempotency | Pass locally — local Drafts, idempotent retry, private-note containment, and no new package/permission |
| Q4 UI/accessibility | Pass locally — matching-viewport native report/correction journey and retained 200% Planner coverage |
| Q5 Android platform | Pending API 24/API 36 clean-emulator matrix |
| Q6 Remote security | Not applicable; no remote client or provider identity introduced |
| Q7 Slice evidence | Pending protected quality and Android matrix completion |

VS-07 Home indicator/target presentation, remote sync, provider Calendar
integration, notifications, maps, and all later-slice work are not implemented.

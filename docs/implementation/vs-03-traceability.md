# VS-03 Traceability — Planner Day and Tasks

**Authorized:** 2026-07-27

**Scope boundary:** VS-03 only; VS-04 and later remain unauthorized.

**Dependencies:** VS-01 and VS-02.

## Exit gate

Task lifecycle and day presentation are deterministic offline; cancellation,
skip, and completion semantics are distinct; required-report Tasks cannot
bypass reporting.

## Functional requirements

| Requirement IDs | Implementation | Verification |
| --- | --- | --- |
| FR-C-001, FR-C-009, FR-C-017 | `PlannerDate`, in-session `PlannerController.selectedDate`, week strip, and full-date picker; cold construction uses today | domain date test; matching-viewport widget journey |
| FR-C-002, FR-C-012, FR-C-020 | Separate Task and Calendar Event domain types, icons, routes, tiles, and creation actions | domain mixed-model test; widget and Android smoke journeys |
| FR-C-003, FR-C-013 | All-day model and time-positioned recurring timed-event model | domain/repository mixed-event tests; timeline-position widget assertion |
| FR-C-004, FR-C-005 | Selected-day Incomplete Task query and separately derived overdue collection | domain and repository tests |
| FR-C-006 | Ended, report-required, unreported scheduled events derive Awaiting Report attention state | domain/repository tests; widget journey |
| FR-C-007, FR-C-008 | Cancelled and original rescheduled occurrences appear only in Changes; replacement identity stays explicit | domain/repository tests |
| FR-C-010 | FAB exposes distinct Task and Calendar Event actions | widget journey; Calendar Event handoff truthfully reports the VS-04 boundary |
| FR-C-011 | Task create/edit commits immediately to local Drift | repository, widget, migration, and Android smoke tests |
| FR-C-014, FR-C-015 | Stored event location remains visible without location permission; contextual map action is distinct and truthfully unavailable | mixed-event repository test; widget journey |
| FR-C-016 | Time derives only Awaiting Report attention; it never changes stored event outcome/state | domain mixed-event test |
| FR-C-018 | Changes can collapse without deletion | widget journey and immutable row assertions |
| FR-C-019 | Transactional writes roll back on injected failure and retain form input | repository rollback and widget recovery tests |
| FR-D-001, FR-D-004, FR-D-016 | Native create/edit form with stable pre-write UUID, retained input, and atomic local save | widget journey and repository failure tests |
| FR-D-002, FR-D-003, FR-D-007 | Nonblank normalized title, Incomplete default, optional due date | domain and repository tests |
| FR-D-005, FR-D-019 | Explicit Completed, Skipped, and Cancelled actions and labels | domain, repository, and widget tests |
| FR-D-006 | Overdue derives only from an earlier due date plus Incomplete status | domain and repository tests |
| FR-D-008, FR-D-013 | Task linked-event read-model fields never mutate event status; linked Calendar Event context remains separately typed | domain/repository mixed-model tests |
| FR-D-009, FR-D-010 | `requiresReport` is explicit; attempted completion returns `reportRequired` and leaves the Task Incomplete | domain, repository, and widget tests |
| FR-D-011 | Task status transactions create no Actual table or direct Actual mutation | repository schema assertion |
| FR-D-012 | Contribution classification is nullable explicit configuration and never title matching | domain and repository tests |
| FR-D-014 | Task detail exposes separately typed Pathway/Goal/Milestone context when supplied by a future authorized source | domain model and widget branch |
| FR-D-015 | Local authoritative Task state has no remote dependency and survives relaunch | repository and Android smoke tests |
| FR-D-017 | Stable operation IDs and a unique status-change index make retries idempotent | repository/database retry test |
| FR-D-018 | Direct reopen is allowed only without historical effects; otherwise `correctionRequired` preserves state | domain and repository historical-effect tests |
| FR-D-020 | Task type remains explicit in mixed Planner presentation | domain and widget tests |

All 40 VS-03 FRs are mapped above: FR-C-001 through FR-C-020 and FR-D-001
through FR-D-020.

## Business rules

| Rule IDs | Enforced by |
| --- | --- |
| BR-C-001, BR-C-005, BR-C-006 | Separate Task/Event models, source port, routes, status logic, and visual indicators |
| BR-C-002 | `PlannerTask.isOverdueOn`; overdue is never persisted as a status |
| BR-C-003, BR-C-004 | `PlannerCalendarItem.isAwaitingReport`; elapsed time creates attention only |
| BR-C-007 | Rescheduled original is a Changes item with an explicit replacement ID |
| BR-C-008 | Drift is the immediate Task write/read source |
| BR-C-009 | Stored location and contextual map control remain optional and separate |
| BR-C-010 | Drift transaction plus injected write guard proves false records roll back |
| BR-D-001, BR-D-002, BR-D-003, BR-D-008 | Four-value status enum, Incomplete default, derived overdue, nullable due date |
| BR-D-004 | Task status repository has no event mutation command |
| BR-D-005 | Required-report completion returns without changing the Task |
| BR-D-006 | No Actual write or contribution table exists in VS-03 |
| BR-D-007 | Explicit `contributionRuleKey`; title is never inspected for classification |
| BR-D-009 | Unique operation ID and append-only status-change row |
| BR-D-010 | Historical-effect port forces correction rather than destructive rewrite |

All 20 VS-03 BRs are mapped above: BR-C-001 through BR-C-010 and BR-D-001
through BR-D-010.

## Acceptance criteria

| Acceptance criteria | Evidence |
| --- | --- |
| AC-C-001, AC-C-009, AC-C-017 | deterministic date domain test and widget navigation state |
| AC-C-002, AC-C-003, AC-C-006, AC-C-007, AC-C-008, AC-C-013, AC-C-014, AC-C-015, AC-C-016, AC-C-020 | mixed Calendar Event domain/repository fixture and full widget journey |
| AC-C-004, AC-C-005, AC-C-011 | selected-day/overdue repository test and local persistence journey |
| AC-C-010, AC-C-012 | distinct create/detail route widget journey |
| AC-C-018 | historical-section collapse widget journey |
| AC-C-019 | transactional rollback plus retained-input widget test |
| AC-D-001, AC-D-004, AC-D-016 | create/edit/recoverable-failure widget and repository tests |
| AC-D-002, AC-D-003, AC-D-006, AC-D-007, AC-D-012, AC-D-020 | Task domain/repository tests |
| AC-D-005, AC-D-008, AC-D-009, AC-D-010, AC-D-011, AC-D-013, AC-D-014, AC-D-018, AC-D-019 | status-policy, independence, context, and correction tests plus widget journey |
| AC-D-015 | local-state relaunch Android smoke journey |
| AC-D-017 | retry/idempotency database test |

All 40 VS-03 ACs are mapped above: AC-C-001 through AC-C-020 and AC-D-001
through AC-D-020.

The 26 release blockers are AC-C-001 through AC-C-008, AC-C-011,
AC-C-015 through AC-C-020, AC-D-001 through AC-D-008, AC-D-010, AC-D-011,
and AC-D-015.

## Locked decisions

| Decision | VS-03 application |
| --- | --- |
| ADR-004 | Tasks and Calendar Events remain separate entities and interactions |
| ADR-011 | required-report attention and completion guard remain explicit |
| ADR-012 | explicit contribution key and idempotent effect boundary; no inferred Actual |
| ADR-006 | Task reads/writes are immediately local and remote-independent |
| ADR-009 | linked context is represented without merging identity or ownership |
| ADR-021 | no new permission; stored location text survives permission denial |
| ADR-023 | failure injection, migration rollback, diagnostics-safe errors, and multi-level tests |
| ADR-005 | Task completion never edits Actual |
| OPD-1-009 | Awaiting Report remains prominent; cancelled/rescheduled history uses Changes |
| OPD-1-010 | selected day survives in-session; cold Planner defaults to today |
| OPD-1-011 | All-day, Timed, Tasks, Overdue, Awaiting Report, Changes order |
| OPD-1-012 | required-report Task remains Incomplete until a coherent future report save |
| OPD-1-013 | direct reopen only without report/ledger effects; otherwise correction |
| OPD-1-014 | Skipped means intentionally not done; Cancelled means no longer intended |
| OPD-1-015 | no V1 hard delete; status history is retained |

## Visual-reference evidence

The approved
`UI Preferences/planner-approved-reference.png` is 862 by 1824 pixels. The
Flutter widget journey fixes its first flow to the matching 431 by 912 logical
viewport at 2x density. The matching
`UI Preferences/stitch_next_transfer/planner_recreated/code.html` supplied the
60-pixel hour slots, 54-pixel time column, event positioning, compact week
strip, dark surfaces, event-green accent, FAB proportion, and bottom-navigation
measurements.

The Flutter render was captured to ignored build output and manually compared
with the PNG. It retains real Android safe areas and does not reproduce the
reference's fake iOS status bar or home indicator.

### Documented visual/scope deviations

| Affected area | Reason | Result |
| --- | --- | --- |
| Planner top-bar search and notification examples | Search and notification behavior belongs to later authorized slices; VS-02 Privacy Center must remain reachable | One truthful Privacy and Data action is shown; no fake working search/notification action |
| All-day, Task, Overdue, Awaiting Report, and Changes content | The PNG sample primarily demonstrates a populated timed-event grid, while the behavioral contract requires all six ordered collections | All-day appears compactly before the grid when present; remaining ordered sections follow the grid |
| Calendar Event create/detail and production data | VS-04 owns Calendar Event persistence, editing, and recurrence; implementing it here would cross the authorization boundary | VS-03 supplies a typed event read-model port and complete presentation tests; the production adapter is empty and create/detail handoff truthfully says unavailable |
| Typography in automated capture | Flutter widget tests use a deterministic test font | Geometry is asserted automatically; typography hierarchy is manually compared from the native widget definitions |

## Quality-gate record

| Gate | VS-03 status |
| --- | --- |
| Q0 Authority and traceability | Pass — local verifier and protected quality run 30326469061 confirm approved hashes, authorization overlay, Android identity, and all VS-03 IDs |
| Q1 Static and build | Pass — strict format, analyzer, byte-identical codegen, dependency review, debug APK assembly, and protected quality run 30326469061 |
| Q2 Domain/database/migration | Pass — schema v3 upgrade/rollback and all Task repository/domain tests pass locally and in protected quality |
| Q3 Offline/privacy/idempotency | Pass — atomic failure, retry, concurrent status, no-permission, relaunch, and API 24/API 36 persistence boundaries pass |
| Q4 UI/accessibility | Pass — matching viewport, timeline geometry, complete widget flow, 200% text scale, and API 24/API 36 Planner journeys pass |
| Q5 Android platform | Pass — Android matrix run 30326502074 verifies startup, privacy, Planner, and process persistence on API 24 and API 36; its cancelled API 24 install lane passed on attempt 2 |
| Q6 Remote security | Not applicable; no remote code introduced |
| Q7 Slice evidence | Pass — all mapped local tests, protected quality run 30326469061, and Android matrix run 30326502074 are green |

No VS-04 schema, recurrence engine, Calendar Event write repository, remote
client, notification worker, maps SDK, contacts SDK, or unrelated permission is
introduced.

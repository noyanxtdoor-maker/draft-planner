# VS-08 Traceability — Weekly Planning Lifecycle

**Authorized:** 2026-07-28

**Scope boundary:** VS-08 only; VS-09 and later remain unauthorized.

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

## Quality-gate record

| Gate | VS-08 status |
| --- | --- |
| Q0 Authority and traceability | Local pass after approved-hash, permanent Android identity, schema v8, dependency boundary, and FR/BR/AC verification |
| Q1 Static and build | Local analyzer and debug APK build pass; protected quality pending |
| Q2 Domain/database/migration | Local pass for lifecycle, v7-to-v8 migration, failed-migration rollback, and injected write rollback |
| Q3 Offline/privacy/idempotency | Local pass; no package, permission, remote client, direct Actual write, or non-transactional review |
| Q4 UI/accessibility | Local widget pass at approved viewport and 200% text scale |
| Q5 Android platform | Debug APK built and installed on Infinix X6731; Flutter integration launch was blocked by stale wireless mDNS alias/tool transport; clean API 24/API 36 matrix pending |
| Q6 Remote security | Not applicable; no remote client or provider identity introduced |
| Q7 Slice evidence | Local evidence complete; protected quality and Android matrix pending |

VS-09 Pathways, remote sync, provider Calendar integration, notifications,
maps, contacts, and all later-slice work are not implemented.

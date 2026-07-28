# VS-07 Traceability — Home and Life Indicators

**Authorized:** 2026-07-28

**Scope boundary:** VS-07 only; VS-08 and later remain unauthorized.

**Dependency:** VS-06, satisfied.

## Exit gate

Home displays the six approved indicators in fixed order and approved units for
the current Monday-Sunday period. Actual is derived only from signed Activity
Ledger entries. Target begins Not set and distinguishes explicit zero.
Scheduled Potential uses only explicitly qualified, future, still-scheduled
Task/Event sources. No combined Actual-plus-Scheduled value or composite
worthiness/life-quality score exists.

## Functional requirements

| Requirement | Implementation and evidence |
| --- | --- |
| FR-B-001 | `IndicatorPeriod.currentWeek` and Home period label expose exact Monday-Sunday boundaries |
| FR-B-002 | seeded definitions are read in persisted fixed position order; matching-viewport widget test asserts all six keys |
| FR-B-003 | Home/detail cards label Actual, Target, and Scheduled separately; no combined-total model exists |
| FR-B-004 | `DriftIndicatorRepository._readActual` signs and sums period-scoped Activity Ledger rows; schema-v7 migration is rollback-tested |
| FR-B-005 | indicator detail route reads immutable contribution and reversal history |
| FR-B-006 | indicator detail lists each explicitly qualified Scheduled source |
| FR-B-007 | append-only target revisions encode Not set separately from explicit zero |
| FR-B-008 | repository tests prove corrected reports change Actual through reversal/replacement rows and stream invalidation observes local writes |
| FR-B-009 | Actual exposes no setter, form field, table, or direct write path |
| FR-B-010 | only the structured `life-indicator:<key>:<value>:<scale>:<unit>` rule qualifies Scheduled Potential; a title-only fixture is ignored |
| FR-B-011 | projection summaries expose Current/Stale/Failed and the controller exposes Rebuilding while retaining the prior snapshot |
| FR-B-012 | each indicator projection is isolated; one malformed unit yields a labeled failure while the other five remain usable |
| FR-B-013 | Home Today action routes to Planner, whose date source selects the current local day |
| FR-B-014 | Home and indicator detail route to the limited weekly target prompt; the VS-08 Weekly Plan lifecycle is not implemented |
| FR-B-015 | Home attention cards show overdue Task and Calendar Event Awaiting Report counts when non-zero |
| FR-B-016 | spiritual-adjacent indicators use factual names and raw counts without qualitative labels |
| FR-B-017 | no composite score, percentage, worthiness, streak, or gamification model exists |
| FR-B-018 | indicator and target routes carry the stable indicator key and exact period start; widget navigation asserts retained boundaries |
| FR-B-019 | cancelled and rescheduled originals are excluded; the explicit replacement contributes once; canonical Task/Event links de-duplicate potential |
| FR-B-020 | Riverpod reads the local Drift repository immediately and watches local table invalidations; no network client is involved |

All 20 VS-07 functional requirements, FR-B-001 through FR-B-020, are mapped.

## Business rules

| Rule | Enforced by |
| --- | --- |
| BR-B-001 | separate Actual, Target, and Scheduled domain values and labels |
| BR-B-002 | Activity Ledger-only Actual query |
| BR-B-003 | future scheduled sources never enter Actual; elapsed unreported Events become Awaiting Report |
| BR-B-004 | nullable Not set target versus explicit scaled zero |
| BR-B-005 | contribution-history route maps every ledger row to its report source |
| BR-B-006 | signed reversal and replacement history remains visible and summed |
| BR-B-007 | structured rule parser; title-only fixture exclusion |
| BR-B-008 | status, occurrence, reschedule replacement, and canonical-link filtering |
| BR-B-009 | neutral factual labels for spiritual-adjacent indicators |
| BR-B-010 | absence of any composite worthiness or life-quality calculation |

All ten VS-07 business rules, BR-B-001 through BR-B-010, are mapped.

## Acceptance criteria

| Acceptance criteria | Evidence |
| --- | --- |
| AC-B-001 through AC-B-003 | approved-viewport Home widget journey asserts period, six fixed cards, and three separate labels |
| AC-B-004 through AC-B-010 | repository tests cover ledger Actual, history, Scheduled sources, zero/Not set, correction refresh, no Actual setter, and title-only exclusion |
| AC-B-011 through AC-B-012 | stale-state and isolated malformed-projection tests; rebuilding/partial-failure UI state |
| AC-B-013 through AC-B-015 | Home Planner/target routes and attention-count read model; Android integration journey |
| AC-B-016 through AC-B-018 | neutral factual presentation, no composite score, and period-preserving detail navigation |
| AC-B-019 through AC-B-020 | cancelled/rescheduled/canonical-source filtering and immediate local repository/controller tests |

All 20 VS-07 acceptance criteria, AC-B-001 through AC-B-020, are mapped.

Release blockers are AC-B-001 through AC-B-010, AC-B-012, AC-B-016, and
AC-B-017.

## Locked decisions

| Decision | VS-07 application |
| --- | --- |
| ADR-004 | Tasks and Calendar Events remain separate sources with explicit canonical de-duplication |
| ADR-005 | Actual is ledger-derived, factual, explainable, and read-only |
| ADR-006 | Home and targets operate from local Drift state without account/network dependency |
| ADR-010 | current week is Monday-Sunday; only the target prompt enters VS-07 |
| ADR-011 | elapsed unreported Events become Awaiting Report, never Actual or future potential |
| ADR-012 | signed Activity Ledger entries are the sole Actual authority |
| OPD-1-005 | targets start Not set; scheduled-derived suggestion is optional and never silently applied |
| OPD-1-006 | Home stays current-week only; period history is entered through indicator detail |
| OPD-1-007 | no Actual-plus-Scheduled combined total exists |
| OPD-1-008 | persisted fixed six-indicator order is retained |

## Visual-reference evidence and deviations

VS-07 opened `UI Preferences/home-approved-reference.png` at its 941 by 1672
reference viewport and inspected
`UI Preferences/stitch_next_transfer/home_recreated/code.html` before changing
Home. The implementation reuses the approved dark charcoal/black surfaces,
dusty pink accent, compact heading hierarchy, dense indicator-card geometry,
border treatment, safe areas, and permanent five-item bottom navigation. It is
native Flutter and uses no HTML, WebView, CDN, sample photograph, or fake OS
chrome.

Documented deviations:

| Affected screen | Reference | Required reason | Result |
| --- | --- | --- | --- |
| Home indicator cards | `home-approved-reference.png` | behavioral requirements and OPD-1-007 prohibit the reference's visually blended fraction treatment | Actual, Target, and Scheduled are separately labeled; no blended fraction or total appears |
| Home secondary content | PNG and matching HTML | VS-09 Pathways is unauthorized and sample content is not approved product data | the sample Active Pathways card is omitted; factual attention cards appear only when local counts are non-zero |
| Home top chrome | PNG and matching HTML | Android-first system behavior and scope | real Android safe areas/navigation are used; sample notification/search actions and simulated iOS chrome are omitted |

## Quality-gate record

| Gate | VS-07 status |
| --- | --- |
| Q0 Authority and traceability | Pass locally — approved hashes, permanent Android identity, permission boundary, schema v7, slice boundary, and FR/BR/AC mapping |
| Q1 Static and build | Pass locally — strict format, analyzer, byte-clean codegen, all 86 tests, and direct debug APK assembly |
| Q2 Domain/database/migration | Pass locally — projection repository tests plus v6-to-v7 migration and failed-migration rollback |
| Q3 Offline/privacy/idempotency | Pass locally — local-only reads/writes, append-only idempotent target revisions, no new package/permission/remote client |
| Q4 UI/accessibility | Pass locally — matching-reference viewport, native safe-area layout, Flutter semantics, and explicit 200% Home coverage |
| Q5 Android platform | Local APK pass; API 24/API 36 clean-emulator matrix pending |
| Q6 Remote security | Not applicable; no remote client or provider identity introduced |
| Q7 Slice evidence | Pending protected quality and Android matrix runs |

VS-08 Weekly Plan creation/review, commitments, carryover, archive/reopen rules,
remote sync, provider Calendar integration, notifications, maps, and all later
slice work are not implemented.

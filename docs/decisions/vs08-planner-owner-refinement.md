# VS-08 Planner Owner Refinement

**Approved by product owner:** 2026-07-29

**Starting implementation commit:** `201f2a35ebafcbea1ad277fd43c0b81050bec63d`

**Scope:** controlled refinement of the existing VS-08 Planner correction on
PR #8. VS-09 and later slices remain unauthorized.

## Decision

The product owner approved these additions before final VS-08 acceptance:

1. a PMG-inspired, bottom-sliding native Calendar Event detail sheet;
2. compact field organization using Next Transfer design tokens;
3. explicit rejection of missionary-only fields and assets;
4. typed location data that remains ready for a future map adapter without
   adding a map dependency in VS-08;
5. first-class Backup Appointment classification and timeline treatment;
6. long-press movement of existing Calendar Event blocks with one final write;
7. pinch-to-zoom for the Planner timeline with a persisted local preference;
8. a reusable contextual floating creation menu;
9. continued Event Type picker-first creation from every implemented entry
   point;
10. continued confirmed-source protection for Actual;
11. a compact Planner top bar with date, filter, selection, and overflow
    controls;
12. removal of the permanent Task, Overdue Task, Awaiting Report, and Changes
    footer sections;
13. display of all non-deleted Events regardless of Report Required;
14. derived Awaiting Report presentation that never creates Actual;
15. typed Schedule, Day, Week, Tasks, and Awaiting Reports presentations;
16. relocation of Planner and Privacy settings under More → Settings.

The two owner instructions attached on 2026-07-29 are the authoritative
follow-up for these overlapping Planner concerns. They supplement
`OWNER-AMENDMENT-001` and do not reopen unrelated ADRs, Product Requirements,
Open Product Decisions, or vertical slices.

## Boundary and conflict resolution

`OWNER-AMENDMENT-001` previously deferred generic Backup screens and
later-destination reverse flows. This refinement authorizes only Calendar
Event Backup Appointment classification inside VS-08. It does not authorize a
standalone Backup destination, backup service, Pathways domain, Contacts
domain, map implementation, notifications, or remote sync.

Pathways and Contacts still have no authorized production screen or repository.
The reusable creation-action component may expose truthful disabled/deferred
actions on existing destinations, but it must not fabricate those later-slice
records or relationships.

## Locked protections

- Task and Calendar Event remain separate entities.
- Selecting an Event Type precedes creation form state and persistence.
- Saving, moving, resizing, filtering, selection, zoom, and time passing never
  create Actual.
- Report Required controls reporting state, never basic Event visibility.
- Awaiting Report is derived from factual time/status/report state.
- Backup and primary appointments cannot both contribute Scheduled Potential
  for one linked planned outcome.
- Reported history and Activity Ledger entries are never rewritten in place.
- Event and Task removal preserves linked-record independence.
- Drift remains the immediate offline source of truth.
- No map, notification, analytics, or network dependency is added.
- Existing UUIDs, reports, links, Weekly Plans, and provenance survive the
  additive migration.

## Authority mapping

This refinement applies within VS-08 and touches the existing authority
families already mapped for the Planner correction:

- ADR-003 through ADR-006, ADR-009 through ADR-013, ADR-021 through ADR-023;
- FR-B-001–020, FR-C-001–020, FR-D-001–020, FR-E-001–024,
  FR-G-001–020, FR-H-001–020, and FR-I-001–020;
- BR-B-001–010, BR-C-001–010, BR-D-001–010, BR-E-001–012,
  and BR-I-001–010;
- AC-B-001–020, AC-C-001–020, AC-D-001–020, AC-E-001–024,
  and AC-I-001–020;
- OPD-1-005–020 and OPD-2-010–012.

No immutable baseline file is modified.

# OWNER-AMENDMENT-001 — Screen Capture and VS-08 Correction Scope

**Approved by product owner:** 2026-07-29
**Applies from:** schema/application correction following VS-08 checkpoint
`af3c6b1ddbedecb0cb441eef4f19f20bb0a9b459`

## Decision

This owner amendment replaces only the screen-capture/app-switcher clauses
listed below. It does not reopen ADR-001 through ADR-025, any other Product
Requirement A–X row, any other Open Product Decision, or any other vertical
slice contract.

| Retired wording | Approved replacement |
| --- | --- |
| FR-W-006 — Sensitive content shall be obscured in app-switcher previews where supported. | FR-W-006A — Next Transfer shall allow Android screenshots, screen recording, and normal app-switcher previews and shall not enable app-level screen-capture prevention. |
| AC-W-006 — Sensitive content is obscured in app-switcher previews where supported. | AC-W-006A — Screenshot, recording, and the normal Android app-switcher preview work without an app-level secure-window flag. |
| BR-W-005 — Obscure sensitive previews where supported. | BR-W-005A — Screen-capture prevention is not a privacy control in Next Transfer; privacy wording must not claim it. |
| OPD-5-012 — Enable the strongest supported obscuring without claiming universal OS coverage. | OPD-5-012A — Permit normal Android capture and app-switcher behavior; do not set `FLAG_SECURE` or an equivalent capture-blocking path. |

The immutable Phase 3 workbook and DOCX remain byte-for-byte preserved. This
file is the explicit approval overlay required by the exception protocol.

## Protections retained

Privacy Lock, biometric/device-credential access, secure token storage,
notification redaction, private attachments, local-only policy options,
encrypted portable backups when their owning slice is implemented, row-level
security when remote sync is implemented, and sensitive logging restrictions
remain unchanged.

## VS-08 correction authorization

The owner authorized the Planner visual/interaction correction, the approved
Activity Type extension presented as Event Types, deterministic Event
Type/Life Indicator mapping, current-scope Planner settings, and capture-policy
correction on the existing VS-08 branch.

Notification permission/scheduling behavior remains owned by VS-16. Reverse
flows and manual QA that require Pathways, Covenant Path, Contacts, Employment,
Documents, Backups, or other not-yet-authorized screens remain deferred to
VS-09 through VS-20 as mapped by the approved workbook. VS-08 supplies stable
extension points and implements only reverse flows from screens that already
exist.

## Data protection

The correction is additive. It must not reset the database, rewrite Actual,
mutate historical ledger entries, delete existing Calendar Events, change
existing UUIDs, or discard reports, task-event links, weekly plans, or
provenance.

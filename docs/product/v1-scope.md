# v1 Scope

**Status:** Recommended, pending owner confirmation. The dividing line is deliberate: v1 must prove
that the trustworthy-progress model works in daily use, on one phone, offline. Everything not serving
that proof is later.

v1 target: **Android first, offline-capable, single-user, Philippines content pack.**

---

## 1. In scope for v1

### 1.1 Foundation

- Flutter application shell, dark theme from `packages/design_tokens`, five-tab navigation.
- Drift local database with the full v1 schema, migrations, and tombstones.
- Supabase email/password plus magic-link authentication, with a local session that survives offline
  launch.
- Onboarding: profile, country selection (Philippines), return date, initial pathway selection.

### 1.2 Planner and the progress engine — the core of v1

- Tasks: create, schedule, complete, skip, cancel; unscheduled task backlog.
- Calendar events: one-off and recurring, with a recurrence rule engine and per-occurrence overrides.
- Activity outcome reporting: Completed / Partially Completed / Did Not Happen / Rescheduled /
  Cancelled, with Awaiting Report surfacing on Home.
- Daily timeline, weekly calendar, monthly overview.
- Weekly Planning flow and Weekly Review.
- Activity ledger with idempotency, reversals, and partial values.
- Progress engine: count, duration, boolean, milestone, and streak metrics; goal / actual /
  scheduledPotential / remaining / overdue; weekly history.
- Backup plans attached to activities.

### 1.3 Pathways

- Templates for Covenant Path, Employment, Education, Documents and Identification, Financial
  Self-Reliance, Health and Routine, Family and Relationships, Service and Community.
- User-created pathways; milestones; goals and goal steps.
- Covenant Path with factual statuses, private-by-default sensitive records, and the stated principle.

### 1.4 Contacts

- Contacts with categories, next follow-up, last interaction, related pathway, private notes.
- Contact interactions log and follow-up scheduling that feeds the ledger.

### 1.5 Documents, employment, education

- Document requirements from the Philippines content pack (PSA, NBI, SSS, PhilHealth, Pag-IBIG,
  BIR TIN, First-Time Jobseeker).
- Local requirement state machine, masked identifier storage, expiry tracking.
- Job applications and education applications with the external state machine and explicit submission
  confirmation.
- BYU–Pathway tracker as a checklist over official steps; My Plan structure.

### 1.6 Country content

- Philippines pack shipped as bundled read-only content, versioned, with authority, source URL,
  effective / last-verified / next-review dates and verification status surfaced in the UI.
- Content read path only. No in-app editing.

### 1.7 Sync

- Outbox with client-generated UUIDs, retry with exponential backoff, idempotency keys, sync cursor.
- Supabase Postgres with RLS for all user tables.
- Private Storage buckets with signed URLs for attachments.
- Conflict resolution per entity, including a manual review queue for notes, applications, and
  documents.

### 1.8 System

- Local notifications for activity reminders, awaiting-report prompts, follow-ups, and deadlines.
- Settings: profile, country and language, notifications, privacy, appearance, accessibility,
  sync and backup, export data.
- Export: full user-data export as JSON plus attachment manifest.
- Maps and Places: saved places, event locations, contact addresses, open-in-external-maps.
- Activity History and Journal.

---

## 2. Explicitly deferred past v1

| Deferred | Until | Why |
| --- | --- | --- |
| Admin content portal (`apps/admin`) | Phase 6 | v1 content is authored in-repo and shipped bundled; a portal before there is content to manage is premature |
| Server-side progress recomputation | Post-v1 | Local engine is authoritative in v1; server reconciliation is added once ledger semantics are proven in the field |
| iOS release build | Post-v1 beta | Android first matches the primary user's device; the codebase stays iOS-compatible but is not certified |
| Real-time multi-device sync | Post-v1 | v1 assumes one primary device; sync is convergent, not live |
| Push notifications (server-initiated) | Phase 5+ | Local notifications cover v1 needs without a push infrastructure |
| Second country pack | Post-v1 | The architecture supports it; the content work is the constraint |
| Sharing, leader views, group features | Not planned | See [`non-goals.md`](non-goals.md) |
| In-app document scanning / OCR | Post-v1 | Camera capture plus file attach is sufficient; OCR adds an accuracy-liability surface |
| Calendar provider two-way sync (Google/Apple) | Post-v1 | Import direction may arrive earlier than export; two-way sync conflicts with the ledger's authority model and needs its own ADR |
| Web application for end users | Not planned | Mobile is the product (ADR-0010) |

---

## 3. Definition of done for v1

Functional:

1. A user plans a week offline, reports outcomes, and sees correct actual / potential / remaining
   figures with the device in airplane mode throughout.
2. All twelve acceptance criteria in [`progress-rules.md`](progress-rules.md) pass as automated tests.
3. Airplane-mode work for 48 hours converges on reconnect with zero data loss and zero duplicate
   ledger rows.
4. Another authenticated user cannot read any row or attachment of the first user — proven by RLS
   tests, not by inspection.
5. Every Philippine document requirement in the pack shows its authority, source URL, and verification
   dates, and links out to the official source.
6. A job application reaches Submitted only via explicit confirmation.
7. Every More row leads somewhere real.

Quality gates:

8. Unit and domain-rule coverage ≥ 80% on `domain_models` and the progress engine; ledger and
   conflict code paths ≥ 95%.
9. Golden tests for the five primary screens in light-impaired conditions: largest supported text
   scale, and reduced-motion.
10. Accessibility: every interactive target ≥ 44dp, contrast ≥ 4.5:1 for body text, full screen-reader
    labelling on Home, Planner day view, and the outcome-report sheet.
11. Cold start to interactive Home ≤ 2.0s on a mid-range Android device with 12 months of data.
12. No sensitive field present in any diagnostic payload — verified by an automated strip-list test.

---

## 4. Scale assumptions for v1

| Dimension | Assumption | Consequence |
| --- | --- | --- |
| Users | Tens to low hundreds (private beta) | Supabase free/low tier is adequate; no read replicas |
| Devices per user | 1 primary, occasional second | Convergent sync sufficient; no presence or live cursors |
| Events per user per year | ~2,000 | Local queries stay indexed and fast; no archival tier needed in v1 |
| Ledger rows per user per year | ~5,000 | Weekly aggregate snapshots keep dashboard reads O(weeks), not O(rows) |
| Attachments per user | ~30 files, ≤ 10 MB each | Signed-URL access; no CDN needed |
| Offline duration | Up to 14 days continuous | Outbox must survive app restarts and bound its growth |

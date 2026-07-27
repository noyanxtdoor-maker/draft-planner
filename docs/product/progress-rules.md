# Progress Rules

**Status: Confirmed.** This is the product's core contract. Every module that displays a number obeys
it. Implementation detail lives in [`../data/activity-ledger.md`](../data/activity-ledger.md) and
[`../data/progress-calculation.md`](../data/progress-calculation.md); this document is the rule itself.

---

## Rule 0 — the one rule

> **Users may edit their goals and targets.**
> **Users must not manually edit actual progress.**
> **Actual progress is produced by confirmed source records.**

`goal` is user input. `actual` is a derived read-only projection of `activity_ledger`. There is no code
path, no debug menu, and no admin tool that sets an actual directly. A correction is expressed by
correcting the *source record*, which emits a reversal into the ledger; the actual then recomputes.

### Why the product is built this way

An app that counts scheduled work as completed work produces numbers that diverge from reality within
one week. Once a user catches it lying, every other number becomes suspect and the product is dead. The
cost of this rule is friction — the user must report outcomes. The return is a number that is still
true in month six.

---

## Rule 1 — time passing is not achievement

**A scheduled event must never count as completed merely because its scheduled time has passed.**

At `scheduled_end < now` with no report, the activity becomes **Awaiting Report** — visible on Home,
counted in *neither* `actual` nor `scheduledPotential`, and counted in `overdueAmount`. The clock alone
writes no ledger row. There is no scheduled job anywhere in this system that completes activities by
time.

## Rule 2 — every past activity resolves to a reported outcome

After a calendar activity's end time the user reports exactly one outcome:

| Outcome | Ledger effect | Notes |
| --- | --- | --- |
| **Completed** | Full credit (count 1, or full planned duration) | |
| **Partially Completed** | Partial credit from a reported actual value | Requires `actual_value`; may not exceed the planned value |
| **Did Not Happen** | No credit | Recorded as a fact, not a failure; optional reason |
| **Rescheduled** | No credit on the original occurrence | Creates a new occurrence; the original never contributes (Rule 5) |
| **Cancelled** | No credit | Removes the occurrence from `scheduledPotential` |

Tasks carry a parallel, smaller set:

| Task outcome | Ledger effect |
| --- | --- |
| **Completed** | Full credit |
| **Incomplete** | No credit; remains open and overdue |
| **Skipped** | No credit; deliberately closed without credit |
| **Cancelled** | No credit; closed and removed from remaining work |

Reporting is never silently inferred, and an unreported activity is never quietly discarded — it stays
in Awaiting Report until the user resolves it. Bulk resolution ("mark these four as Did Not Happen") is
allowed because it is still an explicit user statement about each item.

## Rule 3 — automatic completion is opt-in, per activity, off by default

A **trusted recurring activity** may auto-complete. Constraints:

- default is **off**, globally and per activity;
- the user must enable it explicitly on that specific recurring activity;
- only a recurring activity may be trusted — never a one-off, never a milestone, never an external
  application state, never a government document requirement;
- the ledger row records `source_type = 'system_adjustment'` with `metadata.auto_completed = true` and
  the rule id, so an auto-credited row is always distinguishable from a user-reported one;
- the user can revoke trust, which stops future auto-credit and leaves history intact;
- Progress screens visually distinguish auto-credited contributions.

Rationale: "morning prayer" or "exercise" may genuinely be habitual, and forcing seven daily reports
produces report fatigue that damages reporting accuracy everywhere else. But the default must never
manufacture progress the user did not confirm.

## Rule 4 — no double counting

**Do not count both a parent event and its child task when they represent the same completed action.**

Every metric contribution carries a `contribution_key` derived from `(metric_id, semantic_action)`. The
ledger holds a unique index on `(user_id, metric_id, idempotency_key)`, and the progress engine
deduplicates by contribution group before summing.

Concretely:

- A calendar event *Apply to 2 jobs* linked to two `job_applications` credits the metric once — from
  the applications, which are the authoritative source — not once per event and once per application.
- A task that is the execution record of an event (`task.source_event_id` set) contributes through the
  event's report, not independently.
- A milestone whose completion is evidenced by a document requirement credits the document
  requirement's contribution, not both.

Where the parent and the child genuinely represent *different* work — a preparation task plus the
appointment itself — they are separate metrics or separate `semantic_action` values, and both count.
Establishing which case applies is part of defining an
`activity_type_metric_rules` row, not an implementation decision made at the call site.

## Rule 5 — rescheduling never creates credit, and never destroys it

Rescheduling occurrence A to occurrence B:

1. A is reported `Rescheduled` → no ledger row for A;
2. B is created as `scheduled`, entering `scheduledPotential` for the week B falls in;
3. if A had already been credited before the reschedule, the credit is **reversed**, not deleted.

A reschedule across a week boundary moves potential out of the old week. It never moves *actual* out of
the old week — actuals are stamped to the week in which the work was reported to have occurred.

## Rule 6 — corrections are reversals, never rewrites

Undoing a completion appends a `reversal` row referencing the original via `reversal_of`. Original rows
are never deleted or mutated. Effective progress is the signed sum. Consequences: history is auditable,
"why did my number change?" is always answerable, and sync can replay safely.

## Rule 7 — idempotent processing

Every ledger write carries an `idempotency_key`. Processing the same source event twice — a retried
sync, a double-tap, a replayed outbox entry — produces exactly one row. This is enforced by a unique
database index, not by application vigilance alone.

## Rule 8 — external processes require explicit confirmation

Next Transfer does not submit external applications. A state may become **Submitted by User** only
after the user explicitly confirms an action they took elsewhere, in language that makes the
attribution unmistakable:

> *"I submitted my application through the official BYU–Pathway website."*

Only that confirmation writes a ledger row. Opening the official link does not. Completing the local
checklist does not. See [`../data/content-pack-model.md`](../data/content-pack-model.md) for the full
external state machine.

## Rule 9 — a government document counts exactly once

A document requirement contributes on transition to `received` (or `verified`, per its definition) and
never again. Re-uploading a file, renewing an expiring document, or editing a note does not re-credit.
Renewal of an expiring document is a *new* requirement instance with its own single contribution.

## Rule 10 — scheduled potential is never actual

```
actual            = Σ signed ledger value for the metric within the period   (read-only, derived)
scheduledPotential = Σ planned value of future, still-scheduled occurrences in the period
remaining          = max(goal − actual − scheduledPotential, 0)
overdueAmount      = Σ planned value of past-due occurrences and tasks awaiting resolution
```

`scheduledPotential` answers *"if I do everything I have planned, will I reach my goal?"* — a planning
question. It is rendered in a visually distinct, dimmer treatment from `actual`, is never summed into
`actual`, and is never persisted as progress. `remaining > 0` means the user must plan more work, not
merely do the work already planned.

---

## Worked example

Goal: **Job Applications, 5 this week.** Sunday, week start.

| Event | actual | scheduledPotential | remaining | overdue |
| --- | --- | --- | --- | --- |
| Week starts; 3 application sessions scheduled | 0 | 3 | 2 | 0 |
| Mon: session reported Completed, 1 application submitted and confirmed | 1 | 2 | 2 | 0 |
| Tue: session end passes, unreported | 1 | 1 | 3 | 1 |
| Tue evening: user reports Partially Completed, 1 of 2 applications | 2 | 1 | 2 | 0 |
| Wed: user submits 2 applications with no scheduled session | 4 | 1 | 0 | 0 |
| Thu: user realises Monday's entry was a duplicate; corrects the application record | 3 | 1 | 1 | 0 |
| Fri: remaining session rescheduled to next Monday | 3 | 0 | 2 | 0 |

Note the Thursday row: the correction produced a reversal, `actual` fell from 4 to 3, and the ledger
retains both the original credit and its reversal. Nothing was overwritten.

---

## Acceptance criteria

A progress implementation is correct when all of the following hold. These map one-to-one onto the
required test scenarios in [`../implementation/testing-strategy.md`](../implementation/testing-strategy.md).

1. A scheduled event whose end time passes without a report adds **0** to `actual` and appears in
   `overdueAmount`.
2. A Partially Completed duration activity adds exactly the reported duration, never the planned one,
   and cannot exceed the planned value.
3. A rescheduled event contributes **0** on the original occurrence and full potential on the new one;
   totals across both weeks show no duplication.
4. Deleting a completion produces a reversal row; `actual` decreases; the original row still exists.
5. Processing the same `event_report` twice yields one ledger row and an unchanged `actual`.
6. An offline completion applies locally, survives an app restart, and produces exactly one server row
   after sync.
7. A parent event and its child task representing the same action credit the metric once.
8. A job application contributes only after explicit submission confirmation.
9. A government document requirement contributes exactly once, regardless of re-upload or re-edit.
10. No API, UI control, or debug path can set an `actual` directly. (Enforced by test and by review.)
11. `remaining` is never negative and equals `max(goal − actual − scheduledPotential, 0)`.
12. An auto-completed recurring activity is disabled by default, and when enabled produces rows
      distinguishable by `metadata.auto_completed`.

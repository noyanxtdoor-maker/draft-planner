# Product Overview

**Next Transfer** — *The mission ended. The next transfer begins.*

## 1. The problem

A returning missionary leaves a life with total external structure — a planner, a companion, a
schedule, weekly key indicators, a district leader asking how the week went — and lands in a life with
none of it. Within weeks they are expected to independently pursue employment, education, government
documentation, finances, health, family relationships, Church participation, and personal goals, all at
once, usually with unreliable connectivity and a phone as their only device.

The failure mode is not laziness. It is that each of these tracks lives in a different place: a
government requirement in a browser tab, a job application in an email thread, a BYU–Pathway deadline
on a paper note, a temple plan in memory. Nothing shows the whole week. Nothing tells them what is
actually behind versus what merely feels behind.

Generic to-do applications do not solve this, for three reasons:

1. They treat *scheduling* as *doing*. A calendar block that passes is marked done, so their numbers
   lie to them within a week and they stop trusting the app.
2. They have no model for externally-owned processes. A PSA birth certificate, an NBI clearance, and a
   BYU–Pathway admission are not tasks the app can complete; they are processes the user drives
   elsewhere and needs to track locally.
3. They assume connectivity.

## 2. What Next Transfer is

A single planning system for the years after the mission, built on the planning muscle memory the user
already has: daily plan, weekly plan, weekly key indicators, a review at the end of the week.

It covers daily plans, weekly planning, calendar activities, tasks, long-term pathways, Covenant Path
commitments, employment, job applications, education, BYU–Pathway planning, Philippine government
requirements, My Plan, contacts and follow-ups, locations and maps, financial self-reliance, health and
routines, family and relationships, service and community participation, and personal progress.

### The commitments that distinguish it

**Progress is earned, not typed.** The user sets goals. The user never edits an actual. Every actual
number traces to a confirmed source record — a reported activity, a completed task, a received
document, a milestone reached. A scheduled activity that passes without an outcome report contributes
nothing. The consequence is a number the user can trust in month six, which is the only point at which
trust matters.

**Externally-owned processes are tracked, never impersonated.** Next Transfer does not submit a
BYU–Pathway application, a government registration, or a job application. It holds the checklist,
opens the official source, schedules the reminder, and records what the user says they did — with
explicit confirmation before any state becomes "submitted".

**Changing facts are content, not code.** Government and program requirements change without warning.
They live in versioned country content packs, each record carrying its authority, source URL, effective
date, last-verified date, and next-review date. A PSA process change is a content release, not an app
release. `Verified` means *the source was checked on that date* — never that Next Transfer endorses the
organisation.

**It works without the internet.** Every action writes locally first and the interface responds from
local data. Cloud sync is a background reconciliation, never a precondition for planning your day.

**Spiritual life is planned, never scored.** Covenant Path holds user-selected commitments with factual
statuses. There is no righteousness score, no faithfulness percentage, no spiritual rank. The interface
states the principle plainly: *"This planner tracks your personal commitments, not your standing before
God."* Temple, calling, and ministering records are optional, private by default, and never used to
infer worthiness.

## 3. Who it is for

**Primary — the recently returned missionary (0–24 months home).** Age roughly 19–26. Owns a
mid-range Android phone; connectivity is intermittent and data is metered. Simultaneously job-hunting,
enrolling in school, assembling government documents, adjusting to family life, and holding onto
spiritual habits that used to be scaffolded by a mission schedule. High planning literacy, low
tolerance for an app that produces numbers it cannot justify.

**Secondary — the missionary preparing to return (final 3 months).** Wants the post-mission plan to
exist before the plane lands.

**Tertiary — the returned missionary 2+ years out** still using the system for career, education, and
family goals, with the mission-specific framing faded into the background.

Not a user of this product: a mission president, a ward council, a Church administrator, an employer, or
a school. Next Transfer has no supervisory view, no leader dashboard, and no reporting-upward path.
The user's data belongs to the user. See [`non-goals.md`](non-goals.md).

## 4. Country scope

The first content pack is the **Philippines**: PSA records, NBI Clearance, SSS, PhilHealth, Pag-IBIG,
BIR TIN, First-Time Jobseeker Assistance, PESO, TESDA, local education resources, and Philippine
My Plan material. The content architecture is country-agnostic from day one — layered as Global Core →
Church Member Pack → Country Pack → Regional Overrides → Personal User Rules — so a second country is a
content project, not a rewrite. See
[`../data/content-pack-model.md`](../data/content-pack-model.md).

## 5. Independence

Next Transfer is independent. It is not endorsed by, affiliated with, or produced by The Church of
Jesus Christ of Latter-day Saints, BYU–Pathway Worldwide, any Philippine government agency, any
school, any employer, or any partner organisation. It uses no official logos or seals. It links to
official sources and states plainly when information may have changed.

## 6. How success is judged

Behavioural, not vanity:

| Signal | Why it matters | Target for the v1 beta |
| --- | --- | --- |
| Weekly planning completed | The habit the whole product is built around | ≥ 60% of active users complete a weekly plan in a given week |
| Outcome reporting rate | Whether the trustworthy-progress model is actually used | ≥ 70% of past-dated activities receive an outcome within 72 hours |
| Offline actions surviving sync | Whether the local-first promise holds | ≥ 99.9% of queued operations eventually apply, zero silent data loss |
| Government document progress | Whether the hardest real-world track moves | Median user advances ≥ 2 document requirements in 60 days |
| Retention at week 8 | Whether trust survived contact with reality | ≥ 35% of installs still planning weekly |
| Progress disputes | Whether users believe the numbers | Near zero "why does it say I did this?" reports |

Deliberately *not* success signals: session count, time in app, streak length as a headline metric, or
any aggregate that could read as a spiritual verdict.

## 7. Constraints that shaped the architecture

| Constraint | Architectural consequence |
| --- | --- |
| Intermittent, metered connectivity | Local-first with Drift as the read path; outbox for writes; sync is background-only (ADR-0006) |
| Progress must be defensible | Append-oriented activity ledger as the sole source of automatic actuals (ADR-0007) |
| Government facts change unpredictably | Versioned content packs with verification lifecycle (ADR-0008) |
| Highly sensitive personal data | RLS everywhere, private buckets with signed URLs, masked identifiers, sensitive fields excluded from diagnostics |
| Single developer plus coding agents | Documentation-first monorepo with explicit invariants and module boundaries (ADR-0009) |
| Mobile is the product | Flutter mobile only; Vercel exclusively for the optional admin portal (ADR-0010) |

## 8. Where to read next

1. [`v1-scope.md`](v1-scope.md) — what ships first, and what does not.
2. [`progress-rules.md`](progress-rules.md) — the core product rule, in full.
3. [`navigation-contract.md`](navigation-contract.md) — the fixed information architecture.
4. [`../architecture/system-overview.md`](../architecture/system-overview.md) — how it is built.

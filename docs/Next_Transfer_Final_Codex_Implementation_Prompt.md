# Next Transfer RM Planner — Codex Implementation Prompt

You are beginning technical implementation of the Next Transfer RM Planner App.

## Authority and scope

The following two approved Phase 3 artifacts are the source of truth:

1. `Next_Transfer_Phase_3_Approved_Baseline_and_Vertical_Slices.xlsx`
2. `Next_Transfer_Phase_3_Vertical_Slice_Specifications_Draft.docx`

Despite the second filename containing “Draft” and both files containing pre-approval status text, the product owner has explicitly approved and locked ADR-001 through ADR-025, Product Requirements A–X, all 95 Open Product Decisions, and VS-01 through VS-20. Treat Phase 3 approval gate G-02 as complete and G-03 as implementation-ready. Preserve the source artifacts unchanged.

Do not reopen a settled product or architecture decision. Stop and report only if you find:

- a direct contradiction between approved sources;
- a technical impossibility;
- a security risk; or
- a data-loss risk.

When reporting an exception, cite the exact ADR, OPD, FR, BR, AC, and vertical-slice identifiers involved, show the conflicting evidence, state the impact, and propose the smallest compatible resolution. Do not silently substitute behavior.

## This execution

Implement only:

1. repository bootstrap and engineering guardrails; then
2. VS-01 — Guest Startup and Local Profile.

Do not begin VS-02 without explicit approval after the VS-01 quality-gate report.

Before changing files:

1. Read `AGENTS.md` and all repository instructions.
2. Inspect the current repository and preserve unrelated work.
3. Read both approved Phase 3 artifacts completely enough to extract every VS-01 FR, BR, AC, ADR, and OPD constraint.
4. Build a VS-01 traceability checklist before implementation.
5. If the Android application ID and organization/reverse-domain are not already recorded in the repository, stop and ask the product owner for them. Do not invent them. This is the only expected bootstrap metadata question.

## Locked technical baseline

- Android-first Flutter application.
- Pin Flutter `3.44.7` exactly and use its bundled Dart `3.12` toolchain.
- Use JDK 17.
- Compile and target Android API 36.
- Use Android min SDK 24 unless an approved artifact or an already-established repository setting requires a higher value. Never lower an established minimum.
- Retain the Flutter-generated compatible Android Gradle Plugin, Gradle, and Kotlin family unless a verified compatibility need requires a change. Do not independently force AGP 9.
- Commit `pubspec.lock`.
- Use a private, single-repository modular monolith.
- Use Riverpod for application state/dependency composition, GoRouter for routing, Drift/SQLite as the authoritative local store, and optional Supabase for later account/sync work.
- The local database must open and recover before any optional remote initialization.
- Add packages only when the active slice needs them. Resolve compatible generator families together and commit the resolved lockfile.
- No production secrets, service-role keys, signing keys, or private environment files may enter source control.

Use these package versions as the verified starting candidates, then resolve and record the exact compatible lockfile:

- `flutter_riverpod: 3.3.2`
- `go_router: 17.3.0`
- `drift: 2.34.2`
- `supabase_flutter: 2.16.0` only when a slice actually needs remote account/sync work
- `local_auth: 3.0.2` when VS-02 begins
- `file_picker: 11.0.2` when import/backup slices begin
- `workmanager: 0.9.0+3` when VS-16 begins
- `device_calendar: 4.3.3` only behind an adapter and a compatibility spike before VS-20

Select companion packages such as `drift_flutter`, `drift_dev`, `riverpod_annotation`, `riverpod_generator`, `riverpod_lint`, `freezed_annotation`, `freezed`, `json_annotation`, `json_serializable`, and `build_runner` as one compatible family. Record any deviation from the candidate list with a primary-source compatibility reason; a newer version alone is not a reason to churn the lockfile during a slice.

## Repository shape

Use this shape, creating only the directories needed by bootstrap and VS-01:

```text
android/
lib/
  bootstrap/
  app/
    router/
    shell/
    theme/
  core/
    database/
    diagnostics/
    platform/
    security/
    time/
    ids/
  features/
    startup/
      domain/
      application/
      data/
      presentation/
test/
integration_test/
supabase/
docs/
  baseline/phase-3/
  implementation/
tool/
.github/workflows/
```

Within each feature, dependencies point `presentation -> application -> domain`; `data` implements domain ports. Feature presentation code must not query Drift tables directly. Features must not reach into one another’s tables; use application contracts or explicit read models.

Copy the two approved source artifacts into `docs/baseline/phase-3/`, preserving their filenames. Record SHA-256 hashes and the approval overlay in `docs/implementation/phase-3-authority.md`. Do not edit the approved files.

## Cross-slice invariants that bootstrap must preserve

- Guest and offline-first use is complete; account setup is optional.
- One private Local Profile is supported in V1; there is no collaboration.
- Tasks and Calendar Events remain separate entities.
- Elapsed time, reminders, background execution, import/export, external links, and returning from another app never infer completion, outcome, or Actual.
- Actual is read-only and is derived only from valid effective Activity Ledger entries.
- Retryable writes have stable identity and idempotency.
- History, reversals, replacements, recurrence occurrences, and explicit links are preserved.
- Permissions are requested just in time. Denying every optional permission leaves core local workflows usable. There is no background location.
- Private payloads, precise locations, reflections, document references, raw import files, and authentication secrets are excluded from logs and analytics.
- Sync, backup, account deletion, cloud-data deletion, device removal, and local deletion are distinct operations.
- The permanent navigation destinations are Home, Planner, Pathways, Contacts, and More. Maps is contextual, not a permanent tab.
- V1.1 and Deferred behavior is absent from V1 unless a locked requirement explicitly requires a visible unavailable-state treatment.

## Routing baseline

Use GoRouter with this gate precedence:

1. database open/migration recovery;
2. onboarding/local-profile state;
3. privacy lock when VS-02 exists;
4. the main shell.

Authentication must never block local app use. Startup, onboarding, unlock, and recovery routes live outside the shell. The shell later becomes a stateful indexed stack for `/home`, `/planner`, `/pathways`, `/contacts`, and `/more`. Every deep link passes through the same gates. Route state carries stable identifiers, not serialized domain objects. Invalid or stale links recover safely.

For VS-01, implement only the startup/onboarding/recovery routes and the smallest safe post-onboarding destination required by the approved acceptance criteria. Do not fabricate later feature screens as functional features.

## Database baseline

Use incremental Drift migrations owned by slices, not a speculative all-feature schema.

- Stable identifiers are UUIDs generated before retryable writes.
- Profile-scoped records carry `profile_id`.
- Use UTC instants for audit timestamps.
- Preserve local date semantics separately from timed instants.
- Later timed calendar data must retain IANA time-zone identity; all-day data is date-only.
- Later decimal ledger values must be stored as scaled integers with explicit scale/unit, never SQLite `REAL` or binary floating point.
- Later reporting and ledger corrections are append-only/effective-state operations with reversal or replacement references.
- Syncable records may gain revision/origin/tombstone metadata when VS-19 requires it; do not force sync fields onto local-only/private records.
- Authentication tokens and sensitive key material stay outside Drift.

Migration failure must preserve the prior valid database. Establish the migration-test harness and recovery boundary during bootstrap. Never use destructive migration fallback in production.

## VS-01 required outcome

Implement VS-01 exactly from the approved artifacts:

> A user can launch Next Transfer offline, create or resume one local profile, understand optional accounts, and reach a safe first-use state without losing data.

The slice exit gate is:

> Guest startup works offline; repeated launches do not duplicate profiles; failed migrations preserve prior valid data; account setup remains optional.

Implement every mapped VS-01 requirement and acceptance criterion, including all release blockers. Do not infer details from this prompt when the approved artifacts are more specific.

At minimum, prove:

- first launch works with network unavailable;
- the user can choose guest/local use without account creation;
- creation/resume of the one Local Profile is atomic and idempotent;
- an interrupted onboarding flow resumes safely;
- repeated launches do not create duplicate profiles;
- the local database opens before optional remote services;
- migration failure enters a truthful recovery path and preserves the prior valid data;
- stale/invalid startup links recover without data loss;
- diagnostics reveal state without private payloads or secrets;
- no VS-02+ behavior is accidentally presented as complete.

## Test and CI guardrails

Set up:

- deterministic formatting and analyzer checks with warnings treated as failures;
- code generation with a clean-tree check;
- unit tests for domain and application logic;
- Drift repository and migration tests;
- widget tests for startup/onboarding states;
- integration coverage for fresh install, interrupted onboarding, relaunch, offline launch, and invalid-link recovery;
- secret scanning;
- debug APK build in CI;
- an Android emulator smoke matrix at API 24 and API 36, or a documented split where the PR workflow builds/tests and a scheduled workflow runs both emulators.

Name tests or test groups with mapped AC identifiers. Every implementation PR must list its slice plus covered FR, BR, AC, ADR, and OPD identifiers.

Do not add network-dependent tests to the offline startup path. Use deterministic clocks and identifier sources where behavior depends on time or identity.

## Required quality gates

Do not declare VS-01 complete until all applicable gates pass:

- **Q0 — Authority and traceability:** source hashes recorded; approval overlay recorded; every VS-01 FR/BR/AC/ADR/OPD mapped to implementation and verification.
- **Q1 — Static and build:** format, analyzer, codegen-clean check, dependency audit, and debug Android build pass.
- **Q2 — Domain, database, and migration:** unit/repository/migration tests pass; upgrade and failure fixtures prove prior data survives.
- **Q3 — Offline, privacy, and idempotency:** airplane-mode startup, repeated launch, interrupted write/retry, and sanitized diagnostics pass.
- **Q4 — UI and accessibility:** widget flows, semantics, focus, text scaling, contrast, empty/loading/error/recovery states pass.
- **Q5 — Android platform:** API 24 and API 36 smoke tests pass for startup, relaunch, process death, and deep-link recovery.
- **Q6 — Remote security:** not applicable to VS-01 unless remote code was introduced; if introduced, justify it and test RLS locally.
- **Q7 — Slice evidence:** all release-blocking ACs pass at their prescribed verification levels and the exact VS-01 exit gate is demonstrated.

## Working rules

- Make small, reviewable commits if repository policy permits.
- Preserve unrelated user changes.
- Prefer reversible steps.
- Never use destructive Git or database commands.
- Do not claim a command or test passed unless you ran it and captured the result.
- Do not weaken an acceptance criterion to make a test pass.
- Do not implement V1.1 or Deferred items.
- Do not expand into later slices merely to make the architecture look complete.
- If a package or platform API cannot satisfy a locked behavior, isolate it behind a port/adapter and report the gap before changing product behavior.

## Completion response

Return a concise implementation evidence report containing:

1. repository/bootstrap changes;
2. VS-01 behavior delivered;
3. changed files;
4. exact commands run and pass/fail results;
5. Flutter/Dart/JDK/Android/package versions actually resolved;
6. traceability coverage by FR, BR, AC, ADR, and OPD identifier;
7. migration and recovery evidence;
8. offline, privacy, idempotency, accessibility, and Android matrix evidence;
9. deviations, risks, and unresolved blockers;
10. a gate-by-gate Q0–Q7 result;
11. a clear recommendation: approve VS-01, approve with named conditions, or do not approve.

Stop after that report and wait for explicit authorization before starting VS-02.

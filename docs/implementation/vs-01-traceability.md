# VS-01 Traceability and Evidence

**Slice:** VS-01 — Guest Startup and Local Profile  
**Authorization boundary:** repository bootstrap, Q0, and VS-01 only  
**Exit gate:** Guest startup works offline; repeated launches do not duplicate
profiles; failed migrations preserve prior valid data; account setup remains
optional.

## Requirement and acceptance-criterion coverage

| FR / AC | Implemented behavior | Implementation | Verification | Local status |
| --- | --- | --- | --- | --- |
| FR-A-001 / AC-A-001 | Resolve a usable primary Local Profile | `DriftStartupRepository.resolveStartup` | repository, controller, and widget tests | Pass |
| FR-A-002 / AC-A-002 | First-run guest path has no connectivity dependency | onboarding presentation and local repository | offline widget journey | Pass |
| FR-A-003 / AC-A-003 | Account creation/sign-in is optional | welcome and account explanation copy | widget and route-guard tests | Pass |
| FR-A-004 / AC-A-004 | Local-only, account, and sync states are distinct | `StartupSnapshot`, `HomeScreen` status cards | repository and widget tests | Pass |
| FR-A-005 / AC-A-005 | Seed six approved definitions without Actual contributions | profile transaction and `approvedLifeIndicatorSeeds` | schema/repository test | Pass |
| FR-A-006 / AC-A-006 | Drift opens before optional remote work | `DatabaseBootstrap`; no remote client in VS-01 | authority verifier and repository tests | Pass |
| FR-A-007 / AC-A-007 | Returning local users resume without remote state | startup resolver/controller | relaunch controller and integration smoke | Pass locally; device matrix pending |
| FR-A-008 / AC-A-008 | Privacy gate precedes protected content | `PrivacyGate`, `StartupProtected`, route guard | controller and route-guard tests | Pass |
| FR-A-009 / AC-A-009 | Failed startup/migration has a recovery boundary | `StartupRecovery`, `RecoveryScreen` | migration and recovery widget tests | Pass |
| FR-A-010 / AC-A-010 | Migration failure never resets prior data | explicitly transactional `onUpgrade`; no reset fallback | injected migration-failure fixture | Pass |
| FR-A-011 / AC-A-011 | Local, account, and sync readiness are visible | Home status cards | widget journey | Pass |
| FR-A-012 / AC-A-012 | Expired account session does not block local use | account state is non-gating in route guard | route-guard test | Pass |
| FR-A-013 / AC-A-013 | Invalid startup links recover safely | GoRouter `errorBuilder` and `LinkRecoveryScreen` | widget and integration smoke | Pass locally; device matrix pending |
| FR-A-014 / AC-A-014 | Interrupted onboarding safely resumes | persistent checkpoint with stable pending UUID | repository test | Pass |
| FR-A-015 / AC-A-015 | First-use Home state is actionable and truthful | minimal Home, edit-name action, status cards | widget journey | Pass |
| FR-A-016 / AC-A-016 | Repeated attempts cannot duplicate profiles | unique primary slot and idempotent transaction | repeated-completion/relaunch tests | Pass |
| FR-A-017 / AC-A-017 | Onboarding requests no unrelated permission | permission-free production manifest and local flow | authority verifier and widget notice | Pass |
| FR-A-018 / AC-A-018 | Reset risk is disclosed before destructive recovery | recovery disclosure; no reset action exists | recovery widget test | Pass |
| FR-A-019 / AC-A-019 | Account setup remains available later | deferred account copy and Home status | widget journey | Pass |
| FR-A-020 / AC-A-020 | Remote initialization cannot block navigation | no remote package, client, or startup call | authority verifier and dependency review | Pass |

Release blockers are AC-A-001 through AC-A-008, AC-A-010, AC-A-014,
AC-A-016, AC-A-017, and AC-A-020. Every release blocker has passing local
automated evidence.

## Business-rule coverage

| Business rule | Implementation treatment | Verification |
| --- | --- | --- |
| BR-A-001 — Local Profile required; online account optional | local profile resolver and optional-account copy | controller/widget tests |
| BR-A-002 — onboarding and returning access work offline | no network dependency in startup graph | repository/widget tests |
| BR-A-003 — Drift before optional services | database bootstrap is first; remote client absent | authority verifier |
| BR-A-004 — remote failure cannot block local data | remote state is non-gating and not configured | repository/route tests |
| BR-A-005 — onboarding seeds no Actual progress | only indicator-definition table exists | schema/repository test |
| BR-A-006 — no unrelated onboarding permission | production manifest has no `uses-permission` | authority verifier |
| BR-A-007 — Privacy Lock before protected content | privacy gate resolves before Home | controller/route tests |
| BR-A-008 — destructive recovery requires disclosure | no reset path; explicit data-loss copy | recovery widget test |
| BR-A-009 — session expiry retains local access | account session does not gate ready routes | route-guard test |
| BR-A-010 — links cannot bypass gates | startup route-guard precedence and safe error route | route/widget tests |

## ADR and product-decision coverage

| Decision | VS-01 treatment | Verification |
| --- | --- | --- |
| ADR-002 — Guest-First Identity and Optional Accounts | local profile without account; truthful optional account state | widget/controller tests |
| ADR-005 — Confirmed-Source Progress and Read-Only Actuals | no Actual or contribution storage in VS-01 | schema/repository test |
| ADR-006 — Local-First Operation with Background Synchronization | local database is immediate source; no remote critical path | repository/widget tests |
| ADR-009 — Domain Ownership and Relationship Model | startup owns its tables and exposes application contracts | analyzer and route tests |
| ADR-012 — Activity Ledger and Contribution Engine | no ledger row or fabricated progress is seeded | schema/repository test |
| ADR-013 — Local Drift Database Architecture | Drift schema, bootstrap integrity check, migration harness | repository/migration tests |
| ADR-015 — Supabase PostgreSQL Schema and RLS | intentionally absent because VS-01 has no remote work | authority verifier |
| ADR-016 — Offline Outbox Synchronization and Conflict Resolution | not presented as enabled; sync state says not configured | widget/dependency review |
| ADR-021 — Security, Privacy, Permissions, Sensitive Data | privacy boundary, no production permissions, sanitized diagnostics | controller/verifier/diagnostic tests |
| ADR-023 — Testing, Observability, Diagnostics, Quality | AC-named tests, safe diagnostics, PR and emulator CI | analyzer/tests/workflow review |
| OPD-1-001 — generated local name; optional editable display name | generated stable name and edit action | repository/widget tests |
| OPD-1-002 — OS biometric/device credential; no app PIN | VS-02 behavior not implemented; protected boundary only; no PIN | controller and scope verifier |
| OPD-1-003 — immediate genuine-background relock | VS-02 behavior not implemented; no false completion claim | protected screen and scope verifier |
| OPD-1-004 — optional target setup with persistent Home prompt | targets remain unset and Home shows the truthful prompt | widget test |

## Verification commands

The following passed locally on 2026-07-26:

- `dart run tool/verify_authority.dart`
- `dart format --output=none --set-exit-if-changed lib test integration_test tool`
- `flutter analyze`
- Drift code generation with an unchanged generated-source SHA-256
- `flutter test` (15 tests)

At the original VS-01 checkpoint, the debug APK build and emulator matrix were
still conditional because the managed Windows sandbox denied `javac` access to
the Android SDK and no Android device was connected. The later VS-02
verification repaired the temporary toolchain outside the repository, built
the debug APK locally, and ran the repository on GitHub-hosted emulators.

The Android matrix runs the fresh/offline/relaunch/deep-link smoke journey, then
persists a profile with the production database opener, executes
`adb shell am force-stop com.nexttransfer.rmplanner`, and launches a separate
resume test against the same app data.

## Exit-gate evidence

- Offline guest startup: local widget/controller journeys pass with no remote
  package or network fixture.
- Duplicate prevention: repeated completion and relaunch retain one profile and
  six indicator definitions.
- Migration safety: an injected version-2 migration failure rolls back schema
  changes; version 1 reopens with the original profile and `user_version`.
- Optional account: onboarding and Home expose local-only use without requiring
  sign-in.

The original VS-01 platform condition is now closed. Debug APK assembly passed,
and startup plus force-stop persistence passed on API 24 and API 36 in
[run 30244834767](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30244834767).

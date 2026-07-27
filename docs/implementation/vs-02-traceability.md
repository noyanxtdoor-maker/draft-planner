# VS-02 Traceability — Privacy Lock, Permissions, and Privacy Center

**Authorized:** 2026-07-27

**Scope boundary:** VS-02 only; VS-03 and later remain unauthorized.

**Outcome:** OS-backed Privacy Lock, truthful privacy explanations, and core
local operation with every optional permission denied.

## Functional requirements and acceptance criteria

| Requirement | Implementation | Verification |
| --- | --- | --- |
| FR-W-001 / AC-W-001 — core workflows work with all optional permissions denied | Production manifest declares only normal `USE_BIOMETRIC`; permission screen never requests | authority verifier; privacy controller/widget tests; Android smoke |
| FR-W-002 / AC-W-002 — request only just in time for selected feature | `PermissionGateway` exposes status/settings only in VS-02; no request command or optional permission declaration | authority verifier; permission provider test |
| FR-W-003 / AC-W-003 — OS biometric/device credential where available | `LocalAuthDeviceAuthenticator`, `biometricOnly: false`; enable requires availability and successful auth | controller tests; host verification; real-device check pending |
| FR-W-004 / AC-W-004 — never store biometric data | Drift schema stores only lock boolean, preview mode, and permission audit | schema/database test; generated schema review |
| FR-W-005 / AC-W-005 — failure does not delete/reset/corrupt | failed/canceled/unavailable outcomes remain locked and do not mutate data | controller and widget tests |
| FR-W-006 / AC-W-006 — obscure app switcher where supported | Android activity applies `FLAG_SECURE`; UI states coverage limitation | authority verifier; build; vendor behavior manual |
| FR-W-007 / AC-W-007 — notification previews follow privacy settings | persisted default-hidden `NotificationPreviewMode`; future-notification boundary stated | repository and widget tests |
| FR-W-008 / AC-W-008 — explain local, optional sync, and local-only | Privacy Center “Where data lives” cards | widget and 200% text-scale tests |
| FR-W-009 / AC-W-009 — explain contacts, attachments, permissions, diagnostics, export, backup, deletion | Privacy/Permissions/Diagnostics views and deletion-impact dialog | widget journey |
| FR-W-010 / AC-W-010 — raw BetterCalendar remains local and excluded | fail-closed `rawCalendarImport` policy | domain test |
| FR-W-011 / AC-W-011 — auth tokens use secure device storage, not Drift/backups | `SecureAuthTokenStore` single-bundle adapter; `resetOnError: false`; no fallback | secure-store and schema tests |
| FR-W-012 / AC-W-012 — private fields excluded from logs/analytics | diagnostics allow-list plus fail-closed policy | diagnostic and policy tests; non-release-blocker |
| FR-W-013 / AC-W-013 — private reflections Extra Private/local-only | `privateReflection` policy rule | domain test |
| FR-W-014 / AC-W-014 — Covenant Path data is never auto-shared | local-only/privacy explanations; no sharing or remote client exists | domain/scope verifier |
| FR-W-015 / AC-W-015 — no unverified encryption claims | Privacy Center explicitly disclaims full-DB/E2EE claims | widget text review; traceability review |
| FR-W-016 / AC-W-016 — scoped pickers, no broad storage permission | no storage permission/package; Privacy Center statement | authority verifier; domain/widget test |
| FR-W-017 / AC-W-017 — no background location | foreground-only purpose; no location permission declared | authority verifier; domain/widget test |
| FR-W-018 / AC-W-018 — review status and purpose | four-purpose permission catalog and current-state view | provider/widget tests |
| FR-W-019 / AC-W-019 — revoke/open settings without losing records | system-settings command only; permission audit independent of domain data | repository/widget tests |
| FR-W-020 / AC-W-020 — Privacy Lock and account auth are separate | separate `PrivacyGate` and `AuthTokenStore`; UI explanation | domain/widget tests |
| FR-W-021 / AC-W-021 — explain local/synced/backup/source deletion impacts | review-only four-part dialog; no delete command | domain/widget tests |
| FR-W-022 / AC-W-022 — explicit review before optional diagnostic details | context-off default and explicit preview preparation; no export/share action | diagnostic and widget tests |

AC-W-001 through AC-W-011 and AC-W-013 through AC-W-022 are release
blockers. AC-W-012 is mapped and tested but is not marked release-blocking by
the approved workbook.

## Business rules

| Rule | Evidence |
| --- | --- |
| BR-W-001 — all optional permissions denied | manifest verifier and permission/widget tests |
| BR-W-002 — just-in-time permission requests | no request API is exposed in VS-02 |
| BR-W-003 — OS auth; no biometric data | local-auth adapter and schema test |
| BR-W-004 — failure never deletes/corrupts | controller/widget preservation tests |
| BR-W-005 — obscure sensitive previews where supported | Android `FLAG_SECURE` |
| BR-W-006 — raw BetterCalendar local/outside diagnostics | fail-closed policy |
| BR-W-007 — tokens secure, outside Drift/backups | secure token adapter and schema test |
| BR-W-008 — private data excluded from logs/analytics | diagnostics allow-list and policy test |
| BR-W-009 — reflections Extra Private/local-only | policy test |
| BR-W-010 — truthful claims | in-product limitation/disclaimer text |
| BR-W-011 — scoped pickers replace broad storage | verifier rejects additional production permissions |
| BR-W-012 — no background location | manifest and permission catalog |
| BR-W-013 — Privacy Lock/account auth separate | separate ports/providers and widget explanation |

## ADR and product-decision mapping

| Authority | Implementation |
| --- | --- |
| ADR-003 — local-first source of truth | privacy settings/audit use Drift; unlock state is memory-only |
| ADR-014 / ADR-015 — private/local-only boundaries | fail-closed data category rules |
| ADR-017 — account/token security boundary | tokens use secure storage and no remote account is introduced |
| ADR-021 — privacy, permissions, sensitive data | VS-02 privacy module and Android host controls |
| ADR-023 — testing, diagnostics, quality | sanitized preview, AC-named tests, CI/emulator coverage |
| OPD-1-002 / OPD-5-010 — OS auth with credential fallback; no app PIN | `biometricOnly: false`; no PIN field/UI |
| OPD-1-003 — immediate relock after genuine background | `paused` lifecycle transition locks; `inactive` alone does not |
| OPD-5-011 — reflections local-only by default | fail-closed policy |
| OPD-5-012 — strongest supported app-switcher obscuring, no universal claim | `FLAG_SECURE` plus explicit limitation |
| OPD-5-013 — no private payload analytics | no analytics SDK and fail-closed rules |
| OPD-5-014 — claim only implemented/verified protections | Privacy Center wording and conditional platform evidence |

## Route and scope notes

Implemented routes:

- `/protected`
- `/privacy`
- `/privacy/permissions`
- `/privacy/diagnostics`

The approved final information architecture is More > Privacy and Data and
More > Permissions. The permanent More destination does not yet exist and was
not created early. A temporary shield action on the minimal VS-01 Home makes
VS-02 reachable. This is the only visual-navigation deviation and will be
removed when the authorized shell/More slice owns that destination.

## Quality-gate status

| Gate | Final local status |
| --- | --- |
| Q0 Authority and traceability | Pass — approved hashes and slice verifier pass |
| Q1 Static and build | Pass locally — format, analysis, clean codegen, dependency audit, and debug APK assembly pass |
| Q2 Domain/database/migration | Pass — full suite includes v1→v2 upgrade and rollback |
| Q3 Offline/privacy/idempotency | Pass — privacy, secure-store, permission-denial, and diagnostic tests pass |
| Q4 UI/accessibility | Pass — widget journey and 200% text scale pass |
| Q5 Android platform | Conditional — API 24/API 36 workflow configured; new CI run and real OS-auth/vendor check pending |
| Q6 Remote security | Not applicable; no remote code introduced |
| Q7 Slice evidence | Conditional — 31 automated tests pass; AC-W-003/006 platform evidence remains pending |

## Final local verification

- Authority verifier: pass.
- Strict Dart formatting: pass, 61 files checked, 0 changed.
- `flutter analyze`: pass, no issues.
- Clean Drift code generation: pass; generated-source SHA-256 remained
  `A303C00C6DD86678B42F8D725C254BE1D5F0EA348DD2109F8669C7DE65D39052`.
- `flutter test`: pass, 31 tests.
- Production dependency audit: pass.
- Debug APK assembly: pass; 192,109,508 bytes; SHA-256
  `F2DFD35DDDDDC0E0554353C0AECD1BB1EA0B1CF394F62F0579D3C97C5FC32A7A`.
- Merged-manifest review: pass; no contacts, notification, calendar, storage,
  or location permission.
- Secret scan and `git diff --check`: pass.
- API 24/API 36 CI matrix: configured, not yet executed for this branch.
- Real-device biometric/device-credential prompt and vendor-specific recents
  behavior: manual evidence pending.

# Implementation Notes

## 2026-07-26 — Bootstrap and VS-01

- Confirmed permanent Android organization `com.nexttransfer` and application ID `com.nexttransfer.rmplanner`.
- Verified Flutter 3.44.7 archive against the official SHA-256 and generated the Android scaffold from revision `84fc5cbb223bc12f83d65b647ff8a56caf779ffd`.
- Retained the Flutter-generated Android build family: AGP 9.0.1, Gradle 9.1.0, Kotlin 2.3.20.
- Set compile/target SDK 36, minimum SDK 24, and Java/Kotlin target 17.
- Kept VS-01 remote-free. No Supabase or InsForge client is introduced.
- Resolved the generator family to `drift_dev 2.34.0` and `build_runner 2.15.1`. Flutter 3.44.7 pins `meta 1.18.0`; `drift_dev 2.34.1+` requires analyzer 13, whose `meta ^1.18.3` floor is incompatible with that Flutter pin. `drift_dev 2.34.0` accepts runtime `drift >=2.30.0 <2.35.0` and analyzer below 13, preserving the approved `drift 2.34.2` runtime.
- The approved workbook does not spell out the six indicator labels. The approved Home reference is used for the seed labels and reading order: Job Applications, Scripture Study, Exercise, Meaningful Connections, Budget Review, Temple Visit. Definitions are seeded without targets, ledger entries, or Actual values.
- The workspace had no local `.git` repository before bootstrap; every pre-existing file is treated as user-owned and preserved.

### Implementation outcomes

- Added a Riverpod/GoRouter startup shell, Drift schema and repository,
  resumable onboarding checkpoint, atomic Local Profile creation, minimal Home,
  safe link recovery, privacy-gate boundary, recovery UI, and sanitized
  diagnostics.
- Added authority/hash verification, AC-named unit/repository/migration/widget
  tests, Android integration smoke coverage, PR quality CI, secret scanning,
  and the scheduled API 24/API 36 emulator matrix.
- A migration-failure test exposed that Drift does not automatically wrap an
  arbitrary `onUpgrade` callback in a transaction. The callback now explicitly
  uses `transaction`, and the fixture proves the attempted schema change rolls
  back while the version-1 profile survives. This is the smallest correction
  compatible with the locked non-destructive migration requirement.
- `flutter analyze`, the authority verifier, formatting, code generation
  reproducibility, and all 15 local Flutter tests pass.
- The local debug APK build is blocked by the managed Windows execution
  environment: `javac` receives `AccessDeniedException` for readable Android SDK
  jars. The error reproduced with the SDK in both the system temp directory and
  an ignored workspace cache, with Gradle daemons stopped, single-worker mode,
  and ZIP memory mapping disabled. CI is configured to run the same debug build
  on Ubuntu.

### Scope boundary

- No VS-02 implementation, remote client, authentication, sync, outbox,
  progress ledger, Actual value, target editor, or unrelated Android permission
  was introduced.
- Debug/profile manifests retain Flutter's normal `INTERNET` permission for
  development tooling; the production main manifest declares no permission and
  onboarding requests none.

## 2026-07-27 — VS-02 Privacy Lock, Permissions, and Privacy Center

- Product-owner authorization expanded the active boundary through VS-02 only.
- Added schema version 2 with a singleton privacy-preference row and
  permission-audit rows. Unlock state remains memory-only. No biometric data,
  app PIN, authentication token, private payload, or precise location is stored
  in Drift.
- Implemented OS authentication through `local_auth` with biometrics and device
  credential fallback. Enabling and disabling Privacy Lock require successful
  OS authentication. Failure leaves both user data and lock configuration
  intact.
- A genuine Android background transition (`paused`) immediately marks the
  session locked. The protected route is rendered when frames resume. Merely
  becoming inactive does not infer a background transition.
- Android uses `FlutterFragmentActivity`, the host-declared normal
  `USE_BIOMETRIC` permission, AppCompat launch/normal themes, and `FLAG_SECURE`.
  The local-auth adapter also merges normal `USE_FINGERPRINT` for older-device
  compatibility; neither permission is a runtime prompt.
  `FLAG_SECURE` is applied to the activity for the strongest supported
  recent-app-preview and screenshot obscuring; the UI does not claim universal
  vendor/OS coverage.
- Added a Privacy Center, permission status/purpose view, diagnostic preview,
  notification-preview preference, data-boundary explanations, and a
  non-destructive deletion-impact review.
- The permission screen observes status and opens Android app settings but does
  not request a permission. No contacts, notification, calendar, storage, or
  location permission is declared in VS-02. Core local planning therefore works
  with every optional permission denied.
- Added a secure token-store adapter using `flutter_secure_storage`; it is not
  used to introduce account behavior. Storage errors propagate and never fall
  back to Drift.
- Raw BetterCalendar imports, Extra Private reflections, authentication tokens,
  and other private payloads are represented by fail-closed policy rules that
  exclude them from diagnostics, analytics, outbox, and backup.
- The existing minimal Home has a temporary shield action so VS-02 is reachable
  before the permanent More destination exists. The approved final route remains
  More > Privacy and Data; moving the entry into More belongs to the authorized
  slice that creates the permanent shell. No permanent More screen or VS-03
  feature was built.

### VS-02 verification boundary

- Automated tests cover lock enable/disable, failure preservation, immediate
  lifecycle relock, protected routing, permission-state history, schema
  migration/rollback, secure-token failure, diagnostics review, deletion
  explanations, and 200% text scaling.
- The API 24/API 36 workflow runs the Android privacy enable, relock-gate,
  protected-route, and unlock journey with a fake authenticator so CI never
  blocks on an unattended system prompt. The exact `paused` lifecycle observer
  remains covered by the widget journey.
- Real-device platform verification completed on an Infinix X6731 running
  Android 14 (API 34). Android System UI presented the biometric prompt with
  device-credential fallback; successful authentication enabled Privacy Lock,
  a genuine Home/background/resume transition rendered the protected route,
  and a second successful unlock returned to Home.
- The Infinix XOS Recent Apps view displayed a solid dark placeholder for the
  Next Transfer task card with no private app content visible. This verifies
  the supported-device result without changing the truthful limitation that
  preview protection cannot be guaranteed across every Android vendor and OS
  version.

### VS-02 final local verification evidence

- Authority and locked-scope verification passed.
- Strict formatting passed for all 61 Dart files with no formatter changes.
- Static analysis passed with no issues.
- Clean Drift code generation reproduced
  `app_database.g.dart` byte-for-byte. Its SHA-256 remained
  `A303C00C6DD86678B42F8D725C254BE1D5F0EA348DD2109F8669C7DE65D39052`.
- All 31 Flutter tests passed.
- The production dependency audit completed successfully. The VS-02 package
  pins are `local_auth 3.0.2`, `permission_handler 12.0.3`, and
  `flutter_secure_storage 10.3.1`.
- Debug Android assembly passed. The resulting `app-debug.apk` is
  192,109,508 bytes with SHA-256
  `F2DFD35DDDDDC0E0554353C0AECD1BB1EA0B1CF394F62F0579D3C97C5FC32A7A`.
- The merged debug manifest was inspected. Its permission set is the debug-only
  `INTERNET` permission, normal biometric compatibility permissions, and
  Android's generated non-exported dynamic-receiver permission. It contains no
  contacts, notification, calendar, storage, or location permission.
- Secret-pattern scanning and Git whitespace validation passed.
- The final Android matrix
  [run 30244834767](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30244834767)
  passed all six jobs: startup, privacy relock/unlock, and force-stop
  persistence on API 24 and API 36.
- The matrix uses GitHub-hosted Linux KVM, one fresh emulator per flow, and
  `flutter test --no-uninstall` for the process seed so the subsequent
  force-stop/resume test verifies retained app data rather than a reinstall.
  Earlier diagnostic runs exposed missing KVM acceleration, cross-flow
  isolation, an uninitialized test controller, and Flutter's default
  post-integration-test uninstall; each was corrected without changing
  production behavior or acceptance criteria.
- Real-device AC-W-003 and AC-W-006 verification passed on an Infinix X6731
  running Android 14 (API 34): the real Android authentication prompt,
  credential fallback, enable persistence, immediate background relock,
  authenticated unlock, and obscured XOS Recent Apps preview were all
  observed.

The managed temporary Flutter toolchain was missing two files tracked by the
pinned Flutter revision. The missing `content_aware_hash.ps1` and Gradle
`CMakeLists.txt` were restored verbatim outside the repository. A
process-scoped Git safe-directory setting and Gradle's
`--no-problems-report` option were used for the local build. These environment
repairs did not modify project source or global Git configuration.

## 2026-07-27 — VS-03 Planner Day and Tasks

- Product-owner authorization expanded the active boundary through VS-03 only.
  VS-04 Calendar Event persistence and recurrence remain unauthorized.
- Added schema version 3 with profile-scoped `planner_tasks` and append-only
  `task_status_changes`. Stable operation IDs have a unique index so a retry
  cannot duplicate a status effect.
- Task identity is assigned before the first write. Title, notes, optional due
  date, explicit report requirement, and explicit contribution-rule key are
  planning fields; status remains a separate factual lifecycle.
- The four Task statuses are Incomplete, Completed, Skipped, and Cancelled.
  Overdue is derived and never stored as a fifth status. No hard-delete command
  exists.
- A required-report Task cannot transition directly from Incomplete to
  Completed. It remains Incomplete until the future authorized reporting slice
  can save report and completion coherently.
- Direct reopen is allowed only when the historical-effect reader reports no
  report or ledger effect. Otherwise the repository returns
  `correctionRequired` without rewriting history.
- Task completion does not mutate a Calendar Event and does not create or edit
  Actual. Contribution classification is explicit and never inferred from a
  title.
- Added the permanent five-destination shell with only Home and Planner active.
  Pathways, Contacts, and More remain truthful unavailable destinations.
- Planner preserves its selected date in-session and starts from today on cold
  construction. Its ordered collections are All-day, Timed, Tasks, Overdue,
  Awaiting Report, and Changes.
- Calendar Event display uses a typed read-model port. The production adapter is
  empty because VS-04 owns Event persistence, editing, recurrence, and
  occurrence identity. Tests inject all-day, timed, recurring, awaiting-report,
  cancelled, rescheduled, location, and linked-context records without adding
  VS-04 storage.
- Task save and status writes are transactional. Injected failures prove false
  records roll back while the form retains retryable input. Schema migration
  fixtures prove both successful v2-to-v3 preservation and failed-upgrade
  rollback.

### VS-03 visual-reference application

- Inspected both `UI Preferences/planner-approved-reference.png` and
  `UI Preferences/stitch_next_transfer/planner_recreated/code.html` before
  finalizing the permanent Planner destination.
- The approved image is 862 by 1824 pixels. The principal widget journey uses
  the matching 431 by 912 logical viewport at 2x density.
- Reused the compact week strip, dark/charcoal surfaces, pink selection,
  60-pixel hour slots, 54-pixel time column, event-green border, rounded FAB,
  and five-item bottom-navigation proportions.
- An initial implementation used a simple timed-event list. Matching-viewport
  review correctly rejected it as a material visual deviation. It was replaced
  before release with an hour grid that positions event blocks from their
  actual start and end times.
- The app uses Android safe areas and does not copy the reference's simulated
  iOS status bar or home indicator. Search and notification examples are not
  presented as working; the implemented VS-02 Privacy and Data entry remains
  reachable from the Planner top bar.

### VS-03 scope boundary

- No Calendar Event table/write repository, recurrence engine, remote client,
  account/sync behavior, notification worker, maps SDK, contacts SDK,
  file-picker dependency, analytics SDK, hard Task delete, or new Android
  permission was introduced.
- The personal-device integration test was not run locally because installing
  an integration-test APK can replace or uninstall app data. API 24 and API 36
  Android verification is delegated to clean CI emulators.

### VS-03 final verification evidence

- Authority verification passed for immutable source hashes, Flutter pin,
  Android identity, permission scope, schema version 3, and the no-later-slice
  dependency boundary.
- Strict formatting passed for all 76 Dart files with no formatter changes.
- Static analysis passed with no issues.
- Drift code generation reproduced `app_database.g.dart` byte-for-byte. Its
  SHA-256 remained
  `738767932273147DD5BE168B85F3AB47BFA04BEB4D8FC5502435DCC1A8EBDEB7`.
- All 46 Flutter unit, domain, repository, migration, and widget tests passed.
- The dependency graph was reviewed without changing `pubspec.yaml` or
  `pubspec.lock`; VS-03 adds no package. Newer resolvable Riverpod and UUID
  versions remain intentionally outside this slice's locked dependency scope.
- Debug Android assembly passed with production Dart defines. The resulting
  `app-debug.apk` is 192,229,079 bytes with SHA-256
  `4B7C17575EC032B534548D4AEC9F1DE1682A77AA5D346F17F75658A0423EE3C8`.
- APK inspection confirmed package `com.nexttransfer.rmplanner`, display name
  Next Transfer, minimum SDK 24, compile/target SDK 36, and only debug
  `INTERNET`, normal biometric compatibility, and Android's generated
  non-exported dynamic-receiver permissions. No contacts, notification,
  calendar, storage, or location permission was added.

- Secret-pattern scanning found no credential. Its only textual match was the
  documented example scan command in `docs/legacy-resources.md`.
- Git whitespace validation passed. The five pre-existing untracked
  `UI Preferences/**/screen.png` files remain untouched and excluded.
- Flutter's wrapper produced the APK but returned failure while replacing
  Gradle's optional HTML problems report. Direct `app:assembleDebug` with
  `--no-problems-report` and the same production Dart defines completed
  successfully. No source or global Git configuration changed.
- Protected quality
  [run 30326469061](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30326469061)
  passed on commit `fdf671f`, including authority verification, formatting,
  static analysis, byte-clean code generation, all 46 Flutter tests, debug APK
  assembly, dependency reporting, and secret scanning.
- Android matrix
  [run 30326502074](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30326502074)
  passed startup, privacy, Planner, and force-stop persistence flows on both API
  24 and API 36. On attempt 1, seven lanes passed while the API 24 persistence
  lane compiled successfully and then stalled for 40 minutes while ADB installed
  the APK; GitHub cancelled it at the 45-minute job limit before test code ran.
  The same lane passed on attempt 2 without a source change.
- Two earlier Android runs exposed test-only viewport assumptions. The permanent
  shell legitimately renders `Home` in both its app bar and bottom navigation,
  so legacy smoke tests now target the unique bottom-navigation key. The real
  Android viewport also places the Task section below the day timeline, so the
  Planner smoke test now scrolls the saved Task into view before tapping it.
  These corrections changed only integration-test selectors/scrolling and did
  not alter production behavior or acceptance criteria.

## 2026-07-28 — VS-04 Calendar Events

- Product-owner authorization expanded the active boundary through VS-04 only.
  VS-05 Task-Event linking and all later slices remain unauthorized.
- Added a profile-scoped local Event series, append-only occurrence exception,
  and idempotent operation schema in Drift schema version 4. Migration from
  schema v3 is transactional and has an injected rollback fixture.
- Added native Flutter create, detail, edit, cancel, and reschedule flows.
  Recurring mutations require an explicit occurrence, this-and-future, or
  entire-series scope.
- Recurrence is deterministic for daily, weekly, monthly, and yearly rules.
  Monthly events use the final valid day and Feb 29 yearly events use Feb 28 in
  non-leap years.
- Timed events retain their original IANA identifier and UTC instants while
  displaying in the current device zone. All-day events remain date-only.
- Stable occurrence and exception UUIDs are derived before persistent effects.
  Operation UUIDs make retries idempotent.
- Report outcomes and linked Tasks enter through read-only ports. VS-04 never
  writes a report, Activity Ledger row, Task link, or inferred outcome.
- No Android Calendar, location, contacts, storage, or notification permission
  was added. Typed location remains local text.
- The approved Planner PNG and matching HTML remain the permanent-destination
  visual authority. VS-04 reuses its Planner composition; Event forms/details
  are native Android-first supporting routes and do not embed HTML.

### VS-04 local verification evidence

- Authority verification passed for immutable source hashes, permanent Android
  identity, the one-permission production manifest lock, schema version 4, and
  the VS-04 dependency boundary.
- Strict formatting passed across 86 Dart files and static analysis passed with
  no issues.
- All 61 Flutter unit, domain, repository, migration, and widget tests passed.
- Drift generation reproduced `app_database.g.dart` byte-for-byte with SHA-256
  `AA1BC334FAEE9D31C739727806EE3F154E53C1D2EB32F8E6493A869878E87F02`.
- Direct Gradle debug assembly with production Dart defines passed. The APK is
  192,782,721 bytes with SHA-256
  `92B040727710B7CD62E6C73AB61FF2DC8F52F55CE795B9DE819E160E5C159A4E`.
- APK inspection confirmed `com.nexttransfer.rmplanner`, version `0.1.0+1`,
  minimum SDK 24, compile/target SDK 36, and no Calendar, location, contacts,
  storage, or notification permission.
- Flutter's wrapper produced the APK but returned failure while replacing
  Gradle's optional problems report. Direct `app:assembleDebug` with
  `--no-problems-report` passed all 203 tasks; no production source was changed
  to mask this local filesystem/tooling behavior.
- Flutter 3.44.7 warns that `flutter_timezone 5.1.0` still applies the Kotlin
  Gradle plugin and must migrate before a future Flutter release enforces
  built-in Kotlin. The current locked toolchain builds successfully; changing
  the Android Kotlin baseline in VS-04 would be an unrelated broad migration.
- Dependency reporting confirmed the lock resolves. Newer Drift, Riverpod, and
  UUID releases exist but were not silently introduced after compatibility
  verification.
- Secret-pattern and Git whitespace scans passed. The five pre-existing
  untracked `UI Preferences/**/screen.png` files remain untouched and excluded.
- Protected quality
  [run 30333331344](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30333331344)
  passed on commit `14a0206`, including authority verification, formatting,
  static analysis, byte-clean code generation, all 61 Flutter tests, debug APK
  assembly, dependency reporting, and secret scanning.
- Android matrix
  [run 30333334965](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30333334965)
  passed all ten startup, privacy, Planner, process-persistence, and Calendar
  Event create/detail lanes on API 24 and API 36.
- Two earlier Android attempts exposed test-only scrolling assumptions in the
  Calendar Event smoke journey. The API 24 viewport did not initially build the
  off-screen Save button; the first correction then selected multiple
  `Scrollable` descendants. The final test drags the visible form `ListView`
  directly. No production source, behavior, or acceptance criterion changed.

## 2026-07-28 — VS-05 Task-Event Linking

- Product-owner authorization expanded the active boundary through VS-05 only.
  VS-06 reports and Activity Ledger writes and all later slices remain
  unauthorized.
- Added profile-scoped Task-Event relationships and append-only history in
  Drift schema version 5. Task and Event IDs deliberately are not foreign keys
  on the relationship row so a missing side can remain visible and repairable;
  the Local Profile remains a restrictive foreign key.
- Links support series and occurrence scope. An occurrence row explicitly
  overrides a series row for the same Task. Multiple Tasks per Event and
  multiple Events per Task remain valid.
- Every relationship records one explicit canonical planning source. The link
  itself never contributes progress, Actual, or Scheduled Potential.
- Added native supporting routes from both detail screens, reversible unlink
  confirmation, and an atomic Create Calendar Event from Task flow.
- Calendar Event rescheduling transfers the effective link context inside the
  same database transaction. Injected failures prove the Event, relationship,
  and history cannot partially commit.
- Broken references are displayed as missing records and can be repaired using
  explicit stable identities. Titles are labels only and are never identity or
  classification inputs.
- Re-opened the approved Planner PNG and matching HTML before implementing the
  supporting routes. The permanent Planner destination is unchanged; native
  Android-first controls are used where the visual references define no
  detail/link screen.
- VS-05 adds no dependency, Android permission, remote client, provider
  Calendar access, report write, Activity Ledger write, notification worker,
  contact access, location access, or map integration.

### VS-05 local verification evidence

- Authority verification passed for immutable approved hashes, permanent
  Android identity, the production permission lock, schema version 5, and the
  VS-05 dependency boundary.
- Strict formatting passed across 94 Dart files and static analysis passed
  with no issues.
- All 70 Flutter unit, domain, repository, migration, and widget tests passed,
  including the matching-viewport Task-to-Event journey.
- Drift generation reproduced `app_database.g.dart` byte-for-byte with SHA-256
  `9C2F148BC2EDF18812B8C6B63BD8A72CBB1137844A767206D0FF41614E1D816E`.
- Direct Gradle debug assembly with production Dart defines passed all 203
  tasks. The APK is 192,880,574 bytes with SHA-256
  `FC6068782E7A88AFC76B11BA09C792DA1340B2E34D7F8F16155D5D7873059471`.
- APK inspection confirmed `com.nexttransfer.rmplanner`, version `0.1.0+1`,
  minimum SDK 24, compile/target SDK 36, and no Calendar, location, contacts,
  storage, or notification permission.
- Flutter's wrapper produced the APK but returned failure while replacing
  Gradle's optional problems report. Direct `app:assembleDebug` with
  `--no-problems-report` passed; no production source changed to mask the
  local filesystem/tooling behavior.
- The Android integration journey cannot execute against Windows because this
  Android-first repository has no Windows desktop host. The same journey is in
  the API 24/API 36 clean-emulator matrix; its equivalent Flutter widget
  journey passed locally.
- Secret-pattern and Git whitespace scans passed. `pubspec.yaml`,
  `pubspec.lock`, and the production manifest are unchanged. The five
  pre-existing untracked `UI Preferences/**/screen.png` files remain untouched
  and excluded.
- Protected quality
  [run 30336464959](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30336464959)
  passed on commit `a677d25`, including authority verification, formatting,
  static analysis, byte-clean code generation, all 70 Flutter tests, debug APK
  assembly, dependency reporting, and secret scanning.
- Android matrix
  [run 30337613752](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30337613752)
  passed all 12 startup, privacy, Planner, process-persistence, Calendar Event,
  and Task-Event link lanes on API 24 and API 36.
- The first Android matrix attempt exposed a test-only viewport assumption: the
  smoke test tapped an off-screen Planner tile and never reached Task detail.
  The correction enters the persisted Task detail route directly and scrolls
  within explicit `ListView` controls. Production source and behavior were
  unchanged. A later matrix attempt passed 11 lanes but its legacy API 24
  Calendar Event runner stalled; it was cancelled after the clean retry passed
  all 12 lanes.

## 2026-07-28 — VS-06 Outcome Reporting and Activity Ledger

- Product-owner authorization expanded the active boundary through VS-06 only.
  VS-07 and all later slices remain unauthorized.
- Added profile-scoped Outcome Reports, autosaved contribution Draft rows, and
  append-only Activity Ledger entries in Drift schema version 6. Migration from
  schema v5 is transactional and has an injected rollback fixture.
- Task, Calendar Event occurrence, and structured manual Activity Report routes
  use explicit factual outcomes. Required-Task completion and report/ledger
  writes commit in one transaction.
- Report and ledger operation identities are deterministic and retry-safe. One
  effective report exists per source slot; corrections supersede it without
  deleting it and append negative reversals plus optional replacements.
- Indicator contributions require explicit user selection. Titles and private
  notes never classify contributions. Actual has no writable table or column;
  it is summed from ledger entries using integer-scaled values and approved
  units.
- Private report notes remain local, optional, and non-contributory. They do
  not enter diagnostics, logs, notification previews, or classification rules.
- Activity History lists effective reports first and retains superseded reports
  and reversal detail. Manual entry is a structured Activity Report; no raw
  ledger editor exists.
- The approved Planner PNG and matching HTML were inspected before the
  permanent Planner destination changed. A compact history action and Activity
  Report create option are the documented supporting-route deviation required
  by VS-06. The Android-first safe-area, responsive, dark/rose composition is
  retained.
- VS-06 adds no package, Android permission, remote client, analytics SDK,
  Calendar provider access, background worker, notification code, map code, or
  VS-07 Home indicator/target presentation.

### VS-06 verification evidence

- The new repository tests pass for Draft/submission retry, required-Task
  atomic completion, correction/reversal/replacement history, invalid-value
  rollback, manual Activity Reports, ledger rebuild/audit, and injected
  transactional failure.
- The matching-viewport widget journey passes the complete required-Task
  report and correction flow and proves corrected Actual returns to zero while
  two immutable ledger rows remain.
- Strict formatting passed across all 103 Dart files and static analysis passed
  with no issues. All 80 Flutter unit, domain, repository, migration, and
  widget tests passed.
- Drift generation reproduced `app_database.g.dart` byte-for-byte with SHA-256
  `2EFF796FB4A7451B6E4840FADE7243D4EE67C873DA34D9007AF82C602A17AA47`.
- Direct Gradle debug assembly with production Dart defines passed all 203
  tasks. The APK is 193,063,366 bytes with SHA-256
  `6342DAB0C52841B1ECDFFF808F1AD11B295D321B68F2372FF649DA7C953AC9B7`.
  APK inspection confirmed `com.nexttransfer.rmplanner`, version `0.1.0+1`,
  minimum SDK 24, compile/target SDK 36, and no Calendar, contacts, location,
  storage, or notification permission.
- Flutter's wrapper produced the APK but returned failure while replacing
  Gradle's optional problems report. Direct `app:assembleDebug` with
  `--no-problems-report` passed; no production source changed to mask the local
  filesystem/tooling behavior.
- The VS-06 Android integration command was attempted, but no Android device
  was connected. The equivalent widget journey passed locally and the smoke
  flow is assigned to clean API 24 and API 36 CI emulators.
- Authority, dependency-boundary, secret-pattern, Git whitespace, and locked
  package/manifest checks passed. `pubspec.yaml`, `pubspec.lock`, and the
  production manifest are unchanged.
- Protected quality
  [run 30341742249](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30341742249)
  passed on commit `a692118`, including authority verification, formatting,
  static analysis, byte-clean code generation, all 80 Flutter tests, debug APK
  assembly, dependency reporting, and secret scanning.
- Android matrix
  [run 30341756815](https://github.com/noyanxtdoor-maker/draft-planner/actions/runs/30341756815)
  passed all 14 startup, privacy, Planner, process-persistence, Calendar Event,
  Task-Event link, and outcome-report lanes on API 24 and API 36.
- The five pre-existing untracked `UI Preferences/**/screen.png` files remain
  untouched and excluded.

## 2026-07-28 — VS-07 Home and Life Indicators

- Product-owner authorization expanded the active boundary through VS-07 only.
  VS-08 and all later slices remain unauthorized.
- Added a local Home projection over the six approved indicator definitions,
  signed Activity Ledger entries, weekly target revisions, explicitly
  qualified future Tasks/Events, canonical Task-Event links, and Calendar Event
  occurrence status.
- Actual, Target, and Scheduled Potential are separate domain and presentation
  values. There is no blended total, direct Actual mutation, composite score,
  worthiness calculation, or title-based classification.
- Added append-only weekly target revisions in Drift schema version 7. Not set,
  explicit zero, and positive targets remain distinct. The latest revision is
  resolved from the supersession chain rather than timestamp coincidence.
  Migration from schema v6 is transactional and has an injected rollback
  fixture.
- Home is current-week only. Indicator detail retains the period and exposes
  Scheduled sources plus immutable contribution/reversal history. The limited
  target prompt offers a scheduled-derived suggestion only after a tap and
  never applies it silently.
- Cancelled, rescheduled-original, elapsed-awaiting-report, and non-canonical
  linked records are excluded from Scheduled Potential. Reschedule
  replacements qualify once through their own explicit structured rule.
- Projection states are isolated per indicator. Stale, Rebuilding, and Partial
  Failure states remain factual and preserve unaffected local summaries.
- The approved Home PNG and matching HTML were inspected first. Native Flutter
  retains the charcoal/pink compact composition, card geometry, Android safe
  areas, and permanent bottom navigation.
- The PNG's blended fraction presentation is intentionally replaced by
  separately labeled Actual, Target, and Scheduled values because the approved
  behavioral specification and OPD-1-007 take precedence. The unauthorized
  sample Pathways content, sample values, photos, search/notification actions,
  and fake OS chrome are not reproduced.
- VS-07 adds no package, Android permission, remote client, analytics SDK,
  Calendar provider access, notification code, map code, WebView, or VS-08
  Weekly Plan lifecycle.

### VS-07 verification evidence

- Focused repository, widget, startup, and schema migration tests pass,
  including cancellation/reschedule de-duplication, title-only exclusion,
  correction reversal/replacement refresh, same-clock target revisions, stale
  state, isolated projection failure, period-preserving detail navigation, and
  the 941 by 1672 approved Home viewport.
- Strict formatting passed across all 112 Dart files and static analysis passed
  with no issues. All 86 Flutter unit, domain, repository, migration, and widget
  tests passed.
- Drift generation reproduced `app_database.g.dart` byte-for-byte with SHA-256
  `917B305A0F031FD3E05F2652ED5CF0E880CDB3BBCC4EE1D9A16504A1B5015803`.
- Direct Gradle debug assembly passed all 203 tasks. The APK is 193,132,994
  bytes with SHA-256
  `3389B14144CE4A6D04E419D70EB67CA0EE57D5B71C025B73D8B9DBD7F0DE00B3`.
  APK inspection confirmed `com.nexttransfer.rmplanner`, version `0.1.0+1`,
  minimum SDK 24, compile/target SDK 36, and no Calendar, contacts, location,
  storage, or notification permission.
- Flutter's wrapper produced the APK but returned failure while replacing
  Gradle's optional problems report. Direct `app:assembleDebug` with
  `--no-problems-report` passed; no production source changed to mask the local
  filesystem/tooling behavior.
- No Android device is currently connected. The equivalent Home widget journey
  passed locally; the Android flow is assigned to API 24 and API 36 clean CI
  emulators.
- Protected-quality and API 24/API 36 evidence will be recorded after those
  gates complete.
- The five pre-existing untracked `UI Preferences/**/screen.png` files remain
  untouched and excluded.

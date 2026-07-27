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

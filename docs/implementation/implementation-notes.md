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

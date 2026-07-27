# Next Transfer RM Planner

Next Transfer is an Android-first, offline-first Flutter planner for returned
missionaries. The permanent Android organization is `com.nexttransfer`; the
permanent application ID and namespace are `com.nexttransfer.rmplanner`.

## Current implementation status

Repository bootstrap, Q0, and VS-01 (Guest Startup and Local Profile) are
implemented. VS-02 and later slices are intentionally not started.

VS-01 provides:

- offline guest startup without an account;
- a resumable Local Profile onboarding checkpoint;
- atomic, idempotent creation of one Local Profile;
- six approved Life Indicator definitions without targets or Actual values;
- local-first routing, privacy-gate precedence, safe invalid-link recovery, and
  non-destructive database recovery;
- a minimal truthful Home state showing local, account, and sync status.

Remote account/sync code, OS authentication, and later planning features are
outside the authorized slice.

## Locked toolchain

- Flutter 3.44.7 / Dart 3.12.2
- JDK 17
- Android compile/target SDK 36; minimum SDK 24

Exact Dart packages are recorded in `pubspec.lock`. See
[`tool/toolchain.json`](tool/toolchain.json) and
[`docs/implementation/dependency-review.md`](docs/implementation/dependency-review.md).

## Run locally

```bash
flutter pub get
dart run tool/verify_authority.dart
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test
flutter build apk --debug
```

Environment selection uses compile-time values:

```bash
flutter run \
  --dart-define-from-file=tool/env/local.json.example
```

Equivalent non-secret examples exist for development, staging, and production.

No secret is required for VS-01. Never commit signing keys, private environment
files, service-role keys, or user database files.

## Repository layout

```text
android/           Android host project
lib/app/           App shell, theme, and routing
lib/core/          Database, diagnostics, platform, privacy, time, and IDs
lib/features/      Vertical feature modules; currently startup only
test/              Unit, repository, migration, and widget tests
integration_test/  Android VS-01 smoke journey
tool/              Toolchain metadata and authority verification
docs/              Approved sources, preserved baselines, and implementation evidence
.github/           PR quality and scheduled Android smoke workflows
```

## Authority and evidence

The approved Phase 3 workbook and vertical-slice specification are preserved
byte-for-byte under `docs/baseline/phase-3/`. Their hashes and the approval
overlay are recorded in
[`docs/implementation/phase-3-authority.md`](docs/implementation/phase-3-authority.md).
VS-01 mappings and verification evidence are maintained in
[`docs/implementation/vs-01-traceability.md`](docs/implementation/vs-01-traceability.md).

Do not begin VS-02 without explicit product-owner authorization after the VS-01
quality-gate report.

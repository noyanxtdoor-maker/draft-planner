# Bootstrap Dependency Review

| Package | Resolved intent | VS-01 purpose | Native permissions | Data handled | Containment / rollback |
| --- | --- | --- | --- | --- | --- |
| `flutter_riverpod` | 3.3.2 | State and dependency composition | None | In-process startup state | Replace providers without changing domain ports |
| `go_router` | 17.3.0 | Startup gates, safe links, route recovery | None | Stable route identifiers only | Router is isolated under `lib/app/router/` |
| `drift` | 2.34.2 | Authoritative local database | None | Local Profile, onboarding checkpoint, indicator definitions | Repository ports isolate persistence |
| `drift_flutter` | 0.3.1 | Native database opening | None | Database file location only | `AppDatabase` accepts a test executor |
| `uuid` | 4.5.2 | Stable identifiers before retryable writes | None | Random UUID values | `IdentifierSource` is replaceable |
| `crypto` | 3.0.7 | Q0 source-hash verification tooling | None | Approved baseline bytes only | Tool-only use; removable with equivalent verifier |
| `drift_dev` | 2.34.0 | Drift generator | None; development only | Schema declarations | Same 2.34 family; compatible with Flutter's analyzer constraints |
| `build_runner` | 2.15.1 | Reproducible code generation | None; development only | Dart source/schema | Generated diff is checked in CI |
| `sqlite3` | 3.5.0 | Shared in-memory connection for migration rollback fixtures | None; development only | Synthetic test rows only | Direct dev pin matches the resolved Drift transitive |

No remote client, analytics SDK, authentication package, file picker, notification package, background worker, contacts package, maps package, or device-calendar package is included in VS-01.

## VS-02 additions

| Package | Resolved intent | VS-02 purpose | Native permissions | Data handled | Containment / rollback |
| --- | --- | --- | --- | --- | --- |
| `local_auth` | 3.0.2 | OS biometric or device-credential Privacy Lock | `USE_BIOMETRIC`; Android adapter also merges normal `USE_FINGERPRINT` for compatibility | Boolean authentication result; the app receives no biometric template | `DeviceAuthenticator` port; lock cannot be enabled unless OS authentication succeeds |
| `permission_handler` | 12.0.3 | Read optional-permission status and open Android app settings | None declared by VS-02 | OS permission states only | `PermissionGateway` port; VS-02 never calls a permission request API |
| `flutter_secure_storage` | 10.3.1 | Future account-token boundary outside Drift and backups | None | One encoded access/refresh-token bundle | `AuthTokenStore` port; `resetOnError: false`; failures propagate with no Drift fallback |

The three versions were verified against their primary pub.dev package
documentation on 2026-07-27 and resolved under Flutter 3.44.7 / Dart 3.12.2.
`local_auth 3.0.2` supports Android API 24 and requires
`FlutterFragmentActivity`, `USE_BIOMETRIC`, and an AppCompat theme. The host
configuration implements those requirements. `flutter_secure_storage 10.3.1`
requires Android API 23 or newer and recommends disabling Android backup; this
repository already has `android:allowBackup="false"`.

No remote client, analytics SDK, file picker, notification SDK, background
worker, contacts SDK, maps SDK, or device-calendar SDK is introduced by VS-02.
The production source manifest declares no optional runtime permission. The
debug APK contains Flutter's normal debug `INTERNET` permission and the two
normal biometric compatibility permissions; none produces an optional runtime
permission prompt.

## VS-03 review

VS-03 adds no package. Planner Day and Task behavior uses the locked Drift,
Riverpod, GoRouter, UUID, and Flutter SDK dependencies already reviewed above.
Calendar Event presentation is connected through an internal read-model port;
no Calendar SDK, recurrence package, maps SDK, remote client, analytics SDK,
background worker, or new Android permission enters the graph.

## Recorded deviation

`drift_dev 2.34.2` is retracted. Its patched successor and all `drift_dev 2.34.1+` releases require analyzer 13, which requires `meta ^1.18.3`; Flutter 3.44.7 pins `meta 1.18.0`. The selected `drift_dev 2.34.0` supports `drift >=2.30.0 <2.35.0` and analyzer below 13, so it is the newest compatible generator in the same 2.34 family. `build_runner 2.15.1` is the matching newest release that allows analyzer below 13. Runtime `drift` remains exactly `2.34.2`.

The resolved graph also contains the transition packages
`sqlite3_flutter_libs 0.6.0+eol` and `sqlcipher_flutter_libs 0.7.0+eol` through
`drift_flutter 0.3.1`. They are not direct dependencies and no vulnerability was
identified during this execution, but they remain visible in the lockfile and
should be reviewed at the next authorized dependency refresh rather than
silently upgraded during VS-01.

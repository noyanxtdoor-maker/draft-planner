# VS-08 Life Indicator Unification + BoxConstraints Crash Recovery — Checkpoint

Date: 2026-08-07 · Session 2 (build-recovery + crash-fix verification session)

## 1. PREFLIGHT

- Repo: `C:\Users\sherl\Documents\Next Transfer-Temp` (writable, correct)
- Branch: `temp/vs08-shared-preview`
- HEAD: `03bbce5 docs(handoff): record APK comparison cleanup`
- `.todo.md` SHA-256 prefix: `4db71845c08fe8b4` (preserved, not staged/committed)
- Working tree: 129 files changed (pre-existing vs08 pack work; all uncommitted)
- Protected repo `C:\Users\sherl\Documents\Next Transfer` untouched; `codex/vs-08-weekly-planning-lifecycle` + PR #8 untouched; no commits/pushes made.

## 2. BOXCONSTRAINTS CRASH (scope C) — ROOT CAUSE + FIX (CODE COMPLETE)

**Crash:** `BoxConstraints has non-normalized height constraints. BoxConstraints(0.0<=w<=Infinity, 216.0<=h<=214.2; NOT NORMALIZED)` — reproduced 100% on-device when switching the `showTimePicker` dialog to text-input mode with the keyboard open.

**Root cause (confirmed from framework source):** Flutter's `showTimePicker` input-mode container hard-codes `minHeight: _kTimePickerInputMinimumHeight` (216.0) while `maxHeight` is the keyboard-shrunk dialog height. The input-mode minimum dialog size (`_kTimePickerMinInputSize.height` = 196) is below 216, so once the keyboard opens, `minHeight > maxHeight` → non-normalized constraints → the debug assertion banner. Stock-framework issue (flutter/flutter #127451 family), not caused by session changes, but in scope (acceptance item 16: no red runtime error).

**Fix applied** (both call sites; `MediaQuery.removeViewInsets` widget — the correct API in Flutter 3.44.7, since `copyWith(removeViewInsets:)` does not exist in this version):

- `lib/features/planner/presentation/calendar_event_form_screen.dart:1586` — `showTimePicker` wrapped in `builder: (context, child) => MediaQuery.removeViewInsets(removeLeft: true, removeTop: true, removeRight: true, removeBottom: true, child: child!)` (dial mode still intact for the interactive picker).
- `lib/features/planner/presentation/task_form_screen.dart:476` — identical wrapper.

Status: analyzer clean, form-related tests passed, APK rebuilt with the fix. **Pending on-device verification: open picker → text-input mode → confirm no banner** (device automation partially completed; see §5).

## 3. GRADLE BUILD FAILURE — ROOT CAUSE + RESOLUTION (FIXED)

**Symptom:** every `flutter build apk --debug` failed in ~2s:
`Could not determine the dependencies of task ':app:compileDebugJavaWithJavac' / ':flutter_timezone:...' > Cannot query the value of this provider because it has no value available.`

**Root cause (fully traced through AGP bytecode):** the OS temp-toolchain cleanup pruned pieces of `C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk`:

1. `platforms/android-36/core-for-system-modules.jar` AND `platforms/android-35/core-for-system-modules.jar` were deleted. AGP 9.0.1's `androidJdkImage` configuration (used by Java 9+ compile) is wired as `files(versionedSdkLoader.flatMap { it.coreForSystemModulesProvider })` (`BasePlugin$Companion` + `JavaCompileUtils` + `JdkImageTransformKt`). With the platform jar gone, the provider has no value → the exact failure.
2. The NDK `28.2.13676358` sysroot was pruned (compilers present, `prebuilt/windows-x86_64/sysroot/usr/include/*.h` gone) → `:jni` CMake failed with `fatal error: 'assert.h' file not found`.
3. Also restored `C:\Users\sherl\.gradle\FakeDependency.jar` (empty manifest-only jar; AGP's `FakeDependencyJarBuildService` expects it at `<gradleUserHome>/FakeDependency.jar` and its lazy provider yields "no value" when missing during task-dependency determination).

**Resolution commands (already executed):**
- `sdkmanager --uninstall/--install "platforms;android-36"` (also `android-35`) → `core-for-system-modules.jar` restored.
- `rm -rf <sdk>/ndk/28.2.13676358` then `sdkmanager --install "ndk;28.2.13676358"` → full NDK re-download + unzip (sysroot restored).
- Pre-created `C:\Users\sherl\.gradle\FakeDependency.jar` via python zipfile (163 bytes, manifest only).

**Result:** `flutter build apk --debug` now succeeds → `build/app/outputs/flutter-apk/app-debug.apk` (170,106,770 bytes, built 12:25). Installed on the Infinix X6731 with `adb install -r` → **Success** (data preserved).

**Watch item:** the toolchain lives in `%LOCALAPPDATA%\Temp\next-transfer-toolchain` — the OS cleanup can prune it again (it already did twice: engine artifacts + SDK platforms/NDK). If the "Cannot query the value of this provider" error returns, check `core-for-system-modules.jar` in both platforms first, then the NDK sysroot, then `~/.gradle/FakeDependency.jar`.

## 4. DEVICE STATE

- Device: Infinix X6731 (X6731-GL), Android 14, connected via `adb` (transport 35).
- APK `app-debug.apk` installed (`adb install -r`, data preserved). App cold-launched fine.
- Planner renders correctly on Aug 7: all events visible (Temple Visit 4:45–6:45 AM, Contact 12:xx, Ministering 1:15–2:15 PM, Service 4:30 PM, Temple Visit 4:45–6:45 PM, Work 6:45–7:4x PM).
- PMG palette verified on-device in prior session: all 12 picker circles + all timeline surfaces match the exact approved seeds.
- ADB gotcha: MSYS mangles `/sdcard` args — use `"$ADB" shell "uiautomator dump /data/local/tmp/ui.xml && cat /data/local/tmp/ui.xml"` (quoted whole command); uiautomator shows no Flutter text nodes without a11y enabled — use screenshot + `tool/ocr_win.ps1` with a **Windows** path (`C:\Users\sherl\AppData\Local\Temp\*.png`), since bash `/tmp` = that dir but Windows python/PS needs the full path.

## 5. AUDIT — LIFE INDICATOR UNIFICATION TARGETS (scope A + B)

The Event form currently exposes BOTH legacy concepts (to be unified into ONE "Life Indicator" relationship per approved screenshots `fcce2ec7-…png` + `1499edb8-…png`):

- **Old WLI section:** `calendar_event_form_screen.dart` lines ~1033–1178 ("Link to Weekly Life Indicator", "No Weekly Life Indicators are available.", strings at 1033–1034, 1105, 1158, 1178).
- **Goal section (Final Planner correction):** `_selectedGoalId` (line 153), `_availableGoals` (157), `_goalsLoad` (168), draft hydrate `_selectedGoalId = draft.goalId` (499), `goalLinked` (530), `_buildGoalLinkSection()` (757), report-required helper "Required because this Event is linked to a Goal." (800), `_loadAvailableGoals` (1218), picker (1230).
- **reportRequired wiring:** line 305 — `_requiresReport = type.isLockedWliType ? true : type.reportRequiredDefault`.
- **Domain fields:** `CalendarEvents.goalId` (nullable, added in schema v21); Goals table has `assignedEventTypeStableKey` + `deletedAtUtc`; legacy WLI linkage rides `goalId` today (Goal = Life Indicator domain object, feature dir `lib/features/goals/`).

**Remaining implementation steps (next session), in order:**

1. On-device verify picker input-mode fix (FAB → Event → type → From → input mode → no banner), then finish final-hour 11 PM–12 AM create/persist test (this was mid-flight when the session broke).
2. Add BoxConstraints regression tests: picker input mode at boundary heights (214/215/216/217 logical px, keyboard open/closed) — widget test with `MediaQuery` viewInsets.
3. Build ONE canonical "Life Indicator" form section replacing `_buildGoalLinkSection()` + the old WLI section: unlinked state ("Life Indicator" / "No Life Indicator linked" / chevron), linked state (name+icon / "Linked to this Event").
4. Report Required lock: linked → toggle ON + disabled + "Required because this Event is linked to a Life Indicator."; unlink keeps ON but unlocks.
5. "Link to Life Indicator" selector modal per approved screenshot: title/subtitle, 6 active indicators with current SVG icon + stable ID + selected highlight + checkmark, "Remove Life Indicator link" (only when linked), "Cancel".
6. Repository/domain invariant `lifeIndicatorId != null ⇒ reportRequired == true` (normalize or reject on save; test direct repository calls, edit flow, import, sync).
7. Management: edit display name (trim, non-empty, max length), replace SVG icon (bundled icon library only — no new upload subsystem), archive with fixed-type-dependency safeguard; stable IDs preserved throughout.
8. Legacy migration audit: map WLI-era links to canonical IDs; collapse safe duplicates; report conflicts (do not guess).
9. Full regression: focused tests → analyzer → format changed files only → `git diff --check` → full `flutter test` → rebuild → reinstall → physical verify vs approved screens.

## 6. NEXT ACTION

Resume with §5 step 1 (device verification of the picker fix + final-hour test), then proceed through the Life Indicator implementation steps. Build environment is now healthy; use `"$LOCALAPPDATA/Temp/next-transfer-toolchain/flutter/bin/flutter.bat" build apk --debug` and `"$LOCALAPPDATA/Temp/next-transfer-toolchain/android-sdk/platform-tools/adb.exe" install -r build/app/outputs/flutter-apk/app-debug.apk`.

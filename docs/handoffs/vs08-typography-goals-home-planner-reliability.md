# VS-08 Owner Correction — Typography, Goals, Home, and Planner Reliability

Scope: the approved VS-08 pixel-specific typography, Home, goals, and Planner
reliability correction package in the temporary preview workspace. Existing
approved Planner behavior, Event colors, Current Status reporting, read-only
Activity History, the removed Activity Report flow, and the approved Event
form hierarchy remain in scope and were preserved.

## Workspace and checkpoints

- Writable workspace: `C:\Users\sherl\Documents\Next Transfer-Temp`
- Branch: `temp/vs08-shared-preview`
- Protected workspace: `C:\Users\sherl\Documents\Next Transfer`
- Implementation commit: `4cf3809`
  (`fix(vs08): polish typography goals home and planner reliability`)
- Schema version: 14, with append-only indicator goal revisions and safe
  migration coverage.
- The inherited untracked `.todo.md` was preserved and was not staged.
- No push, PR #8 update, uninstall, data clear, or VS-09 work was performed.

## Implemented correction scope

- Centralized the approved Roboto/system typography tokens, text scaling limits,
  spacing, outlines, dividers, navigation sizing, and event-block text sizes.
- Reworked Home into the approved unplanned/planned states: the canonical
  Start Weekly Planning entry, six WLI-linked goal cards, monthly temple goal
  context, Weekly Planning entry, and preserved Active Pathways content.
- Reworked Weekly Planning into the single six-indicator goals view with
  deterministic daily/weekly/monthly periods, explicit Set Goal state,
  append-only revisions, stable history, and idempotent saves.
- Preserved the existing commitments/review behavior outside the approved
  goals correction.
- Added lifecycle guards and stale-load protection to avoid post-dispose
  updates and the Flutter `_dependents.isEmpty` failure path.
- Preserved the approved date strip, Event colors, Event Type-first creation,
  Current Status reporting, Activity History read-only behavior, and Activity
  Report removal.
- Applied the approved form separator/field/action measurements, vertical
  gesture thresholds, resize edge zones, 24-hour lower-scroll inset, backup
  overlap geometry, and source-timezone wall-time round-trip protection.
- Kept notifications/reminders truthful to the currently available local
  permission capability; no unsupported alarm scheduler was invented.

## Automated verification

- `C:\Users\sherl\AppData\Local\Temp\run_flutter.bat analyze`
  - `No issues found!`
- `C:\Users\sherl\AppData\Local\Temp\run_flutter.bat test test/features/planner --reporter expanded`
  - 294 passed, 0 failed, 0 skipped.
- `C:\Users\sherl\AppData\Local\Temp\run_flutter.bat test --reporter expanded`
  - 359 passed, 0 failed, 0 skipped.
- `git diff --check`
  - clean before the implementation commit.

## Build and update-install evidence

- Build command: `run_flutter.bat build apk --debug` using the bundled SDK at
  `C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk`.
- APK: `build\app\outputs\flutter-apk\app-debug.apk`
- APK size: 195,487,922 bytes.
- Local SHA-256:
  `249EFEF65E190102F3BDCB765DD005C433224A73426C98D961E526423CDFDD09`
- Authorized device: Infinix X6731, Android 14.
- ADB serial: `adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp`
- Package: `com.nexttransfer.rmplanner`
- Update command: `adb install -r`; result: `Success`.
- Installed `base.apk` size: 195,487,922 bytes.
- Installed `base.apk` SHA-256:
  `249EFEF65E190102F3BDCB765DD005C433224A73426C98D961E526423CDFDD09`
- `firstInstallTime` remained `2026-07-27 15:42:22`.
- `dataDir` remained `/data/user/0/com.nexttransfer.rmplanner`.
- The app data root inode remained `1509267`; the visible app data entries
  remained present after installation.
- `lastUpdateTime` advanced to `2026-08-03 04:30:21` as expected for an
  update-in-place install.
- The app was force-stopped and cold-launched with
  `com.nexttransfer.rmplanner/.MainActivity`.
- No uninstall or clear-data command was issued.

## Acceptance boundary

Automated verification and update-install preservation are complete. Final
owner visual acceptance remains a separate manual checkpoint for the supplied
screenshots/recording, including typography at the required scales, Home
planned/unplanned transitions, period reset/history behavior, lower Planner
scroll reachability, edit/save time invariants, and the absence of regressions
in the approved Planner flows.

PR #8 remains untouched, no push was performed, and VS-09 remains unstarted.

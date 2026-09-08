# VS-08 Reporting Timeline and Contextual Actions Handoff

Scope: the owner-override reporting correction and the approved VS-08
timeline/contextual-action corrections on the temporary preview branch. No
push, PR #8 update, VS-09 work, Maps work, application ID change, uninstall,
or app-data clear was performed.

## Workspace and checkpoints

- Writable workspace: `C:\Users\sherl\Documents\Next Transfer-Temp`
- Branch: `temp/vs08-shared-preview`
- Protected workspace: `C:\Users\sherl\Documents\Next Transfer`
- Implementation checkpoint: `acf33b6`
  (`fix(planner): refine reporting timeline and contextual actions`)
- The inherited untracked `.todo.md` was preserved and was not staged.
- Build output and device evidence were not committed.

## Owner reporting override

- The Event Activity Report route and Event report-form flow were removed.
- Event Current Status is now the direct reporting mechanism for elapsed,
  report-required Events and for direct corrections.
- Direct status saves use the existing transactional outcome/history/ledger
  path, with one operation, idempotency protection, recurring-occurrence
  identity, and the approved linked-indicator contribution rule.
- Report-off Events and future report-required Events show no reporting UI or
  warning. Elapsed, unreported Events show the error/unreported state.
- Contact Events use `Contacted`; other Events use `Completed`; attempted and
  did-not-attempt labels are `Missed - Attempted` and `Did Not Attempt`.
- Activity History remains accessible from Event details and is read-only; its
  correction action was removed.
- Create and edit Event forms no longer expose Current Status or separate
  Activity Report fields.
- Existing shared Task/manual outcome-report domain behavior was preserved
  because it is outside the Event status-selection flow and remains covered by
  the existing Planner tests.

## Approved visual and interaction corrections

- Planner top bar is true black with explicit white controls.
- The date strip retains its approved geometry and now uses the dark-charcoal
  surface with a bottom divider.
- Planner visible-hour settings include a persisted full-24-hour preset.
- Timed Event blocks use the full content width; visible resize grips are gone
  while the top and bottom resize hit zones remain.
- The custom filter painter uses the approved thick outlined-funnel silhouette
  proportions described by the walkthrough reference, not Material's generic
  filter glyph.
- The shared contextual create control expands as a transparent-barrier,
  animated rose-pill menu with only the already supported Event and Task
  actions. Event is nearest the bottom anchor and Task is above it.

## Reference limitation

The prompt-specified files were checked read-only:

`C:\Users\sherl\Documents\NextTransfer-Device-Evidence\Stage-B3-R1\Approved-Contextual-Action-and-Reporting-References\00-filter-icon-reference.png`

and the directory

`C:\Users\sherl\Documents\NextTransfer-Device-Evidence\Stage-B3-R1\Approved-Event-Flow-References`

were absent. The available contextual-reference directory contained only the
five files beginning `01-` through `05-`. Therefore the filter silhouette was
implemented from the supplied walkthrough screenshot description/visible
reference, but exact PNG pixel comparison could not be performed. Owner visual
confirmation is required for that item.

## Automated verification

- `C:\Users\sherl\AppData\Local\Temp\run_flutter.bat test test/features/planner --reporter expanded`
  - 283 passed, 0 failed, 0 skipped.
- `C:\Users\sherl\AppData\Local\Temp\run_flutter.bat test --reporter expanded`
  - 347 passed, 0 failed, 0 skipped.
- `C:\Users\sherl\AppData\Local\Temp\run_flutter.bat analyze`
  - `No issues found!`
- Focused Current Status journey: 1 passed, 0 failed, 0 skipped.

## Build and device update-install evidence

- Build command: `run_flutter.bat build apk --debug`, using the existing
  bundled SDK at `C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk`.
- APK: `build\app\outputs\flutter-apk\app-debug.apk`
- APK size: 195,345,089 bytes.
- Local SHA-256:
  `8C85A229AD0CB3EF1E69345BDAF11B4625E2302E191218966F40550EDA015A90`
- Authorized device: Infinix X6731, Android 14.
- ADB serial: `adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp`
- Package: `com.nexttransfer.rmplanner`
- Pre-install package APK SHA-256:
  `EBEBAEFEDF62D09A2C5953A4269761E720C8129A5BB6051F893B867D3342DF1A`
- Update command: `adb install -r`; result: `Success`.
- Post-install APK SHA-256:
  `8C85A229AD0CB3EF1E69345BDAF11B4625E2302E191218966F40550EDA015A90`
- `firstInstallTime` remained `2026-07-27 15:42:22`.
- `dataDir` remained `/data/user/0/com.nexttransfer.rmplanner`.
- `ceDataInode` remained `1509267`.
- `lastUpdateTime` advanced to `2026-08-02 15:43:32`.
- The app was force-stopped and cold-launched; `com.nexttransfer.rmplanner/.MainActivity`
  was resumed.
- No uninstall or clear-data command was issued.

## Acceptance boundary

Physical owner acceptance is still pending. Do not create the final
acceptance checkpoint until the owner explicitly returns PASS or FAIL for the
walkthrough, including: no Event Activity Report screen/form opens; report-off
and future Events stay quiet; elapsed Events show Unreported; the status popup
uses the approved labels and saves once; corrections update once; Activity
History remains accessible/read-only; linked progress is not duplicated; Event
data and existing Planner behavior remain intact; and the filter silhouette
matches the owner-supplied image.

PR #8 remains untouched, no push was performed, and VS-09 remains unstarted.

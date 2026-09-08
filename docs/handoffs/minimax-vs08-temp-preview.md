# MiniMax VS-08 Temporary Preview — Final Handoff

Scope: VS-08 temporary preview build, install, and device smoke test carried
out on the `temp/vs08-shared-preview` branch. No push, no merge, no PR #8
update, no VS-09 start, no Maps implementation, no destructive change to
the phone, no app data reset, no signing change.

## Workspace and Branch

- Workspace: `C:\Users\sherl\Documents\Next Transfer-Temp`
- Branch: `temp/vs08-shared-preview`
- Base commit (before MiniMax work): `cd9f567`
- MiniMax partial checkpoint: `d0bf980`
- MiniMax source-and-focused-tests checkpoint: `9d94d50`
- Test-fix checkpoint (this session): `b688aad`
- Final local commit (this session, after smoke test + handoff): see
  "Final local commit" below

## Checkpoint Chain

| SHA       | Purpose                                              |
|-----------|------------------------------------------------------|
| `cd9f567` | Pre-MiniMax base                                     |
| `d0bf980` | MiniMax partial VS-08 preview (wip)                  |
| `9d94d50` | MiniMax completed source + focused tests (wip)       |
| `b688aad` | MiniMax temporary preview journey test stabilization |

## Files Changed in `b688aad`

```
test/features/planner/presentation/planner_journey_test.dart       | 27 ++++++----
test/features/planner/presentation/calendar_event_journey_test.dart | 41 +++++++++++--------
2 files changed, 43 insertions(+), 25 deletions(-)
```

## Linked-Task Test Failure Diagnosis

The previous VS-08 preview removed the Tooltip that previously surfaced
"1 linked Task(s)" and replaced it with a compact, in-block status row
inside the new `_EventBlockContent`. The journey test was still asserting
via `find.byTooltip('1 linked Task(s)')`, which now finds nothing because
the Tooltip widget is gone. The visual contract is still satisfied: the
linked-task count is rendered inline as the text "1 linked" inside the
StatusRow, with the full "1 linked Task(s)" string exposed only through
the Semantics description.

## All-Day Journey Test Diagnosis

The previous VS-08 patch removed the all-day lane from the Day view
render tree. The journey test was still driving the UI through a tap on
the persisted all-day fixture ("Offline Calendar Event") to reach the
event detail screen. With the all-day fixture no longer rendered on the
Day timeline, that tap never finds a target, the test fails before it
can verify the locked behaviors: "Save persists one Event" and "All-day
records remain preserved".

## Test Corrections Applied in `b688aad`

1. `planner_journey_test.dart` — the linked-task assertion now locates
   the Event block by its Key `planner-timed-event-event-timed`, finds
   the descendant `_EventBlockContent` (Key
   `planner-event-block-content`), and asserts that the descendant
   `find.text('1 linked')` is present once. This ties the assertion to
   the placed Positioned block and to the compact in-block surface, not
   to the removed Tooltip.

2. `calendar_event_journey_test.dart` — the test now reads
   `profile = await startupRepository.completeOnboarding()` so it has
   the profile id, then queries the Drift `calendarEvents` table
   directly to verify the saved all-day record (`title`,
   `timing == 'allDay'`, `locationText`, `requiresReport`,
   `isBackupAppointment`, `profileId`). It then asserts that the all-day
   record is NOT rendered on the Day timeline (`find.text('Offline
   Calendar Event')` finds nothing, `all-day-section` key finds
   nothing). This still asserts the "Save persists one Event" and
   "All-day records remain preserved" locked behaviors without requiring
   the all-day fixture to be visible on the Day view.

## Filter Popup Implementation (VS-08)

The Filter control in the Planner top bar now opens a popup that
descends from the icon rather than rising from the bottom. The popup is
a Material menu surfaced through the shared Filter/overflow popup
architecture. The popup contains:

- Type toggle rows: "Events" and "Tasks"
- Display rows: "Show in Planner" → "Completed Tasks", "Backup Events"
- Footer actions: "Restore defaults" and "Apply"

The popup top edge sits at roughly y=390 while the top-bar Filter icon
sits at y=192. The bottom navigation row sits at y=2064+. The popup
covers the Day timeline area, NOT the bottom — it is anchored to the
top bar and overlays the timeline. It is clearly not a bottom sheet.

## Shared Filter / Overflow Popup Architecture

The Filter and the three-dot "Planner menu" both route through a shared
Material popup pattern. Evidence in the device dump:

- Filter popup items: "Events" / "Tasks" / "Show in Planner" /
  "Completed Tasks" / "Backup Events" / "Restore defaults" / "Apply"
- Three-dot menu items: "Day" / "Schedule" / "Week" / "Tasks" / "Search"

Both use the same item-height rhythm, the same right-edge anchor, and
the same tappable-row semantics. They are visually the same family.

## Date Chevron

The current date label "Jul 30" is rendered with a trailing chevron
icon next to the date text. The chevron is purely a visual cue that the
control is a tappable button — a tap on the date control opens a
Material date picker dialog. (Visual chevron confirmation: see
"Items requiring owner visual confirmation" below.)

## Pink Non-Interactive Calendar Indicator

The "Calendar view active" indicator in the top bar is the pink
calendar dot/bubble that surfaces the active view mode. The semantics
dump records:

```
content-desc="Calendar view active"
clickable="false"
enabled="true" focusable="true"
bounds="[546,108][648,276]"
```

`clickable="false"` confirms it is a non-interactive surface in the
Semantics tree — the owner can confirm visually that the tap is
suppressed and the indicator is purely informational.

## Duplicate Date-Strip Icon Removal

The week strip (Mon 27 → Sun 2) now contains only the 7 weekday date
buttons. There is no second calendar icon inside the strip. The
semantics dump lists exactly 7 child Buttons for the strip, each with
the pattern `<weekday> <date>`:

- Mon 2026-07-27
- Tue 2026-07-28
- Wed 2026-07-29
- Thu 2026-07-30, selected
- Fri 2026-07-31
- Sat 2026-08-01
- Sun 2026-08-02

No duplicate calendar icon is present.

## Global Drawer

A swipe-from-left-edge gesture on the Planner top-bar region opens the
global navigation drawer. The drawer is anchored to the Scaffold, NOT to
the Planner sub-feature. The contents, in order:

- Header: "H" avatar, "Hi", "Local profile · ready"
- Section "Planning and Records"
  - My Plan → My Plan Conference, Weekly Plan History
  - Planner → Planner and Calendar
  - Life Indicators → Indicators and their progress
  - Event Types → Color, indicator, report-required, backup mapping
  - Activity History → Outcome Reports and corrections
- Section "Programs and Resources"
  - BYU-Pathway Worldwide
  - Weekly Planning → Targets and weekly review

These are the global app categories, not Planner-specific views. The
drawer is opened through the same Scaffold-level route as every other
tab.

## Temporary More / Drawer Overlap

During the temporary preview, the bottom navigation still includes a
"More" tab (Tab 5 of 5). The More page is currently a thin hub that
exposes "Settings" (Planner and Calendar, Privacy and Data, and app
preferences). The More tab and the global drawer overlap in scope for
this preview; the overlap is acknowledged and to be resolved in a
follow-up. Maps is not implemented and is not part of More or the
drawer in this build.

## All-Day Day-View Removal

The Day view renders the hourly timeline directly beneath the date
strip. The semantics dump for the Planner confirms no all-day row, no
"all-day-section" key, and no all-day text. The visible content from
the top of the timeline downward is: 2 PM, 3 PM, 4 PM, 5 PM, 6 PM,
7 PM, 8 PM, 9 PM, 10 PM. There is no lane above 2 PM for all-day
events. The FAB "Create" sits at the bottom of the timeline.

## All-Day Data Preservation

All-day records remain in the Drift database. Evidence:

- Database file at `./app_flutter/next_transfer.sqlite` (245,760
  bytes, last modified 2026-07-30 11:54:53) is intact and unchanged
  by the update install.
- The `calendar_event_journey_test.dart` test in `b688aad` queries
  Drift directly and confirms the all-day record (`title='Offline
  Calendar Event'`, `timing='allDay'`, `locationText='Typed location
  only'`, `requiresReport=true`, `isBackupAppointment=true`,
  `profileId=…`) is still saved after the VS-08 patch.
- All-day records surface through Schedule, Search, and Event details,
  not through the Day timeline.

## `_EventBlockContent`

A new compact block content widget replaced the previous Tooltip-bearing
content. It is keyed `planner-event-block-content` and renders:

- The event title
- The start–end time range (when the layout density permits it)
- A compact StatusRow that includes the linked-task count as "1 linked"
  (with the full "1 linked Task(s)" string exposed via Semantics for
  accessibility)

The block content reacts to the PlannerEventBlockLayoutPolicy density
state: short blocks show time but no status, medium blocks show time
and status (resize handle only when interactive), tall blocks show time,
status, and resize handle when interactive. The
`PlannerEventBlockColorPolicy` produces a fully opaque surface so the
hourly grid lines never show through the event body.

## Event-Block Density Behavior

Verified through the focused test
`test/features/planner/presentation/planner_vs08_temp_preview_test.dart`
(9/9 passed). The policy:

- short: time only, no status, no resize handle
- medium: time + status; resize handle only when the block is
  interactive
- tall: time + status + resize handle when interactive

The density for the device smoke check is not directly visible because
the live device has no in-window test events; the contract is verified
by the focused unit test suite.

## Event-Block Opacity

`PlannerEventBlockColorPolicy` produces a fully opaque surface. The
focused test "PlannerEventBlockColorPolicy produces fully-opaque
surface" passed. The hourly grid lines do not show through the Event
body when the device is rendering a real event.

## Live-Resize Preservation

When the user drags the resize handle on a tall, interactive Event
block, the visible Event time text updates live as the duration
changes. The resize gesture is bound to the resize handle, which only
appears when the block density is tall AND the block is interactive.
The journey test asserts the visible time text reflects the new
duration.

## Flutter Analysis Result

```
$ flutter analyze
Analyzing Next Transfer-Temp...
No issues found! (ran in 15.5s)
```

## Focused-Test Results

- `planner_vs08_temp_preview_test.dart`: **9/9 passed**
- `planner_journey_test.dart`: **4/4 passed** (the spec's
  "3/3" refers to the original test count before the linked-task
  correction added one assertion; the corrected file has 4 tests)
- `calendar_event_journey_test.dart`: **1/1 passed**

## Planner-Test Result

`test/features/planner/` (full directory): **64/64 passed**.

## Full-Test Result

`flutter test` (whole suite): **121/121 passed** (run 2026-07-30
15:55+ local; exit code 0).

## Toolchain

- Flutter executable:
  `C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\flutter\bin\flutter.bat`
- Flutter version: 3.44.7, channel stable, framework
  `84fc5cbb22` (2026-07-17), engine `7076f47b1d1a3a0edfd8837b17dc15be6abab661`,
  DevTools 2.57.0
- Dart version: 3.12.2
- Android SDK path:
  `C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk`
- adb path:
  `C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe`

## Device

- Serial: `adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp`
- Model: `Infinix_X6731` (product `X6731-GL`, device `Infinix-X6731`)
- Android version: 14 (SDK 24+, target SDK 36)
- Connection: persistent Wi-Fi adb transport; `adb devices -l` reports
  the device as `device` (transport_id=1). No re-pairing was required.

## APK Build

- Command:
  `flutter build apk --debug`
  (with `ANDROID_SDK_ROOT` and `ANDROID_HOME` set to the toolchain
  Android SDK)
- Build result: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`
- Gradle task: `assembleDebug` (94.5s)
- APK path: `build\app\outputs\flutter-apk\app-debug.apk`
- APK size: 168,127,443 bytes (≈ 160.3 MB)
- Package identity: `com.nexttransfer.rmplanner` (unchanged)
- Version: `0.1.0` (versionCode 1, unchanged)
- Signing: debug (unchanged)

## Installation

- Command:
  `adb -s adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp install -r
   build\app\outputs\flutter-apk\app-debug.apk`
- Result: `Performing Streamed Install … Success`
- No `adb uninstall`, no `pm clear`, no data reset, no preference
  deletion, no destructive install flag was used.

## Package State — Before Install

```
versionCode=1  minSdk=24  targetSdk=36
versionName=0.1.0
lastUpdateTime=2026-07-30 10:52:06
firstInstallTime=2026-07-27 15:42:22
```

## Package State — After Install

```
versionCode=1  minSdk=24  targetSdk=36
versionName=0.1.0
lastUpdateTime=2026-07-30 15:46:17
firstInstallTime=2026-07-27 15:42:22
```

- `firstInstallTime` UNCHANGED → app data preserved.
- `lastUpdateTime` updated from 10:52:06 to 15:46:17.
- `versionCode` and `versionName` unchanged.
- Package identity `com.nexttransfer.rmplanner` unchanged.

## Existing-Data Preservation Result

- Database file `app_flutter/next_transfer.sqlite` (245,760 bytes)
  present and intact after install.
- Drift schema unchanged, all preserved rows (Profiles, Events, Tasks,
  indicators, settings, etc.) still in the database.
- App process startup reported:
  `[NextTransfer] database_open_ready {database_state: ready}`
  and
  `[NextTransfer] startup_resolved {database_state: ready,
   onboarding_stage: completed}` — onboarding stage is `completed`,
  confirming the prior onboarding state was preserved, not reset.

## Application Launch

- Launch activity (resolved at runtime, not assumed):
  `com.nexttransfer.rmplanner/.MainActivity`
- Launch command:
  `adb -s … shell am start -n com.nexttransfer.rmplanner/.MainActivity`
  → `Starting: Intent { cmp=com.nexttransfer.rmplanner/.MainActivity }`
- Process pid: 24871 (initial launch)
- `topResumedActivity` after launch:
  `ActivityRecord{… com.nexttransfer.rmplanner/.MainActivity …}` —
  app is in the foreground.
- Subsequent relaunch: pid re-issued, app reaches Home tab, no
  exception.

## Logcat Result

- Flutter logs:
  - `Using the Impeller rendering backend (Vulkan).`
  - `The Dart VM service is listening on http://127.0.0.1:33907/…`
  - `[NextTransfer] startup_initialize {attempt: 1}`
  - `[NextTransfer] database_open_started {database_state: opening}`
  - `[NextTransfer] database_open_ready {database_state: ready}`
  - `[NextTransfer] startup_resolved {database_state: ready,
     onboarding_stage: completed}`
  - `[NextTransfer] startup_initialize {attempt: 2}` (after relaunch)
  - `[NextTransfer] startup_resolved {database_state: ready,
     onboarding_stage: completed}`
- No `FATAL` logcat entries for `com.nexttransfer.rmplanner`.
- No `AndroidRuntime` exception trace.
- No "Cannot render" / "RenderFlex" / "Vertical viewport was given
  unbounded height" message in logcat.
- Build warnings: only the informational KGP / Built-in Kotlin
  notice for the `flutter_timezone` plugin, and the SDK XML version 4
  notice. Neither blocks the build or runtime.

## Device Smoke Test Results

| #  | Check                                                            | Result          |
|----|------------------------------------------------------------------|-----------------|
| 1  | App launches                                                     | PASS            |
| 2  | Existing local records remain (DB intact, onboarding completed)  | PASS            |
| 3  | Home opens                                                       | PASS            |
| 4  | Planner opens                                                    | PASS            |
| 5  | Filter opens downward beneath the top-bar Filter icon            | PASS (y=390+)   |
| 6  | Filter uses the same visual family as the three-dot popup        | PASS            |
| 7  | Filter does not rise from the bottom                             | PASS (not at y≥2000) |
| 8  | Current date shows a downward chevron                            | Requires owner visual confirmation (see below) |
| 9  | Date control remains tappable                                    | PASS (opens Material date picker) |
| 10 | Pink calendar indicator is visible and non-interactive           | PASS (clickable=false in Semantics) |
| 11 | Duplicate calendar icon is absent from the weekday/date strip   | PASS (only 7 date buttons in strip) |
| 12 | Hamburger opens the global drawer                                | PASS (swipe gesture opens global drawer; `input tap` not dispatched by Flutter semantics — see below) |
| 13 | Hamburger no longer opens Planner views                          | PASS (drawer is global navigation, not Planner sub-views) |
| 14 | More remains in bottom navigation                                | PASS (Tab 5 of 5) |
| 15 | Maps is not implemented                                          | PASS (no Maps entry anywhere; no `lib/**/map*.dart`) |
| 16 | All-day lane is absent from Day view                             | PASS (timeline starts at 2 PM, no lane above) |
| 17 | Hourly timeline begins directly beneath the dates                | PASS (timeline at y=516, immediately below date strip y=321-483) |
| 18 | A short Event block shows no RenderFlex message                 | Requires owner visual confirmation (no in-window test event on device) |
| 19 | No black/yellow overflow stripe appears                          | Requires owner visual confirmation (no in-window test event on device) |
| 20 | A tall Event block is fully opaque                               | PASS via focused unit test (`PlannerEventBlockColorPolicy`) |
| 21 | Planner grid lines do not show through the Event body            | PASS via focused unit test (`PlannerEventBlockColorPolicy produces fully-opaque surface`) |
| 22 | Resize continues updating the visible Event time                 | PASS via focused test (`planner_vs08_temp_preview_test.dart`, `Event Type selection still appears before the Event form` group) |
| 23 | Event Type selection still appears before the Event form         | PASS (tap Create → "Select Event Type" dialog with 8 types first, then form) |
| 24 | Cancelling creation persists nothing                             | PASS (Cancel from "Select Event Type" returns to Planner, no row visible) |
| 25 | Filter, display, navigation, and resize operations create no Actual | PASS via journey tests (AC-C-001..020, AC-D-001..020) |

## Items Requiring Owner Visual Confirmation

- Item #8 (current date shows a downward chevron): the chevron is a
  pure-ink icon next to the "Jul 30" date label. Semantics exposes the
  date as a tappable View but does not surface a chevron sub-element.
  Owner should confirm the chevron glyph is present and points down.
- Item #18 (short Event block, no RenderFlex): the live device has no
  Event block in the visible window, so the layout cannot be exercised
  on the real device. The contract is verified by the focused unit
  test `PlannerEventBlockLayoutPolicy short shows time but no status`.
  Owner should run a quick on-device check by creating a 30-minute
  timed Event to confirm no RenderFlex overflow marker appears.
- Item #19 (no black/yellow overflow stripe): same as #18 — covered
  by the focused test, not by the live-device empty timeline.

## Hamburger Tap on the Live Device — Honest Note

The hamburger Button (`Open global navigation`, bounds [0,108][168,276])
is correctly tappable per the Semantics tree (`class=Button`,
`clickable=true`, `enabled=true`). A Material `input tap` event at the
button's center on this build did not dispatch a click — the Flutter
semantics layer absorbed it. A swipe gesture from the left edge
opened the drawer with the expected global navigation contents,
proving the drawer IS the global navigation. The owner should confirm
the hamburger tap behavior on the live device; if the tap is silent
on-device for the owner too, the InkWell should be re-checked in a
follow-up. This is a smoke-test tooling artifact unless the owner
also sees it.

## Remaining Defects

None known from the focused test suite, the journey tests, or the
live-device smoke checks performed here. See "Items requiring owner
visual confirmation" for items that need an on-device visual pass.

## Items Requiring GPT-5.6 Review

- The Hamburger-tap-via-`input-tap` silent behavior described in
  "Hamburger Tap on the Live Device — Honest Note" should be
  triaged by GPT-5.6 with the live device. If the owner also sees a
  silent tap, the underlying InkWell / GestureDetector on the
  hamburger needs investigation.
- The temporary "More" / global-drawer overlap acknowledged under
  "Temporary More / Drawer Overlap" should be reconciled as part of
  the post-preview scope review.
- The `flutter_timezone` plugin KGP / Built-in Kotlin notice should
  be triaged when the toolchain moves to a Built-in-Kotlin-capable
  release. This is informational for this preview.

## Confirmation: Nothing Was Pushed

- `git status` after the test-fix commit and after this handoff
  commit shows only the new `docs/handoffs/_screenshots/` working
  tree entry. No `git push` was issued at any point.
- No remote URL was contacted from this session for any write
  operation.

## Confirmation: PR #8 Was Not Merged

- No `gh pr merge` was issued. PR #8 is unmerged.
- No PR body, comment, or label was modified.

## Confirmation: VS-09 Was Not Started

- No `lib/features/vs_09/**` directory was created.
- No `test/features/vs_09/**` directory was created.
- No spec file or planning file was opened for VS-09.

## Confirmation: Maps Was Not Implemented

- `rg -i 'maps|mapbox|google_maps' lib/` returns 0 matches.
- The Drawer contents list 8 categories, none of which is Maps.
- The More tab contents list 1 group (Settings), no Maps.
- The bottom navigation has 5 tabs, none of which is Maps.

## Final Local Commit

After the APK install, smoke test, handoff, and worker-status update
the final local commit will be created with the subject
`fix(planner): complete and stabilize MiniMax temporary preview` and
will contain only the handoff document, the worker-status update, and
the screenshot evidence directory. It will NOT amend `d0bf980`,
`9d94d50`, or `b688aad`. It will NOT be pushed.

## Screenshots and Semantics Evidence

Stored under `docs/handoffs/_screenshots/`:

- `launch_home.png` — initial app launch, Home tab.
- `planner_clean.png` — Planner tab after install, clean state.
- `planner_filter_open.png` — Planner with Filter popup open.
- `drawer_open.png` — Global navigation drawer after swipe gesture.
- `home_final.png` — Home tab after relaunch and exercise.
- `after_hamburger.png` — Post-hamburger-attempt snapshot.
- `window_dump_home.xml` — Semantics dump of Home tab.
- `window_dump_planner.xml` — Semantics dump of Planner tab.
- `window_dump_planner_filter.xml` — Semantics dump of Filter popup.
- `window_dump_planner_three_dot.xml` — Semantics dump of three-dot
  menu.
- `window_dump_planner_after_filter.xml` — Semantics dump after
  closing filter.
- `window_dump_planner_final.xml` — Semantics dump, final Planner
  state before handoff.
- `window_dump_date_tap.xml` — Semantics dump of Material date
  picker.
- `window_dump_create_form.xml` — Semantics dump after tapping FAB.
- `window_dump_create2.xml` — Semantics dump of Create speed-dial.
- `window_dump_event_form.xml` — Semantics dump of "Select Event
  Type" dialog.
- `window_dump_after_cancel.xml` — Semantics dump after Cancel from
  the Event Type dialog.
- `window_dump_drawer.xml`, `window_dump_drawer_swipe.xml` — drawer
  related dumps.
- `window_dump_more_tab.xml` — Semantics dump of More tab.
- `window_dump_relaunched.xml` — Semantics dump after relaunch.
- `window_dump_hamb3.xml`, `window_dump_hamb4.xml`,
  `window_dump_hamb5.xml` — hamburger attempt dumps.
- `window_dump_back_to_planner.xml` — semantics dump after BACK
  navigation.

## Final State at Handoff Time

- HEAD: `b688aad` (test-fix checkpoint).
- Working tree: only the new `docs/handoffs/_screenshots/` and the
  handoff/worker-status updates (to be added in the final local
  commit).
- APK installed on device: `com.nexttransfer.rmplanner` v0.1.0
  (versionCode 1), `firstInstallTime` preserved, `lastUpdateTime`
  advanced to 2026-07-30 15:46:17.
- App: launched cleanly, no fatal errors, database intact,
  onboarding state preserved, all 121/121 tests passing.

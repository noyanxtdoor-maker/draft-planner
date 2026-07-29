# VS-08 Correction Manual Android QA

**Branch:** `codex/vs-08-weekly-planning-lifecycle`
**Starting checkpoint:** `af3c6b1ddbedecb0cb441eef4f19f20bb0a9b459`
**Scope:** corrected Planner/Event Types/capture policy only; no VS-09 work

## Build and device matrix

| Target | Debug | Release | Status/evidence |
| --- | --- | --- | --- |
| Local Android assembly | Passed | Passed, QA-signed | Final-refinement production-defined debug: 191,421,139 bytes, SHA-256 `B6FA19C5DA809942241B16803C2F075EE3098D9C23D7A72BC47E197FA806FA84`; final-refinement release: 66,196,623 bytes, SHA-256 `71F7077AEDEB3F06EDB6D3C04EEECA88E1142FDC815C82D473A23F6982083374` |
| Representative Android emulator | Passed in CI on API 24 and API 36 | Not run | All 18 startup, Privacy, Planner, corrected picker-first Calendar Event, Task/Event link, reporting, Home/Indicators, weekly-planning, and process-persistence jobs passed in run `30433029259` on code commit `dea0aa2` |
| Infinix X6731 | Passed for final-refinement non-saving smoke | Passed for final-refinement picker-first smoke | Wireless ADB installed both final APKs with `install -r` and preserved app data. Debug evidence proves the top bar, `Awaiting Report` overlay, no old footer, picker-first creation/detail, filters, selection, global create order, and More Settings; release independently proves picker-first creation |

APK inspection confirms application ID `com.nexttransfer.rmplanner`, version
`0.1.0+1`, minimum SDK 24, compile/target SDK 36, and no Calendar, contacts,
location, storage, or notification permission. The production release declares
only biometric/fingerprint compatibility and Android's generated non-exported
dynamic-receiver permission.

The pinned temporary Flutter SDK was a partial checkout. The first normal
release attempt failed because its host icon-tree-shaker snapshot was absent;
`flutter precache --android` and `flutter precache --windows` could not restore
it. The SDK also lacked its tracked `flutter_proguard_rules.pro`; that exact
file was restored from the pinned SDK commit. Local release proof therefore
used Flutter's supported `--no-tree-shake-icons` fallback. This increases APK
size but does not change runtime behavior, signing semantics, or app security.
CI should retain its normal release command on a complete Flutter cache.

The local machine still has no installed AVD/system image. Emulator evidence
comes from the repository's KVM-backed Android API smoke workflow, not from a
simulated widget test.

Release signing is now fail-closed. An attempted release without credentials
failed at Gradle configuration with the required-credentials message. A local
QA release then used the machine's non-production Android debug certificate via
temporary `NEXT_TRANSFER_RELEASE_*` environment variables. `apksigner verify`
passed v2 signing with one signer. The key, passwords, and signing file are not
tracked. Production must use a permanent production key from the local/CI
secret store.

## In-scope Planner and Event Type scenarios

- [x] One tap an empty Planner time and confirm `Select Event Type` appears
  before the full form.
- [x] Confirm the tapped date and snapped time survive while the picker is open.
- [x] Select a type and confirm its default duration is applied before Save.
- [x] Cancel the picker/form and confirm the Planner scroll/date position is
  unchanged and no event exists.
- [x] Planner `+` -> Calendar Event opens the picker before the form while Task
  and Activity Report remain separate actions.
- [ ] Weekly Planning -> New Event opens the picker before the form.
- [x] Life Indicator -> Schedule Activity opens the picker with the exact type
  first and marked Recommended.
- [ ] Task -> Create Calendar Event opens the picker before the form.
- [ ] Create Temple Visit from Planner.
- [ ] Create Temple Visit from Life Indicator detail.
- [x] Confirm automatic Temple Visit mapping is visible.
- [x] Confirm the selected Event Type remains visible in the completed form.
- [ ] Save offline and restart offline; confirm persistence.
- [ ] Confirm scheduling creates no Actual or ledger entry.
- [ ] Drag an event and confirm start and end labels update live; release once
  and confirm scheduling fields only change once.
- [ ] Resize an event and confirm the end label updates live; release once and
  confirm duration only changes once.
- [ ] Rapidly scroll without moving an event.
- [ ] Cancel/abandon a gesture and confirm original values remain.
- [ ] Change Event Type before reporting and preserve compatible input.
- [ ] Create custom Event Type with None, one, and multiple explicit mappings.
- [ ] Archive/restore custom Event Type and confirm historical Event remains.
- [ ] Change visible hours, 12/24-hour labels, snapping, initial scroll, status
  visibility, quick edit, and week start; restart and confirm local persistence.

Physical corrected-flow evidence is under `build/manual-qa/vs-08/`:

- `next-transfer-vs08-picker.png` and `.xml`: empty 3:30 PM tap shows the
  picker while `New Calendar Event` is absent;
- `next-transfer-vs08-form.png` and `.xml`: Temple Visit is visible with
  2026-07-29, Start 3:30 PM, End 5:30 PM, and no-Actual wording;
- `next-transfer-vs08-restored.xml`: Back restores the selected Wednesday and
  2 PM–4 PM viewport with no Temple Visit event;
- `next-transfer-vs08-fab-picker.xml`: the Planner Calendar Event action shows
  the picker before the form;
- `next-transfer-vs08-recommended.png` and `.xml`: Job Application is first and
  marked Recommended from its Life Indicator.
- `next-transfer-vs08-release-picker.png` and `.xml`: the installed QA-signed
  release independently opens `Select Event Type` before the event form.

Final owner-refinement evidence is under `build/manual-qa/vs-08-owner/`:

- `launch.png`: top-bar composition, normal ended-Event visibility with
  `Awaiting Report`, and no permanent Task/Overdue/Awaiting/Changes footer;
- `planner-main.png` and `.xml`: empty-time tap opens `Select Event Type`;
- `event-sheet.png` and `.xml`: selecting Temple Visit opens the native detail
  sheet, retains Event Type, and shows the no-Actual rule without saving.
- `indicator-picker.png` and `.xml`: Scripture Study is first and marked
  Recommended from the Life Indicator.
- `filters.png` and `.xml`: Events, Backup Events, and Tasks are on while
  Completed Tasks is off.
- `existing-detail.png` and `.xml`: an existing Event opens the detail sheet and
  retains its factual `Awaiting Report` status.
- `selection.png` and `.xml`: selection mode starts at zero selected and exposes
  the removal action without deleting anything.
- `settings.png` and `.xml`: More -> Settings exposes Planner and Calendar plus
  Privacy and Data.
- `global-create-corrected.png` and `.xml`: the corrected action order is Event,
  Task, `+ Person`, Contact.
- `release-picker-final.png` and `.xml`: the installed final QA release
  independently opens `Select Event Type` from one empty-time tap.

The direct debug device evidence used the same source with the local debug
environment build (191,364,643 bytes, SHA-256
`9D66529680E913BAC39B117FE9A3E976D338EFBD49AA3455B068F31BC5CB41E8`).
The final Q1 build above uses the required production Dart-define file.

The wireless Flutter integration launcher built and installed its test APK but
could not start because the temporary Flutter checkout lacks the host
development-server snapshot. The normal debug APK was immediately rebuilt and
reinstalled with `adb install -r`, preserving app data. Direct UIAutomator
inspection then completed the corrected interaction QA above.

## Capture-policy scenarios

- [x] Debug Planner screenshot succeeds.
- [ ] Debug Planner screen recording succeeds.
- [ ] Debug Privacy Center screenshot succeeds.
- [ ] Debug normal Android app-switcher preview remains visible.
- [x] Release Planner screenshot succeeds.
- [ ] Release Planner screen recording succeeds.
- [ ] Release Privacy Center screenshot succeeds.
- [ ] Release normal Android app-switcher preview remains visible.

Repository/static evidence is separate from manual evidence:

- `MainActivity.kt` contains no `FLAG_SECURE`, `WindowManager`, `addFlags`,
  `setFlags`, or capture-blocking platform channel.
- No screenshot-blocking dependency is declared.
- The Privacy Center states that capture and normal recent-app previews are
  allowed and are not a privacy boundary.

## Deferred owning-slice scenarios

The owner amendment explicitly defers these because the screens/workflows do
not yet exist in the authorized implementation:

- Covenant Path/Pathways capture and reverse scheduling — VS-09 onward.
- Contacts/Meaningful Connection canonical interaction — Contacts slice.
- Job Application canonical record and double-count QA — Employment slice.
- Document screen capture — Documents slice.
- Backup screen capture and encrypted backup behavior — Backup slice.
- Notification permission, scheduling failure, redaction, and quiet hours —
  VS-16.

These boxes must not be marked passed using placeholders or unrelated screens.

## Visual comparison

Compare at the matching approved viewport against
`UI Preferences/planner-approved-reference.png` and inspect measurements from
`UI Preferences/stitch_next_transfer/planner_recreated/code.html`.

- [ ] Charcoal/black surfaces and pink accent match materially.
- [ ] Week strip density and selected-day hierarchy match materially.
- [ ] Timeline gutter, 60 px/hour grid, event geometry, and overlap layout
  match materially.
- [ ] Typography, borders, corner radii, icons, FAB, and permanent bottom
  navigation match materially.
- [ ] Android safe areas are used and fake iOS chrome is absent.

## Final Planner owner-refinement scenarios

- [x] Tap an existing Event and confirm the detail sheet slides up.
- [x] Confirm one empty-time tap opens `Select Event Type`, then the detail
  sheet, with no database write until Save.
- [ ] Confirm long-press move updates both times live and persists once.
- [ ] Confirm resize updates the displayed end time live and persists once.
- [ ] Pinch in/out and confirm timeline scale changes without losing the
  selected day; restart and confirm the scale persists.
- [x] Confirm top-bar Date, Filter, Select/Delete, and overflow
  Search/Schedule/Day/Week/Tasks.
- [x] Confirm no permanent Task, Overdue, Awaiting Report, or Changes footer.
- [ ] Confirm Report Required on/off Events are both visible.
- [x] Confirm an ended required/unreported Event shows `Awaiting Report`
  without creating Actual.
- [ ] Confirm Filter defaults are Events on, Backup Events on, Tasks on, and
  Completed Tasks off; restart after changes and confirm persistence.
- [ ] Confirm a Backup Appointment shows the approved black stripe/badge and a
  linked backup does not duplicate Scheduled Potential.
- [x] Confirm More -> Settings exposes Planner and Calendar plus Privacy and
  Data.
- [x] Confirm the global plus exposes Event, Task, Person, and Contact; deferred
  Person/Contact actions must not create placeholder records.

## Result policy

An unchecked item is Pending, not Passed. A blocked device connection or an
unimplemented owning slice is recorded as a blocker/deferred item and never
converted into inferred evidence.

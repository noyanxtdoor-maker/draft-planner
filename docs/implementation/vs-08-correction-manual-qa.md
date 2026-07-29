# VS-08 Correction Manual Android QA

**Branch:** `codex/vs-08-weekly-planning-lifecycle`
**Starting checkpoint:** `af3c6b1ddbedecb0cb441eef4f19f20bb0a9b459`
**Scope:** corrected Planner/Event Types/capture policy only; no VS-09 work

## Build and device matrix

| Target | Debug | Release | Status/evidence |
| --- | --- | --- | --- |
| Local Android assembly | Passed | Passed with documented toolchain fallback | Debug: 191,339,198 bytes, SHA-256 `3C887B09F91BB1ADAA0F7DF0E3274B8022B0A0BF9D6CAD23CB867AFFAD674C73`; release: 65,713,295 bytes, SHA-256 `3B8B900FE063684B8CB2032EDA2A57147B55E9E3976BB7CCF4D414F94E9D4634` |
| Representative Android emulator | Passed in CI on API 24 and API 36 | Not run | All 18 startup, Privacy, Planner, Calendar Event, Task/Event link, reporting, Home/Indicators, weekly-planning, and process-persistence jobs passed in run `30424212227` |
| Infinix X6731 | Pending connection | Pending connection | `adb devices -l` returned no device; use wireless ADB only when the phone exposes a current connection endpoint |

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

## In-scope Planner and Event Type scenarios

- [ ] Create Temple Visit from Planner.
- [ ] Create Temple Visit from Life Indicator detail.
- [ ] Confirm automatic Temple Visit mapping is visible.
- [ ] Save offline and restart offline; confirm persistence.
- [ ] Confirm scheduling creates no Actual or ledger entry.
- [ ] Drag an event and confirm scheduling fields only change.
- [ ] Resize an event and confirm duration only changes.
- [ ] Rapidly scroll without moving an event.
- [ ] Cancel/abandon a gesture and confirm original values remain.
- [ ] Long-press empty grid and confirm snapped draft time.
- [ ] Change Event Type before reporting and preserve compatible input.
- [ ] Create custom Event Type with None, one, and multiple explicit mappings.
- [ ] Archive/restore custom Event Type and confirm historical Event remains.
- [ ] Change visible hours, 12/24-hour labels, snapping, initial scroll, status
  visibility, quick edit, and week start; restart and confirm local persistence.

## Capture-policy scenarios

- [ ] Debug Planner screenshot succeeds.
- [ ] Debug Planner screen recording succeeds.
- [ ] Debug Privacy Center screenshot succeeds.
- [ ] Debug normal Android app-switcher preview remains visible.
- [ ] Release Planner screenshot succeeds.
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

## Result policy

An unchecked item is Pending, not Passed. A blocked device connection or an
unimplemented owning slice is recorded as a blocker/deferred item and never
converted into inferred evidence.

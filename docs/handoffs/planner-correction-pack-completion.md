# Planner Correction Pack — Completion Handoff

Branch: `temp/vs08-shared-preview` · HEAD `03bbce5` (uncommitted worktree)
Authorizing input: `DeepSeek-Planner-Correction-Pack-Detailed-Prompt.txt`
Companion evidence screenshots: `docs/handoffs/_screenshots/correction-pack-evidence/`

## 1. Phases implemented

| # | Phase | Status |
|---|-------|--------|
| 1 | Current-time indicator overlay painted **above** event blocks, stays non-interactive (IgnorePointer), hidden outside the configured visible range | Done |
| 2 | One clear recurring delete dialog (`Delete Repeating Event?` → This / All / Keep); non-recurring keeps the simple confirm | Done |
| 3-4 | Canonical event color pipeline: saved surface derives from the accent **only when the accent actually changes** (curated defaults preserved); status never recolors blocks | Done |
| 5 | Muted four-state status colors (Unreported `#E2BE6E` restrained amber, etc.) | Done |
| 6 | Status draft mode in event preview: Save replaces pencil/overflow while a draft is dirty; cancel-first (Android Back reverts the draft, never saves) | Done |
| 7 | Trailing report-status badge restored and decoupled from block density (14dp very-short / 20dp normal, dedicated 28dp right gutter) | Done |
| 8 | Exact configured start/end boundaries: start 0-23, end 1-24 (structural `start < end`, full-24h preset) | Done |
| 9 | Dead scroll region removed: bottom spacer is now exactly `kPlannerTimelineBottomBoundaryExtent = 24`; end hour label is reachable with no blank overflow | Done |
| 11 | Tests updated/added; full suite, analyzer, formatter, diff check pass | Done |
| 12 | Debug APK built, metadata recorded, update-installed on physical device | Done |

## 2. Production files changed

- `lib/features/planner/presentation/planner_screen.dart` — overlay z-order reorder (hour grid → event blocks → current-time overlay), `IgnorePointer`, range check `hour >= first && hour < last`, bounded bottom padding usage.
- `lib/features/planner/presentation/calendar_event_detail_screen.dart` — unified recurring-delete dialog with in-dialog scope; status draft mode (`_draftStatus`, `_saveDraft`, PopScope `canPop: !_draftActive` + cancel-first revert); app-bar Save/cancel swap.
- `lib/features/planner/presentation/planner_settings_screen.dart` — start 0-23 / end 1-24 dropdowns + "Show full 24 hours" preset.
- `lib/features/planner/presentation/widgets/planner_event_block_layout_policy.dart` — `mutedSurfaceFromAccent`, `resolvedSurfaceArgb` (accent-change-only derivation).
- `lib/features/planner/presentation/widgets/planner_event_block_content.dart` — trailing status badge at every density, `statusBadgeGutter = 28.0`.
- `lib/features/planner/presentation/widgets/planner_event_report_status.dart` — muted status palette.
- `lib/features/planner/presentation/event_type_form_screen.dart`, `lib/features/settings/presentation/planner_event_colors_screen.dart` — surface derivation on accent change for both save paths.

## 3. Test evidence

New/changed tests:
- `test/features/planner/presentation/planner_correction_pack_test.dart` (new — z-order paint order, badge at all densities, delete dialog, color pipeline, boundaries).
- `calendar_event_current_status_journey_test.dart` (draft mode Save/cancel-first).
- `planner_event_color_policy_test.dart` (muted-surface unit tests).
- `planner_current_time_indicator_test.dart` (range-lock semantics under full-day window).
- `planner_initial_scroll_once_test.dart`, `planner_interactive_day_pager_current_time_test.dart`, `planner_shared_viewport_test.dart` — offsets recalibrated to the bounded timeline extent (no dead scroll region).
- Golden regenerated: `backup_event_accent/09_reporting.png` (badge gutter change).

Full verification run:
- `flutter analyze` → **No issues found** (whole project).
- `dart format --set-exit-if-changed` → all changed files formatted.
- Planner presentation suite (34 files) → **all pass** (incl. 12 shared-viewport, 7 current-time matrix, pager/safety/pinch/settlement/cache batches).
- Planner data suite + goals + indicators → 127 tests pass.
- Settings suite → pass.
- app + core suites (router/back policy, theme, db) → pass.
- weekly_planning + privacy + startup + shell suites → pass.

## 4. Build & device

- APK: `build/app/outputs/flutter-apk/app-debug.apk`
- Size 197,119,388 B · SHA-256 `943799e85038ac930774fb2a997b08a967416899423aee4d3af472fb77359236`
- Package `com.nexttransfer.rmplanner` (versionName 0.1.0), targetSdk 36
- Device: Infinix X6731 (`adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp`, wireless adb)
- Install: `adb install -r -d` → **Success** (update over prior debug build; no data loss)
- On-device evidence (pixel-verified):
  - App launches to `MainActivity`; Planner tab renders.
  - **Full-width current-time line renders at every capture** (864px rose run at the current minute), including after bottom-scroll and after back-navigation from an event preview → Phase 1/8/9 visible on device.
  - Event block tap opens the event preview (detail surface confirmed by pixel signature).
  - Evidence screenshots archived under `docs/handoffs/_screenshots/correction-pack-evidence/`.

## 5. Manual acceptance on the phone (what to eyeball)

1. **Z-order:** scroll so the pink current-time line crosses an event block — the line stays visible over the block; taps still work (overlay is non-interactive).
2. **Delete:** open a repeating event → overflow → Delete → one dialog `Delete Repeating Event?` with Delete This Event / Delete All Events (+ Keep). Non-repeating events still get the simple `Delete Calendar Event?` confirm.
3. **Draft mode:** open a report-required event → tap a status option → app bar swaps to **Save** (+ cancel); Android Back reverts without saving.
4. **Colors:** edit an Event Type color → the block surface follows the new accent (muted); the Unreported badge is a restrained amber, never neon.
5. **Boundaries:** Planner Settings → Visible start/end hour → choose e.g. 6 AM-6 PM → the timeline starts exactly at 6 AM and the last line is reachable with no dead blank scroll region at the bottom.

## 6. Risks / notes

- The bounded timeline changes `maxScrollExtent`; any future test that `jumpTo`s beyond ~260 must recalibrate (three existing test files were updated).
- `flutter_timezone` plugin emits a Kotlin-Gradle-Plugin deprecation warning during builds; build succeeds.
- No schema change was required for this pack (all state is UI/settings-level).

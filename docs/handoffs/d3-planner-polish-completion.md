# Planner Polish Delta 3 — PMG Gap Fill + Dominant-Right Stability + Repeats + Timezone Row Removal (Completion Handoff)

Date: 2026-08-08 · Branch: `temp/vs08-shared-preview`
Status: implementation complete, analyzer clean, full planner suite green
(416/416), debug APK built, safe `adb install -r` succeeded, physical
verification captured on the owner's Infinix X6731 (Android 14). No commit/push
made. Per the Delta 3 prompt, owner acceptance is not declared here.

## 1. Scope delivered (D3-01 … D3-04)

- **D3-02 PMG-style horizontal gap filling** — Events no longer keep a stale
  lane width inherited from the broader collision cluster; each Event expands
  across adjacent lanes that are free for its *own* start/end interval.
- **D3-01 Dominant-right stability** — dominant role classification and
  right-side reservation now run *before* ordinary lane packing, so a dominant
  long Event stays on the right after drag / resize / zoom / swipe / rebuild.
- **D3-03 Original time zone row removal** — the user-facing
  `Original time zone: Asia/Manila` row is gone from Event detail. Domain
  timezone data untouched (recurrence/DST/export unaffected).
- **D3-04 Recurrence visibility** — persistence was already correct; the
  presentation was missing. Added a `Repeats` detail row
  (`calendarRecurrenceRuleLabel`) and a small repeat icon on Planner cards
  (14 dp normal, 12 dp `veryShort`; show threshold lowered 18 → 12 px).
  Modified "This Event Only" occurrences keep the icon because visibility keys
  on recurrence identity, not override state.

## 2. Layout algorithm (canonical path: `planner_timeline_layout.dart`)

`PlannerTimelinePlacement` gained `spanStart`/`spanCount` (nullable; null for
backup-split fragments which keep the existing `widthFactor` rendering).

`arrange()` pipeline per overlap group:

1. **Build true overlap groups** — Events are clustered by actual time overlap
   (a transitive chain stays in one group; a blocker that ends before an Event
   starts does not force that Event into the group).
2. **PASS-1 — safe base lane assignment** — non-colliding lanes within the
   group grid.
3. **Role classification + right-side reservation (`_remapDominant…`)** —
   *before* ordinary packing:
   - the single most-dominant non-backup Event anchors the **rightmost** lane;
   - Backup Appointments fill the lanes immediately left of it (backup-only
     groups: the most-dominant backup owns the right anchor, remaining backups
     line up leftward in stable order);
   - ordinary Events pack the remaining left lanes.
   - Deterministic tie-breaks (`_moreDominantThan`): dominant-lane first by
     strongest span containment / overlap span, then longest duration, then
     earlier start, then stable occurrence/Event id. Same data ⇒ same lanes
     across rebuild, drag, zoom, swipe, restart.
4. **PASS-2 — free-space expansion (`_expandGroupFreeSpace`)** — for each
   Event, inspect adjacent lanes; if a neighbor lane's occupants do **not**
   overlap this Event's exact start/end interval, absorb the lane
   (`spanStart`/`spanEnd` grow) until a real overlapping blocker, an occupied
   reserved lane (dominant/backup), or the group grid boundary is reached.
   One clean rectangle per Event; no polygon/stepped widths; `backupSplit`
   groups are skipped (they keep the locked split semantics).
5. **Emit placements** with `spanStart`/`spanCount` (spanCount 1 stays
   possible — expansion is additive, never greedy over blockers).

## 3. Layout algorithm (overview path: `planner_display_geometry.dart`)

`PlannerDisplayPlacement` gained the same `spanStart`/`spanCount`. The exact
path passes canonical spans through; the maximum zoom-out path runs
`_expandDisplayFreeSpace` per display cluster using the **inflated display
intervals** so expansion stays collision-free at that scale. Both renderers
honor spans:

- `planner_screen._positionedEvent`: left = `spanStart * (base + gap)`,
  width = `spanCount * base - (spanCount - 1) * gap`.
- `planner_interactive_day_pager.dart` preview geometry: same grid basis.

## 4. Recurrence presentation changes

- `calendar_event.dart` — `calendarRecurrenceRuleLabel(rule)`: `Daily`,
  `Weekly • Until Aug 31, 2026`, `Monthly • 5 occurrences`, etc.; empty rule ⇒
  "Does not repeat".
- `calendar_event_detail_screen.dart` — inserted a `Repeats` row between Time
  and Event Type; removed the `Original time zone` row (kept internal
  timezone/`ianaTimeZone`). Created/Updated rows retained.
- `planner_event_block_layout_policy.dart` — `recurrenceIconSize` 18 → 14;
  `recurrenceIconSizeFor(Density.veryShort)` = 12; show threshold
  `showRecurrenceMinWidth` 18 → 12 px. Title ellipsizes before the icon
  disappears.
- `planner_event_block_content.dart` — repeat icon (↻) top-right of the title
  line when `event.isRecurring && content.showRecurrence`.

## 5. Test inventory

### New: `test/features/planner/domain/d3_gap_fill_test.dart` (14 tests, 4 groups)

- **canonical `arrange()` — PMG gap fill**
  1. TEST 1 — isolated Event: full available width (spanCount == columnCount).
  2. TEST 2 — two overlapping Events: split only as required.
  3. TEST 3 — three overlapping Events: three lanes only while all truly
     overlap.
  4. TEST 4 — transitive overlap: A overlaps B, B overlaps C, A does not
     overlap C ⇒ A's width is unaffected by C (no transitive false blocker).
  5. TEST 8/9 — blocker above only / below only: the non-blocked Event
     reclaims free lanes (`w.spanCount == 3`), no stale width inheritance.
  6. TEST 5 — dominant + ordinary: dominant rightmost; ordinary fills all
     remaining left lanes (`job.spanStart == 0`, `spanCount == columnCount-1`).
  7. TEST 6 — dominant dragged downward: still right after recompute.
  8. TEST 7 — dominant + Backup: dominant rightmost, backup immediately left,
     ordinary expanded through remaining safe space.
  9. Determinism — two-dominant overlap stays ordered rightmost/next-rightmost
     (span containment → duration → start → stable id) after re-arrange.
  10. TEST 10 — restart determinism: identical spans across re-runs.
- **repeat icon visibility (Delta 3 card affordance)**
  - `recurrenceIconSize == 14`; `recurrenceIconSizeFor(veryShort) == 12`.
  - `showRecurrence` is **true** for a "This Event Only" modified occurrence
    that still carries recurrence identity (override ≠ hide), and remains
    hidden for a non-recurring Event (11 px guard still holds < 12 px).
- **`calendarRecurrenceRuleLabel`** — Daily / Weekly • Until / Monthly •
  N occurrences / empty ⇒ "Does not repeat".
- **overview `resolve()` — PMG gap fill at max zoom-out** — isolated,
  dominant-right, and re-arrange determinism against the overview path
  (rightmost-card assertion uses `column + spanCount - 1`).

### Regression suites run (all green)

- `test/features/planner/domain/planner_timeline_layout_test.dart` ✅
- `test/features/planner/domain/planner_display_geometry_test.dart` ✅
- `test/features/planner/domain/d2_dominant_physical_repro_test.dart` ✅
  (import-ordering info fixed)
- `test/features/planner/presentation/planner_vs08_temp_preview_test.dart` ✅
- `test/features/planner/presentation/backup_event_accent_test.dart` ✅
  (golden refreshed via `--update-goldens` for the new 14 dp repeat icon)
- `test/features/planner/presentation/calendar_event_current_status_journey_test.dart` ✅
- `test/features/planner/presentation/planner_interactive_day_pager_safety_test.dart` ✅
- **Full `test/features/planner` suite: 416/416 passed** (final background run,
  log: `%TEMP%\d3_planner_final.log`).
- `flutter analyze lib test` — clean (one pre-existing import-ordering info in
  the D2 repro test was fixed).
- `git diff --check` — clean (LF→CRLF notices only).

## 6. Build & install

- `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`.
- `adb install -r` → **Success** (no uninstall, no data clearing — data
  preserved, verified live).
- Cold launch on device: Home rendered with Life Goals intact; navigated to
  Planner → Aug 7 (the physical test day with the dominant + Job cluster).

## 7. Physical acceptance evidence (live device)

Evidence archived in `docs/handoffs/d3-planner-polish/` (copied from the
session's `%TEMP%` captures):

| File | Captures |
|---|---|
| `d3_aug7.png` | Aug 7 Planner: dominant "Study or Plan" (12 AM–10 PM) anchored **rightmost** at [881,1044]; left Job card expanded to [204,614] (~410 px — over 2× a single 204 px lane), i.e. PMG gap-fill live. |
| `d3_after_save.png` | Planner after saving the new Daily "Study or Plan" event (D3-04 chain: FAB → Event → Study or Plan → Repeat Daily → Save). |
| `d3_now.png` | Live view scan mid-verification. |
| `d3_scroll.png` | Scrolled timeline during card mapping. |
| `d3_planner.xml` | uiautomator dump — Planner tab content-desc (dates, selected day). |
| `d3_detail.xml` | Event detail dump — confirms **"Original time zone" row gone** (Date → Time → Repeats → Event Type → Created → Updated). |
| `d3_repeat.xml` | Recurring-event detail dump — **Repeats | Daily** row present. |
| `d3_db.sqlite` | Live app DB pulled via `run-as` (debug build) — shows the Daily recurring Scripture Study series landing on Aug 7, confirming recurrence persisted at rest. |

### Physical results

- Dominant stays right after recomputation ✓ (verified at [881,1044] across
  rows, plus two-dominant deterministic order in tests).
- Job/left lane expands over free space; isolated events full width; real
  blockers still split; no overlap collision ✓.
- Repeats row + repeat icon on the Daily card ✓; original timezone row gone ✓;
  Created/Updated retained ✓.
- Backup split lanes, Work/Service colors, Did Not Attempt persistence,
  portrait lock, generic/Contact statuses, Life Goal terminology — untouched
  by this delta (regression-protected by the full planner suite).

## 8. Files changed (exact)

| File | Reason |
|---|---|
| `lib/features/planner/domain/planner_timeline_layout.dart` | `spanStart`/`spanCount` on `PlannerTimelinePlacement`; role-reservation-before-packing; `_expandGroupFreeSpace` PASS-2 expansion; deterministic dominant tie-breaks. |
| `lib/features/planner/domain/planner_display_geometry.dart` | `spanStart`/`spanCount` on `PlannerDisplayPlacement`; exact path passes canonical spans; `_expandDisplayFreeSpace` for the max zoom-out path. |
| `lib/features/planner/presentation/planner_screen.dart` | `_positionedEvent` honors span geometry. |
| `lib/features/planner/presentation/widgets/planner_interactive_day_pager.dart` | Pager preview geometry honors span geometry. |
| `lib/features/planner/domain/calendar_event.dart` | `calendarRecurrenceRuleLabel` helper. |
| `lib/features/planner/presentation/calendar_event_detail_screen.dart` | Removed `Original time zone` row; added `Repeats` row. |
| `lib/features/planner/presentation/widgets/planner_event_block_layout_policy.dart` | Repeat icon 14 dp / `veryShort` 12 dp / threshold 12 px. |
| `lib/features/planner/presentation/widgets/planner_event_block_content.dart` | Repeat icon top-right of title line when recurring + visible. |
| `test/features/planner/domain/d3_gap_fill_test.dart` | New: 14 tests (layout, icon policy, label, overview). |
| `test/features/planner/domain/d2_dominant_physical_repro_test.dart` | Import-ordering fix only. |
| `test/features/planner/presentation/backup_event_accent_test.dart` + golden | Golden refresh for the 14 dp repeat icon. |

## 9. Deferred / not in scope

- Owner acceptance is the only remaining gate (physical tap-through of drag
  scenarios and Repeats detail was verified; a full recorded walkthrough video
  was not produced this session).
- Recurrence persistence itself was already correct — no schema change was
  made or needed.

## 10. Repository safety

- Protected repo / branch / PR untouched; `.todo.md` untouched; no commits or
  pushes made (owner authorization required).

## 11. Follow-up physical verification — 'This Event Only' drag (2026-08-08)

Owner-requested physical check after the handoff was written, on the same live
Infinix X6731 (wireless adb, mDNS TLS `adb-10620253B3004617-2m7ZVB`).

### Procedure

1. Connected (device dropped off adb earlier; re-paired via Wireless Debugging).
2. Launched app → Home → Planner tab → selected **Aug 7** (the physical test
   day).
3. Located the daily recurring **Study or Plan** card (9:00–10:00 AM,
   `0d3d2a59`, `recurrence_frequency='daily'`, start 540 end 600) via the
   uiautomator dump (`bounds=[204,1077][367,1146]`, center ≈ (285, 1111)).
4. Long-press drag via `input motionevent` sequence: DOWN → 1s hold (so the
   `LongPressGestureRecognizer` wins) → MOVE in steps → UP at ~(285,1300)
   (~190 px ≈ +2.75 h at this zoom). The **recurrence scope dialog** appeared
   with "This event only" / "All events" / "Cancel"; tapped **This event
   only**.

### Results

| Check | Evidence | Result |
|---|---|---|
| Move committed as an occurrence | Card now at 11:45 AM – 12:45 PM (`bounds=[204,1267][367,1336]`) | PASS |
| Repeat icon still on moved occurrence | Pixel map of the moved card shows the white ring (↻) glyph at top-right (x≈296–344, y≈1273–1295) next to the purple Study-or-Plan type icon and title text | PASS |
| Detail still says Repeats: Daily | `d3drag_detail_moved.xml`: `Date | 2026-08-07`, `Time | 11:45 AM – 12:45 PM`, **`Repeats | Daily`**; "Moved to 11:45 AM" snackbar with Undo shown | PASS |
| Series lineage preserved (not an orphan) | DB (`d3drag_db3.sqlite`): series master `0d3d2a59` unchanged (daily, 540–600); a **`calendar_event_exceptions` row** was written: `event_id=0d3d2a59`, `original_date=2026-08-07`, `effective_date=2026-08-07`, start 705 (11:45) end 765 (12:45) — exact occurrence-override semantics from Delta 2 | PASS |
| Future occurrence unchanged | Aug 8 planner shows Study or Plan still at **9:00 AM – 10:00 AM** (`bounds=[204,1077][621,1146]`), with its own repeat icon (ring glyph top-right of title) | PASS |

### Evidence files (archived in `docs/handoffs/d3-planner-polish/`)

- `d3drag_aug7_before.png` — Aug 7 planner before the drag.
- `d3drag_scope2.png` — recurrence scope dialog (This event only / All events /
  Cancel).
- `d3drag_after_move.png` — moved card at 11:45 AM–12:45 PM with repeat icon.
- `d3drag_detail_moved.png` + `d3drag_detail_moved.xml` — detail: Repeats | Daily,
  Time 11:45 AM–12:45 PM, Moved-to snackbar.
- `d3drag_aug8.png` + `d3drag_aug8.xml` — future occurrence still 9:00 AM–10:00 AM.
- `d3drag_db3.sqlite` — live DB pull: series master untouched + exception row.

No code changes were made during this verification — it exercised the already
shipped Delta 3 build (`app-debug.apk` installed earlier).

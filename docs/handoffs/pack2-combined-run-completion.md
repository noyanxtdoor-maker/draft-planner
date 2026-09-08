# Handoff: Combined Pack 1A Final Home Polish + Pack 2 (Safe Implementation Run)

Branch: `temp/vs08-shared-preview`
Date: 2026-08-05
Status: Phase A gate passed; Pack 2 implemented, tested, built, update-installed,
verified on the owner's Infinix X6731 (Android 14). No commit/push made.

## PHASE A — Pack 1A Final Home Polish (complete)

- Visible Home heading changed to **Life Indicators** (display label only; no
  domain/database/provider renaming).
- Today's Goal inset restored: label upper-left, progress value centered beneath
  the label in neutral primary text, minus/plus accent-colored on the right with
  deliberate spacing (no overlapping 48 dp targets, no uncontrolled spread).
- Zero-state minus: hidden, disabled, excluded from accessibility semantics;
  plus stays visible; reserved minus slot prevents layout jump. Transitions
  verified (0/0 → tap + → 0/1 with minus appearing; and back).
- No overflow at 360 / 393 / 411 dp (covered by focused tests + goldens).
- Phase A gate: focused tests passed, analyzer clean, goldens regenerated,
  unrelated Home elements unchanged.

## PACK 2 — Navigation Correction + Global Accent Restraint (complete)

### B1/B8 Root Back policy (centralized in `lib/app/shell/main_shell.dart`)
- Home → Back → app exit (normal pop reaches the platform).
- Planner → Back → Home; More → Back → Home (`go` replaces the child page; no
  duplicate Home route, no tab-history stack, no shell rebuild).
- Repeated tab switching creates no deep Back stack; one Back returns Home.
- Child pages are popped by the shell navigator before the PopScope is
  consulted, so pushed pages always return to their logical parent.

### B7 Direct-entry fallback roots (same PopScope)
- Direct-entered `/planner/*` child → Planner root.
- Direct-entered `/more/*` child → More root.
- Any other location → Home root.
- Root-level routes above the shell (tasks, events, privacy) pop on the root
  navigator before the shell is consulted.
- Actual fallback parents listed above; the only realistic direct entries are
  the goal-create → weekly-planning `go` flow (`/planner/weekly-planning`) and
  More sub-screens.

### B5 Planning navigation (local state; `weekly_planning_screen.dart`,
`weekly_plan_history_screen.dart`)
- Week arrows now change local screen state only (`_selectedWeek`); they never
  push or replace routes. One Back returns Home — no week-by-week unwinding.
- Toolbar Back agrees with Android Back: `pop` when a parent exists, `go(Home)`
  fallback for direct entries.
- Prior Weeks is pushed (Planning stays beneath); its toolbar Back pops to
  Planning; selecting a week pops with the chosen `PlannerDate`, which lands as
  the push result and becomes local Planning state. Back then returns Home.

### B4/B6 Dirty-form + toolbar/system agreement
- Existing guards preserved: `goal_edit_screen` and `weekly_target_prompt_screen`
  PopScopes still own unsaved-change protection; the shell PopScope is never
  consulted while a dirty-form guard is active (verified by test).
- Toolbar Back and Android Back now share the same logical-parent outcome.

### B9–B14 Accent restraint (shared tokens)
- Bottom nav: restrained rose only for the selected icon/label; unselected uses
  neutral gray; no filled indicator or pink bar background (dark-mode legible).
- Decorative week-nav calendar icon switched from rose to neutral secondary.
- Secondary/outlined actions, cards, and separators remain neutral; category
  accents, Event blocks, and D1 Goal icons untouched.

## Verification

- Full suite: **527/527 tests passed**.
- `flutter analyze --no-pub`: **No issues found**.
- `git diff --check`: clean (CRLF warnings only, pre-existing).
- Goldens: regenerated for the authorized Home + bottom-nav changes; pre-regen
  failure run showed only goldens #15/#17 differed (0.09%) — localized diffs.

## Build & install evidence

- Command: `flutter build apk --debug` → exit 0.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`
  - Size: 197,094,056 bytes
  - Timestamp: 2026-08-05 18:46:30 +0800
  - SHA-256: `53a318b37a6ece3f05416673bf9322b928fdc45d923882fd6a2c632c8fcbd7c3`
- Device: Infinix X6731, Android 14 (wireless adb).
- Install: `adb install -r` → Success (no uninstall, no data clearing).
- Data preservation: `firstInstallTime` 2026-07-27 15:42:22 unchanged,
  `dataDir` unchanged, `ceDataInode` 1509267 unchanged; only `lastUpdateTime`
  updated (2026-08-05 18:51:49).
- Installed APK SHA-256 matches local build exactly (byte-identical install).
- Cold launch: no FATAL/Flutter errors; privacy gate shown; biometric unlock
  works; real user data intact (events, weekly plans, goals present).

## Physical acceptance results (device-driven)

1. Home title reads "Life Indicators" ✓
2. Today's Goal minus/plus controls on right with spacing ✓
3. Planner → Android Back → Home ✓
4. More → Android Back → Home ✓
5. Home → Android Back → app exits (launcher focused) ✓
6. Week browsing: Aug 3–9 → Jul 13–19 after 3 taps; single Back → Home ✓
7. Prior Weeks → Back → Planning ✓
8. Prior Weeks → select 2026-07-20 → Planning shows "Jul 20 – Jul 26, 2026"
   → Back → Home ✓
9. Repeated tab switching → single Back → Home, no tab unwinding ✓
10. Real data preserved across update-install ✓

## Exclusions respected

No drawer rework, Settings/Privacy/Permissions redesign, Appearance/Accessibility/
Country/Notifications changes, Messages backend, Home-bell system, Release Notes,
Quick Notes, Journal, Covenant Path, Prompt D2, manual Goal dates, bottom-nav
replacement, database redesign, or VS-09 work.

## Git state

- No commits created; nothing pushed (owner authorization required).
- `.todo.md` untouched (SHA-256 `4db71845c08fe8b4761f32948a6563c7561ecbf07e3aa0b8aaec9e7d8a59e2b7`).
- External safety patch: `%TEMP%\next-transfer-before-pack2-combined-run.patch`.

## Unresolved / notes

- `/privacy` is a top-level route; a direct `go('/privacy')` would dead-end on
  Back (out of Pack 2 scope — the Pack 3 drawer owns that entry point).
- Process restoration: the app restores its last route after unlock; if that
  route is a top-level page (e.g. an event detail) the shell's root-back policy
  does not apply to it (it pops on the root navigator).

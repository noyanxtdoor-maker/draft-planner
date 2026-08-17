# Pack 1A Final Correction — Completion Report

## 1. PREFLIGHT

- Repository: `C:\Users\sherl\Documents\Next Transfer-Temp` (writable)
- Branch: `temp/vs08-shared-preview`
- HEAD: `03bbce5` (unchanged; no commits made)
- Status: 48 modified files + 9 new untracked source/test files; nothing staged; nothing committed; nothing pushed
- Safety patch: `/tmp/next-transfer-pack1a-before-final-correction.patch` (written before editing, read-only)
- `.todo.md` SHA-256: `4db71845c08fe8b4761f32948a6563c7561ecbf07e3aa0b8aaec9e7d8a59e2b7` (preserved)
- Protected original: untouched; `codex/vs-08-weekly-planning-lifecycle` branch and PR #8 not modified
- Blocking questions: **none.** All scope items resolved against repository evidence and approved defaults.

## 2. REPOSITORY FINDINGS

- **Goal 1 / Goal 6 widgets**: Home renders Goal cards through a shared outer structural component (`FeaturedGoalCard` in `home_screen.dart`); Goal 6 geometry is the source of truth and Goal 1 derives from it.
- **Management-mode state**: held in the weekly planning screen state only (never persisted to DB/preferences); exits only on X Cancel, leaving Planning, or app restart.
- **Goal menu / archive rows**: normal three-dot menu (Edit/Archive/Delete) and archive rows (Restore/Trash) built in `goal_archive_screen.dart` and `weekly_planning_screen.dart`.
- **Deletion model**: tombstone — `deletedAtUtc` column + `GoalStatus.deleted`; hidden from active/archive queries; not restorable; slot freed; historical records preserved under the original Goal identity; bootstrap never resurrects deleted Goals; backup/restore lets deletion win.
- **Color source of truth**: single canonical `EventType.colorValue`/preference path via the Event Type repository/controller; Event Colors Settings and Edit Event Type share the same read/write path.
- **Existing color inventory**: collected from system Event Type seeds, the retired bright quick-preset list, Contact Group defaults, and PMG-derived planner color defaults (49 normalized entries, listed below).
- **Create Goal slot allocator**: single canonical `_freeSlotOrNull` in `drift_goal_repository.dart`; `nextAvailableSlot` preview and `createGoal(expectedSlotIndex)` validation use the same function, so the previewed slot always matches the saved slot or creation is rejected.
- **Draft state**: preserved across child navigation (no re-mount resets).

## 3. IMPLEMENTATION SUMMARY

Every authorized requirement completed:

| Requirement | Implementation |
|---|---|
| Home Goal 1 shares Goal 6 geometry | Shared featured card component; same outer height/padding/border/radius, icon size, title & secondary typography, right-inset top/bottom margins; only Today's Goal inset width differs (holds target/+/−). |
| Compact Today's Goal inset | Single shaded inner surface, label upper-left, target/−/+ in one lower row; 48×48 dp tap targets via `OverflowBox` with ~22 dp visible icons (no visual inflation); overflow fixed at 200% text scale. |
| Compact Planning button | 118–134 dp visual width, 34–38 dp visual height, 14 sp label, 1 dp neutral border, radius ~18–20 dp, transparent; 48 dp hit target; no pink accents. |
| Major separator breathing room | Monthly Goal card → 14–18 dp → Planning → 20–24 dp → single neutral separator → Active Pathways. |
| Manage Goals beside Create Goal | Persistent neutral secondary button; same canonical manage-mode state as the limit-dialog entry. |
| Normal menu Delete | Edit/Archive/Delete in every active Goal's menu; destructive styling; confirmation before mutation. |
| Manage Goals persistent mode | X Cancel replaces top actions; per-Goal Archive + Trash; remains in mode after archive/delete/cancel; honest empty state; exits only on X/leaving/restart. |
| Safe permanent deletion | Tombstone semantics; active and archived Goals deletable; hidden from active/archive; not restorable; slot freed; fixed Event Type survives; replacement inherits no title/icon/targets/history; old history stays under old identity. |
| Task/Event contribution while slot empty | Existing engine already skips when no active compatible Goal exists (no orphan rows); new Task completing after replacement contributes exactly once under the new identity. |
| Goal Archive Trash | Trash action per archived row with confirmation, immediate removal, no restore-after-delete, no effect on active replacement or Event Type. |
| One canonical Event Type color | Single color path shared by Settings and Edit Event Type; Planner/picker/Goal forms refresh without restart. |
| 15 muted recommended colors | New palette (below), verified against the full inventory with OKLab: no exact duplicates, no near duplicates (min distance 0.0613 to inventory, 0.0618 pairwise), all within saturation 22–48% and lightness 48–68%. |
| Custom hex | Six-digit RGB with or without `#`, normalized uppercase on save; live preview; malformed/alpha/8-digit rejection; poor-contrast and excessive-brightness warnings; no silent mutation. |
| Recommended Colors action in Settings | Icon-button (auto_awesome) beside the palette action, 48×48 tap, tooltip + semantics "Next Transfer Recommended Colors". |
| Shared color UI in Edit Event Type | Replaces the retired bright 8-color list with Color Palette / NT Recommended Colors / Custom Hex panel; fixed-assignment context preserved. |
| Assigned Event Type in Create Goal | Exact future-slot Event Type resolved from `nextAvailableSlot`; shown with its current color; no Change Link/Unlink. |
| Create Goal draft preservation | Drafts survive navigating into Edit Event Type and back. |

## 4. SCHEMA / MIGRATION

- Old schema version: 19 → New: **20**
- v20 migration: adds `goals.deleted_at_utc` (tombstone). No destructive change; existing active/archived Goals untouched; no historical record removed.
- Fresh install: full schema at v20. Upgrade: additive column only.
- Backup/export/restore: `deletedAtUtc`/status serialized; import refuses to resurrect a Goal deleted after a snapshot (deletion wins); verified by test.
- Sync/outbox: delete writes a `deleted` outbox operation; tombstone state is idempotent.

## 5. COLOR PALETTE

**Existing inventory (normalized #RRGGBB)** — 49 entries:
Seeds: `#E91E63` `#868A8D` `#EBC766` `#DE9EDA` `#E27386` `#A272C8` `#DEEDF2` `#B39DDB` `#7CB342` `#FF7043` `#42A5F5` `#AB47BC` `#EC407A` `#76B181` `#26A69A` `#78909C` `#ECC7D8` `#E1CFB9` `#FFA726` (19)
Retired quick presets: `#E91E63` `#B39DDB` `#7CB342` `#FF7043` `#42A5F5` `#AB47BC` `#26A69A` `#FFA726` (8)
Contact groups: `#EBC766` `#7FB7D1` `#D35A70` `#969B9E` (4)
PMG defaults: `#EBC766` `#DE9EDA` `#D9A35F` `#DEEDF2` `#DEEDF2` `#868A8D` `#E27386` `#A272C8` `#B884D1` `#D4B27C` `#6EAAA8` `#76B181` `#98CED8` `#ECC7D8` `#E1CFB9` `#F2E9E0` `#EAA15D` (18)

**Final 15 Next Transfer Recommended Colors** (each checked against all 49 inventory entries and the other 14; min OKLab distance 0.0613 to inventory, 0.0618 pairwise, threshold 0.05):

| Name | Hex |
|---|---|
| Muted Rose | `#BB7772` |
| Dusty Mauve | `#A15E79` |
| Soft Lilac | `#5946B9` |
| Slate Blue | `#676DA2` |
| Dusty Cyan | `#4C8CBD` |
| Sea Teal | `#66C7B3` |
| Sage Green | `#86CC7B` |
| Olive | `#A7B587` |
| Warm Amber | `#A5975F` |
| Sand | `#9F8060` |
| Caramel | `#CB8C72` |
| Coral | `#B66249` |
| Ash Blue | `#888AC3` |
| Heather | `#A062A3` |
| Dusty Plum | `#AE7AA0` |

**Near-duplicate proof**: automated — `recommended_event_colors_test.dart` rejects any exact duplicate and any pair with OKLab ΔE < 0.05, and additionally enforces a 0.055 healthy margin vs the full inventory and pairwise. The original draft palette failed these checks (e.g. Ash Blue `#7E92A0` ≈ Work seed `#78909C` at ΔE 0.011); the shipped values were selected by a deterministic HSL/OKLab search to clear them.

**Note on `isNearDuplicate` threshold**: corrected from `6.0` to `0.05` — raw OKLab distances max out around 1.5 (the 6.0 value was CIELAB-scale thinking and would flag every color as a near-duplicate).

## 6. CHANGED FILES

Production:
- `lib/features/startup/presentation/home_screen.dart` — shared featured Goal card + compact Today's Goal inset (Flexible text, OverflowBox tap targets, no overflow).
- `lib/features/weekly_planning/presentation/weekly_planning_screen.dart` — compact Planning button, separator rhythm, persistent Manage Goals button, manage-mode UI (X Cancel / Archive / Trash), scale-safe `_ScaledGoalActionButton`.
- `lib/features/goals/presentation/goal_archive_screen.dart` — Trash action on archived rows with confirmation.
- `lib/features/goals/presentation/goal_create_screen.dart` — assigned Event Type preview + draft preservation.
- `lib/features/goals/presentation/goal_edit_screen.dart` — passes initial Goal for draft restoration.
- `lib/features/goals/data/drift_goal_repository.dart` — tombstone delete, exact slot allocator, backup import deletion-wins.
- `lib/features/goals/domain/goal.dart` — `deleted` status + `deletedAtUtc`.
- `lib/features/goals/application/goal_repository.dart` — delete contract.
- `lib/core/database/app_database.dart` — schema v20 `deleted_at_utc` migration (plus v19 columns from prior pack).
- `lib/features/planner/domain/recommended_event_colors.dart` — 15 verified muted colors.
- `lib/features/planner/domain/event_color_math.dart` — OKLab/HSL/contrast/hex helpers; corrected near-duplicate threshold.
- `lib/features/planner/presentation/widgets/event_color_picker_components.dart` — shared Recommended Colors dialog + custom hex dialog + panel actions.
- `lib/features/settings/presentation/planner_event_colors_screen.dart` — Recommended Colors action beside palette; wider controls.
- `lib/features/planner/presentation/event_type_form_screen.dart` — shared color panel replaces bright list; fixed-assignment context.
- `lib/features/planner/presentation/event_type_picker_dialog.dart`, `lib/features/planner/data/drift_event_type_repository.dart`, `lib/features/planner/application/planner_providers.dart`, `lib/features/planner/application/planner_repository.dart`, `lib/features/planner/data/drift_outcome_reporting_repository.dart`, `lib/features/planner/data/drift_planner_repository.dart`, `lib/features/planner/domain/event_color_preferences.dart`, `lib/features/planner/domain/event_type.dart`, `lib/features/planner/domain/planner_task.dart`, `lib/features/planner/presentation/task_form_screen.dart` — v19 linking/color plumbing carried forward.
- `lib/app/router/app_router.dart`, `lib/app/shell/main_shell.dart`, `lib/features/goals/domain/canonical_goal_slots.dart`, `lib/features/planner/data/task_goal_contribution_engine.dart` — routing/shared-slot/contribution support.
- `lib/core/database/app_database.g.dart` — regenerated drift code for v19/v20 columns.

Tests:
- `test/core/database/migration_rollback_test.dart` — v20 assertions.
- `test/features/privacy/data/drift_privacy_repository_test.dart` — user_version 20.
- `test/features/goals/data/drift_goal_repository_test.dart` — delete lifecycle, exact slot allocation, stale-preview rejection, backup deletion-wins.
- `test/features/goals/data/goal_planner_backup_test.dart` — planner backup round-trip; empty-slot no-orphan + replacement contribution.
- `test/features/planner/domain/recommended_event_colors_test.dart` — 15 colors, muted/readable, no exact/near duplicates vs full inventory + pairwise, margin enforcement.
- `test/features/planner/domain/event_color_math_test.dart` — hex parse/normalize, HSL, OKLab, contrast/brightness.
- `test/features/indicators/presentation/home_indicator_journey_test.dart`, `test/features/weekly_planning/presentation/weekly_planning_journey_test.dart`, `test/features/settings/presentation/planner_event_colors_test.dart`, `test/features/planner/data/drift_event_type_repository_test.dart`, `test/features/goals/presentation/goal_icon_lifecycle_journey_test.dart`, `test/features/planner/presentation/planner_experience_refinement_test.dart` — updated to new spec/geometry.
- Goldens `test/features/startup/presentation/goldens/goldens/home_pack1/*.png` — regenerated for the new Home/planning visuals.

## 7. TESTS

- Full suite: `flutter test` → **507 passed, 0 failed** (`+507: All tests passed!`), exit 0.
- Focused color tests: 20/20 pass. Goal repo tests: 13/13 pass. Backup + empty-slot tests: pass.
- Analyzer: `flutter analyze --no-pub` → **No issues found!** (exit 0).

## 8. BUILD

- Command: `flutter build apk --debug` (with `ANDROID_SDK_ROOT`/`ANDROID_HOME` pointing at the toolchain SDK)
- Result: `√ Built build\app\outputs\flutter-apk\app-debug.apk` (exit 0)
- Path: `build\app\outputs\flutter-apk\app-debug.apk`
- Size: 197,094,142 bytes (~188 MB)
- Timestamp: 2026-08-05 13:06
- SHA-256: `e64861d62137cfdf91b17a79796a659e278bdf7ea47ca45aa9c44a55b0cd21b2`

## 9. INSTALLATION

- Device: Infinix X6731, Android 14, serial `adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp`
- Pre-install package: versionName 0.1.0, versionCode 1, firstInstallTime 2026-07-27 15:42:22, lastUpdateTime 2026-08-05 09:22:20
- Command: `adb -s <serial> install -r build\app\outputs\flutter-apk\app-debug.apk`
- Result: `Performing Streamed Install` → `Success`
- Post-install: versionName 0.1.0, versionCode 1, **firstInstallTime unchanged** (data preserved), lastUpdateTime 2026-08-05 13:07:15
- Data preservation: `app_flutter/next_transfer.sqlite` present (516,096 bytes), SQLite header intact, on-device schema version **20** confirmed from the DB header (bytes `00 00 00 14` at offset 60)
- Installed APK hash: `e64861d6...cd21b2` — **matches local build exactly**
- No uninstall, no `pm clear`, no data reset.

## 10. PHYSICAL ACCEPTANCE

Automated-verified on device:
- App launches; `topResumedActivity` = `com.nexttransfer.rmplanner/.MainActivity`; process stable (PID alive).
- No `FATAL`, `AndroidRuntime` exception, or `E/flutter` in logcat.
- Schema v20 migration applied to the existing database without data loss.
- Screenshots captured: `docs/handoffs/_screenshots/pack1a_final_01_launch_home.png`, `pack1a_final_02_home_loaded.png`.

Not verified by automation (requires owner hands-on tap-through, using disposable test Goals):
- Interactive menu/manage-mode/delete-confirmation flows (items 1–34 of the acceptance checklist), the Settings recommended-colors modal, and Edit Event Type custom-hex flows (items 35–58).
- Reason: this Flutter build renders without exposing widget semantics to `uiautomator`, and destructive UI flows must not run against real device data without owner approval. Widget/golden tests cover the same behaviors pixel-level.

## 11. REPOSITORY SAFETY

- Protected repository/branch/PR #8: untouched.
- `.todo.md`: unmodified, unstaged, hash preserved.
- Nothing staged, nothing committed, nothing pushed; HEAD still `03bbce5`.
- VS-09, Pack 2, Pack 3, Prompt D2, manual Goal dates, remote Messages: not started.

## 12. LIMITATIONS

- Interactive on-device acceptance checklist (tap-through) remains for owner hands-on verification with disposable data; everything verifiable via adb/DB/build was verified.
- No manual color-distance dependency added (pure Dart OKLab helper used, per scope).

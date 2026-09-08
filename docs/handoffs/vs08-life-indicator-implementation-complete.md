# VS-08 Life Indicator Unification — Implementation Complete

Date: Aug 7, 2026 · Branch: temp/vs08-shared-preview

## 1. PREFLIGHT
- Writable repo: `C:\Users\sherl\Documents\Next Transfer-Temp` (verified)
- Branch: `temp/vs08-shared-preview`
- `.todo.md` hash: `4db71845c08fe8b4` (unchanged throughout)
- Protected repo `Next Transfer`, branch `codex/vs-08-weekly-planning-lifecycle`, PR #8: untouched
- No commit/push performed (owner authorization required)

## 2. CANONICAL DATA MODEL (no schema change)
The existing **Goal** entity is the canonical Life Indicator:
- stable immutable `id` (e.g. `life_indicator_scripture_study` style stable keys)
- mutable `title` (display name), `iconId` (SVG reference), status (active/archived/deleted)
- Events persist the canonical link via `calendar_events.goal_id` + derived `contributionRuleKey`
- Audit confirmed **no separate legacy WLI Event column** — the old "Weekly Life Indicator" UI rode the same `goalId`/`contributionRuleKey` persistence path, and legacy WLI target revisions were already migrated to Goals in the DB layer. One authoritative Event→Life Indicator relationship at runtime.

## 3. IMPLEMENTATION

### Unified Event form section (`calendar_event_form_screen.dart`)
- Removed the old "Link to Weekly Life Indicator" section + picker and the separate "Goal" section.
- Added single `Life Indicator` section (`_buildLifeIndicatorSection`, key `event-life-indicator-section`):
  - **Unlinked:** row shows "Life Indicator" / "No Life Indicator linked" with chevron; below it "Reporting & progress context" / "Optional — Report Required" toggle editable (matches approved `1499edb8`).
  - **Linked:** row shows SVG icon + indicator name / "Linked to this Event"; Report Required label, helper "Required because this Event is linked to a Life Indicator.", toggle locked.
  - **Fixed Event Type:** "Linked automatically by Event Type", picker read-only.
- Linked indicator resolved by stable ID with fallback to `goalByIdProvider` so **archived-linked Events still render name/icon** while archived indicators stay hidden from new linking.

### Selector modal (`_chooseLifeIndicator`)
- `Link to Life Indicator` + "Choose the progress area this Event should contribute to."
- Lists only active indicators with real SVG icons (`GoalIcon`), selected row gets rose border + tint + checkmark (not color-only).
- Footer: "Remove Life Indicator link" (only when linked) + Cancel.
- Selecting returns the goal id; form commits it; Report Required auto-ON.

### Report Required invariant
- Form `_save()`: `_selectedGoalId != null` ⇒ `_requiresReport = true` and `_linkedIndicatorKey = linkedGoal.indicatorKey` (contribution rule follows the Goal). The Goal is resolved by stable ID with an archived-safe fallback (`goalByIdProvider`) so an Event linked to an archived indicator still derives the correct contribution rule (reviewer-driven fix).
- Repository (`drift_calendar_event_repository.dart`): normalizes `requiresReport = true` whenever `goalId != null` in both the event and exception writes; invalid state can never persist.
- Unlink keeps Report Required ON but unlocks the toggle (spec-compliant).

### Management (already existing, verified)
- Edit Name / Replace Icon / Archive / Restore all exist via `goal_edit_screen.dart` (title field, icon picker), `goal_archive_screen.dart` (restore), weekly planning management mode. Stable IDs preserved; archive keeps Event links + history; `restoreGoal` validates fixed Event Type slot occupancy. Archive of a fixed-type indicator is the established replacement-pilot path (replacement inherits the slot's Event Type), so no silent breakage occurs.

## 4. CHANGED FILES
| File | Reason |
|---|---|
| `lib/features/planner/presentation/calendar_event_form_screen.dart` | Unified Life Indicator section; removed WLI + Goal UI; selector; invariant in save |
| `lib/features/planner/presentation/calendar_event_detail_screen.dart` | "Weekly Life Indicator" → "Life Indicator" label |
| `lib/features/planner/data/drift_calendar_event_repository.dart` | Repository-level reportRequired normalization |
| `lib/features/goals/application/goal_providers.dart` | Added `goalByIdProvider` for archived-linked display |
| `test/features/planner/presentation/calendar_event_indicator_link_test.dart` | Rewritten for unified Life Indicator flow + invariant |
| `test/features/planner/presentation/event_type_first_creation_test.dart` | Updated keys/labels for unified flow |

## 5. TESTS (all passed)
- `calendar_event_indicator_link_test.dart` — unified link reversible, forces Report Required, persists only on Save ✅
- `event_type_first_creation_test.dart` (4) ✅
- `calendar_event_journey_test.dart` ✅
- `drift_goal_repository_test.dart` (13) ✅
- `goal_icon_persistence_test.dart` + `goal_icon_lifecycle_journey_test.dart` ✅
- `weekly_planning_journey_test.dart` (3) ✅
- `flutter analyze` on all changed files: No issues ✅
- `dart format` applied (3 files reformatted) ✅
- `git diff --check`: clean (CRLF warnings only) ✅

## 6. BUILD & INSTALL
- `flutter build apk --debug` → `build\app\outputs\flutter-apk\app-debug.apk` (170,106,770 bytes, 13:24) ✅
- `adb install -r` on Infinix X6731 (Android 14): **Success**, data preserved ✅
- Cold launch: Home renders, no crash ✅

## 7. PHYSICAL VERIFICATION (Infinix X6731)
Evidence saved in `docs/handoffs/`:
- `life-indicator-linked-state-ministering.png` — **PASS**: "Ministering Visit / Linked automatically by Event Type" + Report Required ON + helper
- `life-indicator-unlinked-state.png` — **PASS**: "Life Indicator / No Life Indicator linked" + "Optional - Report Required" OFF (matches approved screenshot)
- `life-indicator-selector-modal.png` — **PASS**: 6 active indicators (Job Applications…Temple Visit) + Cancel
- `life-indicator-linked-state-job-applications.png` — **PASS**: selecting an indicator → "Job Applications / Linked to this Event" + "Report Required" + helper + locked gray switch

## 8. FINAL BUILD (post-review fix)
- Rebuilt `app-debug.apk` (13:51, 170,106,770 bytes) after the save-path archived-indicator fix; `adb install -r` Success; cold launch clean, data preserved, no fatal logs.

## 9. REMAINING / LIMITATIONS
- Physical check of Edit Name / Replace Icon / Archive flows not re-tapped on-device this session (management screens pre-existed and their repository/presentation tests pass; entry via Home goal cards / weekly planning management mode).
- Legacy conflict case (Event with both old WLI and new link to DIFFERENT indicators) not encountered in the migrated data — audit showed single-path persistence, so no guess-based merge is needed; if such a row appears, repository keeps both until a product decision.

## 10. REPOSITORY SAFETY
- Protected repo/branch/PR untouched; `.todo.md` untouched (`4db71845c08fe8b4`); no commits made.

## NEXT ACTION
Owner physical acceptance: tap Edit Name / Replace Icon / Archive on a Life Indicator and confirm selector/form updates reactively, then confirm final acceptance.

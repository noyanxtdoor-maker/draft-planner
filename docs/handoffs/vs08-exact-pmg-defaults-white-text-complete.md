# Exact PMG Event-Type Defaults + White Event Text — Implementation Complete

Date: 2026-08-07
Branch: `temp/vs08-shared-preview`  (writable repo: `Next Transfer-Temp`)
Protected repo / branch / PR untouched. `.todo.md` hash unchanged (`4db71845c08fe8b4`).

## 1. Changed files

| File | Reason |
|---|---|
| `lib/features/planner/domain/event_color_preferences.dart` | All 13 mapped default Accent+Surface pairs replaced with the locked exact PMG values; exposed `pmgStableKeyDefaults` (stable-key → locked pair, incl. the previously-missing `other` entry); label-map defaults updated to the same pairs; Ministering Visit + Budget Review constants untouched. |
| `lib/features/planner/data/drift_event_type_repository.dart` | Fresh-install seeds (`_systemSeeds`) recolor the 13 mapped types; `_reconcileLightMutedSurfaces` now skips any surface that already equals its locked default (the exact PMG surfaces are deliberately not derivation-consistent and must never be re-derived); `_LegacySavedAccentMigration` gained an explicit `nextSurfaceArgb`; `_legacySavedAccentMigrations` retargeted to the new accents with exact surfaces and gained `contact/meeting/study_or_plan/service/work/travel/meal/other` keys; `_lockedWliLegacySeedColors` hops retargeted + final hop added for the previous approved defaults. |
| `lib/features/planner/presentation/widgets/planner_event_block_layout_policy.dart` | `PlannerEventBlockColorPolicy.textColor` is now hard-locked to white/near-white for every surface — the luminance-based dark-text switch is gone. |
| `test/features/planner/domain/event_color_preferences_test.dart` | Updated Teaching/Sacrament expectations; added an exact locked-pair table for all 13 mapped types + unchanged Ministering/Budget. |
| `test/features/planner/presentation/planner_event_color_policy_test.dart` | Bright-surface case now asserts white text. |
| `test/features/planner/data/drift_event_type_repository_test.dart` | Updated seed/migration expectations; added: pre-delta pair → exact locked pair convergence (all 12), exact-surface idempotency (no re-write on second read), Ministering/Budget unchanged. |
| `test/features/planner/domain/recommended_event_colors_test.dart` | Comments only — documented that the inventory is a historical pre-delta snapshot; Recommended Colors palette itself untouched. |

## 2. Default color changes (old → new)

| Event Type | Old Accent/Surface | New Accent / Surface |
|---|---|---|
| Job | #B98CA8 / #877580 | **#EBC766 / #4C4942** (PMG Teaching) |
| Scripture Study | #C27E6E / #866F69 | **#DE9EDA / #4C464A** (PMG Finding) |
| Exercise | #90AE79 / #747E6C | **#EAA15D / #474141** (PMG Sacrament) |
| Temple Visit | #77ADA9 / #6B7D7B | **#98CED8 / #454B4B** (PMG Baptism) |
| Contact | #74C385 / #6C8871 | **#76B181 / #494E48** |
| Meeting | #F07175 / #9E6264 | **#E27386 / #463D40** |
| Study or Plan | #A474DC / #7E6996 | **#A272C8 / #47444B** |
| Service | #D3EEF8 / #648C9B | **#DEEDF2 / #404447** |
| Work | #CFE3EC / #708590 | **#DEEDF2 / #404447** |
| Travel | #ECAEC6 / #97687B | **#ECC7D8 / #4F4D4E** |
| Meal | #EAD5B8 / #94836B | **#E1CFB9 / #4B4744** |
| Other | #8E9599 / #70777A | **#868A8D / #494949** |
| Task | #F4EAD9 / #94856B | **#F2E9E0 / #494844** |
| Ministering Visit | #B0A971 / #7D7B6A | unchanged (per delta) |
| Budget Review | #BFA384 / #8A7E72 | unchanged (per delta) |

## 3. Migration

- Untouched defaults are identified by exact value: a saved preference whose ACCENT matches a recognized legacy default (original bright seeds, dark-muted Slate Blue family, light-muted recommended family, device-era values, and the previous approved defaults) is remapped to the new locked pair; the explicit surface is written verbatim via `nextSurfaceArgb`. Any other accent is a genuine user choice and is preserved.
- `color_value` seeds follow the same exact-value hop chain (idempotent: a migrated row no longer matches any hop).
- `_reconcileLightMutedSurfaces` skips surfaces already equal to a locked default, so the explicit PMG surfaces are never re-derived and the document is not rewritten on subsequent reads (proved by test).
- Idempotency verified by the new convergence/idempotency tests (persisted JSON byte-identical across reads).

Known limitation (pre-existing, unchanged by this delta): the legacy surface repair already treated any surface that is not the accent derivation as stale; a user who customized only the surface while keeping a legacy default accent would have had that surface healed by the pre-existing pipeline. This is documented, not a regression.

## 4. White text fix

- Render path changed: `PlannerEventBlockColorPolicy.textColor()` (used by `PlannerEventBlockContentView` title/time and the Colors preview) now always returns white. No luminance-based black switch remains anywhere for Planner Event title/time.

## 5. Tests

- `flutter analyze` on all changed files: **No issues found**.
- Focused + regression (event_color_preferences, color_policy, drift_event_type_repository 16/16, settings colors route, planner_correction_pack, backup_event_accent goldens, recommended_event_colors, full goals suite, event_type_first_creation): **all pass** (goldens unchanged).
- `dart format` clean; `git diff --check` clean.

## 6. Build / install

- APK: `build/app/outputs/flutter-apk/app-debug.apk`, 170,106,770 bytes, SHA-256 prefix `ff25787c0c8175b1`, built 15:11.
- `adb install -r` → **Success**, app data preserved.
- Cold launch clean; no fatal logs.

## 7. Physical acceptance (Infinix X6731)

- **Selector swatches** (measured on-device): Job #E8C060≈#EBC766, Scripture #D898D8≈#DE9EDA, Exercise #E8A058≈#EAA15D, Budget #B8A080≈#BFA384 (unchanged), Ministering #B0A870≈#B0A971 (unchanged), Temple #98C8D8≈#98CED8, Contact #70B080≈#76B181 — all match (within 8-level quantization/antialiasing). Evidence: `docs/handoffs/exact-defaults-picker-swatches.png`.
- **Planner surfaces** (pixel scan of the whole timeline): Temple #454B4B (184k px), Scripture #4C464A (81k), Exercise #474141 (48k), Service/Work #404447 (28k), Travel #4F4D4E, Job #4C4942, Contact #494E48, Study #47444B — the exact locked surfaces render verbatim; no derivation transform. Evidence: `docs/handoffs/exact-defaults-planner-surfaces.png`.
- **White text**: Work + Meeting block glyphs measure #F0F0F0 (near-white); no black text anywhere.
- Ministering/Budget unchanged on-device; user data preserved through `install -r`.

Not declared as owner acceptance — only the owner approves the final result.

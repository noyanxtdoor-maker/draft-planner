# VS-08 Pack 1A — Luna implementation handoff

Date: 2026-08-04
Workspace: `C:\Users\sherl\Documents\Next Transfer-Temp`
Scope: VS-08 Pre-D2 Correction Pack 1 / Pack 1A only

## Boundary and change control

Pack 1A was implemented in the Temp repository only. The protected repository at
`C:\Users\sherl\Documents\Next Transfer` was not modified. No push was performed,
PR #8 was not updated, VS-09 was not started, and no Pack 2, Pack 3, D2, drawer,
Settings, or global-navigation work was started.

All existing accepted Prompt A, Prompt B, Prompt C, D1, Planner, reporting,
Colors, Contact, Pathway, and Backup Event behavior was kept in the same
canonical repositories and database. The implementation does not add a second
Contacts, Tasks, Events, Goals, or reporting architecture.

## Root-cause audit

The Home defects were traced to the presentation layer selecting the original
seeded/default WLI records instead of the current canonical Goal role slots.
The corrected path is:

`canonical Goal repository → GoalPlanningSnapshot → Home WLI cards`

Home no longer decides which cards to display from default Goal IDs, default
titles, seeded flags, or a stale indicator snapshot. The snapshot resolves the
active daily slot, the four weekly slots, and the monthly slot by canonical Goal
role/slot data. This means a newly created replacement Goal is rendered in its
slot after the previous Goal is archived, without any title-based special case.

The daily quick control was audited separately. It changes only the canonical
daily target for the selected Goal, with a serialized per-Goal write queue. It
does not write actual progress, outcomes, contributions, task links, reporting
rows, activity history, or duplicate outbox operations.

The management flow was also audited. The Goal-limit dialog owns its Cancel
action locally. Manage Goals enters Weekly Planning management mode. The direct
Archive action is present only in that mode; Edit Goal and Archive Goal remain
available from the existing three-dot menu. No navigation action performs a
domain mutation.

## Requirement matrix

| Pack 1A requirement | Implementation/evidence | Status |
| --- | --- | --- |
| Remove Home dependence on original/default Goal identities, titles, seeded flags, and stale snapshots | `lib/features/indicators/application/indicator_providers.dart`, `lib/features/startup/presentation/home_screen.dart`, `lib/features/goals/application/goal_repository.dart`; canonical role-slot snapshot tests | PASS |
| Render the currently active daily, four weekly, and monthly canonical Goals | `_CanonicalIndicatorGrid` consumes `GoalPlanningSnapshot`; six role-slot journeys cover active replacement data | PASS |
| Show six newly created replacement Goals on Home | Canonical Home/WLI journey creates/replaces role occupants and asserts titles, ratios, icons, and month card | PASS |
| Goal-limit Cancel closes only the limit dialog | `test/features/weekly_planning/presentation/weekly_planning_journey_test.dart`; Cancel leaves the underlying route/mode unchanged | PASS |
| Manage Goals opens/activates Weekly Planning management mode | `weekly-plan-management-mode` and management-mode journey assertions | PASS |
| Show direct Archive beside the three-dot menu only in management mode | `weekly-plan-goal-direct-archive-*`; normal mode hides it and management mode shows it | PASS |
| Preserve Edit Goal and Archive Goal in the three-dot menu | Existing popup actions remain in `weekly_planning_screen.dart`; journey covers both paths | PASS |
| Derive month labels from the current local date and locale | `lib/features/startup/presentation/home_screen.dart` uses `MaterialLocalizations`/local period data for `August Goal` and future labels | PASS |
| Add compact Daily target quick-control | `_WideAside`, `home-daily-target-quick-control`, minus and plus controls in `home_screen.dart` | PASS |
| Prove target changes do not increment actual progress or create outcomes/contributions | `test/features/indicators/presentation/home_indicator_journey_test.dart`; rapid target updates are serialized and ledger/contribution/outcome counts remain unchanged | PASS |
| Make Weekly Planning a neutral outlined secondary action | `weekly-targets-button` uses the compact neutral outlined style and keeps the route unchanged until activation | PASS |
| Add the neutral major separator between WLI and Active Pathways | `_MajorSectionSeparator` and `home-major-separator` use the full-width neutral separator | PASS |
| Preserve accepted Planner, reporting, colors, Contacts, Pathways, event-type snapshots, and Backup Event behavior | Full regression suite plus focused Planner, reporting, Goal, startup, migration, and Backup Event suites | PASS |
| Maintain requirement matrix, root-cause audit, tests, goldens, analyzer, device verification, install, and hash comparison | Evidence below | PASS |

## Automated verification

Completed on the Temp checkout:

- Canonical Goal migration/snapshot suite: 29 passed.
- Pack-focused matrix covering Home/WLI, goal lifecycle/icons, Weekly Planning,
  Planner, Event Type relationships/snapshots, Tasks, contributions/reporting,
  date-picker transitions, startup, and Backup Event accent: 118 passed.
- Full Flutter suite: 477 passed, 0 failed, 0 skipped.
- Flutter goldens passed, including the Pack 1 Home goldens and existing startup
  and Home goldens.
- `flutter analyze`: `No issues found!`.
- `git diff --check`: no whitespace errors.

The full suite emitted one non-failing Drift debug warning from the icon
persistence test about creating multiple `AppDatabase` instances with the same
QueryExecutor. It did not fail a test or analyzer check and is not part of the
production data path.

## Build, install, and physical evidence

Debug APK:

- Artifact: `build/app/outputs/flutter-apk/app-debug.apk`
- Size: 196,944,755 bytes
- SHA-256: `98C955BDE8711DAF754610AAA56FF47EE188E894F6AEE2E7A962AB3BA1F26EC0`

The APK was installed on the authorized Infinix X6731 (`com.nexttransfer.rmplanner`)
with update-in-place installation. Before and after installation:

- `firstInstallTime`: `2026-07-27 15:42:22` (unchanged)
- `dataDir`: `/data/user/0/com.nexttransfer.rmplanner` (unchanged)
- `ceDataInode`: `1509267` (unchanged)
- Installed APK SHA-256 matched the local APK exactly.

The app was force-stopped and relaunched successfully. The captured physical
Home screen shows the canonical WLI cards, daily minus/plus control, Temple Visit
next-visit/month card, neutral Planning action, full-width major separator,
Active Pathways, and preserved bottom navigation:

[Physical Infinix Pack 1A relaunch capture](../../artifacts/pack1a-physical-relaunch.png)

The compact layout uses bounded text and ellipsis where the physical viewport
cannot fit a long label; the captured viewport has no RenderFlex overflow or
Home/WLI overflow marker. The full target-control hit areas remain accessible.

## Protected-boundary evidence

The protected original repository was checked after implementation and remains
outside this change set. Its only observed status item is the pre-existing
untracked `Icons/` directory; it was not created, edited, staged, or removed by
Pack 1A. No remote operation was run.

## Handoff result

Pack 1A is implemented and verified in `Next Transfer-Temp`. The workspace is
ready for owner review at the requested boundary. Future work must remain
outside this handoff until explicitly authorized; in particular, do not begin
Correction Pack 2 or 3, Prompt D2, or VS-09 as part of this result.

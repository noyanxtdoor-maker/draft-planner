# VS-08 PMG and BetterCalendar Reference Review

**Review date:** 2026-07-29
**Repository:** `C:\Users\sherl\Documents\Next Transfer`
**Branch:** `codex/vs-08-weekly-planning-lifecycle`
**Starting commit:** `4a279bd2dc8947a66a16856b33f34e870a88a403`
**Authorized scope:** the confirmed VS-08 event-type-first, one-tap, and
drag/resize correction; VS-09 and later remain unauthorized.

## 1. Repository and slice status

VS-08 Weekly Planning, the first Planner correction, and their automated and
Android CI evidence are already present. The current implementation still
starts Calendar Event creation with the complete form, requires an empty-grid
long press, and exposes Event Type as a form dropdown. This review authorizes a
surgical interaction correction without changing the existing Drift schema,
Task/Event separation, reporting, Activity Ledger, Actual calculations, or
later-slice feature boundaries.

The repository has no `Pathways` or `Contacts` feature module or route.
Consequently, this correction will provide a reusable creation coordinator for
future entry points but will not build those later-slice screens. The locked
Planner quick-create requirement is preserved: the floating `+` continues to
offer separate Task, Calendar Event, and Activity Report actions; selecting
Calendar Event then opens `Select Event Type` before the form.

## 2. Exact reference files found

Approved visual references:

- `UI Preferences/home-approved-reference.png`
- `UI Preferences/planner-approved-reference.png`
- `UI Preferences/pathways-approved-reference.png`
- `UI Preferences/contacts-approved-reference.png`
- `UI Preferences/more-approved-reference.png`

Matching measurement references:

- `UI Preferences/stitch_next_transfer/home_recreated/code.html`
- `UI Preferences/stitch_next_transfer/planner_recreated/code.html`
- `UI Preferences/stitch_next_transfer/pathways_recreated/code.html`
- `UI Preferences/stitch_next_transfer/contacts_recreated/code.html`
- `UI Preferences/stitch_next_transfer/more_recreated/code.html`

PMG references:

- `UI Preferences/PMG References/pmg-another-workflow.mp4`
- `UI Preferences/PMG References/pmg-event-picker-first.mp4`
- `UI Preferences/PMG References/pmg-select-event-type-first-workflow.mp4`
- `UI Preferences/PMG References/pmg-settings-workflow.mp4`
- `UI Preferences/PMG References/pmg-weekly-planning-workflow.mp4`
- `UI Preferences/PMG References/pm-whole-review-workflow.mp4`
- `UI Preferences/PMG References/Images/pmg-select-event-type-first-reference.jpg`

BetterCalendar references:

- `UI Preferences/BetterCalendar References/Bettercalendar-backup-json.mp4`
- `UI Preferences/BetterCalendar References/bettercalendar-preview-workflow.mp4`

The requested `UI Preferences/Screen Recordings/current-next-transfer-planner-20260729.mp4`
does not exist. The PMG JPG is inside the real `Images/` subfolder rather than
at `UI Preferences/PMG References/` directly. No local DayFlow repository was
found. These path differences are documented rather than guessed around.

## 3. Video metadata and full-duration review

Each recording was reviewed across its complete duration using timestamped
frames from the beginning through the final frame.

| Recording | Duration | Viewport | Primary content |
| --- | ---: | --- | --- |
| `Bettercalendar-backup-json.mp4` | 17.640 s | 720×1600 | Settings, Export Data, Android share sheet, JSON backup |
| `bettercalendar-preview-workflow.mp4` | 289.285 s | 720×1600 | event create/edit, move/resize, calendar/map/tasks/contacts/settings |
| `pmg-another-workflow.mp4` | 393.835 s | 720×1600 | event reporting, event creation, people, Weekly Planning |
| `pmg-event-picker-first.mp4` | 75.760 s | 1080×2400 | app entry, timeline tap, picker, event form, cancel/edit/delete |
| `pmg-select-event-type-first-workflow.mp4` | 17.607 s | 720×1600 | empty 3:30 PM tap, picker first, type selection, prefilled form |
| `pmg-settings-workflow.mp4` | 108.990 s | 1080×2400 | colors, language, notifications, calendar defaults and switches |
| `pmg-weekly-planning-workflow.mp4` | 142.243 s | 720×1600 | goals, plans, people, event scheduling, reporting and sync |
| `pm-whole-review-workflow.mp4` | 519.175 s | 720×1600 | broad PMG navigation, Planner, events, people, settings, sync, maps |

## 4. Approved PNG findings

The approved PNGs establish near-black and charcoal surfaces, warm pink active
states, white primary text, muted gray secondary text, restrained one-pixel
borders, compact content density, rounded cards, and permanent five-destination
navigation. The Planner reference specifically establishes:

- a compact seven-day strip with a pink selected-day outline;
- a 6 AM–10 PM hourly timeline with subtle dividers;
- event height proportional to duration;
- compact event titles and time ranges;
- colored event accents and muted event fills;
- a pink rounded-square floating action button above bottom navigation.

Fake iOS status bars and home indicators are reference artifacts and must not be
implemented. Flutter must use Android safe areas and system behavior.

The Pathways sample `Overall Progress 65%` is not product authority and must not
be implemented. No universal spiritual or Covenant Path percentage is allowed.

## 5. Stitch HTML measurement findings

The HTML is a measurement aid only. It is not production code and must not be
embedded, loaded through a WebView, or copied with Tailwind/CDN dependencies.

The Planner HTML uses:

- 60 px per hour;
- 30 px for a 30-minute event and 60 px for a 60-minute event;
- a one-pixel timeline divider;
- a four-pixel event accent;
- four-pixel event corner radius;
- a 64×64 px rounded-square FAB placed 24 px from the right;
- compact 10–12 px timeline/event text;
- black `#000000`, charcoal `#1C1C1E`, border `#2C2C2E`,
  secondary `#8E8E93`, and accent `#E91E63`.

Across the five HTML files, the visual family is consistently black/near-black,
charcoal, muted gray, white, and pink. The production app will retain its
centralized `AppTheme` equivalents rather than duplicating HTML literals.

## 6. PMG Event Type picker findings

The static image and recordings show a dedicated `Select Event Type` modal over
the existing calendar. It contains a clear title, one colored circular marker
and label per row, generous touch targets, a vertical scrollable list, and a
Cancel action. A row tap immediately continues; no confirmation button appears.
Android back/dismissal returns to the unchanged calendar.

Adopt:

- picker before the complete event form;
- underlying screen retained while the picker is open;
- configured type color in each row;
- single-tap continuation;
- compact dark presentation and accessible touch targets;
- recommended contextual type placed first and labeled `Recommended`.

Reject:

- PMG branding, blue action color, icons, navigation, and terminology;
- Contact, Teaching, Finding, Baptism, and Task as copied Event Types;
- any assumption that Task is a Calendar Event subtype.

## 7. PMG event-creation findings

The decisive workflow is:

`tap empty timeline → Select Event Type → choose type → complete form`.

In the 17.607-second recording, the timeline is tapped at approximately
3:30 PM. The picker appears first. Only after a type is tapped does the complete
form appear with the selected date and 3:30 PM time already populated.

Other PMG recordings confirm that creation from the calendar preserves the
calendar context and that cancel/discard returns without a saved event. The
complete form can include type-specific fields, people, location, recurrence,
and reporting context, but only approved Next Transfer fields are applicable.

## 8. PMG event-editing findings

PMG provides separate detail and edit surfaces, explicit discard confirmation,
and contextual actions such as duplicate, change type, and delete. Next
Transfer should retain its own existing detail/edit/report rules. The useful
pattern is that editing is explicit and unsaved changes can be discarded; PMG
status taxonomies and person-specific teaching fields must not be copied.

## 9. PMG drag and resize findings

The PMG recordings demonstrate calendar event blocks positioned by wall-clock
time and resizable through visible handles. The important transferable rule is
that the proposed time remains visible while the block moves or changes size.
Gesture movement is transient until release.

PMG does not override Next Transfer persistence: one successful release may
produce one local scheduling mutation; cancellation produces none. Dragging or
resizing never submits an Event Report or creates Actual.

## 10. PMG Weekly Planning findings

PMG Weekly Planning enters from Home, separates daily/weekly goal views,
navigates categories, associates people and plans, schedules activities into
the calendar, and returns to factual reporting/sync views. Applicable patterns:

- a clear transition from planning context to event scheduling;
- preserved selected week/date;
- contextual recommendations without silently creating data;
- explicit separation of goals/plans from reported results.

Missionary teaching, finding, baptism, referral, area, and people-management
models are rejected. Next Transfer retains its approved Weekly Plan lifecycle,
Monday–Sunday identity, explicit commitments, immutable review snapshots, and
Actual/Target/Scheduled separation.

## 11. PMG reporting findings

PMG distinguishes scheduled/unreported events from happened, missed, or other
reported outcomes and exposes follow-up scheduling after reporting. This
supports Next Transfer's locked rule that scheduling alone is not Actual.

PMG-specific statuses, privacy notices, teaching principles, commitments,
baptism forms, and person lifecycle rules are not transferable. Next Transfer's
qualifying Event Reports and signed Activity Ledger remain the only Actual
authority.

## 12. PMG Settings findings

The settings recording shows:

- Event Type colors and restoration of defaults;
- per-type default duration;
- default notification lead time;
- clock/time input preference;
- visible calendar start and end hours;
- full-screen versus sheet creation;
- open-calendar-after-scheduling and quick-edit switches;
- default contact interaction type.

Next Transfer already has approved local Event Type colors, durations, reminder
metadata, visible hours, time format, snap interval, initial scroll, quick edit,
status visibility, and week-start preferences. Only those existing approved
settings remain in scope. PMG theme, language, WhatsApp, member, area, sync, and
mission-management settings are rejected.

## 13. PMG people/contact findings

PMG connects events with people, contact methods, locations, commitments, and
status-specific reports. It demonstrates why creation context must be carried
temporarily through the picker. It does not authorize PMG person categories,
finding sources, teaching content, map filters, assignments, or status rules.

Contacts and follow-up scheduling are later-slice entry points. The shared
Next Transfer creation coordinator will accept future contextual identifiers,
but VS-08 will not create those screens or persistence models.

## 14. BetterCalendar export findings

The backup recording navigates to Settings → Export Data and invokes the
Android share sheet with a `.json` backup. This supports clear export messaging
and an explicit user-initiated handoff. It does not establish encryption,
schema compatibility, or import support for any unverified category.

The source recording may support later evidence for Contacts, Tasks, Calendar
Events, Recurring Activities, Reminders, and proven preferences only. It does
not prove map pins, custom places, Weekly Life Indicator history, goals, Weekly
Plans, or arbitrary settings.

## 15. BetterCalendar preview and calendar findings

The preview shows:

- a vertical mobile day timeline;
- a full event form with start/end, recurrence, reminder, color and privacy;
- live event resizing and moving;
- a single post-gesture confirmation with Undo;
- day/week/month selection, map, search, Tasks, Contacts, and Settings;
- extensive theme, timeline zoom, type color, backup, cloud, AI, and map options.

Applicable patterns are legible live time feedback, duration-preserving moves,
end-time-changing resize, one final commit, and a recoverable post-action
message. BetterCalendar's branding, UI, AI, cloud sync, Google/Canvas
integrations, maps, biometric lock, custom themes, task animation, and paid
features are rejected.

## 16. Required Next Transfer interaction

For every existing Calendar Event creation entry point:

`capture context in memory → Select Event Type → choose type → initialize
in-memory draft → apply defaults and deterministic mapping → complete form →
persist only on Save`.

Existing VS-08 entry points are:

- one tap on an empty Planner timeline position;
- Planner `+` → Calendar Event;
- Weekly Planning → New Event;
- Life Indicator → Schedule Activity;
- Task → Create Calendar Event;
- the direct Calendar Event create route.

The picker cancellation path creates no Calendar Event, persisted draft, outbox
entry, notification, Planned Outcome, ledger row, or progress.

## 17. Event Type ordering and mapping

The picker preserves the ten approved protected types and active custom types.
It does not seed prompt examples that are absent from the approved model.

Mapped types appear first:

1. Temple Visit → Temple Visit
2. Scripture Study → Scripture Study
3. Exercise → Exercise
4. Budget Review → Budget Review
5. Job Application → Job Applications
6. Meaningful Connection → Meaningful Connections

Then General, Appointment, Work, Personal, and active custom types follow in
their stable configured order. A contextually exact compatible type moves to
the first row and is marked `Recommended`.

## 18. Conflicts and confirmed resolution

The owner confirmed these resolutions before repository modification:

- preserve the locked multi-entity Planner `+`; its Calendar Event action is
  type-first rather than making the FAB Event-only;
- provide the shared future creation coordinator now, but defer nonexistent
  Pathway and Contact screen wiring/tests to their owning authorized slices;
- preserve the ten approved Event Types rather than seeding unapproved examples;
- record the missing current Next Transfer recording and absent DayFlow checkout
  without inventing paths or evidence.

No security vulnerability, data-loss risk, or technical impossibility remains
inside this resolved scope.

## 19. Proposed implementation changes

- Add temporary creation-context and picker/coordinator presentation components.
- Replace empty-grid long-press creation with one-tap creation.
- Preserve scroll/event/resize gesture precedence.
- Route every existing Calendar Event creation entry through the picker.
- Replace the creation form dropdown with a visible selected-type summary and
  explicit in-memory Change action using the same picker.
- Retain live move/resize preview and verify that it updates start/end text.
- Persist exactly once after a successful gesture release.
- Update empty-state wording and tests.
- Update traceability, manual QA, and implementation notes.

## 20. Expected files

Expected production changes are limited to:

- Planner creation/context/picker presentation files;
- `planner_screen.dart`;
- `calendar_event_form_screen.dart`;
- existing creation callers in Weekly Planning, Indicator detail, Task flow,
  and routing;
- focused widget/domain tests;
- VS-08 audit, traceability, manual QA, and implementation notes.

No schema migration, generated database file, package, permission, network
client, Pathways module, Contacts module, notification scheduler, or VS-09 file
is expected.

## 21. Test plan

Automated coverage will prove:

- empty timeline tap opens the picker first and preserves snapped date/time;
- scroll and existing-event taps do not create;
- Planner Calendar Event action, Weekly Planning, Life Indicator, Task flow, and
  direct create route are type-first;
- recommendation ordering and label;
- cancel/back create no persisted data;
- selecting a mapped type shows its automatic indicator link;
- Event Type remains visible in the form;
- default duration is applied after selection;
- scheduling and selection create no Actual;
- drag/resize labels update live, cancel restores, and release persists once.

Pathway/Contact screen-wiring tests remain deferred because those entry points
do not exist before their authorized slices. The shared coordinator itself will
be reusable and tested.

## 22. Risks and rollback

Risks:

- tap competing with timeline scroll;
- duplicate picker/form navigation;
- losing selected date/time during modal dismissal;
- unintentionally persisting before Save;
- changing type after form entry and retaining incompatible defaults;
- breaking Task/Event quick-create separation.

Mitigations:

- use Flutter's gesture arena and an opaque empty-grid tap surface beneath event
  blocks;
- hold creation context in immutable Dart objects only;
- centralize picker ordering and continuation;
- keep repository writes in the existing Save path;
- retain current one-write move/resize commit path and failure rollback;
- add route and widget regression tests.

Rollback is a code-only revert. No schema or data migration is introduced, so
existing Calendar Events, reports, links, mappings, weekly plans, and ledger
history remain valid.

## 23. Source behavior explicitly rejected

- PMG branding, logos, navigation, blue buttons, Event Type names, teaching
  content, person statuses, mission maps, assignments, referrals, sync model,
  and missionary reporting rules.
- BetterCalendar branding, UI duplication, AI assistant, cloud integrations,
  Google/Canvas dependencies, custom maps/places, paid features, theme system,
  biometric lock, and unsupported backup claims.
- HTML/WebView rendering, external image URLs, fake operating-system chrome,
  and hard-coded sample content from any reference.

## 24. Domain and privacy invariants

- Task and Calendar Event remain separate entities.
- Event Type selection and scheduling never create Actual.
- Actual remains derived from qualifying factual results through the Activity
  Ledger.
- No event or draft is persisted before Save.
- No outbox entry or notification is created on picker cancellation.
- Drag/resize changes scheduling only.
- Existing offline-first, transaction, idempotency, privacy, and provenance
  rules remain unchanged.

## 25. Audit conclusion

The references support a focused VS-08 correction: one-tap empty-timeline
creation, a dedicated Next Transfer Event Type picker before every existing
Calendar Event form, preserved context/defaults/mappings, and continuously
legible move/resize time feedback. The confirmed conflict resolution keeps this
work inside VS-08. Implementation must stop before VS-09.

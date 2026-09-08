import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_timeline_view.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_report_status.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_report_status_icons.dart';

void main() {
  testWidgets(
    'Slice A: cancelled Events render in their own Event-only flow and remain '
    'canonically tappable',
    (tester) async {
      const date = PlannerDate(year: 2026, month: 9, day: 2);
      final entry = ContactTimelineEntry(
        kind: ContactTimelineKind.eventOccurrence,
        date: date,
        chronology: DateTime(2026, 9, 2, 10),
        title: 'Cancelled visit',
        status: CalendarEventStatus.cancelled,
        statusLabel: 'Cancelled',
        eventId: 'cancelled-event',
        originalDate: date,
        occurrenceId: 'cancelled-event:2026-09-02',
        isUpcoming: true,
        isStructurallyCancelled: true,
      );
      ContactTimelineEntry? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: ContactTimeline(
                upcoming: const <ContactTimelineEntry>[],
                history: const <ContactTimelineEntry>[],
                cancelledEvents: <ContactTimelineEntry>[entry],
              ),
              eventColorsByTypeId: const <String, EventColorPreference>{},
              onOpenEvent: (selected, _) async => opened = selected,
            ),
          ),
        ),
      );

      expect(find.text('Cancelled Events'), findsOneWidget);
      expect(find.text('Cancelled visit'), findsOneWidget);
      expect(find.text('Future'), findsNothing);
      expect(find.byType(CustomScrollView), findsOneWidget);
      await tester.tap(find.text('Cancelled visit'));
      await tester.pump();
      expect(opened?.occurrenceId, entry.occurrenceId);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Timeline outcome symbols reuse the canonical Current Status mapper',
    (tester) async {
      ContactTimelineEntry entry(
        String id,
        CalendarEventStatus status,
        String label,
      ) => ContactTimelineEntry(
        kind: ContactTimelineKind.eventOccurrence,
        date: const PlannerDate(year: 2026, month: 8, day: 20),
        chronology: DateTime(2026, 8, 20, 10),
        title: id,
        status: status,
        statusLabel: label,
        eventId: id,
        originalDate: const PlannerDate(year: 2026, month: 8, day: 20),
        occurrenceId: '$id:2026-08-20',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: ContactTimeline(
                upcoming: const <ContactTimelineEntry>[],
                history: <ContactTimelineEntry>[
                  entry(
                    'Unreported card',
                    CalendarEventStatus.scheduled,
                    'Unreported',
                  ),
                  entry(
                    'DNA card',
                    CalendarEventStatus.didNotHappen,
                    'Did Not Attempt',
                  ),
                  entry(
                    'Missed card',
                    CalendarEventStatus.partiallyCompleted,
                    'Missed',
                  ),
                  entry(
                    'Completed card',
                    CalendarEventStatus.completedHappened,
                    'Completed',
                  ),
                ],
              ),
              eventColorsByTypeId: const <String, EventColorPreference>{},
            ),
          ),
        ),
      );

      final icons = tester
          .widgetList<PlannerReportStatusIcon>(
            find.byType(PlannerReportStatusIcon),
          )
          .toList();
      expect(icons.map((icon) => icon.kind), <PlannerReportStatusKind>[
        PlannerReportStatusKind.unreported,
        PlannerReportStatusKind.didNotAttempt,
        PlannerReportStatusKind.missedAttempted,
        PlannerReportStatusKind.completed,
      ]);
      expect(find.byIcon(Icons.phone_missed_outlined), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    },
  );

  testWidgets(
    'Slice A: deleting the tapped Timeline row restores a surviving logical '
    'neighbor without a persistent controller',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _AnchorHarness())),
      );
      await tester.scrollUntilVisible(
        find.text('History 5'),
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('contact-timeline-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('History 5')),
        alignment: 0.5,
        duration: Duration.zero,
      );
      await tester.pump();
      final before = tester.getTopLeft(find.text('History 4')).dy;
      await tester.tap(find.text('History 5'));
      await tester.pump();
      await tester.pump();

      expect(find.text('History 5'), findsNothing);
      expect(find.text('History 4'), findsOneWidget);
      expect(
        (tester.getTopLeft(find.text('History 4')).dy - before).abs(),
        lessThan(3),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'E3 cancelled flow is independently bounded, expands inline, survives '
    'same-Contact refresh, and resets for a different Contact',
    (tester) async {
      final entries = <ContactTimelineEntry>[
        for (var index = 0; index < 5; index++)
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: PlannerDate(year: 2026, month: 9, day: index + 1),
            chronology: DateTime(2026, 9, index + 1, 10),
            title: 'Cancelled $index',
            status: CalendarEventStatus.cancelled,
            eventId: 'cancelled-$index',
            originalDate: PlannerDate(year: 2026, month: 9, day: index + 1),
            occurrenceId: 'cancelled-$index:2026-09-${index + 1}',
            isStructurallyCancelled: true,
          ),
      ];

      Widget app(String contactId, List<ContactTimelineEntry> cancelled) =>
          MaterialApp(
            home: Scaffold(
              body: ContactTimelineView(
                key: const Key('stable-timeline-view'),
                contactId: contactId,
                timeline: ContactTimeline(
                  upcoming: const <ContactTimelineEntry>[],
                  history: const <ContactTimelineEntry>[],
                  cancelledEvents: cancelled,
                ),
                eventColorsByTypeId: const <String, EventColorPreference>{},
              ),
            ),
          );

      await tester.pumpWidget(app('contact-a', entries));
      Finder cancelledCards() => find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data?.startsWith('Cancelled ') == true &&
            widget.data != 'Cancelled Events',
      );
      expect(cancelledCards(), findsNWidgets(3));
      expect(find.text('See more'), findsOneWidget);
      await tester.tap(find.text('See more'));
      await tester.pump();
      expect(cancelledCards(), findsNWidgets(5));
      expect(find.text('See less'), findsOneWidget);

      await tester.pumpWidget(app('contact-a', List.of(entries)));
      await tester.pump();
      expect(cancelledCards(), findsNWidgets(5));
      expect(find.text('See less'), findsOneWidget);

      await tester.pumpWidget(app('contact-b', List.of(entries)));
      await tester.pump();
      expect(cancelledCards(), findsNWidgets(3));
      expect(find.text('See more'), findsOneWidget);
    },
  );

  testWidgets(
    'E3 section-local flows stop every rail, add only non-empty boundaries, '
    'and render left-aligned themed headers in light and dark themes',
    (tester) async {
      ContactTimelineEntry entry(
        String id,
        PlannerDate date, {
        bool upcoming = false,
        bool cancelled = false,
      }) => ContactTimelineEntry(
        kind: ContactTimelineKind.eventOccurrence,
        date: date,
        chronology: DateTime(date.year, date.month, date.day, 10),
        title: id,
        status: cancelled
            ? CalendarEventStatus.cancelled
            : CalendarEventStatus.completedHappened,
        eventId: id,
        originalDate: date,
        occurrenceId: '$id:${date.iso8601}',
        isUpcoming: upcoming,
        isStructurallyCancelled: cancelled,
      );
      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          entry(
            'Future card',
            const PlannerDate(year: 2026, month: 9, day: 3),
            upcoming: true,
          ),
        ],
        history: <ContactTimelineEntry>[
          entry(
            'History card',
            const PlannerDate(year: 2026, month: 8, day: 3),
          ),
        ],
        cancelledEvents: <ContactTimelineEntry>[
          entry(
            'Cancelled card',
            const PlannerDate(year: 2026, month: 9, day: 4),
            cancelled: true,
          ),
        ],
      );

      for (final brightness in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: ContactTimelineView(
                contactId: 'contact-a',
                timeline: timeline,
                eventColorsByTypeId: const <String, EventColorPreference>{},
              ),
            ),
          ),
        );
        expect(
          find.byKey(const Key('timeline-section-divider-future-history')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('timeline-section-divider-history-cancelled')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('timeline-history-spine-connector')),
          findsNothing,
        );
        for (final label in <String>['Future', 'History', 'Cancelled Events']) {
          final keyPrefix = label == 'Cancelled Events'
              ? 'cancelled'
              : label.toLowerCase();
          final header = find.byKey(Key('timeline-section-$keyPrefix'));
          final divider = find.byKey(
            Key('timeline-section-header-divider-$keyPrefix'),
          );
          final text = tester.widget<Text>(find.text(label));
          expect(text.style?.fontSize, 16);
          expect(text.style?.fontWeight, FontWeight.w600);
          expect(tester.getTopLeft(find.text(label)).dx, lessThan(40));
          expect(divider, findsOneWidget);
          expect(tester.getTopLeft(divider).dx, greaterThanOrEqualTo(16));
          expect(
            tester.getTopRight(divider).dx,
            lessThanOrEqualTo(tester.getTopRight(header).dx - 16),
          );
          expect(
            tester.getTopLeft(divider).dy,
            greaterThan(tester.getBottomLeft(find.text(label)).dy),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'sticky Timeline headers physically push and replace without stacking',
    (tester) async {
      ContactTimelineEntry entry(
        String section,
        int index, {
        bool upcoming = false,
        bool cancelled = false,
      }) {
        final date = PlannerDate(
          year: 2026,
          month: upcoming || cancelled ? 9 : 8,
          day: index + 1,
        );
        return ContactTimelineEntry(
          kind: ContactTimelineKind.eventOccurrence,
          date: date,
          chronology: DateTime(date.year, date.month, date.day, 10),
          title: '$section $index',
          status: cancelled
              ? CalendarEventStatus.cancelled
              : upcoming
              ? CalendarEventStatus.scheduled
              : CalendarEventStatus.completedHappened,
          statusLabel: cancelled
              ? 'Cancelled'
              : upcoming
              ? 'Scheduled'
              : 'Completed',
          eventId: '$section-$index',
          originalDate: date,
          occurrenceId: '$section-$index:${date.iso8601}',
          isUpcoming: upcoming,
          isStructurallyCancelled: cancelled,
        );
      }

      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final viewportSize in const <Size>[
        Size(360, 420),
        Size(480, 420),
        Size(1024, 420),
      ]) {
        tester.view.physicalSize = viewportSize;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: viewportSize.width,
                height: viewportSize.height,
                child: ContactTimelineView(
                  key: ValueKey<double>(viewportSize.width),
                  contactId: 'sticky-contact-${viewportSize.width}',
                  timeline: ContactTimeline(
                    upcoming: <ContactTimelineEntry>[
                      for (var index = 0; index < 6; index++)
                        entry('Future', index, upcoming: true),
                    ],
                    history: <ContactTimelineEntry>[
                      for (var index = 0; index < 6; index++)
                        entry('History', index),
                    ],
                    cancelledEvents: <ContactTimelineEntry>[
                      for (var index = 0; index < 5; index++)
                        entry('Cancelled', index, cancelled: true),
                    ],
                  ),
                  eventColorsByTypeId: const <String, EventColorPreference>{},
                ),
              ),
            ),
          ),
        );

        final scrollView = find.byKey(const Key('contact-timeline-list'));
        final scrollable = find
            .descendant(of: scrollView, matching: find.byType(Scrollable))
            .first;
        final futureHeader = find.byKey(const Key('timeline-section-future'));
        final historyHeader = find.byKey(const Key('timeline-section-history'));
        final cancelledHeader = find.byKey(
          const Key('timeline-section-cancelled'),
        );
        final viewportTop = tester.getTopLeft(scrollView).dy;
        Future<void> pin(Finder header) async {
          for (var attempt = 0; attempt < 8; attempt++) {
            final distance = tester.getTopLeft(header).dy - viewportTop;
            if (distance <= 1) return;
            final position = tester.state<ScrollableState>(scrollable).position;
            position.jumpTo(
              (position.pixels + distance).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
            );
            await tester.pump();
          }
        }

        expect(tester.getTopLeft(futureHeader).dy, closeTo(viewportTop, 1));

        await tester.scrollUntilVisible(
          find.text('History 4'),
          240,
          scrollable: scrollable,
        );
        await tester.pump();
        await pin(historyHeader);
        expect(tester.getTopLeft(historyHeader).dy, closeTo(viewportTop, 1));
        expect(futureHeader, findsNothing);

        await tester.scrollUntilVisible(
          find.text('Cancelled 2'),
          240,
          scrollable: scrollable,
        );
        await tester.pump();
        await pin(cancelledHeader);
        expect(tester.getTopLeft(cancelledHeader).dy, closeTo(viewportTop, 1));
        expect(historyHeader, findsNothing);
        final cancelledDivider = find.byKey(
          const Key('timeline-section-header-divider-cancelled'),
        );
        expect(
          tester
              .getRect(cancelledHeader)
              .contains(tester.getCenter(cancelledDivider)),
          isTrue,
        );
        expect(
          tester
              .hitTestOnBinding(tester.getCenter(find.text('Cancelled 2')))
              .path,
          isNotEmpty,
        );

        expect(
          find.byKey(const Key('timeline-cancelled-expansion-control')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}

final class _AnchorHarness extends StatefulWidget {
  const _AnchorHarness();

  @override
  State<_AnchorHarness> createState() => _AnchorHarnessState();
}

final class _AnchorHarnessState extends State<_AnchorHarness> {
  late List<ContactTimelineEntry> entries = <ContactTimelineEntry>[
    for (var index = 0; index < 12; index++)
      ContactTimelineEntry(
        kind: ContactTimelineKind.eventOccurrence,
        date: PlannerDate(year: 2026, month: 8, day: 20 - index),
        chronology: DateTime(2026, 8, 20 - index, 10),
        title: 'History $index',
        eventId: 'history-$index',
        originalDate: PlannerDate(year: 2026, month: 8, day: 20 - index),
        occurrenceId: 'history-$index:2026-08-${20 - index}',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: ContactTimelineView(
        timeline: ContactTimeline(
          upcoming: const <ContactTimelineEntry>[],
          history: entries,
        ),
        eventColorsByTypeId: const <String, EventColorPreference>{},
        onOpenEvent: (entry, anchor) async {
          setState(() {
            entries = entries
                .where((candidate) => candidate != entry)
                .toList(growable: false);
          });
          await WidgetsBinding.instance.endOfFrame;
          await anchor.restore();
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/features/planner/presentation/contextual_create_fab.dart';

void main() {
  // T13: both action pills fill scheme.primary and render their icon and
  // label in scheme.onPrimary across all four theme combinations, with the
  // exact accepted geometry (56 height / radius 28 / glyph 24 / text 18 w600)
  // and stable Event/Task ordering (Task first, Event second).
  ThemeData themeFor(ThemeColorMode mode, Brightness brightness) =>
      brightness == Brightness.light ? AppTheme.light(mode) : AppTheme.dark(mode);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required ThemeColorMode mode,
    required Brightness brightness,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeFor(mode, brightness),
        home: Scaffold(
          body: Center(
            child: ContextualCreateFab(
              destination: CreateActionDestination.home,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contextual-create-fab')));
    await tester.pumpAndSettle();
  }

  for (final mode in ThemeColorMode.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'pills use onPrimary foreground in $mode/$brightness',
        (tester) async {
          await pumpAndOpen(tester, mode: mode, brightness: brightness);
          final context = tester.element(
            find.byKey(const Key('create-task-action')),
          );
          final scheme = Theme.of(context).colorScheme;

          for (final actionKey in const <Key>[
            Key('create-task-action'),
            Key('create-calendar-event-action'),
          ]) {
            final inkWell = tester.widget<InkWell>(find.byKey(actionKey));
            expect(inkWell.borderRadius, BorderRadius.circular(28));

            final icon = tester.widgetList<Icon>(
              find.descendant(
                of: find.byKey(actionKey),
                matching: find.byType(Icon),
              ),
            ).single;
            expect(icon.size, 24);
            expect(icon.color, scheme.onPrimary,
                reason: 'icon foreground must be onPrimary');

            final text = tester.widgetList<Text>(
              find.descendant(
                of: find.byKey(actionKey),
                matching: find.byType(Text),
              ),
            ).single;
            expect(text.style!.fontSize, 18);
            expect(text.style!.fontWeight, FontWeight.w600);
            expect(text.style!.color, scheme.onPrimary,
                reason: 'label foreground must be onPrimary');

            final sized = tester.widgetList<SizedBox>(
              find.descendant(
                of: find.byKey(actionKey),
                matching: find.byWidgetPredicate(
                  (widget) => widget is SizedBox && widget.height != null,
                ),
              ),
            ).first;
            expect(sized.height, 56);
          }
          // Ordering: Task pill above Event pill.
          final taskTop = tester.getTopLeft(
            find.byKey(const Key('create-task-action')),
          );
          final eventTop = tester.getTopLeft(
            find.byKey(const Key('create-calendar-event-action')),
          );
          expect(taskTop.dy, lessThan(eventTop.dy));
        },
      );
    }
  }

  testWidgets('tapping Event routes selection through onSelected',
      (tester) async {
    ContextualCreateAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(ThemeColorMode.rose),
        home: Scaffold(
          body: Center(
            child: ContextualCreateFab(
              destination: CreateActionDestination.home,
              onSelected: (action) => selected = action,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contextual-create-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-calendar-event-action')));
    await tester.pumpAndSettle();
    expect(selected, ContextualCreateAction.event);
  });

  test('appearance Rose law: blue fallback token unchanged', () {
    // Rose = NO CHANGE (R11): the label/storage stay rose; this asserts the
    // Goal fallback blue token the audit pinned is also untouched.
    expect(AppTheme.goalIconFallbackBlue, const Color(0xFF5CAEC9));
  });
}

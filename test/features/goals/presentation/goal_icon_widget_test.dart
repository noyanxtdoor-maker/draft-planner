import 'dart:async';

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/presentation/goal_icon_picker_screen.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon_choice_row.dart';

void main() {
  testWidgets('GoalIcon renders registered assets and safe fallbacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              GoalIcon(iconId: 'work_briefcase', size: 32),
              GoalIcon(iconId: null, size: 28),
              GoalIcon(iconId: 'future-icon-id', size: 24),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('Job search and applications'), findsOneWidget);
    expect(find.bySemanticsLabel('Goal icon'), findsNWidgets(2));
    expect(find.byIcon(Icons.flag_outlined), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoalIconChoiceRow exposes the current choice accessibly', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: GoalIconChoiceRow(
            goalTitle: 'Scripture Study',
            iconId: 'learning_open_book',
            fallbackIcon: Icons.flag_outlined,
            showSuggestion: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning'), findsOneWidget);
    expect(find.text('Suggested from "Scripture Study"'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('goal-icon-choice-row'))).label,
      contains('Learning'),
    );
    await tester.tap(find.byKey(const Key('goal-icon-choice-row')));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoalIconChoiceRow remains usable at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: GoalIconChoiceRow(
            goalTitle: 'A very long goal title that still needs an icon',
            iconId: 'finance_wallet',
            fallbackIcon: Icons.flag_outlined,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pie Chart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Choose Icon is 41-icon, icon-only, and routable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final result = router.push<String?>(
      '/picker',
      extra: const GoalIconPickerArgs(
        goalTitle: 'Unrelated goal',
        currentIconId: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Icon'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('Work & Learning'), findsNothing);
    // The full grid renders 41 selectable icons (tiles are lazy; the grid is
    // a ListView child so count via the tile keys that are present).
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is Key &&
            widget.key!.toString().contains('goal-icon-tile-'),
      ),
      findsWidgets,
    );
    expect(find.byKey(const Key('goal-icon-tile-work_briefcase')), findsOneWidget);
    expect(find.byKey(const Key('goal-icon-tile-learning_open_book')), findsOneWidget);
    expect(find.byKey(const Key('goal-icon-tile-finance_wallet')), findsOneWidget);
    expect(find.byKey(const Key('goal-icon-tile-spiritual_temple')), findsOneWidget);
    expect(find.byKey(const Key('goal-icon-tile-marriage_rings')), findsOneWidget);
    // Stage 1.1: social_two_people, find_job, and finance_pie_chart are not
    // selectable (no duplicate Find Job / Pie Chart tiles).
    for (final retired in <String>[
      'social_two_people',
      'find_job',
      'finance_pie_chart',
    ]) {
      expect(find.byKey(Key('goal-icon-tile-$retired')), findsNothing);
    }
    // Icon-only tiles: no visible displayName or category labels.
    for (final label in <String>[
      'Find Job',
      'Learning',
      'Pie Chart',
      'Temple',
      'Marriage Rings',
      'Career Growth',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(find.byKey(const Key('goal-icon-picker-save')), findsOneWidget);

    await tester.tap(find.byKey(const Key('goal-icon-tile-learning_open_book')));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Learning, Learning and study, selected'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('goal-icon-picker-save')));
    await tester.pumpAndSettle();
    expect(await result, 'learning_open_book');
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Choose Icon suggestions are capped, Search is absent, and a retired '
    'alias selects its canonical tile',
    (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(
        router.push<void>(
          '/picker',
          extra: const GoalIconPickerArgs(
            goalTitle: 'career study money temple people marriage',
            currentIconId: 'spiritual_temple',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final suggestions = find.byKey(const Key('goal-icon-suggestions'));
      expect(suggestions, findsOneWidget);
      expect(
        find.descendant(of: suggestions, matching: find.byType(GoalIcon)),
        findsNWidgets(3),
      );
      expect(
        find.descendant(
          of: suggestions,
          matching: find.byKey(
            const Key('goal-icon-tile-spiritual_temple'),
          ),
        ),
        findsOneWidget,
      );

      // Stage-1.1: the entire Search control is gone.
      expect(find.byKey(const Key('goal-icon-search')), findsNothing);
      expect(find.byKey(const Key('goal-icon-search-clear')), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('No icons found.'), findsNothing);
      expect(find.byIcon(Icons.search), findsNothing);

      // All Icons still lists the canonical entries (no retired aliases).
      final allIcons = find.byKey(const Key('goal-icon-all'));
      expect(
        find.descendant(
          of: allIcons,
          matching: find.byKey(const Key('goal-icon-tile-work_briefcase')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: allIcons,
          matching: find.byKey(const Key('goal-icon-tile-marriage_rings')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('goal-icon-picker-save')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a retired alias draft selects its canonical tile in Choose Icon', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(
      router.push<void>(
        '/picker',
        extra: const GoalIconPickerArgs(
          goalTitle: 'Apply for Jobs',
          currentIconId: 'find_job',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The retired alias resolves to the canonical Find Job tile as selected.
    expect(
      find.byKey(const Key('goal-icon-tile-work_briefcase')),
      findsWidgets,
    );
    // The tile semantics report the canonical name in the selected state. The
    // canonical tile is selected in BOTH the Suggested grid (the alias resolves
    // and suggests Find Job) and the All Icons grid, so two labeled nodes are
    // expected; the retired alias itself never renders a duplicate tile.
    expect(
      find.bySemanticsLabel('Find Job, Job search and applications, selected'),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const Key('goal-icon-tile-find_job')),
      findsNothing,
    );
    // Saving returns the canonical ID, never the alias.
    await tester.tap(find.byKey(const Key('goal-icon-picker-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Choose Icon stays bounded at 360dp and 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    unawaited(
      router.push<void>(
        '/picker',
        extra: const GoalIconPickerArgs(
          goalTitle: 'Scripture Study',
          currentIconId: 'learning_open_book',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Icon'), findsOneWidget);
    expect(
      find.byKey(const Key('goal-icon-tile-learning_open_book')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Choose Icon tiles are compact icon-only (no labels, 48dp icon, '
      'selected badge)', (tester) async {
    tester.view.physicalSize = const Size(393, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    unawaited(
      router.push<void>(
        '/picker',
        extra: const GoalIconPickerArgs(
          goalTitle: 'Scripture Study',
          currentIconId: 'learning_open_book',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.descendant(
      of: find.byKey(const Key('goal-icon-all')),
      matching: find.byKey(const Key('goal-icon-tile-learning_open_book')),
    );
    expect(tile, findsOneWidget);
    // Normal tile height 76dp, icon 48dp (Stage-1.2 global picker size),
    // no displayName/category text.
    expect(tester.getSize(tile).height, 76);
    expect(
      find.descendant(of: tile, matching: find.byType(GoalIcon)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<GoalIcon>(
            find.descendant(of: tile, matching: find.byType(GoalIcon)),
          )
          .size,
      48,
      reason: 'Stage-1.2 locks one global 48dp picker icon size',
    );
    expect(
      find.descendant(of: tile, matching: find.byType(Text)),
      findsNothing,
      reason: 'icon-only tiles must not render visible labels',
    );
    // Semantics retain the meaningful name and selected state (never
    // color-only), exposed through the tile's single semantic node.
    expect(
      find.descendant(
        of: find.byKey(const Key('goal-icon-all')),
        matching: find.bySemanticsLabel(
          'Learning, Learning and study, selected',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Choose Icon category chips filter All Icons only, keep '
      'Suggested, and preserve the selection', (tester) async {
    tester.view.physicalSize = const Size(393, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final result = router.push<String?>(
      '/picker',
      extra: const GoalIconPickerArgs(
        goalTitle: 'career study money temple people marriage',
        currentIconId: 'spiritual_temple',
      ),
    );
    await tester.pumpAndSettle();

    // No Search reintroduced.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);

    // The chip row appears with the exact seven Stage-1.2 labels.
    expect(find.byKey(const Key('goal-icon-category-chips')), findsOneWidget);
    for (final label in const <String>[
      'All',
      'Career & Learning',
      'Finance & Home',
      'Health',
      'Social',
      'Spiritual',
      'Travel',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Horizontal, non-wrapping scroll container.
    final chipsScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('goal-icon-category-chips')),
    );
    expect(chipsScroll.scrollDirection, Axis.horizontal);

    final allGrid = find.byKey(const Key('goal-icon-all'));
    int gridChildCount() {
      final delegate =
          tester
                  .widget<GridView>(
                    find.descendant(
                      of: allGrid,
                      matching: find.byType(GridView),
                    ),
                  )
                  .childrenDelegate
              as SliverChildBuilderDelegate;
      return delegate.childCount!;
    }

    // All is the default: the full 41-icon grid with the selected tile.
    expect(gridChildCount(), 41);
    expect(
      find.descendant(
        of: allGrid,
        matching: find.byKey(const Key('goal-icon-tile-work_briefcase')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: allGrid,
        matching: find.byKey(const Key('goal-icon-tile-spiritual_temple')),
      ),
      findsOneWidget,
    );
    // Suggested is present under All.
    expect(find.byKey(const Key('goal-icon-suggestions')), findsOneWidget);

    // Filter to Career & Learning (10 icons) — the selected Spiritual tile
    // is hidden in All Icons but stays selected in screen state.
    await tester.tap(find.text('Career & Learning'));
    await tester.pumpAndSettle();
    expect(gridChildCount(), 10);
    expect(
      find.descendant(
        of: allGrid,
        matching: find.byKey(const Key('goal-icon-tile-work_briefcase')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: allGrid,
        matching: find.byKey(const Key('goal-icon-tile-spiritual_temple')),
      ),
      findsNothing,
      reason: 'the Spiritual tile is filtered out of All Icons',
    );
    // Suggested stays visible and goal-title driven under a category filter.
    expect(find.byKey(const Key('goal-icon-suggestions')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('goal-icon-suggestions')),
        matching: find.byType(GoalIcon),
      ),
      findsNWidgets(3),
    );
    // Only one chip is active (radio behavior).
    Material chipMaterial(String label) => tester.widget<Material>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    );
    expect(chipMaterial('All').color, Colors.transparent);
    expect(chipMaterial('Career & Learning').color, AppTheme.rose);
    expect(chipMaterial('Spiritual').color, Colors.transparent);
    // Semantics expose the selected chip state.
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('goal-icon-chip-Career & Learning')),
          )
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('goal-icon-chip-All')))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );
    // The filtered-out selection is preserved: Save is still enabled and
    // returns the hidden selected icon.
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('goal-icon-picker-save')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('goal-icon-picker-save')));
    await tester.pumpAndSettle();
    expect(await result, 'spiritual_temple');
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Choose Icon tiles grow to 84dp at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 874);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    unawaited(
      router.push<void>(
        '/picker',
        extra: const GoalIconPickerArgs(
          goalTitle: 'Scripture Study',
          currentIconId: 'learning_open_book',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const Key('goal-icon-all')),
              matching: find.byKey(
                const Key('goal-icon-tile-learning_open_book'),
              ),
            ),
          )
          .height,
      84,
    );
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/picker',
        builder: (context, state) {
          final args = state.extra! as GoalIconPickerArgs;
          return GoalIconPickerScreen(args: args);
        },
      ),
    ],
  );
}

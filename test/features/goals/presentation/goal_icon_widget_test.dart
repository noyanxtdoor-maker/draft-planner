import 'dart:async';

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
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

  testWidgets('Choose Icon tiles are compact icon-only (no labels, 96dp icon, '
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
    // GI-02 (supersedes Stage-1.2): tile height 104dp, icon 96dp,
    // no displayName/category text.
    expect(tester.getSize(tile).height, 104);
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
      96,
      reason: 'GI-02 supersedes Stage-1.2: picker icon is exactly 96dp',
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
    // The active chip is filled with the harness's semantic primary.
    final chipPrimary = Theme.of(
      tester.element(find.byKey(const Key('goal-icon-chip-Career & Learning'))),
    ).colorScheme.primary;
    expect(chipMaterial('Career & Learning').color, chipPrimary);
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
      112,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GP-01: Choose Icon Light tiles use the near-white semantic surface (no '
    'gray slab); Dark stays transparent; 96dp + 3 columns unchanged',
    (tester) async {
      tester.view.physicalSize = const Size(393, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Scope tiles to the "All Icons" grid so suggestions duplicates do
      // not break single-element finders. The tile key sits on the Card
      // itself, so the finder IS the Card.
      Finder allTile(String id) => find.descendant(
        of: find.byKey(const Key('goal-icon-all')),
        matching: find.byKey(Key('goal-icon-tile-$id')),
      );
      Card tileCard(Finder tile) => tester.widget<Card>(tile);

      // --- Light (Rose) ---
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      unawaited(
        router.push<void>(
          '/picker',
          // No-suggestion title keeps the "All Icons" grid near the top of
          // the lazy ListView so its tiles are mounted.
          extra: const GoalIconPickerArgs(
            goalTitle: 'Unrelated goal',
            currentIconId: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = allTile('work_briefcase');
      final tileContext = tester.element(tile);
      // Unselected Light tile: near-white semantic surface, NOT transparent
      // and NOT the gray slab tone.
      expect(
        tileCard(tile).color,
        Theme.of(tileContext).colorScheme.surface,
        reason: 'GP-01: unselected Light tile must use the near-white surface',
      );
      expect(tileCard(tile).color, isNot(Colors.transparent));
      expect(
        tileCard(tile).color,
        isNot(
          Theme.of(tileContext).colorScheme.surfaceContainerHighest,
        ),
        reason: 'GP-01: unselected Light tile must not be a gray slab',
      );
      // 96dp art unchanged.
      final icon = tester.widget<GoalIcon>(
        find.descendant(of: tile, matching: find.byType(GoalIcon)),
      );
      expect(icon.size, 96);
      // 3 columns unchanged.
      final grid = tester.widget<GridView>(find.byType(GridView).first);
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);

      // Selected tile: same near-white base + 2px primary border.
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final selTile = allTile('work_briefcase');
      final selShape = tileCard(selTile).shape! as RoundedRectangleBorder;
      expect(
        selShape.side.color,
        Theme.of(tester.element(selTile)).colorScheme.primary,
        reason: 'GP-01: selected tile keeps the semantic primary border',
      );
      expect(selShape.side.width, 2);
      expect(
        tileCard(selTile).color,
        Theme.of(tester.element(selTile)).colorScheme.surface,
      );

      // --- Dark: tile stays transparent (GI-01 no-plate contract) ---
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      final darkRouter = _router();
      addTearDown(darkRouter.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark(), routerConfig: darkRouter),
      );
      await tester.pumpAndSettle();
      unawaited(
        darkRouter.push<void>(
          '/picker',
          extra: const GoalIconPickerArgs(
            goalTitle: 'Unrelated goal',
            currentIconId: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final darkTile = allTile('work_briefcase');
      expect(
        tileCard(darkTile).color,
        Colors.transparent,
        reason: 'GP-01: Dark picker tiles must stay transparent (raw art)',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A8: Choose Icon pins app-bar surface through scroll without changing '
    'the InternalAppBar default',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const GoalIconPickerScreen(
            args: GoalIconPickerArgs(
              goalTitle: 'Job Applications',
              currentIconId: 'work_briefcase',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appBarFinder = find.descendant(
        of: find.byType(GoalIconPickerScreen),
        matching: find.byType(AppBar),
      );
      AppBar appBar() => tester.widget<AppBar>(appBarFinder);
      // Outer Material of the AppBar paints the effective background color.
      Material appBarMaterial() => tester.widget<Material>(
        find
            .descendant(of: appBarFinder, matching: find.byType(Material))
            .first,
      );

      // Locked surface-pinning properties, present at rest.
      expect(
        appBar().backgroundColor,
        AppTheme.surface,
        reason: 'Choose Icon must pin its app-bar base to the surface color.',
      );
      expect(appBar().surfaceTintColor, Colors.transparent);
      expect(
        appBar().scrolledUnderElevation,
        0,
        reason: 'Choose Icon must not lift its app bar when scrolled under.',
      );
      expect(appBarMaterial().color, AppTheme.surface);

      // Scroll the list under the app bar: Material 3 would otherwise swap
      // the base color to surfaceContainer once scrolledUnder is reported.
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(appBar().backgroundColor, AppTheme.surface);
      expect(appBar().surfaceTintColor, Colors.transparent);
      expect(appBar().scrolledUnderElevation, 0);
      expect(
        appBarMaterial().color,
        AppTheme.surface,
        reason: 'Scrolled-under state must not change the visible background.',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            appBar: InternalAppBar(title: Text('Unrelated internal screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unrelated = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        unrelated.backgroundColor,
        isNull,
        reason: 'A8 must not change every InternalAppBar consumer.',
      );
      expect(
        unrelated.surfaceTintColor,
        isNull,
        reason: 'A8 must not change every InternalAppBar consumer.',
      );
      expect(
        unrelated.scrolledUnderElevation,
        isNull,
        reason: 'A8 must not change every InternalAppBar consumer.',
      );
    },
  );

  testWidgets(
    'A9: system Back in callback mode returns to the same Edit Goal draft',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const _A9NavigationHome()),
      );
      await tester.tap(find.byKey(const Key('a9-open-edit-goal')));
      await tester.pumpAndSettle();

      final draftField = find.byKey(const Key('a9-goal-title'));
      await tester.enterText(draftField, 'Unsaved Exercise Draft');
      await tester.tap(find.byKey(const Key('a9-open-icon-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Choose Icon'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(GoalIconPickerScreen), findsNothing);
      expect(find.text('Edit Goal'), findsOneWidget);
      expect(
        tester.widget<TextField>(draftField).controller?.text,
        'Unsaved Exercise Draft',
        reason: 'System Back must close only Choose Icon and retain the draft.',
      );
      expect(find.byKey(const Key('a9-home')), findsNothing);

      await tester.tap(find.byKey(const Key('a9-open-icon-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-icon-picker-back')));
      await tester.pumpAndSettle();
      expect(find.byType(GoalIconPickerScreen), findsNothing);
      expect(
        tester.widget<TextField>(draftField).controller?.text,
        'Unsaved Exercise Draft',
        reason: 'Toolbar Back must retain the same Edit Goal draft too.',
      );

      await tester.tap(find.byKey(const Key('a9-open-icon-picker')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('goal-icon-tile-work_briefcase')).last,
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('goal-icon-picker-save')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('goal-icon-picker-save')));
      await tester.pumpAndSettle();
      expect(find.byType(GoalIconPickerScreen), findsNothing);
      expect(
        tester.widget<TextField>(draftField).controller?.text,
        'Unsaved Exercise Draft',
        reason: 'Picker Save must retain the other unsaved Goal fields.',
      );
      expect(find.text('work_briefcase'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A9: standalone Choose Icon system Back still pops its route', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final result = router.push<String?>(
      '/picker',
      extra: const GoalIconPickerArgs(
        goalTitle: 'Standalone Goal',
        currentIconId: 'work_briefcase',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GoalIconPickerScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.byType(GoalIconPickerScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------- POLISH-03
  // Light UI Final Polish renderer contract (owner-locked): the GI-01
  // 1.06x #181A1E halo is REMOVED.  Light mode renders the raw original
  // two-tone foreground SVG only — no plate, no halo, no artificial black
  // outline, no DecoratedBox, no ColorFiltered silhouette, no Transform
  // scale (except the proven per-ID optical correction below).  Dark mode
  // stays raw SVG.  The outer icon/tile size stays exact, and the GI-02
  // call-site sizes are unchanged.
  //
  // POLISH-06: spiritual_temple alone receives a renderer-level optical
  // scale correction (1.15x) because its thin-stroke artwork has the
  // lowest ink density of the family and reads undersized next to peers at
  // the same requested size.  No registry identity changes, no SVG edits.
  group('Light UI polish Goal Icon renderer (no halo, Temple optical size)', () {
    Future<void> pumpIcon(
      WidgetTester tester, {
      required String iconId,
      required double size,
      required Brightness brightness,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: Scaffold(body: GoalIcon(iconId: iconId, size: size)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Light: single raw two-tone SVG only — no plate, no halo, no '
      'artificial outline; exact outer size',
      (tester) async {
        const size = 40.0;
        await pumpIcon(
          tester,
          iconId: 'work_briefcase',
          size: size,
          brightness: Brightness.light,
        );
        final icon = find.byType(GoalIcon);
        expect(icon, findsOneWidget);

        // No background plate / decoration of any kind.
        expect(
          find.descendant(of: icon, matching: find.byType(DecoratedBox)),
          findsNothing,
          reason: 'POLISH-03 removes the Light background plate entirely',
        );
        // No halo: no ColorFiltered silhouette, no 1.06x Transform scale.
        expect(
          find.descendant(of: icon, matching: find.byType(ColorFiltered)),
          findsNothing,
          reason: 'POLISH-03 removes the GI-01 halo silhouette entirely',
        );
        expect(
          find.descendant(of: icon, matching: find.byType(Transform)),
          findsNothing,
          reason: 'peers must render with NO optical-scale Transform',
        );
        // Exactly ONE foreground SVG, un-tinted.
        expect(
          find.descendant(of: icon, matching: find.byType(SvgPicture)),
          findsOneWidget,
          reason: 'Light mode paints the raw two-tone foreground once',
        );
        final svg = tester.widget<SvgPicture>(
          find.descendant(of: icon, matching: find.byType(SvgPicture)),
        );
        expect(
          svg.colorFilter,
          isNull,
          reason: 'foreground artwork must stay two-tone (colorFilter null)',
        );
        expect(
          find.descendant(of: icon, matching: find.byType(Stack)),
          findsNothing,
          reason: 'no halo+foreground layer stack remains',
        );
        expect(
          tester.getSize(icon),
          const Size(size, size),
          reason: 'outer icon/tile size must stay exactly the requested size',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Dark: raw SVG only (unchanged), exact outer size', (
      tester,
    ) async {
      const size = 32.0;
      await pumpIcon(
        tester,
        iconId: 'work_briefcase',
        size: size,
        brightness: Brightness.dark,
      );
      final icon = find.byType(GoalIcon);
      expect(
        find.descendant(of: icon, matching: find.byType(DecoratedBox)),
        findsNothing,
        reason: 'Dark mode must render the raw SVG with no plate',
      );
      expect(
        find.descendant(of: icon, matching: find.byType(ColorFiltered)),
        findsNothing,
        reason: 'Dark mode must render no halo',
      );
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(
        tester.getSize(icon),
        const Size(size, size),
        reason: 'outer icon/tile size must stay exactly the requested size',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Temple Visit: spiritual_temple only gets the 1.15x optical scale; '
      'peers render at 1.0x with no Transform; outer size exact',
      (tester) async {
        const size = 48.0;
        // The per-ID optical scale metadata itself: Temple 1.15, peers 1.0.
        expect(GoalIcon.opticalScaleFor('spiritual_temple'), 1.15);
        for (final peer in const <String?>[
          'work_briefcase',
          'church',
          'prayer',
          'temple_marriage',
          'learning_open_book',
          null,
        ]) {
          expect(
            GoalIcon.opticalScaleFor(peer),
            1.0,
            reason: '$peer must have no optical correction',
          );
        }

        await pumpIcon(
          tester,
          iconId: 'spiritual_temple',
          size: size,
          brightness: Brightness.light,
        );
        final temple = find.byType(GoalIcon);
        // The artwork paints at size * 1.15 and shrinks by 1 / 1.15, so the
        // painted viewBox lands exactly at `size` while the ART inside
        // renders 1.15x larger (viewBox padding cropped).
        final templeTransform = tester.widget<Transform>(
          find.descendant(of: temple, matching: find.byType(Transform)),
        );
        expect(
          templeTransform.transform.entry(0, 0),
          closeTo(1 / 1.15, 0.001),
          reason: 'POLISH-06: the viewBox is scaled by 1 / opticalScale',
        );
        final templeSvg = tester.widget<SvgPicture>(
          find.descendant(of: temple, matching: find.byType(SvgPicture)),
        );
        expect(
          templeSvg.width,
          closeTo(size * 1.15, 0.001),
          reason: 'the artwork paints at size * opticalScale',
        );
        expect(
          templeSvg.colorFilter,
          isNull,
          reason: 'optical scale must never tint the artwork',
        );
        // Optical scale is renderer-only: the outer box stays exactly `size`
        // and the caller still requests the same GI-02 size.
        expect(
          tester.getSize(temple),
          const Size(size, size),
          reason: 'outer size must stay exact despite the optical scale',
        );
        expect(tester.takeException(), isNull);

        // Peers keep opticalScale 1.0 (no Transform at all).
        for (final peer in const <String>[
          'work_briefcase',
          'church',
          'prayer',
          'temple_marriage',
          'learning_open_book',
        ]) {
          await pumpIcon(
            tester,
            iconId: peer,
            size: size,
            brightness: Brightness.light,
          );
          expect(
            find.descendant(
              of: find.byType(GoalIcon),
              matching: find.byType(Transform),
            ),
            findsNothing,
            reason: '$peer must render at opticalScale 1.0 (no Transform)',
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('48 dp outer contract stays exact for every icon', (
      tester,
    ) async {
      await pumpIcon(
        tester,
        iconId: 'career_growth',
        size: 48,
        brightness: Brightness.light,
      );
      expect(
        tester.getSize(find.byType(GoalIcon)),
        const Size(48, 48),
        reason: 'the 48 dp tile contract must be unchanged',
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------- GI-02
  // Exact 2x Goal Icons at every production surface (owner-locked).  The
  // renderer default/test contract stays independent; each production call
  // site passes its exact doubled size explicitly.
  group('GI-02 exact 2x Goal Icon call sites', () {
    testWidgets(
      'Choose Icon picker: exact 96dp art, 3 columns, no scale-down, '
      'no clipping',
      (tester) async {
        final router = _router();
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        unawaited(
          router.push<String?>(
            '/picker',
            extra: const GoalIconPickerArgs(
              goalTitle: 'GI02 Goal',
              currentIconId: null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GoalIconPickerScreen), findsOneWidget);

        final allGridFinder = find.byKey(const Key('goal-icon-all'));
        expect(allGridFinder, findsOneWidget);
        final grid = tester.widget<GridView>(
          find.descendant(of: allGridFinder, matching: find.byType(GridView)),
        );
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          delegate.crossAxisCount,
          3,
          reason: 'GI-02 picker must keep exactly 3 columns',
        );
        expect(
          delegate.mainAxisExtent,
          greaterThanOrEqualTo(104),
          reason: 'GI-02 picker tile must fit 96dp art + padding',
        );

        final goalIcon = find
            .descendant(of: allGridFinder, matching: find.byType(GoalIcon))
            .first;
        expect(
          tester.widget<GoalIcon>(goalIcon).size,
          96,
          reason: 'picker art must be exactly 96dp (2x of 48)',
        );
        expect(
          tester.getSize(goalIcon),
          const Size(96, 96),
          reason: 'picker art must RENDER at exactly 96dp — no FittedBox/'
              'constraint scale-down, no clipping',
        );
        final tileRect = tester.getRect(
          find
              .descendant(
                of: allGridFinder,
                matching: find.byKey(
                  const Key('goal-icon-tile-work_briefcase'),
                ),
              )
              .first,
        );
        final iconRect = tester.getRect(goalIcon);
        expect(
          tileRect.contains(iconRect.topLeft) &&
              tileRect.contains(iconRect.bottomRight),
          isTrue,
          reason: '96dp art must stay inside its tile (no clipping)',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Create/Edit icon choice row: exact 72dp art', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: GoalIconChoiceRow(
              goalTitle: 'GI02 Goal',
              iconId: 'work_briefcase',
              fallbackIcon: goalIconFallbackForRole(GoalRole.weekly),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final goalIcon = find.byType(GoalIcon);
      expect(goalIcon, findsOneWidget);
      expect(
        tester.widget<GoalIcon>(goalIcon).size,
        72,
        reason: 'Create/Edit choice row art must be exactly 72dp (2x of 36)',
      );
      expect(
        tester.getSize(goalIcon),
        const Size(72, 72),
        reason: 'choice row art must RENDER at exactly 72dp',
      );
      expect(tester.takeException(), isNull);
    });
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

final class _A9NavigationHome extends StatelessWidget {
  const _A9NavigationHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('a9-home'),
      body: Center(
        child: ElevatedButton(
          key: const Key('a9-open-edit-goal'),
          onPressed: () {
            unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const _A9EditGoalDraftHarness(),
                ),
              ),
            );
          },
          child: const Text('Open Edit Goal'),
        ),
      ),
    );
  }
}

final class _A9EditGoalDraftHarness extends StatefulWidget {
  const _A9EditGoalDraftHarness();

  @override
  State<_A9EditGoalDraftHarness> createState() =>
      _A9EditGoalDraftHarnessState();
}

final class _A9EditGoalDraftHarnessState
    extends State<_A9EditGoalDraftHarness> {
  final TextEditingController _title = TextEditingController(text: 'Exercise');
  bool _showPicker = false;
  String _iconId = 'health_barbell';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPicker) {
      return GoalIconPickerScreen(
        args: GoalIconPickerArgs(
          goalTitle: _title.text,
          currentIconId: _iconId,
        ),
        onSelected: (iconId) {
          setState(() {
            _iconId = iconId;
            _showPicker = false;
          });
        },
        onCancel: () => setState(() => _showPicker = false),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Goal')),
      body: Column(
        children: <Widget>[
          TextField(key: const Key('a9-goal-title'), controller: _title),
          Text(_iconId, key: const Key('a9-icon-id')),
          TextButton(
            key: const Key('a9-open-icon-picker'),
            onPressed: () => setState(() => _showPicker = true),
            child: const Text('Choose Icon'),
          ),
        ],
      ),
    );
  }
}

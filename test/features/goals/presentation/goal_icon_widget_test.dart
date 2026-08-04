import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    expect(find.bySemanticsLabel('Work and career'), findsOneWidget);
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

    expect(find.text('Open Book'), findsOneWidget);
    expect(find.text('Suggested from "Scripture Study"'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('goal-icon-choice-row'))).label,
      contains('Open Book'),
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

    expect(find.text('Wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Choose Icon is six-icon, searchable, selectable, and routable', (
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
    for (final label in <String>[
      'Briefcase',
      'Open Book',
      'Wallet',
      'Two People',
      'Temple',
      'Rings',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('goal-icon-picker-save')), findsOneWidget);

    await tester.tap(find.text('Open Book'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Open Book, Learning and study, selected'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('goal-icon-picker-save')));
    await tester.pumpAndSettle();
    expect(await result, 'learning_open_book');
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Choose Icon suggestions are capped and search has clear/no-match states',
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
      expect(find.text('Temple'), findsAtLeastNWidgets(1));

      await tester.enterText(
        find.byKey(const Key('goal-icon-search')),
        'budget',
      );
      await tester.pumpAndSettle();
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Briefcase'), findsNothing);
      expect(find.byKey(const Key('goal-icon-search-clear')), findsOneWidget);

      await tester.tap(find.byKey(const Key('goal-icon-search-clear')));
      await tester.pumpAndSettle();
      final allIcons = find.byKey(const Key('goal-icon-all'));
      expect(
        find.descendant(of: allIcons, matching: find.text('Briefcase')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: allIcons, matching: find.text('Rings')),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('goal-icon-search')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No icons found.'), findsOneWidget);
      expect(find.byKey(const Key('goal-icon-picker-save')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('Open Book'), findsAtLeastNWidgets(1));
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

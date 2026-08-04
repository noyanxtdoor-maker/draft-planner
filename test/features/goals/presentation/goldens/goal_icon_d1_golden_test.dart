import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';
import 'package:rmplanner/features/goals/presentation/goal_icon_picker_screen.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon_choice_row.dart';

void main() {
  for (final definition in GoalIconRegistry.allIcons) {
    for (final size in <double>[24, 28, 32]) {
      for (final brightness in Brightness.values) {
        final themeName = brightness == Brightness.dark ? 'dark' : 'light';
        final key = Key('d1-icon-${definition.id}-${size.toInt()}-$themeName');
        testWidgets(
          'D1 icon ${definition.id} at ${size.toInt()}dp on $themeName',
          (tester) async {
            _configureViewport(tester, const Size(80, 80));
            await tester.pumpWidget(
              _harness(
                brightness: brightness,
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    color: brightness == Brightness.dark
                        ? AppTheme.background
                        : const Color(0xFFF4F4F4),
                    alignment: Alignment.center,
                    child: GoalIcon(
                      iconId: definition.id,
                      size: size,
                      semanticLabel: definition.semanticsLabel,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(key),
              matchesGoldenFile(
                'goldens/goal_icon_d1/${definition.id}_'
                '${themeName}_${size.toInt()}dp.png',
              ),
            );
          },
        );
      }
    }
  }

  _registerContextGolden(
    name: 'picker_360_scale_1',
    viewport: const Size(360, 800),
    child: const GoalIconPickerScreen(
      args: GoalIconPickerArgs(
        goalTitle: 'Scripture Study',
        currentIconId: 'learning_open_book',
      ),
    ),
  );
  _registerContextGolden(
    name: 'picker_393_scale_1_15',
    viewport: const Size(393, 874),
    textScale: 1.15,
    child: const GoalIconPickerScreen(
      args: GoalIconPickerArgs(
        goalTitle: 'Monthly Budget',
        currentIconId: 'finance_wallet',
      ),
    ),
  );
  _registerContextGolden(
    name: 'picker_411_scale_1_30',
    viewport: const Size(411, 915),
    textScale: 1.3,
    child: const GoalIconPickerScreen(
      args: GoalIconPickerArgs(
        goalTitle: 'Temple Attendance',
        currentIconId: 'spiritual_temple',
      ),
    ),
  );
  _registerContextGolden(
    name: 'picker_search_wallet',
    viewport: const Size(393, 874),
    child: const GoalIconPickerScreen(
      args: GoalIconPickerArgs(goalTitle: 'Budget Review', currentIconId: null),
    ),
    beforeCapture: (tester) async {
      await tester.enterText(
        find.byKey(const Key('goal-icon-search')),
        'budget',
      );
      await tester.pumpAndSettle();
    },
  );
  _registerContextGolden(
    name: 'create_icon_suggestion',
    viewport: const Size(393, 150),
    child: _choiceSurface(
      goalTitle: 'Scripture Study',
      iconId: 'learning_open_book',
      showSuggestion: true,
    ),
  );
  _registerContextGolden(
    name: 'create_icon_manual_selection',
    viewport: const Size(393, 150),
    child: _choiceSurface(goalTitle: 'Budget Review', iconId: 'finance_wallet'),
  );
  _registerContextGolden(
    name: 'edit_icon_selection',
    viewport: const Size(393, 150),
    child: _choiceSurface(
      goalTitle: 'Renamed Goal',
      iconId: 'spiritual_temple',
    ),
  );
  _registerContextGolden(
    name: 'home_goal_card_compact',
    viewport: const Size(360, 160),
    child: _goalCard(
      key: 'home-golden-card',
      iconId: 'work_briefcase',
      iconSize: 36,
      title: 'Job Applications',
      value: '2/5',
      trailing: "Today's Goal\n0/1",
    ),
  );
  _registerContextGolden(
    name: 'home_goal_card_wide',
    viewport: const Size(411, 180),
    child: _goalCard(
      key: 'home-golden-card',
      iconId: 'spiritual_temple',
      iconSize: 40,
      title: 'Temple Visit',
      value: '1/2',
      trailing: 'Next Visit\nJun 15',
    ),
  );
  _registerContextGolden(
    name: 'weekly_planning_goal_row',
    viewport: const Size(393, 116),
    child: _goalRow(
      key: 'weekly-golden-row',
      iconId: 'learning_open_book',
      title: 'Scripture Study',
      value: '5/7',
    ),
  );
  _registerContextGolden(
    name: 'archive_row_compact',
    viewport: const Size(393, 160),
    child: _archiveRow(
      key: 'archive-golden-row',
      iconId: 'finance_wallet',
      title: 'Budget Review',
      role: 'Was weekly goal',
      compact: true,
    ),
  );
  _registerContextGolden(
    name: 'archive_row_wide',
    viewport: const Size(411, 160),
    child: _archiveRow(
      key: 'archive-golden-row',
      iconId: 'social_two_people',
      title: 'Meaningful Connections',
      role: 'Was weekly goal',
      compact: false,
    ),
  );
  _registerContextGolden(
    name: 'null_and_unknown_fallbacks',
    viewport: const Size(180, 100),
    child: RepaintBoundary(
      key: const Key('fallback-golden-surface'),
      child: Container(
        color: AppTheme.background,
        padding: const EdgeInsets.all(20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            GoalIcon(iconId: null, size: 32, semanticLabel: 'No icon selected'),
            GoalIcon(
              iconId: 'unknown-id',
              size: 32,
              semanticLabel: 'Unknown icon fallback',
            ),
          ],
        ),
      ),
    ),
  );
  _registerContextGolden(
    name: 'choice_row_long_title_scale_1_30',
    viewport: const Size(360, 180),
    textScale: 1.3,
    child: _choiceSurface(
      goalTitle: 'A long goal title that remains readable after renaming',
      iconId: 'marriage_rings',
    ),
  );
}

void _registerContextGolden({
  required String name,
  required Size viewport,
  required Widget child,
  double textScale = 1,
  Future<void> Function(WidgetTester tester)? beforeCapture,
}) {
  final key = Key('d1-context-$name');
  testWidgets('D1 contextual golden: $name', (tester) async {
    _configureViewport(tester, viewport);
    await tester.pumpWidget(
      _harness(
        textScale: textScale,
        child: RepaintBoundary(key: key, child: child),
      ),
    );
    await tester.pumpAndSettle();
    if (beforeCapture != null) {
      await beforeCapture(tester);
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/goal_icon_d1/context_$name.png'),
    );
  });
}

void _configureViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _harness({
  required Widget child,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) {
  final dark = brightness == Brightness.dark;
  final theme = dark
      ? AppTheme.dark()
      : ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppTheme.rose,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F4F4),
        );
  return MaterialApp(
    theme: theme,
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        );
      },
    ),
  );
}

Widget _choiceSurface({
  required String goalTitle,
  required String? iconId,
  bool showSuggestion = false,
}) {
  return Scaffold(
    backgroundColor: AppTheme.background,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: GoalIconChoiceRow(
          goalTitle: goalTitle,
          iconId: iconId,
          fallbackIcon: Icons.flag_outlined,
          showSuggestion: showSuggestion,
          onTap: () {},
        ),
      ),
    ),
  );
}

Widget _goalCard({
  required String key,
  required String iconId,
  required double iconSize,
  required String title,
  required String value,
  required String trailing,
}) {
  return Scaffold(
    backgroundColor: AppTheme.background,
    body: Padding(
      padding: const EdgeInsets.all(18),
      child: Card(
        key: Key(key),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              GoalIcon(iconId: iconId, size: iconSize),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppTypography.cardTitle),
                    Text(value, style: AppTypography.metricLarge),
                  ],
                ),
              ),
              Container(
                width: 116,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF292B2F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(trailing, style: AppTypography.secondary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _goalRow({
  required String key,
  required String iconId,
  required String title,
  required String value,
}) {
  return Scaffold(
    backgroundColor: AppTheme.background,
    body: Padding(
      padding: const EdgeInsets.all(18),
      child: Card(
        key: Key(key),
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                GoalIcon(iconId: iconId, size: 32),
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppTypography.cardTitle),
                    Text(value, style: AppTypography.metricCompact),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.more_vert),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _archiveRow({
  required String key,
  required String iconId,
  required String title,
  required String role,
  required bool compact,
}) {
  return Scaffold(
    backgroundColor: AppTheme.background,
    body: Padding(
      padding: const EdgeInsets.all(18),
      child: Card(
        key: Key(key),
        child: SizedBox(
          height: compact ? 92 : 96,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 12,
                top: compact ? 32 : 30,
                child: GoalIcon(iconId: iconId, size: compact ? 28 : 32),
              ),
              Positioned(
                left: compact ? 52 : 56,
                top: 10,
                right: 92,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
              ),
              Positioned(
                left: compact ? 52 : 56,
                top: 34,
                child: Text(
                  'Archived on Aug 4, 2026',
                  style: AppTypography.secondary,
                ),
              ),
              Positioned(
                left: compact ? 52 : 56,
                top: 56,
                child: Text(role, style: AppTypography.secondary),
              ),
              const Positioned(
                right: 12,
                top: 33,
                child: Text('Restore', style: AppTypography.button),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

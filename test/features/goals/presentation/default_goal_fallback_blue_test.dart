import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon_choice_row.dart';

void main() {
  // T11: the default null/unknown-icon Goal fallback renders the existing
  // #5CAEC9 blue in every theme combination, with the role glyph preserved.
  Future<Color?> renderedFallbackColor(
    WidgetTester tester,
    ThemeColorMode mode,
    Brightness brightness,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light(mode)
            : AppTheme.dark(mode),
        home: Scaffold(
          body: GoalIcon(
            iconId: null,
            size: 32,
            fallbackIcon: goalIconFallbackForRole(null),
            color: AppTheme.goalIconFallbackBlue,
          ),
        ),
      ),
    );
    final icon = tester.widgetList<Icon>(find.byType(Icon)).single;
    return icon.color;
  }

  test('GoalIcon constructor default is the goal artwork-family blue', () {
    // The constructor default itself must be blue (contract Step 8), not
    // Rose and not theme primary.
    const icon = GoalIcon(iconId: null);
    expect(icon.color, const Color(0xFF5CAEC9));
    expect(icon.color, AppTheme.goalIconFallbackBlue);
  });

  test('fallback glyph is the no-role flag icon', () {
    expect(goalIconFallbackForRole(null), Icons.flag_outlined);
    expect(
      goalIconFallbackForRole(GoalRole.dailyWeekly),
      Icons.today_outlined,
    );
    expect(goalIconFallbackForRole(GoalRole.weekly), Icons.flag_outlined);
    expect(
      goalIconFallbackForRole(GoalRole.weeklyMonthly),
      Icons.calendar_month_outlined,
    );
  });

  for (final mode in ThemeColorMode.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'null-icon fallback renders #5CAEC9 in $mode/$brightness',
        (tester) async {
          final color = await renderedFallbackColor(tester, mode, brightness);
          expect(color, const Color(0xFF5CAEC9));
        },
      );
    }
  }

  testWidgets('choice row fallback icon paints the blue token',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(ThemeColorMode.rose),
        home: Scaffold(
          body: Center(
            child: GoalIconChoiceRow(
              goalTitle: 'Sample1',
              iconId: null,
              fallbackIcon: goalIconFallbackForRole(null),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final icon = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byKey(const Key('goal-icon-choice-row')),
            matching: find.byIcon(Icons.flag_outlined),
          ),
        )
        .single;
    expect(icon.color, AppTheme.goalIconFallbackBlue);
    expect(icon.size, 72);
  });

  testWidgets('spiritual_temple keeps its 1.15 optical scale', (tester) async {
    expect(GoalIcon.opticalScaleFor('spiritual_temple'), 1.15);
    expect(GoalIcon.opticalScaleFor('unknown-icon-id'), 1.0);
    expect(GoalIcon.opticalScaleFor(null), 1.0);
  });
}

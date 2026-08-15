import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/goals/presentation/goal_icon_picker_screen.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';
import 'package:rmplanner/features/settings/presentation/appearance_screen.dart';
import 'package:rmplanner/features/settings/presentation/settings_screen.dart';

import '../../../support/test_dependencies.dart';

/// Pack B2 bounded Light-appearance walkthrough.  Deliberately small: it
/// catches shared-token and feature-local light mistakes across the main
/// surfaces without manufacturing a large golden set.  Dark mode coverage is
/// the existing 113-master golden suite (byte-identical gate); owner physical
/// review remains the authority for pixel-perfect Light acceptance.
void main() {
  Future<AppDatabase> pumpApp(
    WidgetTester tester, {
    double width = 393,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startup = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    await startup.completeOnboarding();
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        initialAppearance: AppearanceMode.light,
      ),
    );
    await tester.pumpAndSettle();
    return database;
  }

  bool rendersLight(WidgetTester tester) =>
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .brightness ==
      Brightness.light;

  Future<void> goToTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byKey(const Key('main-bottom-navigation')),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  group('B2 light walkthrough', () {
    testWidgets('Home renders Light at 360 / 393 / 411 without exceptions',
        (tester) async {
      for (final width in <double>[360, 393, 411]) {
        await pumpApp(tester, width: width);
        expect(rendersLight(tester), isTrue);
        expect(find.byKey(const Key('home-app-bar')), findsOneWidget);
        expect(tester.takeException(), isNull);
        // The Home scaffold paints the light background.
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, isNull);
      }
    });

    testWidgets('Home at 393 textScale 1.3 stays overflow-free in Light',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, width: 393);
      expect(rendersLight(tester), isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Planner renders Light with the light date-strip surface',
        (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'Planner');
      expect(find.byKey(const Key('planner-week-strip')), findsOneWidget);
      final strip = tester.widget<DecoratedBox>(
        find.byKey(const Key('planner-date-strip-surface')),
      );
      expect(strip.decoration, isA<BoxDecoration>());
      final decoration = strip.decoration as BoxDecoration;
      // B2-CORRECTION: the date strip resolves the active Light app/nav
      // surface (surfaceOf -> surfaceContainer).
      expect(decoration.color, AppTheme.roseLightNav);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Contacts renders Light without exceptions', (tester) async {
      await pumpApp(tester, width: 360);
      await goToTab(tester, 'Contacts');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'More -> Settings -> Appearance keeps Light and shows selection',
        (tester) async {
      await pumpApp(tester);
      await goToTab(tester, 'More');
      await tester.tap(find.byKey(const Key('more-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceScreen), findsOneWidget);
      expect(rendersLight(tester), isTrue);
      final darkOption = tester.widget<RadioListTile<AppearanceMode>>(
        find.byKey(const Key('appearance-option-light')),
      );
      expect(darkOption.value, AppearanceMode.light);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Choose Icon appbar stays pinned on the light surface',
        (tester) async {
      await pumpApp(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: GoalIconPickerScreen(
            args: const GoalIconPickerArgs(
              goalTitle: 'Find a better job',
              currentIconId: 'career_growth',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      // B2-CORRECTION: the pinned Choose Icon app bar resolves the active
      // Light app/nav surface (surfaceOf -> surfaceContainer).
      expect(appBar.backgroundColor, AppTheme.roseLightNav);
      expect(appBar.surfaceTintColor, Colors.transparent);
      expect(appBar.scrolledUnderElevation, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'GoalIcon renders the raw two-tone SVG in Light and Dark — no '
        'plate and no halo (Light UI Final Polish POLISH-03)',
        (tester) async {
      Future<int> plateCount() async {
        await tester.pump();
        return find
            .descendant(
              of: find.byType(GoalIcon),
              matching: find.byType(DecoratedBox),
            )
            .evaluate()
            .where((element) {
              final widget = element.widget as DecoratedBox;
              final decoration = widget.decoration;
              return decoration is BoxDecoration &&
                  decoration.color == AppTheme.surface;
            })
            .length;
      }

      Future<int> haloCount() async {
        await tester.pump();
        return find
            .descendant(
              of: find.byType(GoalIcon),
              matching: find.byType(ColorFiltered),
            )
            .evaluate()
            .where((element) {
              final filter = element.widget as ColorFiltered;
              return filter.colorFilter ==
                  const ColorFilter.mode(AppTheme.surface, BlendMode.srcIn);
            })
            .length;
      }

      Future<int> svgCount() async {
        await tester.pump();
        return find
            .descendant(of: find.byType(GoalIcon), matching: find.byType(SvgPicture))
            .evaluate()
            .length;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Center(child: GoalIcon(iconId: 'career_growth', size: 48)),
          ),
        ),
      );
      // POLISH-03: NO plate, NO halo, exactly one raw un-tinted foreground
      // SVG in Light mode.
      expect(await plateCount(), 0);
      expect(await haloCount(), 0);
      expect(await svgCount(), 1);

      // Force a fresh tree so the identical const GoalIcon cannot be reused
      // across the brightness switch.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: Center(child: GoalIcon(iconId: 'career_growth', size: 48)),
          ),
        ),
      );
      // Dark: raw SVG only — no plate, no halo.
      expect(await plateCount(), 0);
      expect(await haloCount(), 0);
      expect(await svgCount(), 1);
    });
  });
}

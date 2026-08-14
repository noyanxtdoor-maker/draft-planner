import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';

/// B2-CORRECTION fail-first: the shared color-less titleTextStyle bug.
///
/// Under Light the resolved title style must carry the active onSurface
/// (never null — null renders white via TextPainter and is invisible on the
/// Light app bar).  Under Dark it must be explicit white so the existing
/// dark masters stay pixel-identical to the pre-correction render.
void main() {
  testWidgets(
    'Light: plain shared AppBar title resolves to non-null Light onSurface',
    (tester) async {
      Color? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            appBar: AppBar(
              title: Builder(
                builder: (context) {
                  resolved = DefaultTextStyle.of(context).style.color;
                  return const Text('Home');
                },
              ),
            ),
          ),
        ),
      );
      expect(resolved, isNotNull);
      expect(resolved, const Color(0xFF1A1C1F));
    },
  );

  testWidgets(
    'Light: InternalAppBar title resolves to non-null Light onSurface',
    (tester) async {
      Color? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            appBar: InternalAppBar(
              title: Builder(
                builder: (context) {
                  resolved = DefaultTextStyle.of(context).style.color;
                  return const Text('Settings');
                },
              ),
            ),
          ),
        ),
      );
      expect(resolved, isNotNull);
      expect(resolved, const Color(0xFF1A1C1F));
    },
  );

  testWidgets(
    'Dark: shared AppBar + InternalAppBar titles stay explicit white',
    (tester) async {
      Color? appBarResolved;
      Color? internalResolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            appBar: AppBar(
              title: Builder(
                builder: (context) {
                  appBarResolved = DefaultTextStyle.of(context).style.color;
                  return const Text('Home');
                },
              ),
            ),
            body: InternalAppBar(
              title: Builder(
                builder: (context) {
                  internalResolved = DefaultTextStyle.of(context).style.color;
                  return const Text('Settings');
                },
              ),
            ),
          ),
        ),
      );
      // The pre-correction render painted white through the null-color path;
      // the explicit contract keeps that pixel color exact.
      expect(appBarResolved, isNotNull);
      expect(appBarResolved, Colors.white);
      expect(internalResolved, isNotNull);
      expect(internalResolved, Colors.white);
    },
  );
}

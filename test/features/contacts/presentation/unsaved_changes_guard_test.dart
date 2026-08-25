import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/presentation/unsaved_changes_guard.dart';

void main() {
  Future<UnsavedChangesDecision?> openGuard(WidgetTester tester) async {
    UnsavedChangesDecision? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                decision = await showUnsavedChangesGuard(context);
              },
              child: const Text('Open guard'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open guard'));
    await tester.pumpAndSettle();
    return decision;
  }

  testWidgets('offers explicit save, discard, and keep-editing decisions', (
    tester,
  ) async {
    await openGuard(tester);

    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Save & leave'), findsOneWidget);
    expect(find.text('Discard & leave'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
  });

  testWidgets('returns the selected explicit decision', (tester) async {
    UnsavedChangesDecision? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                decision = await showUnsavedChangesGuard(context);
              },
              child: const Text('Open guard'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open guard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard & leave'));
    await tester.pumpAndSettle();

    expect(decision, UnsavedChangesDecision.discardAndLeave);
  });
}

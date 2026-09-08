import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/notifications/presentation/reminder_time_picker.dart';

void main() {
  testWidgets(
    'Custom 6 saves and repeated open/cancel/back stays lifecycle-safe',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ReminderLauncher()));

      await tester.tap(find.byKey(const Key('open-reminder-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom...'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '6');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Selected: 6'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('open-reminder-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Selected: none'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('open-reminder-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom...'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Selected: none'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Custom validation remains visible and retryable', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _ReminderLauncher()));
    await tester.tap(find.byKey(const Key('open-reminder-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10081');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter 0 to 10080 minutes.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '27');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 27'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _ReminderLauncher extends StatefulWidget {
  const _ReminderLauncher();

  @override
  State<_ReminderLauncher> createState() => _ReminderLauncherState();
}

final class _ReminderLauncherState extends State<_ReminderLauncher> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Selected: ${_selected?.toString() ?? 'none'}'),
            FilledButton(
              key: const Key('open-reminder-picker'),
              onPressed: () async {
                final selected = await showReminderTimePicker(context);
                if (mounted) setState(() => _selected = selected);
              },
              child: const Text('Open reminder'),
            ),
          ],
        ),
      ),
    );
  }
}

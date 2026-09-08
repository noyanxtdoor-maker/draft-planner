import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_form_sheet.dart';

void main() {
  const coordinate = MapCoordinate(latitude: 14.59951, longitude: 120.98422);

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget editor({
    required Future<void> Function(SavedPlaceDraft) onSave,
    VoidCallback? onCancel,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: SavedPlaceFormScreen(
          coordinate: coordinate,
          onSave: onSave,
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  testWidgets('full-screen editor hides coordinates and deferred controls', (
    tester,
  ) async {
    setViewport(tester);
    await tester.pumpWidget(editor(onSave: (_) async {}));

    expect(find.byKey(const Key('saved-place-form-screen')), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('14.59951, 120.98422'), findsNothing);
    // VS-15 M6.1: the Boundary section is now part of the form (previously a
    // deferred control); coordinates stay hidden and the map never mounts.
    expect(find.text('Boundary'), findsNWidgets(2));
    expect(find.byKey(const Key('saved-place-add-boundary')), findsOneWidget);
    expect(find.text('Boundary Color'), findsOneWidget);
    // Pass 4: the grid is content-sized rows — no fixed-aspect tile can
    // overflow, and all nine category labels stay fully visible.
    expect(find.byType(GridView), findsNothing);
    expect(
      find.byKey(const Key('saved-place-category-information')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('saved-place-category-laundry')),
      findsOneWidget,
    );
    expect(find.byType(Icon), findsAtLeastNWidgets(11));
  });

  testWidgets('Cancel and blank label never invoke persistence', (
    tester,
  ) async {
    setViewport(tester);
    var saveCount = 0;
    var cancelCount = 0;
    await tester.pumpWidget(
      editor(
        onSave: (_) async => saveCount += 1,
        onCancel: () => cancelCount += 1,
      ),
    );

    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pump();
    expect(find.text('Place name cannot be blank.'), findsOneWidget);
    expect(saveCount, 0);

    await tester.tap(find.byKey(const Key('saved-place-cancel')));
    expect(cancelCount, 1);
    expect(saveCount, 0);
  });

  testWidgets('Standard emits category without exposing a manual hex field', (
    tester,
  ) async {
    setViewport(tester);
    final saved = <SavedPlaceDraft>[];
    await tester.pumpWidget(editor(onSave: (draft) async => saved.add(draft)));
    await tester.enterText(
      find.byKey(const Key('saved-place-label')),
      '  Family Home  ',
    );
    await tester.tap(find.byKey(const Key('saved-place-category-food')));
    await tester.pump();
    expect(find.byKey(const Key('saved-place-hex')), findsNothing);
    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pump();

    expect(saved, hasLength(1));
    expect(saved.single.label, 'Family Home');
    expect(saved.single.markerMode, SavedPlaceMarkerMode.standard);
    expect(saved.single.standardCategory, SavedPlaceStandardCategory.food);
    expect(saved.single.markerColorHex, '#175A8F');
  });

  testWidgets('Standard exposes the continuous project color picker', (
    tester,
  ) async {
    setViewport(tester);
    await tester.pumpWidget(editor(onSave: (_) async {}));
    await tester.tap(find.byKey(const Key('saved-place-continuous-color')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-event-color-picker')), findsOneWidget);
    expect(
      find.byKey(const Key('planner-event-color-sv-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('planner-event-color-hue-picker')),
      findsOneWidget,
    );
  });

  testWidgets('Custom has no presets or color row and saves one emoji', (
    tester,
  ) async {
    setViewport(tester);
    final saved = <SavedPlaceDraft>[];
    await tester.pumpWidget(editor(onSave: (draft) async => saved.add(draft)));
    await tester.enterText(
      find.byKey(const Key('saved-place-label')),
      'Favorite Cafe',
    );
    await tester.tap(find.text('Custom'));
    await tester.pump();

    expect(find.byKey(const Key('saved-place-continuous-color')), findsNothing);
    expect(find.byKey(const Key('saved-place-hex')), findsNothing);
    expect(find.byType(Wrap), findsNothing);

    await tester.enterText(find.byKey(const Key('saved-place-emoji')), 'A');
    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pump();
    expect(saved, isEmpty);
    expect(
      find.text('Choose exactly one emoji for the custom marker.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('saved-place-emoji')), '☕');
    await tester.tap(find.byKey(const Key('saved-place-save')));
    await tester.pump();
    expect(saved, hasLength(1));
    expect(saved.single.markerMode, SavedPlaceMarkerMode.custom);
    expect(saved.single.customEmoji, '☕');
  });

  testWidgets('Custom input formatter rejects multiple graphemes', (
    tester,
  ) async {
    setViewport(tester);
    await tester.pumpWidget(editor(onSave: (_) async {}));
    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('saved-place-emoji')), '😀😁');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('saved-place-emoji')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(find.byKey(const Key('saved-place-emoji')), 'word7');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('saved-place-emoji')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('blank-space tap clears focus and removes the cursor', (
    tester,
  ) async {
    setViewport(tester);
    await tester.pumpWidget(editor(onSave: (_) async {}));
    await tester.tap(find.byKey(const Key('saved-place-label')));
    await tester.pump();
    final editable = find.descendant(
      of: find.byKey(const Key('saved-place-label')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    await tester.tapAt(const Offset(760, 1500));
    await tester.pump();
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isFalse);
  });

  testWidgets('edit mode prefills the approved editor without coordinates', (
    tester,
  ) async {
    setViewport(tester);
    final place = SavedPlace(
      id: 'place-1',
      profileId: 'profile-1',
      label: 'Existing Place',
      coordinate: coordinate,
      markerMode: SavedPlaceMarkerMode.standard,
      standardCategory: SavedPlaceStandardCategory.transit,
      customEmoji: null,
      markerColorHex: '#0A72B8',
      createdAtUtc: DateTime.utc(2026, 9, 2),
      updatedAtUtc: DateTime.utc(2026, 9, 2),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SavedPlaceFormScreen(
            coordinate: coordinate,
            initialPlace: place,
            onSave: (_) async {},
            onCancel: () {},
          ),
        ),
      ),
    );
    expect(find.text('Edit Place'), findsOneWidget);
    expect(find.byKey(const Key('saved-place-hex')), findsNothing);
    expect(find.textContaining('14.59951'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('saved-place-label')))
          .controller!
          .text,
      'Existing Place',
    );
  });
}

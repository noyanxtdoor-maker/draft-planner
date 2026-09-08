import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';

void main() {
  test('Contact Group palette has the exact approved 32-color vocabulary', () {
    expect(
      ContactGroupColorPalette.recommended
          .map((color) => '${color.name}:${color.argb.toRadixString(16)}')
          .toList(),
      <String>[
        'Rose ember:ffe2944e',
        'Dusty crimson:ffe4825b',
        'Terracotta rose:ffe89c72',
        'Plum brown:ffd77d78',
        'Burnt apricot:ffe3b756',
        'Copper:ffeacc80',
        'Ochre orange:ffbdb66d',
        'Rust:ffd1a947',
        'Antique gold:ffaf7c57',
        'Warm ochre:ffc1955d',
        'Olive gold:ffc8a97e',
        'Deep olive:ffada66c',
        'Moss:ff7fb06d',
        'Leaf green:ff6fc087',
        'Forest sage:ff94bc88',
        'Jade green:ff8fb59e',
        'Deep teal:ff76c6bc',
        'Reference teal:ff63aea8',
        'Slate teal:ff51bbc8',
        'Blue teal:ff459a95',
        'Denim:ff7698da',
        'Steel blue:ff64b1e6',
        'Indigo blue:ff648ae6',
        'Deep blue:ffa19fe2',
        'Dusty violet:ff8d72b1',
        'Orchid violet:ffa785bb',
        'Mulberry:ff8e7fc8',
        'Orchid plum:ffbfa0ca',
        'Cool gray:ffb373a2',
        'Taupe gray:ffc96b8f',
        'Lavender gray:ffd975b3',
        'Slate gray:ffd987c5',
      ],
    );
    expect(ContactBuiltInGroupDefaults.family.colorArgb, 0xFFE3B756);
    expect(ContactBuiltInGroupDefaults.friends.colorArgb, 0xFF63AEA8);
    expect(ContactBuiltInGroupDefaults.avoid.colorArgb, 0xFFE2944E);
    expect(ContactBuiltInGroupDefaults.other.colorArgb, 0xFFB373A2);
  });

  testWidgets(
    'Group identity dot is a 19dp solid canonical color in both themes',
    (tester) async {
      Future<void> pump(Brightness brightness) {
        return tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(
              body: ContactGroupIdentityDot(
                colorValue: ColorValue(ContactGroupColorPalette.tealArgb),
              ),
            ),
          ),
        );
      }

      await pump(Brightness.light);
      final dotFinder = find.descendant(
        of: find.byType(ContactGroupIdentityDot),
        matching: find.byType(Container),
      );
      final lightDot = tester.widget<Container>(dotFinder);
      expect(lightDot.constraints?.maxWidth, 19);
      expect(lightDot.constraints?.maxHeight, 19);
      expect(
        (lightDot.decoration! as BoxDecoration).color,
        const Color(ContactGroupColorPalette.tealArgb),
      );

      await pump(Brightness.dark);
      final darkDot = tester.widget<Container>(dotFinder);
      expect(darkDot.constraints?.maxWidth, 19);
      expect(darkDot.constraints?.maxHeight, 19);
      expect(
        (darkDot.decoration! as BoxDecoration).color,
        const Color(ContactGroupColorPalette.tealArgb),
        reason: 'Light and Dark use the same saved canonical Group color.',
      );
    },
  );
}

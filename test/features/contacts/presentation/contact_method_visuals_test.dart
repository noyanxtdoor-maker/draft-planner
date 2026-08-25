import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/contact_reference_style.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_method_visuals.dart';

void main() {
  test('Social defaults use the locked cyclic active-platform sequence', () {
    expect(activeSocialProfileLabels, <String>[
      'Facebook',
      'Facebook Messenger',
      'WhatsApp',
      'LINE',
      'Skype',
      'KakaoTalk',
      'Instagram',
      'X',
    ]);
    expect(activeSocialProfileLabels, isNot(contains('Other')));
    expect(activeSocialProfileLabels, isNot(contains('HelloTalk')));
    for (var index = 0; index < activeSocialProfileLabels.length; index++) {
      expect(
        nextSocialProfileLabel(
          List<String?>.filled(index, 'legacy row', growable: false),
        ),
        activeSocialProfileLabels[index],
      );
    }
    expect(
      nextSocialProfileLabel(
        List<String?>.filled(activeSocialProfileLabels.length, 'duplicate'),
      ),
      'Facebook',
    );
    expect(socialProfileDisplayLabel('Messenger'), 'Facebook Messenger');
    expect(socialProfileDisplayLabel('Other'), 'Other');
  });

  test('Email type icons use the one approved semantic mapping', () {
    expect(contactEmailTypeIcon('Personal'), Icons.person_outline);
    expect(contactEmailTypeIcon('Work'), Icons.business_outlined);
    expect(contactEmailTypeIcon('Family'), Icons.groups_3_outlined);
    expect(contactEmailTypeIcon('Other'), Icons.more_horiz);
  });

  test('Social artwork uses the audited per-platform optical-size map', () {
    expect(socialProfileVisualSizeFor('Facebook'), 22);
    expect(socialProfileVisualSizeFor('Facebook Messenger'), 18);
    expect(socialProfileVisualSizeFor('WhatsApp'), 19);
    expect(socialProfileVisualSizeFor('LINE'), 28);
    expect(socialProfileVisualSizeFor('Skype'), 20);
    expect(socialProfileVisualSizeFor('KakaoTalk'), 24);
    expect(socialProfileVisualSizeFor('Instagram'), 18);
    expect(socialProfileVisualSizeFor('X'), 26);
    expect(socialProfileVisualSizeFor('Other'), 22);
    expect(
      socialProfileVisualSizeFor('LINE', nominalSize: 18),
      closeTo(22.90909, 0.00001),
    );
  });

  testWidgets('Phone and all active Social shapes are runtime theme tinted', (
    tester,
  ) async {
    const rose = Color(0xffb03060);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            children: <Widget>[
              contactMethodVisual(
                type: ContactMethodType.phone,
                label: 'Mobile',
                color: rose,
              ),
              contactMethodVisual(
                type: ContactMethodType.phone,
                label: 'Home',
                color: rose,
              ),
              contactMethodVisual(
                type: ContactMethodType.phone,
                label: 'Work',
                color: rose,
              ),
              contactMethodVisual(
                type: ContactMethodType.social,
                label: 'Facebook',
                color: rose,
              ),
              for (final label in activeSocialProfileLabels.where(
                (label) => label != 'Facebook',
              ))
                contactMethodVisual(
                  type: ContactMethodType.social,
                  label: label,
                  color: rose,
                ),
              contactMethodVisual(
                type: ContactMethodType.email,
                label: 'Work',
                color: rose,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsNWidgets(10));
    expect(find.text('𝕏'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.business_outlined)).color,
      rose,
    );
  });

  testWidgets('recognized Social icons inherit Blue and Rose theme primaries', (
    tester,
  ) async {
    for (final primary in <Color>[
      const Color(0xff1f6feb),
      const Color(0xffb03060),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(primary),
          theme: ThemeData(colorScheme: ColorScheme.light(primary: primary)),
          home: Builder(
            builder: (context) => Material(
              child: contactMethodVisual(
                type: ContactMethodType.social,
                label: 'Facebook',
                color: ContactReferenceStyle.actionOf(context),
              ),
            ),
          ),
        ),
      );
      final visual = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(visual.colorFilter, ColorFilter.mode(primary, BlendMode.srcIn));
    }
  });

  testWidgets('X keeps a fixed drawing box while its glyph receives the '
      'audited optical-size correction', (tester) async {
    const primary = Color(0xff1f6feb);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: contactMethodVisual(
              type: ContactMethodType.social,
              label: 'X',
              color: primary,
              normalizeSocialOptics: true,
            ),
          ),
        ),
      ),
    );

    final x = tester.widget<Text>(find.text('𝕏'));
    expect(x.style?.fontSize, 26);
    expect(x.style?.color, primary);
    expect(
      tester.getSize(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 22 && widget.height == 22,
          description: 'the fixed X visual drawing box',
        ),
      ),
      const Size(22, 22),
    );
  });
}

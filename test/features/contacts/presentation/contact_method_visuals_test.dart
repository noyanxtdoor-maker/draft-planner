import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_method_visuals.dart';

void main() {
  test('Social defaults advance through the locked unused platform order', () {
    expect(nextSocialProfileLabel(const <String?>[]), 'Facebook');
    expect(nextSocialProfileLabel(const <String?>['Facebook']), 'Messenger');
    expect(
      nextSocialProfileLabel(const <String?>['Facebook', 'Messenger']),
      'WhatsApp',
    );
    expect(activeSocialProfileLabels, isNot(contains('HelloTalk')));
  });

  testWidgets('Phone and social owner shapes are runtime theme tinted', (
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
              contactMethodVisual(
                type: ContactMethodType.social,
                label: 'Other',
                color: rose,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsNWidgets(4));
    expect(tester.widget<Icon>(find.byIcon(Icons.more_horiz)).color, rose);
  });
}

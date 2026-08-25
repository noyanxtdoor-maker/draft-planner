import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/presentation/external_handoff.dart';

void main() {
  test('WhatsApp handoff preserves only explicit international numbers', () {
    expect(ExternalHandoff.whatsappDigits('+63 917-555-0101'), '639175550101');
    expect(
      ExternalHandoff.whatsappDigits('00 63 917 555 0101'),
      '639175550101',
    );
    expect(ExternalHandoff.whatsappDigits('0917 555 0101'), isNull);
    expect(ExternalHandoff.whatsappDigits(''), isNull);
  });

  test(
    'only the locked Philippine 09 mobile pattern has a local candidate',
    () {
      expect(
        ExternalHandoff.philippineLocalWhatsAppDigits('0919 097 8863'),
        '639190978863',
      );
      expect(
        ExternalHandoff.displayInternationalDigits('639190978863'),
        '+63 919 097 8863',
      );
      expect(
        ExternalHandoff.philippineLocalWhatsAppDigits('0919097886'),
        isNull,
      );
      expect(
        ExternalHandoff.philippineLocalWhatsAppDigits('08190978863'),
        isNull,
      );
      expect(
        ExternalHandoff.philippineLocalWhatsAppDigits('+639190978863'),
        isNull,
      );
    },
  );

  test(
    'active Social Profiles map to their explicit native app-home packages',
    () {
      final packages = <String, String>{
        'Facebook': ExternalHandoff.socialNativeAppDestination(
          platform: 'Facebook',
          rawValue: 'arbitrary display text',
        )!.packageName,
        'Facebook Messenger': ExternalHandoff.socialNativeAppDestination(
          platform: 'Facebook Messenger',
          rawValue: 'arbitrary display text',
        )!.packageName,
        'WhatsApp': ExternalHandoff.socialNativeAppDestination(
          platform: 'WhatsApp',
          rawValue: 'Joshua',
        )!.packageName,
        'LINE': ExternalHandoff.socialNativeAppDestination(
          platform: 'LINE',
          rawValue: 'arbitrary display text',
        )!.packageName,
        'Skype': ExternalHandoff.socialNativeAppDestination(
          platform: 'Skype',
          rawValue: 'arbitrary display text',
        )!.packageName,
        'KakaoTalk': ExternalHandoff.socialNativeAppDestination(
          platform: 'KakaoTalk',
          rawValue: 'arbitrary display text',
        )!.packageName,
        'Instagram': ExternalHandoff.socialNativeAppDestination(
          platform: 'Instagram',
          rawValue: 'arbitrary display text',
        )!.packageName,
        'X': ExternalHandoff.socialNativeAppDestination(
          platform: 'X',
          rawValue: 'arbitrary display text',
        )!.packageName,
      };

      expect(packages, <String, String>{
        'Facebook': 'com.facebook.katana',
        'Facebook Messenger': 'com.facebook.orca',
        'WhatsApp': 'com.whatsapp',
        'LINE': 'jp.naver.line.android',
        'Skype': 'com.skype.raider',
        'KakaoTalk': 'com.kakao.talk',
        'Instagram': 'com.instagram.android',
        'X': 'com.twitter.android',
      });
      expect(
        ExternalHandoff.socialNativeAppDestination(
          platform: 'X',
          rawValue: 'one saved display value',
        )!.packageName,
        ExternalHandoff.socialNativeAppDestination(
          platform: 'X',
          rawValue: 'another arbitrary value',
        )!.packageName,
      );
    },
  );

  test(
    'Social app-home launch ignores raw values and reports missing apps',
    () async {
      String? requestedPackage;
      final launched = await ExternalHandoff.launchSocialProfile(
        platform: 'WhatsApp',
        rawValue: 'Joshua',
        launchAppHome: (packageName) async {
          requestedPackage = packageName;
          return true;
        },
      );
      expect(launched, SocialNativeAppLaunchResult.launched);
      expect(requestedPackage, 'com.whatsapp');

      final unavailable = await ExternalHandoff.launchSocialProfile(
        platform: 'Instagram',
        rawValue: 'not a profile route',
        launchAppHome: (_) async => false,
      );
      expect(unavailable, SocialNativeAppLaunchResult.appRequired);
      expect(
        ExternalHandoff.appRequiredTitle('Facebook'),
        'Facebook app required',
      );
      expect(
        ExternalHandoff.appRequiredMessage('Facebook'),
        'Install the Facebook app first to open it from Next Transfer.',
      );
      expect(
        ExternalHandoff.socialNativeAppDestination(
          platform: 'WhatsApp',
          rawValue: 'arbitrary display text',
        ),
        isNotNull,
      );
      expect(
        ExternalHandoff.socialNativeAppDestination(
          platform: 'Other',
          rawValue: 'not a native destination',
        ),
        isNull,
      );
      expect(ExternalHandoff.isSupportedSocialPlatform('Facebook'), isTrue);
      expect(ExternalHandoff.isSupportedSocialPlatform('Other'), isFalse);
    },
  );
}

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
}

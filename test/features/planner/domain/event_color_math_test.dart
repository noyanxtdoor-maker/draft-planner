import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/event_color_math.dart';

void main() {
  group('EventColorMath.parseHex', () {
    test('accepts six-digit RGB with and without a leading hash', () {
      expect(EventColorMath.parseHex('#A1B2C3'), 0xFFA1B2C3);
      expect(EventColorMath.parseHex('A1B2C3'), 0xFFA1B2C3);
      expect(EventColorMath.parseHex('#ffffff'), 0xFFFFFFFF);
      expect(EventColorMath.parseHex('000000'), 0xFF000000);
    });

    test('rejects wrong lengths and non-hex characters', () {
      expect(EventColorMath.parseHex('#A1B2'), isNull);
      expect(EventColorMath.parseHex('#A1B2C3D4'), isNull);
      expect(EventColorMath.parseHex('A1B2C3D4'), isNull);
      expect(EventColorMath.parseHex('#A1B2CG'), isNull);
      expect(EventColorMath.parseHex('ZZZZZZ'), isNull);
      expect(EventColorMath.parseHex(''), isNull);
    });

    test('rejects alpha-only input', () {
      expect(EventColorMath.parseHex('FFFFFF00'), isNull);
      expect(EventColorMath.parseHex('FFA1B2C3'), isNull);
    });
  });

  group('EventColorMath.formatHex', () {
    test('normalizes to uppercase with a leading hash', () {
      expect(EventColorMath.formatHex(0xFFA1b2c3), '#A1B2C3');
      expect(EventColorMath.formatHex(0xFF000000), '#000000');
      expect(EventColorMath.formatHex(0xFFffffff), '#FFFFFF');
    });
  });

  group('EventColorMath.toHsl', () {
    test('maps known colors to the expected hue families', () {
      final rose = EventColorMath.toHsl(0xFFE91E63);
      expect(rose.h, closeTo(340, 6));
      final teal = EventColorMath.toHsl(0xFF26A69A);
      expect(teal.h, closeTo(172, 6));
      final gray = EventColorMath.toHsl(0xFF868A8D);
      expect(gray.s, lessThan(0.05));
    });

    test('returns channels within range', () {
      for (final argb in <int>[
        0xFF000000,
        0xFFFFFFFF,
        0xFFE91E63,
        0xFF7CB342,
        0xFF42A5F5,
      ]) {
        final hsl = EventColorMath.toHsl(argb);
        expect(hsl.h, inInclusiveRange(0, 360));
        expect(hsl.s, inInclusiveRange(0, 1));
        expect(hsl.l, inInclusiveRange(0, 1));
      }
    });
  });

  group('EventColorMath.isMutedAndReadable', () {
    test('accepts muted mid-tone colors and rejects bright/extreme ones', () {
      expect(EventColorMath.isMutedAndReadable(0xFFBB7772), isTrue);
      expect(EventColorMath.isMutedAndReadable(0xFF868A8D), isFalse); // gray
      expect(EventColorMath.isMutedAndReadable(0xFFE91E63), isFalse); // vivid
      expect(EventColorMath.isMutedAndReadable(0xFFFFFFFF), isFalse); // white
      expect(EventColorMath.isMutedAndReadable(0xFF000000), isFalse); // black
    });
  });

  group('EventColorMath OKLab helpers', () {
    test('self distance is zero and distance is symmetric', () {
      expect(EventColorMath.okLabDistance(0xFFA1B2C3, 0xFFA1B2C3), 0);
      expect(
        EventColorMath.okLabDistance(0xFFE91E63, 0xFF42A5F5),
        EventColorMath.okLabDistance(0xFF42A5F5, 0xFFE91E63),
      );
    });

    test('distinct colors are not near duplicates', () {
      expect(EventColorMath.isNearDuplicate(0xFFE91E63, 0xFF42A5F5), isFalse);
    });

    test('identical colors are near duplicates', () {
      expect(EventColorMath.isNearDuplicate(0xFFA1B2C3, 0xFFA1B2C3), isTrue);
    });
  });

  group('EventColorMath dark-surface warnings', () {
    test('white and very dark colors are flagged, mid-tones are not', () {
      expect(EventColorMath.hasPoorContrastOnDarkSurface(0xFF101014), isTrue);
      expect(EventColorMath.hasPoorContrastOnDarkSurface(0xFFA1B2C3), isFalse);
    });

    test('excessively bright detection rejects glaring colors', () {
      expect(EventColorMath.isExcessivelyBright(0xFFFFFFFF), isTrue);
      expect(EventColorMath.isExcessivelyBright(0xFFF2E9E0), isTrue);
      expect(EventColorMath.isExcessivelyBright(0xFFA1B2C3), isFalse);
    });
  });
}

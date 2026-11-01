// Test coordinates are deliberately outside Ukraine (spec NFR-9).
// Expected centres were produced by an independent reference implementation
// (Krueger series UTM inverse), see tools/mgrs_ref.py.

import 'package:flutter_test/flutter_test.dart';
import 'package:ggmap/mgrs/mgrs_parser.dart';

void main() {
  const tol = 1e-6; // ~0.1 m

  void expectCenter(String input, double lat, double lon, {double t = tol}) {
    final r = MgrsParser.parse(input);
    expect(r.isOk, isTrue, reason: '$input -> ${r.error}');
    expect(r.coordinate!.center.latitude, closeTo(lat, t), reason: input);
    expect(r.coordinate!.center.longitude, closeTo(lon, t), reason: input);
  }

  group('full records', () {
    test('1 m precision, Nevada (library README vector)', () {
      expectCenter('11SPA7234911844', 36.2361279, -115.0820920);
    });

    test('spaces and lower case are normalized', () {
      expectCenter('11s pa 72349 11844', 36.2361279, -115.0820920);
      final r = MgrsParser.parse('  11s  PA\t72349\n11844 ');
      expect(r.coordinate!.display, '11S PA 72349 11844');
      expect(r.coordinate!.compact, '11SPA7234911844');
    });

    test('single digit zone, Hawaii', () {
      expectCenter('4QFJ1234567890', 21.4098012, -157.9160763);
    });

    test('equator and prime meridian', () {
      expectCenter('31N AA 66021 00000', 0.0000045, 0.0000005);
    });

    test('southern hemisphere, Chile', () {
      expectCenter('18G YP 00000 00000', -46.9233766, -72.3729923);
    });

    test('Norway special zone 32V', () {
      expectCenter('32V NM 50000 00000', 59.5353677, 9.8840750);
    });

    test('Germany', () {
      expectCenter('33U UU 00000 00000', 52.3138483, 12.0658171);
    });
  });

  group('precision and cell centre', () {
    test('10 km cell -> centre of the cell', () {
      expectCenter('11SPA72', 36.3541861, -115.0496631);
      final c = MgrsParser.parse('11SPA72').coordinate!;
      expect(c.precision, 1);
      expect(c.cellSizeMeters, 10000);
      expect(c.cellSizeLabel, 'комірка 10 км');
    });

    test('1 km cell, far south', () {
      expectCenter('60CWT1234', -78.9593523, 177.5847009);
      expect(MgrsParser.parse('60CWT1234').coordinate!.cellSizeLabel,
          'комірка 1 км');
    });

    test('1 m cell label', () {
      final c = MgrsParser.parse('11SPA7234911844').coordinate!;
      expect(c.precision, 5);
      expect(c.cellSizeLabel, 'комірка 1 м');
    });
  });

  group('rejected records', () {
    void expectError(String input, MgrsError error) {
      final r = MgrsParser.parse(input);
      expect(r.isOk, isFalse, reason: input);
      expect(r.error, error, reason: input);
    }

    test('empty', () => expectError('   ', MgrsError.empty));
    test('bad characters', () => expectError('11SPA72349-11844', MgrsError.invalidCharacters));
    test('zone 0', () => expectError('0SPA7234911844', MgrsError.invalidZone));
    test('zone 61', () => expectError('61SPA7234911844', MgrsError.invalidZone));
    test('band I', () => expectError('11IPA7234911844', MgrsError.invalidBand));
    test('band Y', () => expectError('11YPA7234911844', MgrsError.invalidBand));
    test('odd digits', () => expectError('11SPA723491184', MgrsError.oddDigits));
    test('12 digits', () => expectError('11SPA723491118440', MgrsError.tooManyDigits));
    test('no digits', () => expectError('11SPA', MgrsError.noDigits));
    test('row letter W is never valid', () => expectError('11SPW7234911844', MgrsError.invalidCombination));
    test('column letter from another zone set', () => expectError('11SAA7234911844', MgrsError.invalidCombination));
    test('shortened record without working area', () {
      expectError('PA 72349 11844', MgrsError.incomplete);
      expectError('72349 11844', MgrsError.incomplete);
    });
  });

  group('look-alike characters are suggested, not applied (MGRS-5)', () {
    test('O instead of 0 in digits', () {
      final r = MgrsParser.parse('11SPA72349 1184O');
      expect(r.isOk, isFalse);
      expect(r.suggestion, '11S PA 72349 11840');
    });

    test('I instead of 1 in zone', () {
      final r = MgrsParser.parse('I1SPA7234911844');
      expect(r.isOk, isFalse);
      expect(r.suggestion, '11S PA 72349 11844');
    });

    test('5 instead of S in band', () {
      final r = MgrsParser.parse('115PA7234911844');
      expect(r.isOk, isFalse);
      expect(r.suggestion, '11S PA 72349 11844');
    });

    test('no suggestion for hopeless input', () {
      expect(MgrsParser.parse('HELLO').suggestion, isNull);
    });
  });
}

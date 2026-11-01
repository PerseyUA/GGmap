import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import 'mgrs_coordinate.dart';

/// Reasons why an MGRS record was rejected.
enum MgrsError {
  empty,
  invalidCharacters,
  incomplete,
  invalidFormat,
  invalidZone,
  invalidBand,
  noDigits,
  oddDigits,
  tooManyDigits,
  invalidCombination,
}

extension MgrsErrorMessage on MgrsError {
  /// User-facing explanation in Ukrainian.
  String get message => switch (this) {
        MgrsError.empty => 'Введіть координати MGRS.',
        MgrsError.invalidCharacters =>
          'Недопустимі символи. Дозволені лише латинські літери, цифри й пробіли.',
        MgrsError.incomplete =>
          'Запис неповний: бракує зони, широтної смуги або квадрата. '
              'Підстановка з робочої області з’явиться в MVP.',
        MgrsError.invalidFormat =>
          'Не схоже на MGRS. Очікується, наприклад: 37U DQ 12345 67890.',
        MgrsError.invalidZone => 'Зона має бути від 1 до 60.',
        MgrsError.invalidBand =>
          'Недопустима широтна смуга. Дозволено C–X, крім I та O.',
        MgrsError.noDigits => 'Бракує цифр координат.',
        MgrsError.oddDigits =>
          'Непарна кількість цифр: схід і північ мають бути однакової довжини.',
        MgrsError.tooManyDigits =>
          'Забагато цифр: максимум 5 на схід і 5 на північ (точність 1 м).',
        MgrsError.invalidCombination =>
          'Така комбінація зони, смуги й квадрата не існує або не узгоджується.',
      };
}

/// Result of parsing a single MGRS record.
class MgrsParseResult {
  const MgrsParseResult._({
    this.coordinate,
    this.error,
    this.suggestion,
  });

  const MgrsParseResult.ok(MgrsCoordinate c) : this._(coordinate: c);

  const MgrsParseResult.fail(MgrsError e, {String? suggestion})
      : this._(error: e, suggestion: suggestion);

  final MgrsCoordinate? coordinate;
  final MgrsError? error;

  /// A corrected record proposed for ambiguous characters (O/0, I/1, S/5…).
  /// Never applied automatically — see spec MGRS-5.
  final String? suggestion;

  bool get isOk => coordinate != null;
}

/// Parses and validates MGRS records. Pure Dart, no Flutter dependency.
abstract final class MgrsParser {
  static const _bands = 'CDEFGHJKLMNPQRSTUVWX';
  static const _squareLetters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

  static final _strict = RegExp(r'^(\d{1,2})([A-Z])([A-Z]{2})(\d*)$');
  static final _allowed = RegExp(r'^[0-9A-Z]+$');
  static final _whitespace = RegExp(r'\s+');
  static final _shortWithSquare = RegExp(r'^[A-Z]{2}\d+$');
  static final _digitsOnly = RegExp(r'^\d+$');

  /// Characters that look like digits.
  static const _toDigit = {
    'O': '0',
    'Q': '0',
    'D': '0',
    'I': '1',
    'L': '1',
    'Z': '2',
    'S': '5',
    'G': '6',
    'B': '8',
  };

  /// Digits that look like valid MGRS letters (I and O are never valid).
  static const _toLetter = {'2': 'Z', '5': 'S', '6': 'G', '8': 'B'};

  /// Uppercase and remove all whitespace.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(_whitespace, '');

  static MgrsParseResult parse(String input) {
    final s = normalize(input);
    if (s.isEmpty) return const MgrsParseResult.fail(MgrsError.empty);
    if (!_allowed.hasMatch(s)) {
      return const MgrsParseResult.fail(MgrsError.invalidCharacters);
    }

    final strictResult = _parseStrict(s);
    if (strictResult.isOk) return strictResult;

    final suggestion = _suggest(s);
    if (_digitsOnly.hasMatch(s) || _shortWithSquare.hasMatch(s)) {
      return MgrsParseResult.fail(MgrsError.incomplete, suggestion: suggestion);
    }
    return MgrsParseResult.fail(
      strictResult.error ?? MgrsError.invalidFormat,
      suggestion: suggestion,
    );
  }

  static MgrsParseResult _parseStrict(String s) {
    final m = _strict.firstMatch(s);
    if (m == null) return const MgrsParseResult.fail(MgrsError.invalidFormat);

    final zone = int.parse(m.group(1)!);
    final band = m.group(2)!;
    final square = m.group(3)!;
    final digits = m.group(4)!;

    if (zone < 1 || zone > 60) {
      return const MgrsParseResult.fail(MgrsError.invalidZone);
    }
    if (!_bands.contains(band)) {
      return const MgrsParseResult.fail(MgrsError.invalidBand);
    }
    if (!_squareLetters.contains(square[0]) ||
        !_squareLetters.contains(square[1]) ||
        'WXYZ'.contains(square[1])) {
      return const MgrsParseResult.fail(MgrsError.invalidCombination);
    }
    if (digits.isEmpty) return const MgrsParseResult.fail(MgrsError.noDigits);
    if (digits.length.isOdd) {
      return const MgrsParseResult.fail(MgrsError.oddDigits);
    }
    if (digits.length > 10) {
      return const MgrsParseResult.fail(MgrsError.tooManyDigits);
    }

    final half = digits.length ~/ 2;
    final easting = digits.substring(0, half);
    final northing = digits.substring(half);
    final compact = '$zone$band$square$easting$northing';

    try {
      final (lat, lon) = _cellCenter(
        '$zone$band$square',
        easting,
        northing,
      );
      if (lat.isNaN || lon.isNaN || lat < -80 || lat > 84.5) {
        return const MgrsParseResult.fail(MgrsError.invalidCombination);
      }
      // Round trip: the center must encode back to the same record.
      // This rejects squares that do not exist in the zone and band
      // letters that do not match the latitude.
      final back = Mgrs.forward([lon, lat], half);
      if (back.toUpperCase() != compact) {
        return const MgrsParseResult.fail(MgrsError.invalidCombination);
      }
      return MgrsParseResult.ok(
        MgrsCoordinate(
          zone: zone,
          band: band,
          square: square,
          easting: easting,
          northing: northing,
          center: LatLng(lat, lon),
        ),
      );
    } catch (_) {
      return const MgrsParseResult.fail(MgrsError.invalidCombination);
    }
  }

  /// Centre of the MGRS cell in WGS84 (spec MGRS-9).
  ///
  /// For precision below 1 m the centre is the grid point at half a cell
  /// (e.g. `12` at 1 km -> `12500`), converted exactly. For 1 m precision the
  /// centre is the middle of the 1 m cell bounding box.
  static (double, double) _cellCenter(
    String prefix,
    String easting,
    String northing,
  ) {
    final p = easting.length;
    if (p < 5) {
      final pad = '5'.padRight(5 - p, '0');
      final point = Mgrs.toPoint('$prefix$easting$pad$northing$pad');
      return (point[1], point[0]);
    }
    // inverse -> [left, bottom, right, top]
    final bbox = Mgrs.inverse('$prefix$easting$northing');
    return ((bbox[1] + bbox[3]) / 2, (bbox[0] + bbox[2]) / 2);
  }

  /// Proposes a correction for look-alike characters, or null.
  static String? _suggest(String s) {
    for (final zoneLen in const [2, 1]) {
      if (s.length < zoneLen + 3) continue;
      final zone = _map(s.substring(0, zoneLen), _toDigit);
      final band = _map(s.substring(zoneLen, zoneLen + 1), _toLetter);
      final square = _map(s.substring(zoneLen + 1, zoneLen + 3), _toLetter);
      final digits = _map(s.substring(zoneLen + 3), _toDigit);
      final candidate = '$zone$band$square$digits';
      if (candidate == s) continue;
      final r = _parseStrict(candidate);
      if (r.isOk) return r.coordinate!.display;
    }
    return null;
  }

  static String _map(String part, Map<String, String> table) =>
      part.split('').map((c) => table[c] ?? c).join();
}

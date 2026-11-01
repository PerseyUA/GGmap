import 'package:latlong2/latlong.dart';

/// A validated, fully specified MGRS coordinate.
class MgrsCoordinate {
  const MgrsCoordinate({
    required this.zone,
    required this.band,
    required this.square,
    required this.easting,
    required this.northing,
    required this.center,
  });

  /// UTM zone number, 1..60.
  final int zone;

  /// Latitude band letter (C..X without I and O).
  final String band;

  /// 100 km square identification, two letters.
  final String square;

  /// Easting digits (1..5 digits, same length as [northing]).
  final String easting;

  /// Northing digits.
  final String northing;

  /// Center of the MGRS cell (WGS84). See spec MGRS-9.
  final LatLng center;

  /// Number of digit pairs, 1 (10 km) .. 5 (1 m).
  int get precision => easting.length;

  /// Size of the MGRS cell side in metres.
  int get cellSizeMeters {
    var size = 1;
    for (var i = precision; i < 5; i++) {
      size *= 10;
    }
    return size;
  }

  /// Compact form without spaces, e.g. `37UDQ1234567890`.
  String get compact => '$zone$band$square$easting$northing';

  /// Canonical display form, e.g. `37U DQ 12345 67890`.
  String get display => '$zone$band $square $easting $northing';

  /// Human readable cell size in Ukrainian.
  String get cellSizeLabel {
    final m = cellSizeMeters;
    return m >= 1000 ? 'комірка ${m ~/ 1000} км' : 'комірка $m м';
  }

  @override
  String toString() => display;
}

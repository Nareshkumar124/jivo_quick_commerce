import 'package:rider_app/features/task/domain/rider_task.dart';

/// Track points from a GPX file (`<trkpt lat=".." lon="..">`), in order.
List<GeoPoint> parseGpx(String gpx) => [
  for (final match in RegExp(
    r'<trkpt\s+lat="(-?[\d.]+)"\s+lon="(-?[\d.]+)"',
  ).allMatches(gpx))
    GeoPoint(double.parse(match.group(1)!), double.parse(match.group(2)!)),
];

/// A ride from ~700 m south-west of the fake store (Jivo Sector 18, Noida)
/// to the store, then on to the fake customer in Sector 21: two points stop
/// short of each geofence (200 m), so the server-side check is exercised.
///
/// The same track is in `integration_test/routes/sector18_to_sector21.gpx`
/// for a mock-location app on the phone (P5 device run); a test keeps the
/// two identical. Inline here because a test on the phone cannot read the
/// host's files.
const sector18ToSector21Gpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="jivo-rider-tests" xmlns="http://www.topografix.com/GPX/1/1">
  <trk><name>Sector 18 store to Sector 21 drop</name><trkseg>
    <trkpt lat="28.5650" lon="77.3230"><time>2026-11-02T06:30:00Z</time></trkpt>
    <trkpt lat="28.5680" lon="77.3245"><time>2026-11-02T06:31:00Z</time></trkpt>
    <trkpt lat="28.5703" lon="77.3259"><time>2026-11-02T06:32:30Z</time></trkpt>
    <trkpt lat="28.5740" lon="77.3300"><time>2026-11-02T06:40:00Z</time></trkpt>
    <trkpt lat="28.5790" lon="77.3360"><time>2026-11-02T06:43:00Z</time></trkpt>
    <trkpt lat="28.5815" lon="77.3395"><time>2026-11-02T06:45:00Z</time></trkpt>
    <trkpt lat="28.5830" lon="77.3410"><time>2026-11-02T06:46:30Z</time></trkpt>
  </trkseg></trk>
</gpx>
''';

/// Indexes into [sector18ToSector21Gpx].
abstract final class RoutePoints {
  static const start = 0;
  static const atStore = 2;
  static const nearCustomer = 4;
  static const atCustomer = 6;
}

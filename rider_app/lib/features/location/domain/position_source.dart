import 'location_point.dart';
import 'tracking_config.dart';

/// A stream of GPS fixes at roughly [TrackingIntervals.sample].
///
/// The stream may emit errors (GPS switched off, permission revoked) and may
/// close. The tracker re-subscribes after a delay in both cases.
abstract interface class PositionSource {
  Stream<LocationPoint> positions(TrackingIntervals intervals);
}

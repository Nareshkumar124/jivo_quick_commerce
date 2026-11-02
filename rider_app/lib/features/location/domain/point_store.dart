import 'location_point.dart';

/// Durable storage behind [LocationBuffer], so points recorded while the
/// network is down survive an app or service restart.
///
/// Implementations do not need to be safe for concurrent calls: the buffer
/// runs its store operations one at a time, in call order.
abstract interface class PointStore {
  /// All stored points, oldest first. Unreadable entries are skipped.
  Future<List<LocationPoint>> load();

  /// Adds [points] after the existing ones.
  Future<void> append(List<LocationPoint> points);

  /// Replaces the whole content with [points].
  Future<void> replaceAll(List<LocationPoint> points);
}

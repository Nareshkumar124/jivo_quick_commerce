import 'package:geolocator/geolocator.dart';

import '../../addresses/data/device_location.dart';
import '../domain/delivery_location.dart';

/// Serviceability and notify-me (`06 §2.3`). Implementations throw
/// `ApiError`.
///
/// The app uses `ApiServiceabilityRepository` (the generated
/// `ServiceabilityApi`). [FakeServiceabilityRepository] is only a test double
/// and the dev flavor's `FAKE_API=true` stand-in.
abstract interface class ServiceabilityRepository {
  /// `GET /serviceability/?lat=&lng=`.
  Future<Serviceability> check(GeoPoint point);

  /// `POST /serviceability/notify-me/`: saves interest in [point]. The
  /// server uses the signed-in user's phone; [addressText] is the address
  /// shown to the customer, for ops planning.
  Future<void> notifyMe(GeoPoint point, {String? addressText});
}

/// Test double and dev `FAKE_API` stand-in, never used in staging or prod.
/// One demo store in central New Delhi serves a [radiusMeters] circle;
/// everything else is not serviceable.
class FakeServiceabilityRepository implements ServiceabilityRepository {
  FakeServiceabilityRepository({
    this.latency = const Duration(milliseconds: 300),
    this.storeOpen = true,
    this.radiusMeters = 15000,
    this.storeId = 1,
  });

  static const storeLocation = (lat: 28.613939, lng: 77.209023);

  final Duration latency;
  bool storeOpen;
  double radiusMeters;

  /// The store id returned for serviceable points.
  int storeId;

  /// When set, the next call throws it once (tests).
  Object? failNext;
  final List<GeoPoint> checks = [];
  final List<GeoPoint> notified = [];

  Future<void> _respond() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<Serviceability> check(GeoPoint point) async {
    checks.add(point);
    await _respond();
    final meters = Geolocator.distanceBetween(
      point.lat,
      point.lng,
      storeLocation.lat,
      storeLocation.lng,
    );
    // Like the API: always a 200, `store: null` outside every area.
    if (meters > radiusMeters) {
      return const Serviceability(
        serviceable: false,
        message: "We're not delivering here yet.",
      );
    }
    final now = DateTime.now().toUtc();
    return Serviceability(
      serviceable: true,
      // The API sends no ETA (and a message) while the store is closed.
      etaMinutes: storeOpen ? 14 : null,
      message: storeOpen ? null : 'Store opens at 7:00 AM.',
      store: StoreInfo(
        id: storeId,
        name: 'Jivo Connaught Place',
        isOpen: storeOpen,
        // 7:00 AM IST tomorrow.
        opensAt: storeOpen
            ? null
            : DateTime.utc(now.year, now.month, now.day + 1, 1, 30),
      ),
    );
  }

  @override
  Future<void> notifyMe(GeoPoint point, {String? addressText}) async {
    await _respond();
    notified.add(point);
  }
}

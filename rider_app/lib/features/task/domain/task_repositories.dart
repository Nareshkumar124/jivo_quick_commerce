import '../../offers/domain/delivery_offer.dart';
import 'rider_task.dart';
import 'task_rules.dart';

/// An offer as received, with the server time if the response had it (for
/// the clock-skew correction of [OfferCountdown]).
class ReceivedOffer {
  const ReceivedOffer(this.offer, {this.serverNow});

  final DeliveryOffer offer;
  final DateTime? serverNow;
}

/// Offers (06 §3; slice 5.3 contract). Every method throws jivo_core's
/// `ApiError` on failure.
///
/// TODO(api): bind to the generated `RiderApi` once the PM regenerates
/// `jivo_api` from the slice 5.3 schema; the fake stands in until then.
abstract interface class OfferRepository {
  /// `GET /rider/offers/current/`: the pending offer, or null (polling
  /// fallback, and the app start from an offer notification).
  Future<ReceivedOffer?> fetchCurrentOffer();

  /// `POST /rider/offers/{id}/accept/` → the ASSIGNED `RiderTask` (safe to
  /// repeat). 409 `OFFER_EXPIRED` or `OFFER_TAKEN`.
  Future<RiderTask> accept(int offerId);

  /// `POST /rider/offers/{id}/reject/ {reason?}` → 204 (a no-op once the
  /// offer expired or was withdrawn).
  Future<void> reject(int offerId, {OfferRejectReason? reason});
}

/// Pushed offer events: `offer.new` / `offer.withdrawn` (06 §4; FCM in P5,
/// WebSocket in P6). The fake emits them in dev and tests.
sealed class OfferEvent {
  const OfferEvent();
}

class OfferArrived extends OfferEvent {
  const OfferArrived(this.received);

  final ReceivedOffer received;
}

class OfferWithdrawn extends OfferEvent {
  const OfferWithdrawn(this.offerId);

  final int offerId;
}

abstract interface class OfferEventSource {
  Stream<OfferEvent> get events;
}

/// What the rider sends with `fail`.
class FailReport {
  const FailReport({
    required this.reason,
    this.note = '',
    this.callAttempts = 0,
    this.photo,
  });

  final FailReason reason;

  /// Required (non-blank) for OTHER; at most 300 characters.
  final String note;

  /// `call_attempts`: CUSTOMER_NOT_REACHABLE needs at least 2.
  final int callAttempts;

  /// Optional compressed JPEG, at most 1 MB (multipart `photo`).
  final List<int>? photo;
}

/// The rider's task (06 §3). Every method throws `ApiError` on failure and
/// returns the task as the server now has it (the app renders that).
abstract interface class TaskRepository {
  /// `GET /rider/tasks/current/`: the active task (RETURNING included) or
  /// none, and the task that ended in the last 10 minutes.
  Future<CurrentTask> fetchCurrentTask();

  /// `POST .../arrived-store/ {lat, lng, accuracy?}`. 422 `OUTSIDE_GEOFENCE`
  /// with `distance_m` / `radius_m`.
  Future<RiderTask> arrivedAtStore(int taskId, GeoPoint at);

  /// `POST .../pickup/ {order_code}`: the 4-character code or the whole bag
  /// QR payload. 400 `PICKUP_CODE_INVALID` (`attempts_remaining`), 423
  /// `PICKUP_CODE_LOCKED`, 409 when the order is not PACKED.
  Future<RiderTask> pickup(int taskId, String orderCode);

  /// `POST .../arrived-customer/ {lat, lng, accuracy?, override_reason?}`.
  Future<RiderTask> arrivedAtCustomer(
    int taskId,
    GeoPoint at, {
    String? overrideReason,
  });

  /// `POST .../cod-qr/`: a UPI QR for the COD amount.
  Future<CodQr> createCodQr(int taskId);

  /// `POST .../deliver/ {otp, cod?: {mode, amount}}`. `DELIVERY_OTP_INVALID`
  /// (attempts left) or `DELIVERY_OTP_LOCKED`.
  Future<RiderTask> deliver(
    int taskId, {
    required String otp,
    CodMode? codMode,
    String? codAmount,
  });

  /// `POST .../fail/` (multipart: reason, note, call_attempts, photo?) →
  /// RETURNING in one call. 409 `INVALID_STATE_TRANSITION` with
  /// `details.reason` = `WAIT_NOT_ELAPSED` before `not_reachable_after`.
  Future<RiderTask> fail(int taskId, FailReport report);
}

/// Opens turn-by-turn navigation in another app (agent rule 8; no embedded
/// navigation in v1).
abstract interface class NavigationLauncher {
  /// Returns false when no app could open it.
  Future<bool> navigateTo(GeoPoint destination, {required String label});
}

/// One fresh location fix for arrived-at-store / arrived-at-customer. The
/// server enforces the geofence; the app only sends where the rider is.
abstract interface class CurrentLocationReader {
  /// Throws [LocationUnavailable] when there is no fix.
  Future<GeoPoint> current();
}

class LocationUnavailable implements Exception {
  const LocationUnavailable();
}

/// Rings and vibrates for an offer through the high-priority offer channel
/// (04 §2.4), also over the lock screen.
abstract interface class OfferAlerter {
  Future<void> ring(
    DeliveryOffer offer, {
    required String title,
    required String body,
    required Duration timeout,
  });

  Future<void> stop();
}

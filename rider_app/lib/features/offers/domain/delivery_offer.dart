import '../../task/domain/rider_task.dart';

/// A pending order offer (04 §2.4, 07 §2.8 `DeliveryOffer`), as
/// `GET /rider/offers/current/` and the `offer.new` push carry it.
///
/// TODO(api): hand-written until the rider contract lands (end of P4).
class DeliveryOffer {
  const DeliveryOffer({
    required this.id,
    required this.storeName,
    required this.dropLocality,
    required this.distanceKm,
    required this.paymentType,
    required this.estimatedPayout,
    required this.expiresAt,
    this.codAmount,
  });

  final int id;
  final String storeName;

  /// Locality only, never the full address (revealed on accept).
  final String dropLocality;

  /// Store → customer, as the server sends it (`"2.4"`).
  final String distanceKm;
  final PaymentType paymentType;

  /// COD amount to collect (`"249.00"`), null for prepaid.
  final String? codAmount;
  final String estimatedPayout;

  /// Server time (UTC) when the offer expires.
  final DateTime expiresAt;

  @override
  String toString() => 'DeliveryOffer($id)';
}

/// Offers last 30 s (04 §2.4, 08 §5).
const kOfferWindow = Duration(seconds: 30);

/// The countdown for an offer, driven by the server's `expires_at` (agent
/// rule 4), not by a local 30 s timer.
///
/// The phone clock can be wrong. When the response carries the server time
/// ([serverNow]), the deadline is moved onto the phone clock with that skew.
/// Without it, `expires_at` is read on the phone clock. Either way the
/// deadline is capped at [kOfferWindow] after the offer arrived, so a phone
/// clock that is behind never shows more than 30 s.
class OfferCountdown {
  OfferCountdown({
    required DateTime expiresAt,
    required DateTime receivedAt,
    DateTime? serverNow,
    Duration window = kOfferWindow,
  }) : deadline = _deadline(expiresAt, receivedAt, serverNow, window);

  /// When the offer expires, on the phone clock.
  final DateTime deadline;

  static DateTime _deadline(
    DateTime expiresAt,
    DateTime receivedAt,
    DateTime? serverNow,
    Duration window,
  ) {
    final received = receivedAt.toUtc();
    final byServer = serverNow == null
        ? expiresAt.toUtc()
        : received.add(expiresAt.toUtc().difference(serverNow.toUtc()));
    final cap = received.add(window);
    return byServer.isAfter(cap) ? cap : byServer;
  }

  Duration remaining(DateTime now) {
    final left = deadline.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  /// Whole seconds left, rounded up (shows 30 … 1, then 0).
  int secondsLeft(DateTime now) {
    final ms = remaining(now).inMilliseconds;
    return (ms / 1000).ceil();
  }

  bool isExpired(DateTime now) => remaining(now) == Duration.zero;
}

/// Why the rider declined (04 §2.4: optional).
///
/// TODO(api): wire values assumed.
enum OfferRejectReason {
  tooFar('TOO_FAR'),
  vehicleIssue('VEHICLE_ISSUE'),
  onBreak('ON_BREAK'),
  other('OTHER');

  const OfferRejectReason(this.wireValue);

  final String wireValue;
}

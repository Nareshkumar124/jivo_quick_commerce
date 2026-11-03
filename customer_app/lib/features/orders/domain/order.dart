import 'package:flutter/foundation.dart';

/// Orders as the checkout screens use them (`06 §2.6`, `08 §1`).
///
/// TODO(api): field names follow `06 §2.6` until the Phase 3 contract is
/// published; the API repository maps the generated models at S3-A.

/// `08 §1` order states. Customer-facing labels live in the ARB file.
enum OrderStatus {
  paymentPending('PAYMENT_PENDING'),
  placed('PLACED'),
  accepted('ACCEPTED'),
  packing('PACKING'),
  packed('PACKED'),
  outForDelivery('OUT_FOR_DELIVERY'),
  delivered('DELIVERED'),
  cancelled('CANCELLED'),
  paymentFailed('PAYMENT_FAILED'),
  deliveryFailed('DELIVERY_FAILED'),
  returned('RETURNED'),

  /// A status this build doesn't know (a newer server).
  unknown(null);

  const OrderStatus(this.wireValue);

  final String? wireValue;

  static OrderStatus fromWire(String? value) => values.firstWhere(
    (status) => status.wireValue != null && status.wireValue == value,
    orElse: () => unknown,
  );

  /// The server has the order: paid online or confirmed as COD. Only these
  /// statuses lead to the success screen (`02` rule 2: success only after
  /// the server confirms).
  bool get isConfirmed => switch (this) {
    placed ||
    accepted ||
    packing ||
    packed ||
    outForDelivery ||
    delivered => true,
    _ => false,
  };
}

/// How the customer pays (`03 §2.9`).
enum PaymentMethod {
  online('ONLINE'),
  cod('COD');

  const PaymentMethod(this.wireValue);

  final String wireValue;
}

/// What `razorpay_flutter` needs to open checkout, as `POST /orders/` (and
/// retry-payment) return it: `razorpay: {key_id, order_id, amount,
/// prefill}` (`06 §2.6`).
@immutable
class RazorpayCheckout {
  const RazorpayCheckout({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    this.currency = 'INR',
    this.prefillName,
    this.prefillEmail,
    this.prefillContact,
  });

  /// The public key id (never the secret).
  final String keyId;

  /// The Razorpay order id (`order_…`), not ours.
  final String orderId;

  /// Passed to Razorpay as is. TODO(api): `06 §2.6` doesn't say whether
  /// `amount` is integer paise (what Razorpay expects) or a rupee string;
  /// the app never converts it.
  final int amountPaise;
  final String currency;
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillContact;
}

/// An order as checkout sees it: `POST /orders/`, verify, retry-payment and
/// `GET /orders/{id}/`.
@immutable
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentMethod,
    required this.grandTotal,
    this.etaMinutes,
    this.paymentExpiresAt,
    this.razorpay,
  });

  final int id;

  /// The customer-facing order number.
  final String number;
  final OrderStatus status;
  final PaymentMethod paymentMethod;

  /// The server's grand total for this order.
  final String grandTotal;
  final int? etaMinutes;

  /// When a `PAYMENT_PENDING` order stops accepting payment (UTC; the
  /// 15-minute window, `08` T1/T4). TODO(api): not in `06 §2.6` yet.
  final DateTime? paymentExpiresAt;

  /// Set for ONLINE orders awaiting payment.
  final RazorpayCheckout? razorpay;

  PlacedOrder copyWith({OrderStatus? status, RazorpayCheckout? razorpay}) =>
      PlacedOrder(
        id: id,
        number: number,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        grandTotal: grandTotal,
        etaMinutes: etaMinutes,
        paymentExpiresAt: paymentExpiresAt,
        razorpay: razorpay ?? this.razorpay,
      );
}

/// `POST /orders/` body (`06 §2.6`).
@immutable
class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.addressId,
    required this.paymentMethod,
    required this.expectedGrandTotal,
  });

  final int addressId;
  final PaymentMethod paymentMethod;

  /// The grand total the customer saw, echoed back so the server can answer
  /// `PRICE_CHANGED` (`08` T1 guard). TODO(api): not in `06 §2.6` yet.
  final String expectedGrandTotal;
}

/// `POST /payments/razorpay/verify/` body (`06 §2.6`).
@immutable
class PaymentProof {
  const PaymentProof({
    required this.orderId,
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
  });

  /// Our order id.
  final int orderId;
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final String razorpaySignature;
}

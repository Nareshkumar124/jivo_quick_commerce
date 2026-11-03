import 'package:flutter/foundation.dart';

/// Orders as the checkout screens use them (`06 §2.6`, schema `Order`,
/// `OrderSummary`, `OrderPlacement`, `RazorpayCheckout`).

/// `08 §1` order states (`OrderStatusEnum`).
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
  /// statuses lead to the success screen (success only after the server
  /// confirms, `08 §4`).
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

/// How the customer pays (`PaymentMethodEnum`).
enum PaymentMethod {
  online('ONLINE'),
  cod('COD');

  const PaymentMethod(this.wireValue);

  final String wireValue;
}

/// Why an order is cancelled (`CancelReasonEnum`).
enum CancelReason {
  changePaymentMethod('CHANGE_PAYMENT_METHOD'),
  paymentProblem('PAYMENT_PROBLEM'),
  orderedByMistake('ORDERED_BY_MISTAKE'),
  changedMind('CHANGED_MIND'),
  deliveryTooSlow('DELIVERY_TOO_SLOW'),
  other('OTHER');

  const CancelReason(this.wireValue);

  final String wireValue;
}

/// Options for Razorpay checkout (`RazorpayCheckout`), all set by the
/// server and passed to the SDK unchanged.
@immutable
class RazorpayCheckout {
  const RazorpayCheckout({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    this.currency = 'INR',
    this.name = '',
    this.description = '',
    this.prefillName,
    this.prefillEmail,
    this.prefillContact,
    this.expiresAt,
    this.timeoutSeconds,
  });

  /// The key id the server chose. `rzp_fake_…` means the server's local
  /// fake gateway (`06 §2.6`): pay with the dev-only scheme instead of
  /// opening Razorpay.
  final String keyId;

  /// The Razorpay order id (`order_…`), not ours.
  final String orderId;

  /// `grand_total` in integer paise, as the server sent it. Display the
  /// order's `bill.grand_total` instead.
  final int amountPaise;
  final String currency;

  /// Merchant name and description shown in checkout.
  final String name;
  final String description;
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillContact;

  /// The end of the payment window (UTC).
  final DateTime? expiresAt;

  /// Seconds left in the window, Razorpay's `timeout`.
  final int? timeoutSeconds;

  /// The server's local fake gateway key (`06 §2.6`).
  bool get isFakeGateway => keyId.startsWith(fakeGatewayKeyPrefix);

  static const fakeGatewayKeyPrefix = 'rzp_fake_';
}

/// An order as checkout sees it: `OrderPlacement`, `Order` and
/// `OrderSummary` all map to this.
@immutable
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentMethod,
    required this.grandTotal,
    this.etaAt,
    this.paymentExpiresAt,
    this.canCancel = false,
    this.canRetryPayment = false,
    this.razorpay,
  });

  final int id;

  /// `order_number`, e.g. "JV-261103-000123".
  final String number;
  final OrderStatus status;
  final PaymentMethod paymentMethod;

  /// The server's `bill.grand_total` for this order.
  final String grandTotal;

  /// Promised delivery time (UTC); null until PLACED.
  final DateTime? etaAt;

  /// `PAYMENT_PENDING` only: the end of the payment window (UTC). A hint for
  /// the "Pay by" line; whether retry is allowed is [canRetryPayment].
  final DateTime? paymentExpiresAt;

  /// The server allows `POST /orders/{id}/cancel/` now.
  final bool canCancel;

  /// The server allows `POST /orders/{id}/retry-payment/` now.
  final bool canRetryPayment;

  /// Set while an ONLINE order awaits payment (`OrderPlacement.razorpay`).
  final RazorpayCheckout? razorpay;
}

/// `POST /orders/` body (`OrderCreateRequest`).
@immutable
class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.addressId,
    required this.paymentMethod,
    required this.expectedGrandTotal,
  });

  final int addressId;
  final PaymentMethod paymentMethod;

  /// The cart's `bill.grand_total` exactly as displayed; a different server
  /// total is 409 `PRICE_CHANGED`.
  final String expectedGrandTotal;

  @override
  bool operator ==(Object other) =>
      other is PlaceOrderRequest &&
      other.addressId == addressId &&
      other.paymentMethod == paymentMethod &&
      other.expectedGrandTotal == expectedGrandTotal;

  @override
  int get hashCode => Object.hash(addressId, paymentMethod, expectedGrandTotal);
}

/// `POST /payments/razorpay/verify/` body (`PaymentVerifyRequest`).
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

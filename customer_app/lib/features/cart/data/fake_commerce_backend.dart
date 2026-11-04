import 'dart:math' as math;

import 'package:jivo_core/jivo_core.dart';

import '../../catalog/domain/catalog_models.dart';
import '../../checkout/data/fake_payment_launcher.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../domain/cart.dart';
import 'cart_repository.dart';

/// Demo pricing rules for the fake backend only. The real values are a
/// Jivo decision (D-09) and live on the server.
class FakeBillRules {
  const FakeBillRules({
    this.freeDeliveryThreshold = 19900,
    this.deliveryFee = 2500,
    this.smallCartThreshold = 9900,
    this.smallCartFee = 1500,
    this.handlingFee = 500,
    this.minimumOrder = 4900,
    this.codMaxOrderValue = 150000,
    this.maxTip = 50000,
    this.paymentWindow = const Duration(minutes: 15),
    this.eta = const Duration(minutes: 15),
  });

  static const demo = FakeBillRules();

  // Amounts in paise.
  final int freeDeliveryThreshold;
  final int deliveryFee;
  final int smallCartThreshold;
  final int smallCartFee;
  final int handlingFee;
  final int minimumOrder;
  final int codMaxOrderValue;

  /// `CART_MAX_TIP`.
  final int maxTip;
  final Duration paymentWindow;
  final Duration eta;
}

/// A demo coupon (fake backend only).
class FakeCoupon {
  const FakeCoupon({
    required this.code,
    required this.title,
    required this.description,
    this.minItemTotal = 0,
    this.flatOff,
    this.percentOff,
    this.maxDiscount,
    this.firstOrderOnly = false,
    this.expired = false,
  });

  final String code;
  final String title;
  final String description;

  // Paise.
  final int minItemTotal;
  final int? flatOff;
  final int? percentOff;
  final int? maxDiscount;
  final bool firstOrderOnly;

  /// Not listed; applying it is `COUPON_EXPIRED`.
  final bool expired;
}

/// The key id the server's local fake gateway sends (`06 §2.6`).
const fakeGatewayKeyId = 'rzp_fake_jivo_local';

/// A stand-in for the server cart and orders (`06 §2.5`, `§2.6`, `08`
/// T1–T5), with the same shapes and rules as the Phase 3 contract. It
/// serves the tests and the **dev** flavor with `FAKE_API=true` only, never
/// staging or prod (`app/repositories.dart`).
///
/// Because it plays the server, this is the only code in the app that adds
/// money up. It mirrors `compute_bill` (`08 §6.2`) in integer paise with the
/// demo [FakeBillRules]; screens and controllers only render what it
/// returns, exactly as they render the real API. Online payments use the
/// server's fake gateway scheme (`rzp_fake_jivo_local`, HMAC signatures).
class FakeCommerceBackend implements CartRepository, OrderRepository {
  FakeCommerceBackend({
    this.rules = FakeBillRules.demo,
    this.latency = const Duration(milliseconds: 250),
    this.signer = fakePaymentSignature,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FakeBillRules rules;
  final Duration latency;

  /// Checks the verify call's signature (the fake gateway's scheme).
  final FakePaymentSigner signer;
  final DateTime Function() _clock;

  static const demoCoupons = [
    FakeCoupon(
      code: 'JIVO50',
      title: 'Flat ₹50 off',
      description: 'On orders above ₹299',
      minItemTotal: 29900,
      flatOff: 5000,
    ),
    FakeCoupon(
      code: 'WELCOME10',
      title: '10% off up to ₹100',
      description: 'On orders above ₹149',
      minItemTotal: 14900,
      percentOff: 10,
      maxDiscount: 10000,
    ),
    FakeCoupon(
      code: 'FIRSTORDER',
      title: 'Flat ₹75 off',
      description: 'On your first order',
      flatOff: 7500,
      firstOrderOnly: true,
    ),
    FakeCoupon(
      code: 'OILFEST',
      title: 'Flat ₹25 off',
      description: 'On cooking oils',
      flatOff: 2500,
      expired: true,
    ),
  ];

  final _lines = <int, _FakeLine>{};
  int _nextLineId = 1;
  String? _couponCode;
  int _tip = 0;
  DeliveryInstructions _instructions = DeliveryInstructions.none;
  int? _savedAddressId;

  /// Whether the store takes orders (`STORE_CLOSED` when false).
  bool storeOpen = true;

  /// Units orderable per variant id, overriding the tile's
  /// `orderable_quantity` (simulates stock dropping after adding).
  final stock = <int, int>{};

  /// Coupons this customer has used up (`COUPON_USAGE_EXCEEDED`).
  final usedCoupons = <String>{};

  /// When set, the next call throws it once.
  Object? failNext;

  final _orders = <int, _FakeOrder>{};
  final _orderByKey = <String, (int, PlaceOrderRequest)>{};
  final _retryByKey = <String, RazorpayCheckout>{};
  int _nextOrderId = 1001;
  int _razorpaySequence = 1;

  /// Orders placed so far (tests).
  Iterable<PlacedOrder> get orders => _orders.values.map(_toOrder);

  Future<void> _respond() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  static Never _fail(
    ApiErrorCode code, {
    int status = 400,
    Map<String, Object?> details = const {},
  }) => throw ApiError(
    code: code,
    rawCode: code.wireValue,
    details: details,
    statusCode: status,
  );

  // --- CartRepository -----------------------------------------------------

  @override
  Future<CartSnapshot> load({int? addressId}) async {
    await _respond();
    return _snapshot(addressId: addressId);
  }

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) async {
    await _respond();
    final line = _lines[variantId];
    if (quantity <= 0) {
      _lines.remove(variantId);
      return _snapshot();
    }
    final known = preview ?? line?.preview;
    if (known == null) _fail(ApiErrorCode.notFound, status: 404);
    final current = line?.quantity ?? 0;
    // A decrease is always accepted; an increase is checked.
    if (quantity > current) {
      final variant = known.variant;
      if (quantity > variant.maxQtyPerOrder) {
        _fail(
          ApiErrorCode.maxQtyExceeded,
          status: 422,
          details: {
            'variant_id': variantId,
            'max_qty_per_order': variant.maxQtyPerOrder,
          },
        );
      }
      final orderable = _orderable(known.variant);
      if (quantity > orderable) {
        _fail(
          ApiErrorCode.stockUnavailable,
          status: 409,
          details: {
            'items': [
              {
                'variant_id': variantId,
                'requested_quantity': quantity,
                'orderable_quantity': orderable,
              },
            ],
          },
        );
      }
    }
    if (line == null) {
      _lines[variantId] = _FakeLine(_nextLineId++, known, quantity);
    } else {
      line.quantity = quantity;
    }
    return _snapshot();
  }

  @override
  Future<CartSnapshot> clear() async {
    await _respond();
    // Lines, coupon and tip go; the address and instructions stay.
    _lines.clear();
    _couponCode = null;
    _tip = 0;
    return _snapshot();
  }

  @override
  Future<List<CouponOffer>> coupons() async {
    await _respond();
    final itemTotal = _itemTotal();
    final offers = <CouponOffer>[];
    for (final coupon in demoCoupons) {
      if (coupon.expired || usedCoupons.contains(coupon.code)) continue;
      final result = _evaluate(coupon, itemTotal);
      offers.add(
        CouponOffer(
          code: coupon.code,
          title: coupon.title,
          description: coupon.description,
          isEligible: result.reason == null,
          isApplied: _couponCode == coupon.code,
          savings: result.reason == null ? _amount(result.discount) : null,
          ineligibility: result.reason,
          message: result.reason == null ? null : 'Not eligible',
          amountToUnlock: result.toUnlock == null
              ? null
              : _amount(result.toUnlock!),
        ),
      );
    }
    // Eligible first.
    offers.sort((a, b) => (a.isEligible ? 0 : 1) - (b.isEligible ? 0 : 1));
    return offers;
  }

  @override
  Future<CartSnapshot> applyCoupon(String code) async {
    await _respond();
    final normalised = code.trim().toUpperCase();
    final coupon = demoCoupons.where((c) => c.code == normalised).firstOrNull;
    if (coupon == null) _fail(ApiErrorCode.couponInvalid, status: 422);
    if (coupon.expired) _fail(ApiErrorCode.couponExpired, status: 422);
    if (usedCoupons.contains(coupon.code)) {
      _fail(
        ApiErrorCode.couponUsageExceeded,
        status: 422,
        details: {'scope': 'per_user'},
      );
    }
    final result = _evaluate(coupon, _itemTotal());
    switch (result.reason) {
      case null:
        _couponCode = coupon.code;
        return _snapshot();
      case CouponIneligibility.minOrderValue:
        _fail(
          ApiErrorCode.couponNotEligible,
          status: 422,
          details: {
            'reason': 'MIN_ORDER_VALUE',
            'min_order_value': _amount(coupon.minItemTotal),
            'amount_to_unlock': _amount(result.toUnlock!),
          },
        );
      case CouponIneligibility.firstOrderOnly:
        _fail(
          ApiErrorCode.couponNotEligible,
          status: 422,
          details: {'reason': 'FIRST_ORDER_ONLY'},
        );
      case _:
        _fail(ApiErrorCode.couponNotEligible, status: 422);
    }
  }

  @override
  Future<CartSnapshot> removeCoupon() async {
    await _respond();
    _couponCode = null;
    return _snapshot();
  }

  @override
  Future<CartSnapshot> update(CartUpdate update) async {
    await _respond();
    final tip = update.tip;
    final paise = tip == null ? null : _paise(tip);
    if (paise != null && (paise < 0 || paise > rules.maxTip)) {
      _fail(
        ApiErrorCode.validationError,
        details: {
          'tip': ['Ensure this value is at most ${_amount(rules.maxTip)}.'],
        },
      );
    }
    final instructions = update.instructions;
    if (instructions != null &&
        instructions.note.length > DeliveryInstructions.maxNoteLength) {
      _fail(
        ApiErrorCode.validationError,
        details: {
          'instructions': [
            'Ensure this field has no more than 200 characters.',
          ],
        },
      );
    }
    if (paise != null) _tip = paise;
    if (instructions != null) _instructions = instructions;
    if (update.addressId != null) _savedAddressId = update.addressId;
    return _snapshot();
  }

  // --- OrderRepository ----------------------------------------------------

  @override
  Future<PlacedOrder> placeOrder(
    PlaceOrderRequest request, {
    required String idempotencyKey,
  }) async {
    await _respond();
    final repeat = _orderByKey[idempotencyKey];
    if (repeat != null) {
      if (repeat.$2 != request) {
        _fail(
          ApiErrorCode.validationError,
          details: {
            'Idempotency-Key': ['This key was used for a different order.'],
          },
        );
      }
      return _toOrder(_order(repeat.$1));
    }
    final pending = _orders.values.where(
      (o) => _refresh(o).status == OrderStatus.paymentPending,
    );
    if (pending.isNotEmpty) {
      _fail(
        ApiErrorCode.invalidStateTransition,
        status: 409,
        details: {'pending_order_id': pending.first.id},
      );
    }
    final cart = _snapshot(addressId: request.addressId);
    final bill = cart.bill!;
    if (cart.isEmpty) {
      _fail(
        ApiErrorCode.validationError,
        details: {
          'non_field_errors': ['Your cart is empty.'],
        },
      );
    }
    if (!storeOpen) _fail(ApiErrorCode.storeClosed, status: 422);
    if (cart.hasProblems) {
      _fail(
        ApiErrorCode.stockUnavailable,
        status: 409,
        details: {
          'items': [
            for (final line in cart.problemLines)
              {
                'variant_id': line.variantId,
                'requested_quantity': line.quantity,
                'orderable_quantity': line.orderableQuantity,
              },
          ],
        },
      );
    }
    final toMinimum = cart.thresholds?.amountToMinOrder;
    if (toMinimum != null) {
      _fail(
        ApiErrorCode.minOrderNotMet,
        status: 422,
        details: {
          'min_order_value': cart.thresholds!.minOrderValue,
          'item_total': bill.itemTotal,
          'amount_to_min_order': toMinimum,
        },
      );
    }
    if (cart.coupon?.isApplicable == false) {
      _fail(ApiErrorCode.couponNotEligible, status: 422);
    }
    if (_paise(request.expectedGrandTotal) != _paise(bill.grandTotal)) {
      _fail(
        ApiErrorCode.priceChanged,
        status: 409,
        details: {
          'expected_grand_total': request.expectedGrandTotal,
          'grand_total': bill.grandTotal,
        },
      );
    }
    final cod = request.paymentMethod == PaymentMethod.cod;
    if (cod && !cart.codAvailable) {
      _fail(
        ApiErrorCode.codNotAvailable,
        status: 422,
        details: {
          'reason': 'ABOVE_LIMIT',
          'cod_max_order_value': _amount(rules.codMaxOrderValue),
        },
      );
    }

    final id = _nextOrderId++;
    final now = _clock().toUtc();
    final order = _FakeOrder(
      id: id,
      number: 'JV-${_yymmdd(now)}-${id.toString().padLeft(6, '0')}',
      method: request.paymentMethod,
      grandTotal: bill.grandTotal,
      status: cod ? OrderStatus.placed : OrderStatus.paymentPending,
      couponCode: _couponCode,
    );
    if (cod) {
      _redeem(order);
    } else {
      order
        ..expiresAt = now.add(rules.paymentWindow)
        ..razorpay = _newRazorpayOrder(order);
    }
    _orders[id] = order;
    _orderByKey[idempotencyKey] = (id, request);
    return _toOrder(order);
  }

  @override
  Future<PlacedOrder> verifyPayment(PaymentProof proof) async {
    await _respond();
    final order = _order(proof.orderId);
    if (order.status.isConfirmed) return _toOrder(order);
    if (order.status != OrderStatus.paymentPending) {
      _fail(
        ApiErrorCode.invalidStateTransition,
        status: 409,
        details: {'status': order.status.wireValue},
      );
    }
    final expected = signer(proof.razorpayOrderId, proof.razorpayPaymentId);
    if (proof.razorpayOrderId != order.razorpay?.orderId ||
        proof.razorpaySignature != expected) {
      _fail(ApiErrorCode.paymentVerificationFailed);
    }
    order.status = OrderStatus.placed;
    _redeem(order);
    return _toOrder(order);
  }

  @override
  Future<PlacedOrder> retryPayment(
    int orderId, {
    required String idempotencyKey,
  }) async {
    await _respond();
    final order = _order(orderId);
    if (order.status != OrderStatus.paymentPending) {
      _fail(
        ApiErrorCode.invalidStateTransition,
        status: 409,
        details: {'status': order.status.wireValue},
      );
    }
    order.razorpay = _retryByKey.putIfAbsent(
      idempotencyKey,
      () => _newRazorpayOrder(order),
    );
    return _toOrder(order);
  }

  @override
  Future<PlacedOrder> cancelOrder(
    int orderId, {
    required CancelReason reason,
  }) async {
    await _respond();
    final order = _order(orderId);
    if (order.status != OrderStatus.paymentPending) {
      _fail(
        ApiErrorCode.invalidStateTransition,
        status: 409,
        details: {'status': order.status.wireValue},
      );
    }
    // T5: stock and the coupon hold are released; the cart stays.
    order
      ..status = OrderStatus.cancelled
      ..cancelReason = reason;
    return _toOrder(order);
  }

  @override
  Future<PlacedOrder> getOrder(int orderId) async {
    await _respond();
    return _toOrder(_order(orderId));
  }

  @override
  Future<List<PlacedOrder>> activeOrders() async {
    await _respond();
    return [
      for (final order in _orders.values.toList().reversed)
        if (_isActive(_refresh(order).status)) _toOrder(order),
    ];
  }

  /// The webhook confirmed a payment (T3) that the app never verified.
  void confirmByWebhook(int orderId) {
    final order = _orders[orderId]!;
    order.status = OrderStatus.placed;
    _redeem(order);
  }

  /// Why the order was cancelled (tests).
  CancelReason? cancelReasonOf(int orderId) => _orders[orderId]?.cancelReason;

  // --- internals ----------------------------------------------------------

  static bool _isActive(OrderStatus status) => switch (status) {
    OrderStatus.delivered ||
    OrderStatus.cancelled ||
    OrderStatus.paymentFailed ||
    OrderStatus.returned => false,
    _ => true,
  };

  _FakeOrder _order(int id) {
    final order = _orders[id];
    if (order == null) _fail(ApiErrorCode.notFound, status: 404);
    return _refresh(order);
  }

  /// T4: the expiry job fails an unpaid order after the window.
  _FakeOrder _refresh(_FakeOrder order) {
    final expiresAt = order.expiresAt;
    if (order.status == OrderStatus.paymentPending &&
        expiresAt != null &&
        !_clock().toUtc().isBefore(expiresAt)) {
      order.status = OrderStatus.paymentFailed;
    }
    return order;
  }

  PlacedOrder _toOrder(_FakeOrder order) {
    final pending = order.status == OrderStatus.paymentPending;
    final expiresAt = pending ? order.expiresAt : null;
    final razorpay = order.razorpay;
    return PlacedOrder(
      id: order.id,
      number: order.number,
      status: order.status,
      paymentMethod: order.method,
      grandTotal: order.grandTotal,
      etaAt: order.status.isConfirmed ? order.etaAt : null,
      paymentExpiresAt: expiresAt,
      canCancel: pending,
      canRetryPayment: pending && order.method == PaymentMethod.online,
      razorpay: pending && razorpay != null
          ? RazorpayCheckout(
              keyId: razorpay.keyId,
              orderId: razorpay.orderId,
              amountPaise: razorpay.amountPaise,
              name: razorpay.name,
              description: razorpay.description,
              prefillName: razorpay.prefillName,
              prefillContact: razorpay.prefillContact,
              expiresAt: expiresAt,
              timeoutSeconds: expiresAt == null
                  ? null
                  : math.max(
                      1,
                      expiresAt.difference(_clock().toUtc()).inSeconds,
                    ),
            )
          : null,
    );
  }

  /// T2/T3: the ordered lines leave the cart and the coupon is redeemed.
  void _redeem(_FakeOrder order) {
    final code = order.couponCode;
    if (code != null) usedCoupons.add(code);
    order.etaAt = _clock().toUtc().add(rules.eta);
    _lines.clear();
    _couponCode = null;
    _tip = 0;
    _hasOrdered = true;
  }

  bool _hasOrdered = false;

  RazorpayCheckout _newRazorpayOrder(_FakeOrder order) => RazorpayCheckout(
    keyId: fakeGatewayKeyId,
    // "order_" + 14 letters/digits, like the server's fake gateway.
    orderId: 'order_FAKE${(_razorpaySequence++).toString().padLeft(10, '0')}',
    amountPaise: _paise(order.grandTotal),
    name: 'Jivo',
    description: order.number,
    prefillName: 'Test Customer',
    prefillContact: '+919000000001',
  );

  int _orderable(CatalogVariant variant) {
    final cap = variant.maxSelectable;
    final available = stock[variant.id];
    return available == null ? cap : math.max(0, math.min(cap, available));
  }

  int _itemTotal() => _lines.values.fold(
    0,
    (sum, line) =>
        sum + _paise(line.preview.variant.sellingPrice) * line.quantity,
  );

  ({int discount, CouponIneligibility? reason, int? toUnlock}) _evaluate(
    FakeCoupon coupon,
    int itemTotal,
  ) {
    if (coupon.firstOrderOnly && _hasOrdered) {
      return (
        discount: 0,
        reason: CouponIneligibility.firstOrderOnly,
        toUnlock: null,
      );
    }
    if (itemTotal == 0 || itemTotal < coupon.minItemTotal) {
      return (
        discount: 0,
        reason: CouponIneligibility.minOrderValue,
        toUnlock: math.max(coupon.minItemTotal - itemTotal, 0),
      );
    }
    var discount =
        coupon.flatOff ?? (itemTotal * (coupon.percentOff ?? 0) + 50) ~/ 100;
    final cap = coupon.maxDiscount;
    if (cap != null) discount = math.min(discount, cap);
    return (
      discount: math.min(discount, itemTotal),
      reason: null,
      toUnlock: null,
    );
  }

  /// `compute_bill` (`08 §6.2`), in paise, plus the cart's thresholds,
  /// payment methods and checkout blockers. [addressId] checks the cart
  /// against that address without saving it (`GET /cart/?address_id=`).
  CartSnapshot _snapshot({int? addressId}) {
    final lines = <CartLine>[];
    var mrpTotal = 0;
    var itemTotal = 0;
    var units = 0;
    for (final line in _lines.values) {
      final variant = line.preview.variant;
      final orderable = _orderable(variant);
      final issue = orderable <= 0
          ? const CartLineIssue(
              code: CartIssueCode.outOfStock,
              message: 'Out of stock: remove it to continue.',
            )
          : line.quantity > orderable
          ? CartLineIssue(
              code: CartIssueCode.quantityUnavailable,
              message: 'Only $orderable left',
            )
          : null;
      final price = _paise(variant.sellingPrice);
      final mrp = _paise(variant.mrp);
      mrpTotal += mrp * line.quantity;
      itemTotal += price * line.quantity;
      units += line.quantity;
      lines.add(
        CartLine(
          id: line.id,
          productName: line.preview.productName,
          variant: _withOrderable(variant, orderable),
          quantity: line.quantity,
          lineMrpTotal: _amount(mrp * line.quantity),
          lineTotal: _amount(price * line.quantity),
          issue: issue,
        ),
      );
    }
    final empty = lines.isEmpty;

    AppliedCoupon? coupon;
    var couponDiscount = 0;
    final code = _couponCode;
    if (code != null) {
      final rule = demoCoupons.firstWhere((c) => c.code == code);
      final result = _evaluate(rule, itemTotal);
      couponDiscount = result.discount;
      coupon = AppliedCoupon(
        code: code,
        title: rule.title,
        discount: _amount(couponDiscount),
        isApplicable: result.reason == null,
        message: result.toUnlock == null
            ? null
            : 'Add items worth ${_rupees(result.toUnlock!)} more',
      );
    }

    final deliveryFee = empty || itemTotal >= rules.freeDeliveryThreshold
        ? 0
        : rules.deliveryFee;
    final smallCartFee = !empty && itemTotal < rules.smallCartThreshold
        ? rules.smallCartFee
        : 0;
    final handlingFee = empty ? 0 : rules.handlingFee;
    final tip = empty ? 0 : _tip;
    final grandTotal =
        itemTotal -
        couponDiscount +
        deliveryFee +
        smallCartFee +
        handlingFee +
        tip;
    final productDiscount = mrpTotal - itemTotal;
    final toFreeDelivery = rules.freeDeliveryThreshold - itemTotal;
    final toMinimum = rules.minimumOrder - itemTotal;
    final address = addressId ?? _savedAddressId;
    final codAvailable = grandTotal <= rules.codMaxOrderValue;
    final hasProblems = lines.any((line) => line.issue != null);

    final blockers = <CheckoutBlocker>[
      if (empty)
        const CheckoutBlocker(
          code: CheckoutBlockerCode.cartEmpty,
          message: 'Add items to your cart.',
        )
      else ...[
        if (address == null)
          const CheckoutBlocker(
            code: CheckoutBlockerCode.addressRequired,
            message: 'Select a delivery address.',
          ),
        if (!storeOpen)
          const CheckoutBlocker(
            code: CheckoutBlockerCode.storeClosed,
            message: 'The store is not accepting orders right now.',
          ),
        if (hasProblems)
          const CheckoutBlocker(
            code: CheckoutBlockerCode.stockUnavailable,
            message: 'Some items are not available as chosen.',
          ),
        if (toMinimum > 0)
          CheckoutBlocker(
            code: CheckoutBlockerCode.minOrderNotMet,
            message: 'Add items worth ${_rupees(toMinimum)} more to order.',
          ),
        if (coupon != null && !coupon.isApplicable)
          const CheckoutBlocker(
            code: CheckoutBlockerCode.couponNotEligible,
            message: 'This cart is not eligible for the coupon.',
          ),
      ],
    ];

    return CartSnapshot.fromLines(
      lines: lines,
      itemCount: units,
      bill: CartBill(
        mrpTotal: _amount(mrpTotal),
        itemTotal: _amount(itemTotal),
        productDiscount: _amount(productDiscount),
        couponDiscount: _amount(couponDiscount),
        deliveryFee: _amount(deliveryFee),
        smallCartFee: _amount(smallCartFee),
        handlingFee: _amount(handlingFee),
        tip: _amount(tip),
        grandTotal: _amount(grandTotal),
        totalSavings: _amount(productDiscount + couponDiscount),
      ),
      coupon: coupon,
      tip: _amount(_tip),
      instructions: _instructions,
      addressId: address,
      thresholds: CartThresholds(
        minOrderValue: _amount(rules.minimumOrder),
        amountToMinOrder: toMinimum > 0 ? _amount(toMinimum) : null,
        freeDeliveryThreshold: _amount(rules.freeDeliveryThreshold),
        amountToFreeDelivery: toFreeDelivery > 0
            ? _amount(toFreeDelivery)
            : null,
      ),
      paymentOptions: [
        const PaymentOption(method: PaymentMethod.online, available: true),
        PaymentOption(
          method: PaymentMethod.cod,
          available: codAvailable,
          reason: codAvailable ? null : PaymentUnavailableReason.aboveLimit,
          message: codAvailable
              ? null
              : 'Cash on delivery is available up to '
                    '${_rupees(rules.codMaxOrderValue)}.',
        ),
      ],
      checkout: CheckoutStatus(
        canPlaceOrder: blockers.isEmpty,
        blockers: blockers,
      ),
      storeOpen: storeOpen,
    );
  }

  static CatalogVariant _withOrderable(CatalogVariant v, int orderable) =>
      CatalogVariant(
        id: v.id,
        name: v.name,
        sellingPrice: v.sellingPrice,
        mrp: v.mrp,
        stockStatus: orderable <= 0 ? StockStatus.outOfStock : v.stockStatus,
        orderableQuantity: orderable,
        maxQtyPerOrder: v.maxQtyPerOrder,
        discountAmount: v.discountAmount,
        discountPercent: v.discountPercent,
        unitsLeft: v.unitsLeft,
        unitPrice: v.unitPrice,
        imageUrl: v.imageUrl,
      );

  static String _yymmdd(DateTime t) =>
      '${(t.year % 100).toString().padLeft(2, '0')}'
      '${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}';

  static final _money = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

  static int _paise(String amount) {
    final match = _money.firstMatch(amount.trim());
    if (match == null) {
      _fail(
        ApiErrorCode.validationError,
        details: {
          'amount': ['Not a valid amount.'],
        },
      );
    }
    final rupees = int.parse(match.group(1)!);
    final paise = int.parse((match.group(2) ?? '0').padRight(2, '0'));
    return rupees * 100 + paise;
  }

  static String _amount(int paise) =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

  /// "₹74" style text for the fake server's display messages.
  static String _rupees(int paise) => paise % 100 == 0
      ? '₹${paise ~/ 100}'
      : '₹${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
}

class _FakeLine {
  _FakeLine(this.id, this.preview, this.quantity);

  final int id;
  final CartLinePreview preview;
  int quantity;
}

class _FakeOrder {
  _FakeOrder({
    required this.id,
    required this.number,
    required this.method,
    required this.grandTotal,
    required this.status,
    this.couponCode,
  });

  final int id;
  final String number;
  final PaymentMethod method;
  final String grandTotal;
  final String? couponCode;
  OrderStatus status;
  DateTime? expiresAt;
  DateTime? etaAt;
  RazorpayCheckout? razorpay;
  CancelReason? cancelReason;
}

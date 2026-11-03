import 'dart:math' as math;

import 'package:jivo_core/jivo_core.dart';

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
    this.paymentWindow = const Duration(minutes: 15),
    this.etaMinutes = 15,
  });

  static const demo = FakeBillRules();

  // All amounts in paise.
  final int freeDeliveryThreshold;
  final int deliveryFee;
  final int smallCartThreshold;
  final int smallCartFee;
  final int handlingFee;
  final int minimumOrder;
  final int codMaxOrderValue;
  final Duration paymentWindow;
  final int etaMinutes;
}

/// A demo coupon (fake backend only).
class FakeCoupon {
  const FakeCoupon({
    required this.code,
    required this.title,
    this.description,
    this.minItemTotal = 0,
    this.flatOff,
    this.percentOff,
    this.maxDiscount,
    this.expired = false,
  });

  final String code;
  final String title;
  final String? description;

  // Paise.
  final int minItemTotal;
  final int? flatOff;
  final int? percentOff;
  final int? maxDiscount;
  final bool expired;
}

/// TODO(api): a stand-in for the server cart and orders (`06 §2.5`,
/// `§2.6`, `08` T1–T5) until the Phase 3 API is wired at S3-A. It is used by
/// tests and by the **dev** flavor only, never staging or prod
/// (`app/repositories.dart`).
///
/// Because it plays the server, this is the only code in the app that adds
/// money up. It mirrors `compute_bill` (`08 §6.2`) in integer paise with the
/// demo [FakeBillRules]; screens and controllers only render what it
/// returns, exactly as they will render the real API.
class FakeCommerceBackend implements CartRepository, OrderRepository {
  FakeCommerceBackend({
    this.rules = FakeBillRules.demo,
    this.latency = const Duration(milliseconds: 250),
    this.signer = fakePaymentSignature,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FakeBillRules rules;
  final Duration latency;

  /// The fake-payment signature scheme (TODO(api)).
  final FakePaymentSigner signer;
  final DateTime Function() _clock;

  static const demoCoupons = [
    FakeCoupon(
      code: 'JIVO50',
      title: '₹50 off on orders above ₹299',
      description: 'Flat ₹50 off on Jivo products.',
      minItemTotal: 29900,
      flatOff: 5000,
    ),
    FakeCoupon(
      code: 'WELCOME10',
      title: '10% off up to ₹100',
      description: 'On orders above ₹149.',
      minItemTotal: 14900,
      percentOff: 10,
      maxDiscount: 10000,
    ),
    FakeCoupon(
      code: 'FIRSTORDER',
      title: '₹75 off your first order',
      flatOff: 7500,
    ),
    FakeCoupon(
      code: 'OILFEST',
      title: '₹25 off cooking oils',
      flatOff: 2500,
      expired: true,
    ),
  ];

  final _lines = <int, _FakeLine>{};
  int _nextLineId = 1;
  String? _couponCode;
  int _tip = 0;
  DeliveryInstructions _instructions = DeliveryInstructions.none;
  int? _addressId;

  /// Units available per variant id, overriding the tile's
  /// `orderable_quantity` (simulates stock dropping after adding).
  final stock = <int, int>{};

  /// Coupons this customer has already used up.
  final usedCoupons = <String>{'FIRSTORDER'};

  /// When set, the next call throws it once.
  Object? failNext;

  final _orders = <int, _FakeOrder>{};
  final _orderByKey = <String, int>{};
  final _retryByKey = <String, RazorpayCheckout>{};
  int _nextOrderId = 1001;
  int _razorpaySequence = 1;

  /// Placed orders, newest last (tests).
  Iterable<PlacedOrder> get orders => _orders.values.map((o) => o.toOrder());

  Future<void> _respond() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  static Never _fail(
    ApiErrorCode code, [
    Map<String, Object?> details = const {},
  ]) => throw ApiError(
    code: code,
    rawCode: code.wireValue,
    details: details,
    statusCode: 400,
  );

  // --- CartRepository -----------------------------------------------------

  @override
  Future<CartSnapshot> load({int? addressId}) async {
    await _respond();
    if (addressId != null) _addressId = addressId;
    return _snapshot();
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
    if (known == null) _fail(ApiErrorCode.notFound);
    final cap = _orderable(variantId, known);
    if (cap <= 0) {
      _fail(ApiErrorCode.stockUnavailable, {
        'items': [
          {'variant_id': variantId, 'available': 0},
        ],
      });
    }
    if (quantity > cap) {
      _fail(ApiErrorCode.maxQtyExceeded, {'max_quantity': cap});
    }
    if (line == null) {
      _lines[variantId] = _FakeLine(_nextLineId++, variantId, known, quantity);
    } else {
      line.quantity = quantity;
    }
    return _snapshot();
  }

  @override
  Future<CartSnapshot> clear() async {
    await _respond();
    _clearCart();
    return _snapshot();
  }

  @override
  Future<List<CouponOffer>> coupons() async {
    await _respond();
    final itemTotal = _itemTotal();
    return [
      for (final coupon in demoCoupons)
        () {
          final result = _evaluate(coupon, itemTotal);
          return CouponOffer(
            code: coupon.code,
            title: coupon.title,
            description: coupon.description,
            savings: result.problem == null ? _amount(result.discount) : null,
            problem: result.problem,
            shortfall: result.shortfall == null
                ? null
                : _amount(result.shortfall!),
          );
        }(),
    ];
  }

  @override
  Future<CartSnapshot> applyCoupon(String code) async {
    await _respond();
    final normalised = code.trim().toUpperCase();
    final coupon = demoCoupons.where((c) => c.code == normalised).firstOrNull;
    if (coupon == null) _fail(ApiErrorCode.couponInvalid);
    final result = _evaluate(coupon, _itemTotal());
    switch (result.problem) {
      case null:
        _couponCode = coupon.code;
        return _snapshot();
      case CouponProblem.expired:
        _fail(ApiErrorCode.couponExpired);
      case CouponProblem.usageExceeded:
        _fail(ApiErrorCode.couponUsageExceeded);
      case CouponProblem.minOrderNotMet:
        _fail(ApiErrorCode.couponNotEligible, {
          'shortfall': _amount(result.shortfall!),
        });
      case CouponProblem.notEligible:
        _fail(ApiErrorCode.couponNotEligible);
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
    if (tip != null) {
      final paise = _paise(tip);
      if (paise < 0) {
        _fail(ApiErrorCode.validationError, {
          'tip': ['Enter a valid tip.'],
        });
      }
      _tip = paise;
    }
    final instructions = update.instructions;
    if (instructions != null) {
      if (instructions.note.length > DeliveryInstructions.maxNoteLength) {
        _fail(ApiErrorCode.validationError, {
          'instructions': ['Too long.'],
        });
      }
      _instructions = instructions;
    }
    if (update.addressId != null) _addressId = update.addressId;
    return _snapshot();
  }

  // --- OrderRepository ----------------------------------------------------

  @override
  Future<PlacedOrder> placeOrder(
    PlaceOrderRequest request, {
    required String idempotencyKey,
  }) async {
    await _respond();
    final existing = _orderByKey[idempotencyKey];
    if (existing != null) return _orders[existing]!.toOrder();

    final cart = _snapshot();
    final bill = cart.bill;
    if (cart.isEmpty || bill == null) {
      _fail(ApiErrorCode.validationError, {
        'non_field_errors': ['Your cart is empty.'],
      });
    }
    if (cart.hasProblems) {
      _fail(ApiErrorCode.stockUnavailable, {
        'items': [
          for (final line in cart.problemLines)
            {
              'variant_id': line.variantId,
              'available': line.availableQuantity ?? 0,
            },
        ],
      });
    }
    if (!(cart.minimumOrder?.met ?? true)) {
      _fail(ApiErrorCode.minOrderNotMet);
    }
    if (_paise(request.expectedGrandTotal) != _paise(bill.grandTotal)) {
      _fail(ApiErrorCode.priceChanged);
    }
    final cod = request.paymentMethod == PaymentMethod.cod;
    if (cod && !cart.codAvailable) _fail(ApiErrorCode.codNotAvailable);

    final id = _nextOrderId++;
    final order = _FakeOrder(
      id: id,
      number: 'JQ${id.toString().padLeft(6, '0')}',
      method: request.paymentMethod,
      grandTotal: bill.grandTotal,
      etaMinutes: rules.etaMinutes,
      status: cod ? OrderStatus.placed : OrderStatus.paymentPending,
      couponCode: _couponCode,
    );
    if (cod) {
      _redeem(order);
    } else {
      order
        ..expiresAt = _clock().toUtc().add(rules.paymentWindow)
        ..razorpay = _newRazorpayOrder(bill.grandTotal);
    }
    _orders[id] = order;
    _orderByKey[idempotencyKey] = id;
    return order.toOrder();
  }

  @override
  Future<PlacedOrder> verifyPayment(PaymentProof proof) async {
    await _respond();
    final order = _order(proof.orderId);
    if (order.status.isConfirmed) return order.toOrder();
    if (order.status != OrderStatus.paymentPending) {
      _fail(ApiErrorCode.invalidStateTransition);
    }
    final expected = signer(proof.razorpayOrderId, proof.razorpayPaymentId);
    if (proof.razorpayOrderId != order.razorpay?.orderId ||
        proof.razorpaySignature != expected) {
      _fail(ApiErrorCode.paymentVerificationFailed);
    }
    order.status = OrderStatus.placed;
    _redeem(order);
    return order.toOrder();
  }

  @override
  Future<PlacedOrder> retryPayment(
    int orderId, {
    required String idempotencyKey,
  }) async {
    await _respond();
    final order = _order(orderId);
    if (order.status != OrderStatus.paymentPending) {
      _fail(ApiErrorCode.invalidStateTransition);
    }
    order.razorpay = _retryByKey.putIfAbsent(
      idempotencyKey,
      () => _newRazorpayOrder(order.grandTotal),
    );
    return order.toOrder();
  }

  @override
  Future<PlacedOrder> cancelOrder(int orderId) async {
    await _respond();
    final order = _order(orderId);
    if (order.status != OrderStatus.paymentPending) {
      _fail(ApiErrorCode.invalidStateTransition);
    }
    // T5: stock and the coupon hold are released; the cart stays.
    order.status = OrderStatus.cancelled;
    return order.toOrder();
  }

  @override
  Future<PlacedOrder> getOrder(int orderId) async {
    await _respond();
    return _order(orderId).toOrder();
  }

  /// The webhook confirmed a payment (T3) that the app never verified.
  void confirmByWebhook(int orderId) {
    final order = _orders[orderId]!;
    order.status = OrderStatus.placed;
    _redeem(order);
  }

  // --- internals ----------------------------------------------------------

  _FakeOrder _order(int id) {
    final order = _orders[id];
    if (order == null) _fail(ApiErrorCode.notFound);
    // T4: the expiry job fails an unpaid order after the window.
    final expiresAt = order.expiresAt;
    if (order.status == OrderStatus.paymentPending &&
        expiresAt != null &&
        _clock().toUtc().isAfter(expiresAt)) {
      order.status = OrderStatus.paymentFailed;
    }
    return order;
  }

  /// T2/T3: the coupon is redeemed and the cart cleared.
  void _redeem(_FakeOrder order) {
    final code = order.couponCode;
    if (code != null) usedCoupons.add(code);
    _clearCart();
  }

  void _clearCart() {
    _lines.clear();
    _couponCode = null;
    _tip = 0;
    _instructions = DeliveryInstructions.none;
  }

  RazorpayCheckout _newRazorpayOrder(String grandTotal) => RazorpayCheckout(
    keyId: 'rzp_test_fake',
    orderId: 'order_fake_${_razorpaySequence++}',
    amountPaise: _paise(grandTotal),
    prefillName: 'Test Customer',
    prefillContact: '+919000000001',
  );

  int _orderable(int variantId, CartLinePreview preview) {
    final cap = preview.orderableQuantity;
    final available = stock[variantId];
    return available == null ? cap : math.min(cap, available);
  }

  int _itemTotal() => _lines.values.fold(
    0,
    (sum, line) => sum + _paise(line.preview.sellingPrice) * line.quantity,
  );

  ({int discount, CouponProblem? problem, int? shortfall}) _evaluate(
    FakeCoupon coupon,
    int itemTotal,
  ) {
    if (coupon.expired) {
      return (discount: 0, problem: CouponProblem.expired, shortfall: null);
    }
    if (usedCoupons.contains(coupon.code)) {
      return (
        discount: 0,
        problem: CouponProblem.usageExceeded,
        shortfall: null,
      );
    }
    if (itemTotal == 0 || itemTotal < coupon.minItemTotal) {
      return (
        discount: 0,
        problem: CouponProblem.minOrderNotMet,
        shortfall: math.max(coupon.minItemTotal - itemTotal, 0),
      );
    }
    var discount =
        coupon.flatOff ?? (itemTotal * (coupon.percentOff ?? 0) + 50) ~/ 100;
    final cap = coupon.maxDiscount;
    if (cap != null) discount = math.min(discount, cap);
    return (
      discount: math.min(discount, itemTotal),
      problem: null,
      shortfall: null,
    );
  }

  /// `compute_bill` (`08 §6.2`), in paise.
  CartSnapshot _snapshot() {
    if (_lines.isEmpty) {
      return CartSnapshot(instructions: _instructions, addressId: _addressId);
    }
    final lines = <CartLine>[];
    var mrpTotal = 0;
    var itemTotal = 0;
    for (final line in _lines.values) {
      final preview = line.preview;
      final available = _orderable(line.variantId, preview);
      final issue = available <= 0
          ? CartLineIssue.unavailable
          : line.quantity > available
          ? CartLineIssue.reduced
          : CartLineIssue.none;
      final price = _paise(preview.sellingPrice);
      mrpTotal += _paise(preview.mrp) * line.quantity;
      itemTotal += price * line.quantity;
      lines.add(
        CartLine(
          id: line.id,
          variantId: line.variantId,
          productName: preview.productName,
          variantName: preview.variantName,
          imageUrl: preview.imageUrl,
          sellingPrice: preview.sellingPrice,
          mrp: preview.mrp,
          quantity: line.quantity,
          lineTotal: _amount(price * line.quantity),
          orderableQuantity: math.max(available, 0),
          issue: issue,
          availableQuantity: issue == CartLineIssue.reduced ? available : null,
        ),
      );
    }

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
        problem: result.problem,
      );
    }

    final deliveryFee = itemTotal >= rules.freeDeliveryThreshold
        ? 0
        : rules.deliveryFee;
    final smallCartFee = itemTotal < rules.smallCartThreshold
        ? rules.smallCartFee
        : 0;
    final grandTotal =
        itemTotal -
        couponDiscount +
        deliveryFee +
        smallCartFee +
        rules.handlingFee +
        _tip;
    final productDiscount = mrpTotal - itemTotal;
    final shortfall = rules.freeDeliveryThreshold - itemTotal;
    final minimumShort = rules.minimumOrder - itemTotal;

    return CartSnapshot.fromLines(
      lines: lines,
      bill: CartBill(
        mrpTotal: _amount(mrpTotal),
        itemTotal: _amount(itemTotal),
        productDiscount: _amount(productDiscount),
        couponDiscount: _amount(couponDiscount),
        deliveryFee: _amount(deliveryFee),
        smallCartFee: _amount(smallCartFee),
        handlingFee: _amount(rules.handlingFee),
        tip: _amount(_tip),
        grandTotal: _amount(grandTotal),
        totalSavings: _amount(productDiscount + couponDiscount),
        freeDeliveryShortfall: shortfall > 0 ? _amount(shortfall) : null,
      ),
      coupon: coupon,
      instructions: _instructions,
      addressId: _addressId,
      minimumOrder: MinimumOrder(
        met: minimumShort <= 0,
        amount: _amount(rules.minimumOrder),
        shortfall: minimumShort > 0 ? _amount(minimumShort) : null,
      ),
      codAvailable: grandTotal <= rules.codMaxOrderValue,
    );
  }

  static final _money = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

  static int _paise(String amount) {
    final match = _money.firstMatch(amount.trim());
    if (match == null) {
      _fail(ApiErrorCode.validationError, {
        'amount': ['Not a valid amount.'],
      });
    }
    final rupees = int.parse(match.group(1)!);
    final paise = int.parse((match.group(2) ?? '0').padRight(2, '0'));
    return rupees * 100 + paise;
  }

  static String _amount(int paise) =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
}

class _FakeLine {
  _FakeLine(this.id, this.variantId, this.preview, this.quantity);

  final int id;
  final int variantId;
  final CartLinePreview preview;
  int quantity;
}

class _FakeOrder {
  _FakeOrder({
    required this.id,
    required this.number,
    required this.method,
    required this.grandTotal,
    required this.etaMinutes,
    required this.status,
    this.couponCode,
  });

  final int id;
  final String number;
  final PaymentMethod method;
  final String grandTotal;
  final int etaMinutes;
  final String? couponCode;
  OrderStatus status;
  DateTime? expiresAt;
  RazorpayCheckout? razorpay;

  PlacedOrder toOrder() => PlacedOrder(
    id: id,
    number: number,
    status: status,
    paymentMethod: method,
    grandTotal: grandTotal,
    etaMinutes: etaMinutes,
    paymentExpiresAt: expiresAt,
    razorpay: status == OrderStatus.paymentPending ? razorpay : null,
  );
}

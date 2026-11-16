import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import 'cart_fixtures.dart';

/// The stand-in for the server (tests, `FAKE_API=true`): it must follow the
/// Phase 3 contract (`06 §2.5`, `§2.6`) closely enough for the screens.
void main() {
  late FakeCommerceBackend backend;

  setUp(() => backend = FakeCommerceBackend(latency: Duration.zero));

  Future<CartSnapshot> add(int quantity, {String price = '249.00'}) =>
      backend.setQuantity(
        101,
        quantity,
        preview: CartLinePreview.of(oil(price: price), 'Jivo Canola Oil'),
      );

  Matcher apiError(ApiErrorCode code) =>
      throwsA(isA<ApiError>().having((e) => e.code, 'code', code));

  const online = PlaceOrderRequest(
    addressId: 1,
    paymentMethod: PaymentMethod.online,
    expectedGrandTotal: '503.00',
  );

  test('a small cart pays delivery, small-cart and handling fees', () async {
    final cart = await add(1, price: '60.00');
    final bill = cart.bill!;
    expect(bill.mrpTotal, '299.00');
    expect(bill.itemTotal, '60.00');
    expect(bill.productDiscount, '239.00');
    expect(bill.deliveryFee, '25.00');
    expect(bill.smallCartFee, '15.00');
    expect(bill.handlingFee, '5.00');
    expect(bill.grandTotal, '105.00');
    expect(cart.thresholds!.amountToFreeDelivery, '139.00');
    expect(cart.thresholds!.amountToMinOrder, isNull);
    // No address yet: the server's blocker.
    expect(cart.checkout.canPlaceOrder, isFalse);
    expect(
      cart.checkout.blockers.single.code,
      CheckoutBlockerCode.addressRequired,
    );
    // Checked against an address, it can be ordered.
    expect((await backend.load(addressId: 1)).checkout.canPlaceOrder, isTrue);
  });

  test('coupon and tip: grand = items − coupon + fees + tip', () async {
    await add(2); // ₹498
    await backend.applyCoupon('welcome10'); // 10% = ₹49.80
    final cart = await backend.update(const CartUpdate(tip: '20.00'));
    final bill = cart.bill!;
    expect(bill.couponDiscount, '49.80');
    expect(bill.deliveryFee, '0.00');
    expect(bill.grandTotal, '473.20'); // 498 − 49.80 + 5 + 20
    expect(bill.totalSavings, '149.80');
    expect(cart.coupon!.code, 'WELCOME10');
    expect(cart.tip, '20.00');

    await expectLater(
      backend.update(const CartUpdate(tip: '500.01')),
      apiError(ApiErrorCode.validationError),
    );
  });

  test('a coupon below its minimum names the amount to unlock', () async {
    await add(1); // ₹249 < ₹299
    await expectLater(
      backend.applyCoupon('JIVO50'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.couponNotEligible)
            .having((e) => e.details['reason'], 'reason', 'MIN_ORDER_VALUE')
            .having((e) => e.details['amount_to_unlock'], 'unlock', '50.00'),
      ),
    );
    final offers = await backend.coupons();
    final jivo50 = offers.firstWhere((o) => o.code == 'JIVO50');
    expect(jivo50.isEligible, isFalse);
    expect(jivo50.ineligibility, CouponIneligibility.minOrderValue);
    expect(jivo50.amountToUnlock, '50.00');
    // Expired coupons are not listed; applying one says so.
    expect(offers.any((o) => o.code == 'OILFEST'), isFalse);
    await expectLater(
      backend.applyCoupon('OILFEST'),
      apiError(ApiErrorCode.couponExpired),
    );
  });

  test('a coupon that stops applying stays, with a blocker', () async {
    await add(2); // ₹498
    await backend.applyCoupon('JIVO50');
    final cart = await add(1); // ₹249: below ₹299
    expect(cart.coupon!.isApplicable, isFalse);
    expect(cart.coupon!.discount, '0.00');
    expect(
      cart.checkout.blockers.map((b) => b.code),
      contains(CheckoutBlockerCode.couponNotEligible),
    );
  });

  test('quantities are set; increases are checked against stock', () async {
    await add(2);
    backend.stock[101] = 3;
    await expectLater(
      add(4),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.stockUnavailable)
            .having((e) => e.details['items'], 'items', [
              {
                'variant_id': 101,
                'requested_quantity': 4,
                'orderable_quantity': 3,
              },
            ]),
      ),
    );
    await expectLater(add(6), apiError(ApiErrorCode.maxQtyExceeded));
    backend.stock[101] = 1;
    // A decrease is always accepted, even above the new stock.
    final cart = await add(2);
    expect(cart.lines.single.quantity, 2);
    expect(cart.lines.single.issue!.code, CartIssueCode.quantityUnavailable);
    expect(cart.lines.single.orderableQuantity, 1);
  });

  group('minimum units per order (MIN_UNITS_NOT_MET)', () {
    Future<CartSnapshot> addTo(
      FakeCommerceBackend to,
      int variantId,
      int quantity,
    ) => to.setQuantity(
      variantId,
      quantity,
      preview: CartLinePreview.of(
        oil(id: variantId, price: '20.00'),
        'Jivo Water $variantId',
      ),
    );

    test('off by default: nothing changes', () async {
      final cart = await add(1);
      expect(cart.thresholds!.minOrderUnits, 0);
      expect(cart.thresholds!.unitsToMinOrder, isNull);
      expect(
        cart.checkout.blockers.map((b) => b.code),
        isNot(contains(CheckoutBlockerCode.minUnitsNotMet)),
      );
    });

    test('counts units over a mix of products until the minimum', () async {
      final store = FakeCommerceBackend(
        latency: Duration.zero,
        rules: const FakeBillRules(minimumUnits: 5, orderUnitLabel: 'cartons'),
      );
      await addTo(store, 1501, 2);
      var cart = await addTo(store, 1502, 2);
      expect(cart.thresholds!.minOrderUnits, 5);
      expect(cart.thresholds!.unitsToMinOrder, 1);
      expect(cart.thresholds!.orderUnitLabel, 'cartons');
      expect(
        cart.checkout.blockers.map((b) => b.code),
        contains(CheckoutBlockerCode.minUnitsNotMet),
      );

      cart = await addTo(store, 1503, 1); // 2 + 2 + 1 = 5
      expect(cart.thresholds!.unitsToMinOrder, isNull);
      expect(
        cart.checkout.blockers.map((b) => b.code),
        isNot(contains(CheckoutBlockerCode.minUnitsNotMet)),
      );
    });

    test('placing a short order is refused with the shortfall', () async {
      final store = FakeCommerceBackend(
        latency: Duration.zero,
        rules: const FakeBillRules(
          minimumUnits: 5,
          orderUnitLabel: 'cartons',
          minimumOrder: 0,
        ),
      );
      await addTo(store, 1501, 3);
      final cart = await store.load(addressId: 1);
      await expectLater(
        store.placeOrder(
          PlaceOrderRequest(
            addressId: 1,
            paymentMethod: PaymentMethod.cod,
            expectedGrandTotal: cart.bill!.grandTotal,
          ),
          idempotencyKey: 'units',
        ),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.minUnitsNotMet)
              .having((e) => e.statusCode, 'status', 422)
              .having((e) => e.minOrderUnits, 'min', 5)
              .having((e) => e.unitsToMinOrder, 'short', 2),
        ),
      );
      expect(store.orders, isEmpty);
    });
  });

  group('minimum per order (MIN_QTY_REQUIRED)', () {
    Future<CartSnapshot> addWater(int quantity, {int orderable = 5}) =>
        backend.setQuantity(
          1501,
          quantity,
          preview: CartLinePreview.of(
            oil(id: 1501, orderable: orderable, minQty: 5),
            'Jivo Water 1 L x 12',
          ),
        );

    test('1..min-1 is refused up and down; min and 0 are fine', () async {
      await expectLater(
        addWater(1),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.minQtyRequired)
              .having((e) => e.statusCode, 'status', 422)
              .having((e) => e.details, 'details', {
                'variant_id': 1501,
                'min_qty_per_order': 5,
              }),
        ),
      );
      final cart = await addWater(5);
      expect(cart.lines.single.quantity, 5);
      expect(cart.lines.single.minQty, 5);
      expect(cart.lines.single.issue, isNull);
      await expectLater(addWater(4), apiError(ApiErrorCode.minQtyRequired));
      expect((await addWater(0)).isEmpty, isTrue);
    });

    test('fewer orderable than the minimum is out of stock', () async {
      await addWater(5);
      backend.stock[1501] = 4;
      final line = (await backend.load()).lines.single;
      expect(line.orderableQuantity, 0);
      expect(line.issue!.code, CartIssueCode.outOfStock);
    });

    test('a raised minimum flags the line, blocks checkout and refuses the '
        'order', () async {
      await add(2);
      backend.minimums[101] = 5;
      final cart = await backend.load(addressId: 1);
      expect(cart.lines.single.issue!.code, CartIssueCode.minQtyRequired);
      expect(
        cart.checkout.blockers.map((b) => b.code),
        contains(CheckoutBlockerCode.minQtyRequired),
      );
      expect(
        cart.checkout.blockers.map((b) => b.code),
        isNot(contains(CheckoutBlockerCode.stockUnavailable)),
      );
      await expectLater(
        backend.placeOrder(
          PlaceOrderRequest(
            addressId: 1,
            paymentMethod: PaymentMethod.cod,
            expectedGrandTotal: cart.bill!.grandTotal,
          ),
          idempotencyKey: 'min',
        ),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.minQtyRequired)
              .having((e) => e.minQtyPerOrder, 'min', 5),
        ),
      );
    });
  });

  test('ONLINE: fake gateway key, HMAC verify, idempotent key', () async {
    await add(2);
    final order = await backend.placeOrder(online, idempotencyKey: 'k1');
    expect(order.status, OrderStatus.paymentPending);
    final checkout = order.razorpay!;
    expect(checkout.keyId, 'rzp_fake_jivo_local');
    expect(checkout.isFakeGateway, isTrue);
    expect(checkout.orderId, matches(RegExp(r'^order_[A-Za-z0-9]{14}$')));
    expect(checkout.amountPaise, 50300);
    expect(order.canRetryPayment, isTrue);
    expect((await backend.load()).isEmpty, isFalse); // kept until paid

    // The same key and body: the same order. A different body: refused.
    expect(
      (await backend.placeOrder(online, idempotencyKey: 'k1')).id,
      order.id,
    );
    await expectLater(
      backend.placeOrder(
        const PlaceOrderRequest(
          addressId: 2,
          paymentMethod: PaymentMethod.online,
          expectedGrandTotal: '503.00',
        ),
        idempotencyKey: 'k1',
      ),
      apiError(ApiErrorCode.validationError),
    );
    // A second order while this one awaits payment (DL-44).
    await expectLater(
      backend.placeOrder(online, idempotencyKey: 'k2'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'c', ApiErrorCode.invalidStateTransition)
            .having((e) => e.details['pending_order_id'], 'id', order.id),
      ),
    );

    PaymentProof proof(String signature) => PaymentProof(
      orderId: order.id,
      razorpayOrderId: checkout.orderId,
      razorpayPaymentId: 'pay_AbCdEfGh123456',
      razorpaySignature: signature,
    );
    await expectLater(
      backend.verifyPayment(proof('0' * 64)),
      apiError(ApiErrorCode.paymentVerificationFailed),
    );
    final placed = await backend.verifyPayment(
      proof(fakePaymentSignature(checkout.orderId, 'pay_AbCdEfGh123456')),
    );
    expect(placed.status, OrderStatus.placed);
    expect(placed.etaAt, isNotNull);
    expect((await backend.load()).isEmpty, isTrue);
  });

  test(
    'PRICE_CHANGED carries both totals; COD above the cap is refused',
    () async {
      await add(2);
      await expectLater(
        backend.placeOrder(
          const PlaceOrderRequest(
            addressId: 1,
            paymentMethod: PaymentMethod.cod,
            expectedGrandTotal: '500.00',
          ),
          idempotencyKey: 'k1',
        ),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'c', ApiErrorCode.priceChanged)
              .having((e) => e.details['expected_grand_total'], 'x', '500.00')
              .having((e) => e.details['grand_total'], 'y', '503.00'),
        ),
      );

      final capped = FakeCommerceBackend(
        latency: Duration.zero,
        rules: const FakeBillRules(codMaxOrderValue: 100),
      );
      final cart = await capped.setQuantity(
        101,
        1,
        preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
      );
      expect(cart.codAvailable, isFalse);
      expect(cart.offers(PaymentMethod.online), isTrue);
      await expectLater(
        capped.placeOrder(
          PlaceOrderRequest(
            addressId: 1,
            paymentMethod: PaymentMethod.cod,
            expectedGrandTotal: cart.bill!.grandTotal,
          ),
          idempotencyKey: 'k2',
        ),
        apiError(ApiErrorCode.codNotAvailable),
      );
    },
  );

  test('T5 cancel keeps the cart; T4 fails an unpaid order', () async {
    var now = DateTime.utc(2026, 11, 3, 10);
    final timed = FakeCommerceBackend(latency: Duration.zero, clock: () => now);
    await timed.setQuantity(
      101,
      2,
      preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
    );
    final first = await timed.placeOrder(online, idempotencyKey: 'k1');
    final cancelled = await timed.cancelOrder(
      first.id,
      reason: CancelReason.changePaymentMethod,
    );
    expect(cancelled.status, OrderStatus.cancelled);
    expect(timed.cancelReasonOf(first.id), CancelReason.changePaymentMethod);
    expect((await timed.load()).isEmpty, isFalse);

    final second = await timed.placeOrder(online, idempotencyKey: 'k2');
    expect((await timed.activeOrders()).single.id, second.id);
    now = now.add(const Duration(minutes: 16));
    final failed = await timed.getOrder(second.id);
    expect(failed.status, OrderStatus.paymentFailed);
    expect(failed.canRetryPayment, isFalse);
    expect(await timed.activeOrders(), isEmpty);
  });

  group('volume (slab) prices, like the server (ADR 0001)', () {
    const small = [
      PriceTier(minOrderUnits: 5, price: '90.00'),
      PriceTier(minOrderUnits: 25, price: '87.00'),
      PriceTier(minOrderUnits: 50, price: '85.00'),
    ];
    const half = [
      PriceTier(minOrderUnits: 5, price: '125.00'),
      PriceTier(minOrderUnits: 25, price: '122.00'),
    ];
    CatalogVariant box(int id, String price, List<PriceTier> tiers) =>
        CatalogVariant(
          id: id,
          name: '$id',
          sellingPrice: price,
          mrp: price,
          stockStatus: StockStatus.inStock,
          orderableQuantity: 300,
          maxQtyPerOrder: 300,
          priceTiers: tiers,
        );
    Future<CartSnapshot> set(int id, int quantity) => backend.setQuantity(
      id,
      quantity,
      preview: CartLinePreview.of(
        id == 1502 ? box(1502, '125.00', half) : box(1501, '90.00', small),
        'Jivo Water',
      ),
    );

    test(
      'at 4 cartons the next slab is 25 (5+ costs the normal price)',
      () async {
        final cart = await set(1501, 4);
        final line = cart.lines.single;
        expect(line.priceTier, isNull);
        expect(line.billedPrice, '90.00');
        expect(cart.thresholds!.tierUnits, 4);
        expect(cart.thresholds!.nextPriceTier!.minOrderUnits, 25);
        expect(cart.thresholds!.nextPriceTier!.unitsToNextTier, 21);
        expect(line.nextTierPrice, '87.00');
      },
    );

    test('every size counts towards one total', () async {
      await set(1501, 20);
      final cart = await set(1502, 5);
      expect(cart.thresholds!.tierUnits, 25);
      final litre = cart.lineFor(1501)!;
      final halfLitre = cart.lineFor(1502)!;
      expect(litre.priceTier!.minOrderUnits, 25);
      expect(litre.billedPrice, '87.00');
      expect(litre.lineTotal, '1740.00');
      expect(halfLitre.billedPrice, '122.00');
      expect(cart.bill!.itemTotal, '2350.00');
      // Only the 1 L gets cheaper at 50.
      expect(cart.thresholds!.nextPriceTier!.minOrderUnits, 50);
      expect(litre.nextTierPrice, '85.00');
      expect(halfLitre.nextTierPrice, isNull);
    });

    test('at the top slab there is no next tier', () async {
      final cart = await set(1501, 60);
      expect(cart.lines.single.billedPrice, '85.00');
      expect(cart.thresholds!.nextPriceTier, isNull);
      expect(cart.lines.single.nextTierPrice, isNull);
    });

    test('items without tiers: normal price, no tier fields', () async {
      final cart = await add(2);
      expect(cart.lines.single.billedPrice, '249.00');
      expect(cart.lines.single.priceTier, isNull);
      expect(cart.thresholds!.tierUnits, 0);
      expect(cart.thresholds!.nextPriceTier, isNull);
    });
  });
}

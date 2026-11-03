import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import 'cart_fixtures.dart';

/// The dev-flavor stand-in for the server (TODO(api)): it must behave like
/// `compute_bill` (`08 §6.2`) and T1–T5 closely enough for the screens.
void main() {
  late FakeCommerceBackend backend;

  setUp(() => backend = FakeCommerceBackend(latency: Duration.zero));

  Future<CartSnapshot> add(int quantity, {String price = '249.00'}) =>
      backend.setQuantity(
        101,
        quantity,
        preview: CartLinePreview.of(oil(price: price), 'Jivo Canola Oil'),
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
    expect(bill.freeDeliveryShortfall, '139.00');
    expect(cart.minimumOrder!.met, isTrue);
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
  });

  test('a coupon below its minimum names the shortfall', () async {
    await add(1); // ₹249 < ₹299
    await expectLater(
      backend.applyCoupon('JIVO50'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.couponNotEligible)
            .having((e) => e.details['shortfall'], 'shortfall', '50.00'),
      ),
    );
    final offers = await backend.coupons();
    final jivo50 = offers.firstWhere((o) => o.code == 'JIVO50');
    expect(jivo50.problem, CouponProblem.minOrderNotMet);
    expect(jivo50.shortfall, '50.00');
  });

  test('ONLINE: pending with a Razorpay order; verify places it', () async {
    await add(2);
    final order = await backend.placeOrder(
      const PlaceOrderRequest(
        addressId: 1,
        paymentMethod: PaymentMethod.online,
        expectedGrandTotal: '503.00',
      ),
      idempotencyKey: 'k1',
    );
    expect(order.status, OrderStatus.paymentPending);
    expect(order.razorpay!.amountPaise, 50300);
    expect((await backend.load()).isEmpty, isFalse); // cart kept until paid

    // The same key returns the same order.
    final again = await backend.placeOrder(
      const PlaceOrderRequest(
        addressId: 1,
        paymentMethod: PaymentMethod.online,
        expectedGrandTotal: '503.00',
      ),
      idempotencyKey: 'k1',
    );
    expect(again.id, order.id);

    await expectLater(
      backend.verifyPayment(
        PaymentProof(
          orderId: order.id,
          razorpayOrderId: order.razorpay!.orderId,
          razorpayPaymentId: 'pay_1',
          razorpaySignature: 'forged',
        ),
      ),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.paymentVerificationFailed,
        ),
      ),
    );
    final placed = await backend.verifyPayment(
      PaymentProof(
        orderId: order.id,
        razorpayOrderId: order.razorpay!.orderId,
        razorpayPaymentId: 'pay_1',
        razorpaySignature: fakePaymentSignature(
          order.razorpay!.orderId,
          'pay_1',
        ),
      ),
    );
    expect(placed.status, OrderStatus.placed);
    expect((await backend.load()).isEmpty, isTrue);
  });

  test('a stale total is PRICE_CHANGED; COD over the cap is refused', () async {
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
        isA<ApiError>().having((e) => e.code, 'c', ApiErrorCode.priceChanged),
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
    await expectLater(
      capped.placeOrder(
        PlaceOrderRequest(
          addressId: 1,
          paymentMethod: PaymentMethod.cod,
          expectedGrandTotal: cart.bill!.grandTotal,
        ),
        idempotencyKey: 'k2',
      ),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'c',
          ApiErrorCode.codNotAvailable,
        ),
      ),
    );
  });
}

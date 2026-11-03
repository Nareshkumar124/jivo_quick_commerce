import 'package:customer_app/features/cart/data/api_cart_repository.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../../helpers/fake_http.dart';

/// `ApiCartRepository` on the generated client, answered with the Phase 3
/// contract's own examples (`backend/openapi/schema.yaml`).
void main() {
  late FakeHttp http;
  late ApiCartRepository repository;
  late Object? Function(String method, String path) answer;
  int? storeId = 7;

  setUp(() {
    storeId = 7;
    answer = (_, _) => contractExample('cart_retrieve/200/ReadyToOrder');
    http = FakeHttp((request) {
      final body = answer(request.method, request.uri.path);
      if (body is (int, Object?)) return body;
      return (200, body);
    });
    repository = ApiCartRepository(http.api(), () => storeId);
  });

  test('GET /cart/ carries X-Store-Id and the address to check', () async {
    answer = (_, _) => contractExample(
      'cart_retrieve/200/StockChanged:LinesToFix,CODAboveLimit',
    );
    final cart = await repository.load(addressId: 12);

    final request = http.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/cart/');
    expect(request.uri.queryParameters['address_id'], '12');
    expect('${request.headers['X-Store-Id']}', '7');

    // The server's values, unchanged.
    expect(cart.itemCount, 4);
    expect(cart.bill!.grandTotal, '4086.00');
    expect(cart.bill!.totalSavings, '1074.00');
    expect(cart.thresholds!.freeDeliveryThreshold, '299.00');
    expect(cart.thresholds!.amountToFreeDelivery, isNull);
    expect(cart.addressId, 12);
    expect(cart.offers(PaymentMethod.online), isTrue);
    expect(cart.codAvailable, isFalse);
    expect(
      cart.paymentOptions.last.reason,
      PaymentUnavailableReason.aboveLimit,
    );
    expect(cart.checkout.canPlaceOrder, isFalse);
    expect(
      cart.checkout.blockers.single.code,
      CheckoutBlockerCode.stockUnavailable,
    );

    final reduced = cart.lines.firstWhere((l) => l.id == 506);
    expect(reduced.variantId, 1002);
    expect(reduced.quantity, 3);
    expect(reduced.orderableQuantity, 2);
    expect(reduced.issue!.code, CartIssueCode.quantityUnavailable);
    final gone = cart.lines.firstWhere((l) => l.id == 507);
    expect(gone.issue!.code, CartIssueCode.outOfStock);
    expect(gone.orderableQuantity, 0);
    expect(cart.quantityOf(1002), 3);
  });

  test('every documented cart decodes', () async {
    for (final name in [
      'ReadyToOrder',
      'Empty',
      'CouponApplied,DeliveryStillFree',
      'SmallCart:DeliveryAndSmall-cartFees',
      'BelowTheMinimumOrder',
      'CouponNoLongerApplies',
      'NoAddressSelected',
      'AddressNotServedByThisStore',
      'StoreClosed',
    ]) {
      answer = (_, _) => contractExample('cart_retrieve/200/$name');
      final cart = await repository.load();
      expect(cart.bill, isNotNull, reason: name);
    }
    answer = (_, _) =>
        contractExample('cart_retrieve/200/CouponNoLongerApplies');
    final cart = await repository.load();
    expect(cart.coupon!.isApplicable, isFalse);
    expect(cart.coupon!.discount, '0.00');
    answer = (_, _) => contractExample('cart_retrieve/200/Empty');
    expect((await repository.load()).isEmpty, isTrue);
  });

  test('codes this build does not know decode to unknown, never throw', () {
    // A newer server: every enum the cart uses gets a value from the future.
    final json =
        contractExample(
              'cart_retrieve/200/StockChanged:LinesToFix,CODAboveLimit',
            )!
            as Map<String, Object?>;
    final items = json['items']! as List<Object?>;
    final line = items.first! as Map<String, Object?>;
    (line['issue']! as Map<String, Object?>)['code'] = 'BATCH_RECALLED';
    (line['variant']! as Map<String, Object?>)['stock_status'] = 'PREORDER';
    final methods = json['payment_methods']! as List<Object?>;
    (methods.last! as Map<String, Object?>)['unavailable_reason'] = 'NEW_RULE';
    methods.add({
      'method': 'PAY_LATER',
      'is_available': true,
      'unavailable_reason': null,
      'message': null,
    });
    final checkout = json['checkout']! as Map<String, Object?>;
    (checkout['blockers']! as List<Object?>).add({
      'code': 'KYC_REQUIRED',
      'message': 'Verify your account to order.',
    });
    (json['instructions']! as Map<String, Object?>)['chips'] = [
      'LEAVE_AT_DOOR',
      'RING_TWICE',
    ];
    answer = (_, _) => json;

    return repository.load().then((cart) {
      expect(cart.lines.first.issue!.code, CartIssueCode.unknown);
      expect(cart.lines.first.issue!.message, isNotEmpty); // shown as is
      expect(cart.lines.first.variant.inStock, isFalse); // not sellable
      expect(
        cart.paymentOptions.map((o) => o.method),
        [PaymentMethod.online, PaymentMethod.cod], // PAY_LATER is skipped
      );
      expect(cart.paymentOptions.last.reason, PaymentUnavailableReason.unknown);
      expect(cart.checkout.blockers.last.code, CheckoutBlockerCode.unknown);
      expect(
        cart.checkout.blockers.last.message,
        'Verify your account to order.',
      );
      expect(cart.instructions.tags, {InstructionTag.leaveAtDoor});
    });
  });

  test('a quantity is set with POST /cart/items/ (0 removes)', () async {
    answer = (_, _) => contractExample('cart_items_add/200/Updated');
    await repository.setQuantity(1001, 2);
    await repository.setQuantity(1001, 0);
    expect(http.requests.map((r) => '${r.method} ${r.uri.path}'), [
      'POST /api/v1/cart/items/',
      'POST /api/v1/cart/items/',
    ]);
    expect(http.body(0), {'variant_id': 1001, 'quantity': 2});
    expect(http.body(1), {'variant_id': 1001, 'quantity': 0});
    expect('${http.requests.first.headers['X-Store-Id']}', '7');
  });

  test('STOCK_UNAVAILABLE keeps its details for the message', () async {
    answer = (_, _) =>
        (409, contractExample('cart_items_add/409/STOCKUNAVAILABLE'));
    await expectLater(
      repository.setQuantity(1002, 5),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.stockUnavailable)
            .having((e) => e.details['items'], 'items', isA<List<Object?>>()),
      ),
    );
  });

  test('coupons: list, apply (with the reason), remove', () async {
    answer = (method, path) => switch ((method, path)) {
      ('GET', '/api/v1/cart/coupons/') => contractExample(
        'cart_coupons_list/200/Coupons',
      ),
      ('POST', _) => (
        422,
        contractExample('cart_coupon_apply/422/COUPONNOTELIGIBLEMINORDER'),
      ),
      _ => contractExample('cart_coupon_remove/200/Removed'),
    };
    final offers = await repository.coupons();
    expect(offers.first.code, 'OILS15');
    expect(offers.first.isEligible, isTrue);
    expect(offers.first.savings, '83.70');
    final locked = offers.where((o) => !o.isEligible);
    expect(locked, isNotEmpty);
    expect(locked.first.ineligibility, isNotNull);

    await expectLater(
      repository.applyCoupon(' bigsave200 '),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.couponNotEligible)
            .having((e) => e.details['amount_to_unlock'], 'x', '716.00'),
      ),
    );
    expect(http.body(1), {'code': 'bigsave200'});
    await repository.removeCoupon();
    expect(http.requests.last.method, 'DELETE');
    expect(http.requests.last.uri.path, '/api/v1/cart/coupon/');
  });

  test('PATCH /cart/ sends only what changes', () async {
    answer = (_, _) => contractExample('cart_update/200/Updated');
    await repository.update(const CartUpdate(tip: '20.00'));
    await repository.update(
      const CartUpdate(
        instructions: DeliveryInstructions(
          tags: {InstructionTag.leaveAtDoor, InstructionTag.dontRingBell},
          note: ' Gate 2 ',
        ),
      ),
    );
    await repository.update(const CartUpdate(addressId: 12));
    expect(http.body(0), {'tip': '20.00'});
    expect(http.body(1), {
      'instructions': {
        'chips': ['LEAVE_AT_DOOR', 'DONT_RING_BELL'],
        'note': 'Gate 2',
      },
    });
    expect(http.body(2), {'address_id': 12});
    expect(http.requests.every((r) => r.method == 'PATCH'), isTrue);
  });

  test('DELETE /cart/ clears it', () async {
    answer = (_, _) => contractExample('cart_clear/200/Empty');
    expect((await repository.clear()).isEmpty, isTrue);
    expect(http.requests.single.method, 'DELETE');
  });

  test('without a store there is no call: STORE_NOT_FOUND, locally', () async {
    storeId = null;
    await expectLater(
      repository.load(),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.storeNotFound)
            .having((e) => e.rawCode, 'rawCode', isNull),
      ),
    );
    expect(http.requests, isEmpty);
  });
}

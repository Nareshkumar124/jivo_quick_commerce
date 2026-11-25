import 'package:customer_app/features/cart/data/api_cart_repository.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/orders/data/api_order_history_repository.dart';
import 'package:customer_app/features/referral/data/referral_repository.dart';
import 'package:customer_app/features/referral/domain/referral.dart';
import 'package:customer_app/features/rewards/data/rewards_repository.dart';
import 'package:customer_app/features/rewards/domain/reward.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../../helpers/fake_http.dart';

/// The ADR 0002 contract (free cartons, rewards, the referral reward type)
/// on the generated client, answered with the schema's own examples.
void main() {
  late FakeHttp http;
  late Object? Function(String method, String path) answer;

  setUp(() {
    answer = (_, _) => null;
    http = FakeHttp((request) {
      final body = answer(request.method, request.uri.path);
      if (body is (int, Object?)) return body;
      return (200, body);
    });
  });

  group('cart', () {
    late ApiCartRepository repository;
    setUp(() => repository = ApiCartRepository(http.api(), () => 7));

    test('free lines, the offer, free_items_value and the reward coupon '
        'are carried as sent', () async {
      answer = (_, _) => contractExample(
        'cart_retrieve/200/FreeCartons:VolumeOfferAndAReward',
      );
      final cart = await repository.load();

      expect(cart.freeLines, hasLength(2));
      final volume = cart.freeLines.first;
      expect(volume.source, FreeLineSource.volumeOffer);
      expect(volume.variantId, 4001);
      expect(volume.productName, 'Jivo Water');
      expect(volume.variantName, '1 L x 12 (carton)');
      expect(volume.quantity, 1);
      expect(volume.mrp, '110.00');
      expect(volume.value, '110.00');
      expect(volume.imageUrl, isNotNull);
      expect(cart.freeLines.last.source, FreeLineSource.reward);
      expect(cart.freeLines.last.variantId, 4002);

      // Free cartons never reach the steppers or the paid count.
      expect(cart.quantities, {
        for (final line in cart.lines) line.variantId: line.quantity,
      });
      expect(cart.itemCount, 12);

      final offer = cart.freeOffer!;
      expect(offer.every, 10);
      expect(offer.paidUnits, 12);
      expect(offer.freeUnits, 1);
      expect(offer.unitsToNextFree, 8);
      expect(offer.message, 'Add 8 more cartons to get 1 more free');
      expect(offer.notice, isNull);

      expect(cart.bill!.freeItemsValue, '250.00');
      expect(cart.bill!.totalSavings, '250.00');
      expect(cart.bill!.grandTotal, '1440.00');

      final coupon = cart.coupon!;
      expect(coupon.isFreeCarton, isTrue);
      expect(coupon.source, RewardSource.welcome);
      expect(coupon.freeVariantId, 4002);
    });

    test('an earned carton out of stock: a notice, no free line', () async {
      answer = (_, _) =>
          contractExample('cart_retrieve/200/FreeCartonEarnedButOutOfStock');
      final cart = await repository.load();
      expect(cart.freeLines, isEmpty);
      expect(cart.freeOffer!.notice, isNotEmpty);
      expect(cart.bill!.freeItemsValue, '0.00');
    });

    test('an ordinary cart has no free lines and no offer', () async {
      answer = (_, _) => contractExample('cart_retrieve/200/ReadyToOrder');
      final cart = await repository.load();
      expect(cart.freeLines, isEmpty);
      expect(cart.coupon?.isFreeCarton ?? false, isFalse);
    });

    test('applying a reward sends free_variant_id', () async {
      answer = (_, _) =>
          contractExample('cart_coupon_apply/200/Free-cartonRewardApplied');
      final cart = await repository.applyCoupon(
        ' WEL7K2M9QPX ',
        freeVariantId: 4002,
      );

      final request = http.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/cart/coupon/');
      expect('${request.headers['X-Store-Id']}', '7');
      expect(http.body(0), {'code': 'WEL7K2M9QPX', 'free_variant_id': 4002});
      expect(cart.coupon!.isFreeCarton, isTrue);
    });

    test('an ordinary coupon sends no free_variant_id', () async {
      answer = (_, _) => contractExample('cart_coupon_apply/200/Applied');
      await repository.applyCoupon('JIVO50');
      expect(http.body(0).containsKey('free_variant_id'), isFalse);
    });

    test('MIN_ORDER_UNITS keeps its reason and numbers', () async {
      answer = (_, _) => (
        422,
        contractExample('cart_coupon_apply/422/COUPONNOTELIGIBLEMINUNITS'),
      );
      final error = await repository
          .applyCoupon('WEL7K2M9QPX', freeVariantId: 4002)
          .then<ApiError?>((_) => null, onError: (Object e) => e as ApiError);
      expect(error!.code, ApiErrorCode.couponNotEligible);
      expect(error.details['reason'], 'MIN_ORDER_UNITS');
      expect(error.details['units_to_unlock'], 3);
    });

    test('the coupon list marks the free-carton reward', () async {
      answer = (_, _) => contractExample('cart_coupons_list/200/Coupons');
      final offers = await repository.coupons();
      final reward = offers.singleWhere((o) => o.code == 'WEL7K2M9QPX');
      expect(reward.isFreeCarton, isTrue);
      expect(reward.discountType, CouponDiscountType.freeUnit);
      expect(reward.source, RewardSource.welcome);
      final old = offers.singleWhere((o) => o.code == 'REFK7M2PQ9X');
      expect(old.isFreeCarton, isFalse);
      expect(old.discountType, CouponDiscountType.flat);
      expect(old.source, RewardSource.referralReferrer);
      final plain = offers.singleWhere((o) => o.code == 'JIVO50');
      expect(plain.source, RewardSource.none);
    });
  });

  test('order detail: free lines apart from the paid lines', () async {
    answer = (_, _) =>
        contractExample('orders_retrieve/200/DeliveredWithFreeCartons');
    final repository = ApiOrderHistoryRepository(http.api(), () => 7);
    final order = await repository.getOrderDetail(1);

    expect(order.lines, hasLength(2));
    expect(order.lines.every((l) => l.sellingPrice != '0.00'), isTrue);
    expect(order.freeLines, hasLength(2));
    expect(order.freeLines.first.source, FreeLineSource.volumeOffer);
    expect(order.freeLines.first.value, '110.00');
    expect(order.freeLines.last.source, FreeLineSource.reward);
    expect(order.freeLines.last.value, '140.00');
    expect(order.bill.freeItemsValue, '250.00');
  });

  group('rewards', () {
    test('GET /account/rewards/ maps statuses, sources and history', () async {
      answer = (_, _) =>
          contractExample('account_rewards_retrieve/200/Rewards');
      final summary = await ApiRewardsRepository(http.api()).fetch();

      final request = http.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v1/account/rewards/');
      expect(request.headers.containsKey('X-Store-Id'), isFalse);

      expect(summary.available, hasLength(2));
      final welcome = summary.available.first;
      expect(welcome.code, 'WEL7K2M9QPX');
      expect(welcome.source, RewardSource.welcome);
      expect(welcome.status, RewardStatus.available);
      expect(welcome.isFreeCarton, isTrue);
      expect(welcome.expiresAt, DateTime.utc(2026, 12, 25, 9, 30));
      final claimed = summary.available.last;
      expect(claimed.status, RewardStatus.claimed);
      expect(claimed.orderNumber, 'JV-261124-000318');
      expect(claimed.source, RewardSource.referralReferrer);

      expect(summary.history.map((e) => e.kind), [
        RewardHistoryKind.claimed,
        RewardHistoryKind.volumeFree,
        RewardHistoryKind.earned,
        RewardHistoryKind.earned,
      ]);
      expect(summary.history[1].quantity, 2);
    });

    test('no rewards', () async {
      answer = (_, _) =>
          contractExample('account_rewards_retrieve/200/NoRewards');
      final summary = await ApiRewardsRepository(http.api()).fetch();
      expect(summary.available, isEmpty);
      expect(summary.history, isEmpty);
    });

    test('a failure is an ApiError', () async {
      answer = (_, _) =>
          (429, contractExample('account_rewards_retrieve/429/RATELIMITED'));
      await expectLater(
        ApiRewardsRepository(http.api()).fetch(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.rateLimited,
          ),
        ),
      );
    });
  });

  test('referral: reward_type FREE_UNIT is a free-carton reward', () async {
    answer = (_, _) =>
        contractExample('account_referral_retrieve/200/NewCustomer');
    final info = await ApiReferralRepository(http.api()).fetch();
    expect(info.rewardType, ReferralRewardType.freeCarton);
    expect(info.isFreeCarton, isTrue);
    expect(info.rewardQuantity, 1);
  });
}

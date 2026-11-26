import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/cart/presentation/cart_texts.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/rewards/domain/reward.dart';
import 'package:customer_app/features/rewards/presentation/reward_texts.dart';
import 'package:customer_app/features/rewards/presentation/rewards_providers.dart';
import 'package:customer_app/l10n/generated/app_localizations_en.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:jivo_core/jivo_core.dart';

import '../cart/cart_fixtures.dart';

final l10n = AppLocalizationsEn();

Reward reward(
  String code, {
  RewardStatus status = RewardStatus.available,
  DateTime? expiresAt,
  RewardSource source = RewardSource.welcome,
}) => Reward(
  code: code,
  title: '1 free carton',
  source: source,
  status: status,
  expiresAt: expiresAt,
);

/// A water carton as the catalog sends it (flat rate, no tiers).
CatalogVariant carton(
  int id,
  String name,
  String price, {
  int orderable = 50,
}) => CatalogVariant(
  id: id,
  name: name,
  sellingPrice: price,
  mrp: price,
  stockStatus: orderable > 0 ? StockStatus.inStock : StockStatus.outOfStock,
  orderableQuantity: orderable,
  maxQtyPerOrder: 50,
);

void main() {
  group('wire values', () {
    test('known and unknown values', () {
      expect(RewardStatus.fromWire('CLAIMED'), RewardStatus.claimed);
      expect(RewardStatus.fromWire('NEW'), RewardStatus.unknown);
      expect(
        RewardHistoryKind.fromWire('VOLUME_FREE'),
        RewardHistoryKind.volumeFree,
      );
      expect(RewardHistoryKind.fromWire(null), RewardHistoryKind.unknown);
      expect(
        RewardSource.fromWire('REFERRAL_REFERRED'),
        RewardSource.referralReferred,
      );
      expect(
        RewardSource.fromWire('unknown_default_open_api'),
        RewardSource.unknown,
      );
      expect(RewardSource.referralReferrer.isReferral, isTrue);
      expect(RewardSource.welcome.isReferral, isFalse);
      expect(FreeLineSource.fromWire('REWARD'), FreeLineSource.reward);
      expect(FreeLineSource.fromWire(null), FreeLineSource.unknown);
      expect(
        CouponDiscountType.fromWire('FREE_UNIT'),
        CouponDiscountType.freeUnit,
      );
      expect(CouponDiscountType.fromWire('BOGO'), CouponDiscountType.unknown);
    });
  });

  group('RewardsSummary', () {
    test('the main list hides used and expired rewards', () {
      final summary = RewardsSummary(
        available: [
          reward('USED1', status: RewardStatus.used),
          reward('GONE1', status: RewardStatus.expired),
          reward('ON1', status: RewardStatus.claimed),
          reward('NOW1'),
        ],
      );
      expect(summary.listed.map((r) => r.code), ['NOW1', 'ON1']);
    });

    test('available first, then the soonest expiry; no expiry last', () {
      final summary = RewardsSummary(
        available: [
          reward('LATE', expiresAt: DateTime.utc(2026, 12, 30)),
          reward('NEVER'),
          reward('SOON', expiresAt: DateTime.utc(2026, 12, 1)),
          reward('ON', status: RewardStatus.claimed),
        ],
      );
      expect(summary.listed.map((r) => r.code), [
        'SOON',
        'LATE',
        'NEVER',
        'ON',
      ]);
    });

    test('the history is newest first', () {
      final summary = RewardsSummary(
        history: [
          RewardHistoryEntry(
            at: DateTime.utc(2026, 11, 1),
            kind: RewardHistoryKind.earned,
            title: 'a',
          ),
          RewardHistoryEntry(
            at: DateTime.utc(2026, 11, 20),
            kind: RewardHistoryKind.used,
            title: 'b',
          ),
        ],
      );
      expect(summary.timeline.map((e) => e.title), ['b', 'a']);
    });

    test('Use only for an available reward', () {
      expect(reward('A').canUse, isTrue);
      expect(reward('B', status: RewardStatus.claimed).canUse, isFalse);
    });
  });

  group('splitRewardsAndCoupons', () {
    test('no code twice; a listed free-carton coupon becomes a reward', () {
      final split = splitRewardsAndCoupons(
        rewards: [reward('WEL1')],
        coupons: const [
          CouponOffer(
            code: 'wel1',
            title: 'dup',
            description: '',
            isEligible: true,
            discountType: CouponDiscountType.freeUnit,
          ),
          CouponOffer(
            code: 'REF2',
            title: '1 free carton',
            description: '',
            isEligible: true,
            discountType: CouponDiscountType.freeUnit,
            source: RewardSource.referralReferred,
          ),
          CouponOffer(
            code: 'JIVO50',
            title: '₹50 off',
            description: '',
            isEligible: true,
          ),
        ],
      );
      expect(split.rewards.map((r) => r.code), ['WEL1', 'REF2']);
      expect(split.rewards.last.source, RewardSource.referralReferred);
      expect(split.rewards.last.status, RewardStatus.available);
      expect(split.coupons.map((c) => c.code), ['JIVO50']);
      expect(split.isEmpty, isFalse);
    });

    test('nothing at all', () {
      expect(
        splitRewardsAndCoupons(rewards: const [], coupons: const []).isEmpty,
        isTrue,
      );
    });

    test('ADR 0003: the coupon list fixed size and quantity reach the '
        'reward card', () {
      const fixed = CouponOffer(
        code: 'wel1',
        title: '2 free cartons',
        description: '',
        isEligible: true,
        discountType: CouponDiscountType.freeUnit,
        freeVariantId: 4001,
        freeQuantity: 2,
      );
      const onlyListed = CouponOffer(
        code: 'REF2',
        title: '2 free cartons',
        description: '',
        isEligible: true,
        discountType: CouponDiscountType.freeUnit,
        freeVariantId: 4001,
        freeQuantity: 2,
      );
      final split = splitRewardsAndCoupons(
        rewards: [reward('WEL1')],
        coupons: const [fixed, onlyListed],
      );
      final welcome = split.rewards.first;
      expect(welcome.hasFixedSize, isTrue);
      expect(welcome.freeVariantId, 4001);
      final extra = split.rewards.last;
      expect(extra.code, 'REF2');
      expect(extra.quantity, 2);
      expect(extra.hasFixedSize, isTrue);

      // No fixed size anywhere: the size sheet (ADR 0002).
      expect(reward('X').hasFixedSize, isFalse);
      expect(reward('X').quantity, 1);
    });
  });

  test('size options: in-stock variants once, in catalog order', () {
    final options = freeSizeOptions([
      CatalogProduct(
        id: 1,
        slug: 'water-1l',
        name: 'Jivo Water',
        defaultVariantId: 11,
        variants: [
          carton(11, '1 L', '110.00'),
          carton(12, '500 ml', '140.00', orderable: 0),
        ],
      ),
      CatalogProduct(
        id: 2,
        slug: 'water-250',
        name: 'Jivo Water',
        defaultVariantId: 13,
        variants: [carton(13, '250 ml', '110.00'), carton(11, '1 L', '110.00')],
      ),
    ]);
    expect(options.map((o) => o.variant.id), [11, 13]);
  });

  group('texts', () {
    test('reward source, status and history kind', () {
      expect(rewardSourceText(l10n, RewardSource.welcome), 'Welcome gift');
      expect(
        rewardSourceText(l10n, RewardSource.referralReferred),
        'Referral reward',
      );
      expect(rewardSourceText(l10n, RewardSource.none), isNull);
      expect(rewardStatusText(l10n, RewardStatus.available), 'Available');
      expect(rewardStatusText(l10n, RewardStatus.claimed), 'Claimed');
      expect(
        rewardHistoryKindText(l10n, RewardHistoryKind.volumeFree),
        'Volume offer',
      );
      expect(rewardHistoryKindText(l10n, RewardHistoryKind.unknown), isNull);
    });

    test('free line source', () {
      expect(
        freeLineSourceText(l10n, FreeLineSource.volumeOffer, every: 10),
        'Buy 10 get 1 free',
      );
      expect(freeLineSourceText(l10n, FreeLineSource.reward), 'Reward');
      expect(
        freeLineSourceText(l10n, FreeLineSource.volumeOffer),
        'Free with your order',
      );
    });

    test('free offer nudge: the server message, else from its number', () {
      CartSnapshot withOffer(FreeOffer? offer) => CartSnapshot.fromLines(
        lines: const [],
        itemCount: 0,
        freeOffer: offer,
        thresholds: const CartThresholds(
          minOrderValue: '0.00',
          orderUnitLabel: 'cartons',
        ),
      );
      expect(
        freeOfferNudge(
          l10n,
          withOffer(
            const FreeOffer(
              every: 10,
              paidUnits: 2,
              freeUnits: 0,
              unitsToNextFree: 8,
              message: 'Add 8 more cartons to get 1 more free',
            ),
          ),
        ),
        'Add 8 more cartons to get 1 more free',
      );
      expect(
        freeOfferNudge(
          l10n,
          withOffer(
            const FreeOffer(
              every: 10,
              paidUnits: 7,
              freeUnits: 0,
              unitsToNextFree: 3,
            ),
          ),
        ),
        'Add 3 more cartons to get 1 more free',
      );
      expect(freeOfferNudge(l10n, withOffer(null)), isNull);
    });

    test('the slab nudge never shows without price tiers', () {
      final cart = cartSnapshot(
        lines: [cartLine(nextTierPrice: '87.00')],
        thresholds: const CartThresholds(
          minOrderValue: '0.00',
          nextPriceTier: NextPriceTier(minOrderUnits: 25, unitsToNextTier: 3),
        ),
      );
      expect(priceTierNudge(l10n, cart), isNull);
      expect(priceTierNudgeParts(l10n, cart), isNull);
    });
  });

  group('fake server (ADR 0002 rules)', () {
    FakeCommerceBackend backend({int every = 10}) => FakeCommerceBackend(
      latency: Duration.zero,
      rules: FakeBillRules(
        minimumUnits: 5,
        orderUnitLabel: 'cartons',
        freeUnitEvery: every,
        minimumOrder: 0,
      ),
      variantLookup: (id) => id == 4003
          ? (
              productName: 'Jivo Water',
              variant: carton(4003, '250 ml', '110.00'),
            )
          : null,
    );

    Future<void> add(FakeCommerceBackend b, CatalogVariant v, int qty) =>
        b.setQuantity(v.id, qty, preview: CartLinePreview.of(v, 'Jivo Water'));

    test(
      '1 free per 10 paid, of the cheapest size; free never counted',
      () async {
        final b = backend();
        await add(b, carton(4002, '500 ml', '140.00'), 8);
        await add(b, carton(4001, '1 L', '110.00'), 13);
        final cart = await b.load();

        expect(cart.itemCount, 21);
        expect(cart.freeLines.single.variantId, 4001);
        expect(cart.freeLines.single.quantity, 2);
        expect(cart.freeLines.single.source, FreeLineSource.volumeOffer);
        expect(cart.freeOffer!.paidUnits, 21);
        expect(cart.freeOffer!.unitsToNextFree, 9);
        expect(cart.bill!.freeItemsValue, '220.00');
        expect(cart.bill!.totalSavings, '220.00');
        expect(cart.quantityOf(4001), 13);
      },
    );

    test('a tie on price: the size with more paid units', () async {
      final b = backend();
      await add(b, carton(4001, '1 L', '110.00'), 4);
      await add(b, carton(4003, '250 ml', '110.00'), 6);
      final cart = await b.load();
      expect(cart.freeLines.single.variantId, 4003);
    });

    test('the cheapest size short of stock: the next one', () async {
      final b = backend()..stock[4001] = 11;
      await add(b, carton(4001, '1 L', '110.00'), 11);
      await add(b, carton(4002, '500 ml', '140.00'), 9);
      final cart = await b.load();
      expect(cart.freeLines.single.variantId, 4002);
    });

    test('no size can supply it: a notice, no free carton', () async {
      final b = backend()..stock[4001] = 10;
      await add(b, carton(4001, '1 L', '110.00'), 10);
      final cart = await b.load();
      expect(cart.freeLines, isEmpty);
      expect(cart.freeOffer!.notice, isNotNull);
      expect(cart.freeOffer!.freeUnits, 0);
    });

    test('a reward needs a size the store sells, and adds 1 free', () async {
      final b = backend()
        ..rewardCoupons.add(const FakeCoupon.freeCarton(code: 'WEL1'));
      await add(b, carton(4001, '1 L', '110.00'), 5);
      final listed = await b.coupons();
      expect(listed.singleWhere((c) => c.code == 'WEL1').isFreeCarton, isTrue);

      await expectLater(b.applyCoupon('WEL1'), throwsA(isA<ApiError>()));
      await expectLater(
        b.applyCoupon('WEL1', freeVariantId: 9999),
        throwsA(isA<ApiError>()),
      );
      final cart = await b.applyCoupon('wel1', freeVariantId: 4003);
      expect(cart.coupon!.isFreeCarton, isTrue);
      expect(cart.coupon!.freeVariantId, 4003);
      expect(cart.freeLines.single.source, FreeLineSource.reward);
      expect(cart.freeLines.single.variantId, 4003);
      expect(cart.bill!.couponDiscount, '0.00');

      final removed = await b.removeCoupon();
      expect(removed.freeLines, isEmpty);
    });

    test('the order keeps its free lines; the reward is used up', () async {
      final b = backend()
        ..rewardCoupons.add(const FakeCoupon.freeCarton(code: 'WEL1'));
      await add(b, carton(4001, '1 L', '110.00'), 10);
      final cart = await b.applyCoupon('WEL1', freeVariantId: 4003);
      final order = await b.placeOrder(
        PlaceOrderRequest(
          addressId: 1,
          paymentMethod: PaymentMethod.cod,
          expectedGrandTotal: cart.bill!.grandTotal,
        ),
        idempotencyKey: 'k1',
      );
      final detail = await b.getOrderDetail(order.id);
      expect(detail.freeLines.map((l) => l.source), [
        FreeLineSource.volumeOffer,
        FreeLineSource.reward,
      ]);
      expect(detail.lines, hasLength(1));
      expect(b.usedCoupons, contains('WEL1'));
      expect((await b.load()).freeLines, isEmpty);
    });
  });

  test('the controller passes the picked size to the repository', () async {
    final repo = StubCartRepository(cartSnapshot());
    final container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(cartProvider);
    await container
        .read(cartProvider.notifier)
        .applyCoupon('WEL1', freeVariantId: 4003);
    expect(repo.calls, contains('coupon:WEL1:4003'));
  });
}

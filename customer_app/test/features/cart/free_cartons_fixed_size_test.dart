import 'dart:math' as math;

import 'package:customer_app/app/bootstrap.dart' show initializeFormatting;
import 'package:customer_app/app/theme.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/widgets/coupon_sheet.dart';
import 'package:customer_app/features/cart/presentation/widgets/delivery_address_card.dart';
import 'package:customer_app/features/catalog/data/fake_catalog_repository.dart'
    show fakeCatalogVariant;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import 'cart_fixtures.dart';
import 'cart_screen_test.dart' show openCart;
import 'free_cartons_cart_test.dart' show freeCart, freeLine, openWith;

/// ADR 0003 (every free carton is the store's fixed 1 L size; rewards can
/// be 2 cartons) in the cart, and the highlighted free-offer banner (PM,
/// 2026-11-26).
void main() {
  setUpAll(initializeFormatting);

  const welcome = CouponOffer(
    code: 'WEL7K2M9QPX',
    title: '2 free cartons',
    description: 'Welcome reward',
    isEligible: true,
    isPersonal: true,
    discountType: CouponDiscountType.freeUnit,
    source: RewardSource.welcome,
    freeVariantId: 4001,
    freeQuantity: 2,
  );
  const applied = AppliedCoupon(
    code: 'WEL7K2M9QPX',
    title: '2 free cartons',
    discount: '0.00',
    discountType: CouponDiscountType.freeUnit,
    source: RewardSource.welcome,
    freeVariantId: 4001,
    freeQuantity: 2,
  );

  StubCartRepository repoWithReward() => StubCartRepository(freeCart())
    ..couponList = const [welcome]
    ..afterApply = freeCart(
      coupon: applied,
      free: [
        freeLine(),
        freeLine(quantity: 2, value: '220.00', source: FreeLineSource.reward),
      ],
    );

  List<String> applies(StubCartRepository repo) =>
      repo.calls.where((c) => c.startsWith('coupon:')).toList();

  group('coupon sheet', () {
    testWidgets('a fixed-size reward: "Get 2 free cartons." and Apply adds '
        'it at once, no size sheet', (tester) async {
      final repo = repoWithReward();
      await openCart(
        tester,
        TestApp(tokens: signedInTokens, cartRepository: repo),
      );
      await tester.tap(find.byKey(const Key('apply-coupon')));
      await tester.pumpAndSettle();
      expect(find.text('Get 2 free cartons.'), findsOneWidget);
      expect(find.textContaining('Pick a size'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('coupon-apply-WEL7K2M9QPX')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('free-size-sheet')), findsNothing);
      expect(applies(repo), ['coupon:WEL7K2M9QPX']);
      expect(find.byType(CouponSheet), findsNothing);
      expect(find.text('2 free cartons added to your cart'), findsOneWidget);
      expect(
        find.text('Your 2 free cartons are in the items above'),
        findsOneWidget,
      );
    });

    testWidgets('a typed fixed-size reward code is applied at once too', (
      tester,
    ) async {
      final repo = repoWithReward();
      await openCart(
        tester,
        TestApp(tokens: signedInTokens, cartRepository: repo),
      );
      await tester.tap(find.byKey(const Key('apply-coupon')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('coupon-code')),
        'wel7k2m9qpx',
      );
      await tester.tap(find.byKey(const Key('coupon-apply-code')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('free-size-sheet')), findsNothing);
      expect(applies(repo), ['coupon:wel7k2m9qpx']);
      expect(find.text('2 free cartons added to your cart'), findsOneWidget);
    });

    testWidgets('the fixed size not available: said plainly, under the '
        'code field', (tester) async {
      final repo = repoWithReward()
        ..applyError = const ApiError(
          code: ApiErrorCode.couponNotEligible,
          statusCode: 422,
          details: {
            'reason': 'FREE_VARIANT_UNAVAILABLE',
            'free_variant_id': 4001,
          },
        );
      await openCart(
        tester,
        TestApp(tokens: signedInTokens, cartRepository: repo),
      );
      await tester.tap(find.byKey(const Key('apply-coupon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('coupon-apply-WEL7K2M9QPX')));
      await tester.pumpAndSettle();
      expect(find.byType(CouponSheet), findsOneWidget);
      expect(
        find.text(
          'The free carton size is not available at this store right now. '
          'Please try again later.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the fake server (FAKE_API) with a fixed free size', () {
    FakeCommerceBackend backend() =>
        FakeCommerceBackend(
            latency: Duration.zero,
            rules: const FakeBillRules(
              freeUnitEvery: 10,
              freeUnitVariantId: 1501,
              minimumOrder: 0,
            ),
            variantLookup: fakeCatalogVariant,
          )
          ..rewardCoupons.add(
            const FakeCoupon.freeCarton(code: 'W2', freeQuantity: 2),
          );

    Future<void> add250ml(FakeCommerceBackend server, int quantity) {
      final found = fakeCatalogVariant(1503)!;
      return server.setQuantity(
        1503,
        quantity,
        preview: CartLinePreview.of(found.variant, found.productName),
      );
    }

    test('10 paid 250 ml cartons give 1 free 1 L carton', () async {
      final server = backend();
      await add250ml(server, 10);
      final cart = await server.load();
      final free = cart.freeLines.single;
      expect(free.variantId, 1501);
      expect(free.source, FreeLineSource.volumeOffer);
      expect(free.quantity, 1);
      expect(cart.freeOffer!.freeVariant?.id, 1501);
      expect(cart.freeOffer!.freeVariant?.name, '1 L');
    });

    test('the reward: listed with its quantity and the size pre-filled, '
        'applied with no size, 2 cartons of 1 L', () async {
      final server = backend();
      await add250ml(server, 6);
      final offer = (await server.coupons()).singleWhere((o) => o.code == 'W2');
      expect(offer.freeQuantity, 2);
      expect(offer.freeVariantId, 1501);
      expect(offer.hasFixedFreeSize, isTrue);

      final cart = await server.applyCoupon('W2');
      final reward = cart.freeLines.singleWhere(
        (line) => line.source == FreeLineSource.reward,
      );
      expect(reward.variantId, 1501);
      expect(reward.quantity, 2);
      expect(cart.coupon!.freeQuantity, 2);
    });

    test('another size is FREE_VARIANT_UNAVAILABLE', () async {
      final server = backend();
      await add250ml(server, 6);
      await expectLater(
        server.applyCoupon('W2', freeVariantId: 1502),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.couponNotEligible)
              .having(
                (e) => e.details['reason'],
                'reason',
                'FREE_VARIANT_UNAVAILABLE',
              ),
        ),
      );
    });
  });

  group('the free-offer banner', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    Finder banner() => find.byKey(const Key('free-offer-nudge'));

    testWidgets('nothing earned yet: the server message is the bold '
        'headline on gold, with a gift icon, first in the cart', (
      tester,
    ) async {
      await openWith(
        tester,
        freeCart(
          free: const [],
          offer: const FreeOffer(
            every: 10,
            paidUnits: 5,
            freeUnits: 0,
            unitsToNextFree: 5,
            message: 'Add 5 more cartons to get 1 free',
          ),
        ),
      );
      expect(banner(), findsOneWidget);
      final headline = tester.widget<Text>(
        find.byKey(const Key('free-offer-message')),
      );
      expect(headline.data, 'Add 5 more cartons to get 1 free');
      expect(headline.style?.fontWeight, FontWeight.w800);
      expect(find.byKey(const Key('free-offer-earned')), findsNothing);
      expect(
        find.descendant(
          of: banner(),
          matching: find.byIcon(Icons.card_giftcard),
        ),
        findsOneWidget,
      );

      // The gold offer gradient, and dark text that passes WCAG AA on it.
      const colors = CustomerColors();
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(of: banner(), matching: find.byType(DecoratedBox))
            .first,
      );
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, colors.offerGradient);
      expect(headline.style?.color, colors.onGold);
      for (final background in gradient.colors) {
        expect(contrast(colors.onGold, background), greaterThan(7));
      }

      // Above every other card in the cart.
      expect(
        tester.getTopLeft(banner()).dy,
        lessThan(tester.getTopLeft(find.byType(DeliveryAddressCard)).dy),
      );
    });

    testWidgets('free cartons earned: "You get 2 free cartons" leads, the '
        'next nudge under it', (tester) async {
      await openWith(
        tester,
        freeCart(
          free: [freeLine(quantity: 2, value: '220.00')],
          offer: const FreeOffer(
            every: 10,
            paidUnits: 24,
            freeUnits: 2,
            unitsToNextFree: 6,
            message: 'Add 6 more cartons to get 1 more free',
          ),
        ),
      );
      expect(
        find.descendant(
          of: banner(),
          matching: find.text('You get 2 free cartons with this order!'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: banner(),
          matching: find.text('Add 6 more cartons to get 1 more free'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: banner(), matching: find.byIcon(Icons.redeem)),
        findsOneWidget,
      );
    });

    testWidgets('one earned: the singular', (tester) async {
      await openWith(tester, freeCart());
      expect(
        find.text('You get 1 free carton with this order!'),
        findsOneWidget,
      );
    });

    testWidgets('a fixed free size: named from free_offer.free_variant', (
      tester,
    ) async {
      await openWith(
        tester,
        freeCart(
          offer: const FreeOffer(
            every: 10,
            paidUnits: 12,
            freeUnits: 1,
            unitsToNextFree: 8,
            message: 'Add 8 more cartons to get 1 more free',
            freeVariant: FreeVariant(
              id: 4001,
              name: '1 L x 12 (carton)',
              productName: 'Jivo Water',
            ),
          ),
        ),
      );
      expect(
        find.text('Free carton size: Jivo Water 1 L x 12 (carton)'),
        findsOneWidget,
      );
    });

    testWidgets('no fixed size: no size line', (tester) async {
      await openWith(tester, freeCart());
      expect(find.byKey(const Key('free-offer-size')), findsNothing);
    });
  });
}

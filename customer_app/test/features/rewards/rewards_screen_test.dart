import 'package:customer_app/app/bootstrap.dart' show initializeFormatting;
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/rewards/domain/reward.dart';
import 'package:customer_app/features/rewards/presentation/rewards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import '../cart/cart_fixtures.dart';
import '../cart/free_cartons_cart_test.dart' show freeCart, freeLine, cartons;

final _expiry = DateTime.utc(2026, 12, 25, 9, 30);

/// The server's rewards: one to use, one on an order, and two that must
/// only show in the history (a server that sends them anyway).
final summary = RewardsSummary(
  available: [
    Reward(
      code: 'WEL7K2M9QPX',
      title: '1 free carton: welcome reward',
      source: RewardSource.welcome,
      status: RewardStatus.available,
      expiresAt: _expiry,
    ),
    const Reward(
      code: 'REF4Q8N2KXW',
      title: '1 free carton: you invited a friend',
      source: RewardSource.referralReferrer,
      status: RewardStatus.claimed,
      orderNumber: 'JV-261124-000318',
    ),
    const Reward(
      code: 'USED1',
      title: 'x',
      source: RewardSource.welcome,
      status: RewardStatus.used,
    ),
    const Reward(
      code: 'GONE1',
      title: 'x',
      source: RewardSource.welcome,
      status: RewardStatus.expired,
    ),
  ],
  history: [
    RewardHistoryEntry(
      at: DateTime.utc(2026, 11, 18, 9, 30),
      kind: RewardHistoryKind.earned,
      title: 'Welcome reward',
    ),
    RewardHistoryEntry(
      at: DateTime.utc(2026, 11, 24, 8, 15),
      kind: RewardHistoryKind.claimed,
      title: 'Referral reward: you invited a friend',
      orderNumber: 'JV-261124-000318',
    ),
    RewardHistoryEntry(
      at: DateTime.utc(2026, 11, 22, 12, 40),
      kind: RewardHistoryKind.volumeFree,
      title: '2 free cartons with your order',
      quantity: 2,
      orderNumber: 'JV-261122-000287',
    ),
  ],
);

const coupons = [
  // The same reward in the coupon list: shown once.
  CouponOffer(
    code: 'WEL7K2M9QPX',
    title: '1 free carton',
    description: '',
    isEligible: true,
    isPersonal: true,
    discountType: CouponDiscountType.freeUnit,
    source: RewardSource.welcome,
  ),
  CouponOffer(
    code: 'JIVO50',
    title: 'Flat ₹50 off',
    description: 'On orders above ₹299',
    isEligible: true,
  ),
];

/// Opens Rewards from Home, on [repo] (the cart) and [rewards].
Future<TestApp> openRewards(
  WidgetTester tester, {
  RewardsSummary? rewards,
  Object? rewardsError,
  StubCartRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cart = repo ?? (StubCartRepository(freeCart())..couponList = coupons);
  final app = TestApp(tokens: signedInTokens, cartRepository: cart);
  app.rewards
    ..summary = rewards ?? summary
    ..error = rewardsError;
  await app.pump(tester);
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.myCoupons);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUpAll(initializeFormatting);

  testWidgets('the Account tile says Rewards and opens the screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('account-my-coupons'));
    expect(
      find.descendant(of: tile, matching: find.text('Rewards')),
      findsOneWidget,
    );
    expect(find.text('My coupons'), findsNothing);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(RewardsScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Rewards'), findsOneWidget);
  });

  testWidgets('rewards with Available / Claimed chips, then coupons; used '
      'and expired ones are not listed', (tester) async {
    await openRewards(tester);

    const welcome = ValueKey('reward-WEL7K2M9QPX');
    expect(find.byKey(welcome), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(welcome),
        matching: find.text('1 free carton'),
      ),
      findsOneWidget,
    );
    expect(find.text('Welcome gift'), findsOneWidget);
    expect(find.text('Expires on 25 Dec 2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reward-status-WEL7K2M9QPX')),
        matching: find.text('Available'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reward-use-WEL7K2M9QPX')),
      findsOneWidget,
    );

    expect(find.text('Referral reward'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reward-status-REF4Q8N2KXW')),
        matching: find.text('Claimed'),
      ),
      findsOneWidget,
    );
    expect(find.text('On your order JV-261124-000318'), findsOneWidget);
    expect(find.byKey(const ValueKey('reward-use-REF4Q8N2KXW')), findsNothing);

    expect(find.byKey(const ValueKey('reward-USED1')), findsNothing);
    expect(find.byKey(const ValueKey('reward-GONE1')), findsNothing);

    // The reward is not listed again as a coupon; JIVO50 is.
    expect(find.byKey(const ValueKey('my-coupon-WEL7K2M9QPX')), findsNothing);
    expect(find.byKey(const ValueKey('my-coupon-JIVO50')), findsOneWidget);
    expect(find.text('Free cartons'), findsOneWidget);
    expect(find.text('Coupons'), findsOneWidget);
  });

  testWidgets('History: newest first, with dates, kinds and order numbers', (
    tester,
  ) async {
    await openRewards(tester);
    await tester.tap(find.byKey(const Key('rewards-tab-history')));
    await tester.pumpAndSettle();

    Finder row(int i) => find.byKey(ValueKey('reward-history-$i'));
    expect(
      find.descendant(
        of: row(0),
        matching: find.text('Claimed · 1 free carton'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row(1),
        matching: find.text('Volume offer · 2 free cartons'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row(1),
        matching: find.text('22 Nov 2026 · Order JV-261122-000287'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row(2),
        matching: find.text('Earned · 1 free carton'),
      ),
      findsOneWidget,
    );
    expect(find.text('Welcome reward'), findsOneWidget);
  });

  testWidgets('Use: pick a size, the reward is applied, the cart opens with '
      'the free carton', (tester) async {
    final repo =
        StubCartRepository(
            cartSnapshot(lines: [cartLine()], thresholds: cartons),
          )
          ..couponList = coupons
          ..afterApply = freeCart(
            free: [freeLine(variantId: 1502, source: FreeLineSource.reward)],
            offer: null,
            coupon: const AppliedCoupon(
              code: 'WEL7K2M9QPX',
              title: '1 free carton',
              discount: '0.00',
              discountType: CouponDiscountType.freeUnit,
              freeVariantId: 1502,
            ),
          );
    await openRewards(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('reward-use-WEL7K2M9QPX')));
    await tester.pumpAndSettle();
    expect(find.text('Pick a size for your free carton'), findsOneWidget);
    expect(
      find.text('Your order still needs at least 5 paid cartons.'),
      findsOneWidget,
    );
    // The water sizes of the store (the fake catalog's water category),
    // each with the server's MRP.
    expect(find.byKey(const ValueKey('free-size-1501')), findsOneWidget);
    expect(find.byKey(const ValueKey('free-size-1503')), findsOneWidget);
    expect(find.text('Worth ₹125'), findsOneWidget);
    // Nothing picked yet: no apply.
    final confirm = find.descendant(
      of: find.byKey(const Key('free-size-confirm')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('free-size-1502')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('free-size-confirm')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('coupon:WEL7K2M9QPX:1502'));
    expect(find.byType(CartScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cart-free-line-1502-reward')),
      findsOneWidget,
    );
    expect(find.text('Free carton reward applied'), findsOneWidget);
  });

  testWidgets('too few paid cartons: the server reason and Add cartons', (
    tester,
  ) async {
    final repo =
        StubCartRepository(
            cartSnapshot(lines: [cartLine()], thresholds: cartons),
          )
          ..couponList = coupons
          ..applyError = const ApiError(
            code: ApiErrorCode.couponNotEligible,
            rawCode: 'COUPON_NOT_ELIGIBLE',
            statusCode: 422,
            details: {
              'code': 'WEL7K2M9QPX',
              'reason': 'MIN_ORDER_UNITS',
              'min_order_units': 5,
              'paid_units': 2,
              'units_to_unlock': 3,
            },
          );
    await openRewards(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('reward-use-WEL7K2M9QPX')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('free-size-1503')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('free-size-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Add 3 more cartons to use this reward (minimum 5 paid cartons)',
      ),
      findsOneWidget,
    );
    expect(find.byType(CartScreen), findsNothing);
    await tester.tap(find.byKey(const Key('free-size-add-cartons')));
    await tester.pumpAndSettle();
    expect(find.text('Pick a size for your free carton'), findsNothing);
  });

  testWidgets('a size that is no longer sold: choose another', (tester) async {
    final repo =
        StubCartRepository(
            cartSnapshot(lines: [cartLine()], thresholds: cartons),
          )
          ..couponList = coupons
          ..applyError = const ApiError(
            code: ApiErrorCode.couponNotEligible,
            statusCode: 422,
            details: {
              'reason': 'FREE_VARIANT_UNAVAILABLE',
              'free_variant_id': 1503,
            },
          );
    await openRewards(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('reward-use-WEL7K2M9QPX')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('free-size-1503')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('free-size-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This size is not available for your free carton here. '
        'Choose another size.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('free-size-add-cartons')), findsNothing);
  });

  testWidgets('a reward already on the cart: In your cart and View cart', (
    tester,
  ) async {
    final repo = StubCartRepository(
      freeCart(
        coupon: const AppliedCoupon(
          code: 'WEL7K2M9QPX',
          title: '1 free carton',
          discount: '0.00',
          discountType: CouponDiscountType.freeUnit,
        ),
      ),
    )..couponList = coupons;
    await openRewards(tester, repo: repo);
    expect(find.byKey(const ValueKey('reward-use-WEL7K2M9QPX')), findsNothing);
    expect(find.text('In your cart'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('reward-view-cart-WEL7K2M9QPX')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
  });

  testWidgets('nothing at all: empty states on both tabs', (tester) async {
    await openRewards(
      tester,
      rewards: RewardsSummary.empty,
      repo: StubCartRepository(cartSnapshot()),
    );
    expect(find.text('No rewards or coupons right now'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rewards-tab-history')));
    await tester.pumpAndSettle();
    expect(find.text('No rewards history yet'), findsOneWidget);
  });

  testWidgets('rewards fail, coupons load: a Retry for the rewards only', (
    tester,
  ) async {
    final app = await openRewards(
      tester,
      rewardsError: const ApiError(code: ApiErrorCode.network),
    );
    expect(find.byKey(const Key('rewards-load-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-coupon-JIVO50')), findsOneWidget);
    // Its free-carton coupon can still be used.
    expect(
      find.byKey(const ValueKey('reward-use-WEL7K2M9QPX')),
      findsOneWidget,
    );

    app.rewards.error = null;
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('rewards-load-failed')),
        matching: find.text('Retry'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rewards-load-failed')), findsNothing);
    expect(find.text('On your order JV-261124-000318'), findsOneWidget);
  });

  testWidgets('both fail: one error with Retry', (tester) async {
    await openRewards(
      tester,
      rewardsError: const ApiError(code: ApiErrorCode.network),
      repo: StubCartRepository(cartSnapshot())
        ..couponError = const ApiError(code: ApiErrorCode.network),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const Key('rewards-list')), findsNothing);
  });

  testWidgets('the history fails alone: its own Retry', (tester) async {
    await openRewards(
      tester,
      rewardsError: const ApiError(code: ApiErrorCode.network),
    );
    await tester.tap(find.byKey(const Key('rewards-tab-history')));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsWidgets);
    expect(find.byKey(const Key('rewards-history')), findsNothing);
  });
}

import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import 'cart_fixtures.dart';

Future<StubCartRepository> openCoupons(
  WidgetTester tester, {
  List<CouponOffer> coupons = const [],
  Object? error,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = StubCartRepository(cartSnapshot())
    ..couponList = coupons
    ..couponError = error;
  final app = TestApp(tokens: signedInTokens, cartRepository: repo);
  await app.pump(tester);
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.myCoupons);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('lists coupons: For you label, copy, reason, min order', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openCoupons(
      tester,
      coupons: const [
        CouponOffer(
          code: 'FRIEND100',
          title: 'Friend reward',
          description: '₹100 off',
          isEligible: true,
          isPersonal: true,
          minOrderValue: '500.00',
        ),
        CouponOffer(
          code: 'BIG',
          title: 'Big order',
          description: 'Big orders only',
          isEligible: false,
          ineligibility: CouponIneligibility.minOrderValue,
          amountToUnlock: '200.00',
        ),
      ],
    );

    // Account > Rewards (was My coupons, ADR 0002): same route.
    expect(find.text('Rewards'), findsWidgets);
    expect(
      find.byKey(const ValueKey('coupon-for-you-FRIEND100')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('coupon-for-you-BIG')), findsNothing);
    expect(find.text('Min order ₹500'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-coupon-problem-BIG')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('my-coupon-copy-FRIEND100')));
    await tester.pump();
    expect(copied, 'FRIEND100');
    expect(find.text('Code FRIEND100 copied'), findsOneWidget);
  });

  testWidgets('no store yet: a choose-location state, not a failing retry', (
    tester,
  ) async {
    await openCoupons(
      tester,
      error: const ApiError(code: ApiErrorCode.storeNotFound, statusCode: 404),
    );
    expect(
      find.text('Choose your delivery location to see coupons'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.byKey(const Key('my-coupons-choose-location')), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await openCoupons(tester);
    expect(find.text('No rewards or coupons right now'), findsOneWidget);
  });

  testWidgets('error shows retry, retry loads the list', (tester) async {
    final repo = await openCoupons(
      tester,
      error: const ApiError(code: ApiErrorCode.unknown),
    );
    expect(find.text('Retry'), findsOneWidget);
    repo
      ..couponError = null
      ..couponList = const [
        CouponOffer(
          code: 'WELCOME',
          title: 'Welcome',
          description: 'd',
          isEligible: true,
        ),
      ];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-coupon-WELCOME')), findsOneWidget);
  });
}

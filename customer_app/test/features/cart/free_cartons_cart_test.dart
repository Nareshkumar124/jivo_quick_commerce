import 'package:customer_app/app/bootstrap.dart' show initializeFormatting;
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/widgets/coupon_sheet.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/checkout/presentation/checkout_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/presentation/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';
import 'cart_fixtures.dart';
import 'cart_screen_test.dart' show openCart, textOf;

/// A free carton as the server sends it (ADR 0002).
FreeLine freeLine({
  int variantId = 4001,
  String variantName = '1 L x 12 (carton)',
  int quantity = 1,
  String mrp = '110.00',
  String value = '110.00',
  FreeLineSource source = FreeLineSource.volumeOffer,
}) => FreeLine(
  variantId: variantId,
  productName: 'Jivo Water',
  variantName: variantName,
  quantity: quantity,
  mrp: mrp,
  value: value,
  source: source,
);

/// A paid water line (flat rate, no price tiers).
CartLine waterLine({int quantity = 12, int variantId = 4001}) => cartLine(
  variantId: variantId,
  name: 'Jivo Water',
  variantName: '1 L x 12 (carton)',
  price: '110.00',
  mrp: '110.00',
  quantity: quantity,
  lineTotal: '1320.00',
  lineMrpTotal: '1320.00',
  orderable: 50,
);

/// A bill whose numbers deliberately don't add up: the screen must show
/// the server's strings.
const freeBill = CartBill(
  mrpTotal: '1320.00',
  itemTotal: '1320.00',
  productDiscount: '0.00',
  couponDiscount: '0.00',
  deliveryFee: '0.00',
  smallCartFee: '0.00',
  handlingFee: '0.00',
  tip: '0.00',
  grandTotal: '1320.00',
  totalSavings: '777.00',
  freeItemsValue: '250.00',
);

const cartons = CartThresholds(
  minOrderValue: '0.00',
  minOrderUnits: 5,
  orderUnitLabel: 'cartons',
);

CartSnapshot freeCart({
  List<CartLine>? lines,
  List<FreeLine>? free,
  FreeOffer? offer = const FreeOffer(
    every: 10,
    paidUnits: 12,
    freeUnits: 1,
    unitsToNextFree: 8,
    message: 'Add 8 more cartons to get 1 more free',
  ),
  AppliedCoupon? coupon,
  CartThresholds thresholds = cartons,
  int? itemCount,
  CartBill bill = freeBill,
  CheckoutStatus checkout = okCheckout,
}) {
  final paid = lines ?? [waterLine()];
  return CartSnapshot.fromLines(
    lines: paid,
    itemCount: itemCount ?? paid.fold(0, (n, l) => n + l.quantity),
    bill: bill,
    coupon: coupon,
    thresholds: thresholds,
    checkout: checkout,
    paymentOptions: bothMethods,
    addressId: 1,
    freeLines:
        free ??
        [
          freeLine(),
          freeLine(
            variantId: 4002,
            variantName: '500 ml x 24 (carton)',
            mrp: '140.00',
            value: '140.00',
            source: FreeLineSource.reward,
          ),
        ],
    freeOffer: offer,
  );
}

Future<void> openWith(WidgetTester tester, CartSnapshot snapshot) => openCart(
  tester,
  TestApp(tokens: signedInTokens, cartRepository: StubCartRepository(snapshot)),
);

void main() {
  setUpAll(initializeFormatting);

  group('cart', () {
    testWidgets('free rows: FREE tag, ₹0, struck MRP, quantity and source', (
      tester,
    ) async {
      await openWith(tester, freeCart());

      const volume = 'cart-free-line-4001-volumeOffer';
      const reward = 'cart-free-line-4002-reward';
      expect(find.byKey(const ValueKey(volume)), findsOneWidget);
      expect(find.byKey(const ValueKey(reward)), findsOneWidget);
      expect(textOf(tester, 'cart-free-line-price-4001-volumeOffer'), '₹0');
      expect(textOf(tester, 'cart-free-line-mrp-4001-volumeOffer'), '₹110');
      final mrp = tester.widget<Text>(
        find.byKey(const ValueKey('cart-free-line-mrp-4001-volumeOffer')),
      );
      expect(mrp.style?.decoration, TextDecoration.lineThrough);
      expect(textOf(tester, 'cart-free-line-qty-4002-reward'), '· Qty 1');
      // 2 tags, the delivery row and the Free cartons bill row.
      expect(find.text('FREE'), findsNWidgets(4));
      expect(find.text('Buy 10 get 1 free'), findsOneWidget);
      expect(find.text('Reward'), findsOneWidget);
      // No stepper or remove on a free line.
      expect(find.byKey(const ValueKey('cart-line-remove-4002')), findsNothing);
      expect(
        tester.getSemantics(find.byKey(const ValueKey(volume))),
        matchesSemantics(
          label: 'Jivo Water 1 L x 12 (carton), 1 free, worth ₹110',
        ),
      );
    });

    testWidgets('the nudge is the server message; the notice shows', (
      tester,
    ) async {
      await openWith(
        tester,
        freeCart(
          free: const [],
          offer: const FreeOffer(
            every: 10,
            paidUnits: 10,
            freeUnits: 1,
            unitsToNextFree: 10,
            message: 'Add 10 more cartons to get 1 more free',
            notice: 'Your free carton is out of stock right now.',
          ),
        ),
      );
      expect(
        find.text('Add 10 more cartons to get 1 more free'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('free-offer-notice')), findsOneWidget);
      expect(
        find.text('Your free carton is out of stock right now.'),
        findsOneWidget,
      );
      // A notice is not a blocker.
      expect(find.byKey(const Key('min-units-warning')), findsNothing);
    });

    testWidgets('no offer: no nudge, no notice', (tester) async {
      await openWith(tester, freeCart(offer: null, free: const []));
      expect(find.byKey(const Key('free-offer-nudge')), findsNothing);
      expect(find.byKey(const Key('free-offer-notice')), findsNothing);
    });

    testWidgets('bill: a Free cartons row, the server savings', (tester) async {
      await openWith(tester, freeCart());
      expect(find.text('Free cartons'), findsOneWidget);
      expect(textOf(tester, 'bill-free-items-struck'), '₹250');
      expect(textOf(tester, 'bill-free-items'), 'FREE');
      // To pay and the savings banner are the server's, not derived.
      expect(textOf(tester, 'bill-to-pay'), '₹1,320');
      expect(find.text('You save ₹777 on this order'), findsOneWidget);
    });

    testWidgets('no free cartons: no bill row', (tester) async {
      await openWith(
        tester,
        cartSnapshot(lines: [waterLine()], thresholds: cartons),
      );
      expect(find.byKey(const ValueKey('bill-free-items')), findsNothing);
    });

    testWidgets('the minimum is the server count: free ones never help', (
      tester,
    ) async {
      // 4 paid + 1 free reward carton: still 1 short of 5.
      await openWith(
        tester,
        freeCart(
          lines: [waterLine(quantity: 4)],
          free: [freeLine(source: FreeLineSource.reward)],
          thresholds: const CartThresholds(
            minOrderValue: '0.00',
            minOrderUnits: 5,
            unitsToMinOrder: 1,
            orderUnitLabel: 'cartons',
          ),
          checkout: const CheckoutStatus(
            canPlaceOrder: false,
            blockers: [
              CheckoutBlocker(
                code: CheckoutBlockerCode.minUnitsNotMet,
                message: 'x',
              ),
            ],
          ),
        ),
      );
      expect(
        find.text('Add 1 more to place your order (minimum 5 cartons)'),
        findsWidgets,
      );
    });

    testWidgets('a reward on the cart: its own coupon row with Remove', (
      tester,
    ) async {
      await openWith(
        tester,
        freeCart(
          coupon: const AppliedCoupon(
            code: 'WEL7K2M9QPX',
            title: '1 free carton',
            discount: '0.00',
            discountType: CouponDiscountType.freeUnit,
            source: RewardSource.welcome,
            freeVariantId: 4002,
          ),
        ),
      );
      expect(find.text('Free carton reward applied'), findsOneWidget);
      expect(
        find.text('Your free carton is in the items above'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('remove-coupon')), findsOneWidget);
      expect(find.text('You save ₹0'), findsNothing);
    });

    testWidgets('only a reward carton, nothing paid: the cart still shows', (
      tester,
    ) async {
      await openWith(
        tester,
        freeCart(
          lines: const [],
          itemCount: 0,
          free: [freeLine(source: FreeLineSource.reward)],
          offer: null,
        ),
      );
      expect(find.byKey(const Key('cart-empty')), findsNothing);
      expect(
        find.byKey(const ValueKey('cart-free-line-4001-reward')),
        findsOneWidget,
      );
    });

    testWidgets('the coupon sheet: a reward says what it gives and opens '
        'the size picker', (tester) async {
      final repo = StubCartRepository(freeCart())
        ..couponList = const [
          CouponOffer(
            code: 'WEL7K2M9QPX',
            title: '1 free carton',
            description: 'Welcome reward',
            isEligible: true,
            isPersonal: true,
            discountType: CouponDiscountType.freeUnit,
            source: RewardSource.welcome,
          ),
        ];
      await openCart(
        tester,
        TestApp(tokens: signedInTokens, cartRepository: repo),
      );
      await tester.tap(find.byKey(const Key('apply-coupon')));
      await tester.pumpAndSettle();
      expect(find.byType(CouponSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('coupon-free-carton-WEL7K2M9QPX')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('coupon-apply-WEL7K2M9QPX')));
      await tester.pumpAndSettle();
      expect(find.text('Pick a size for your free carton'), findsOneWidget);
      // The fake catalog's water sizes.
      await tester.tap(find.byKey(const ValueKey('free-size-1502')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('free-size-confirm')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('coupon:WEL7K2M9QPX:1502'));
      expect(find.byType(CouponSheet), findsNothing);
      expect(find.text('Free carton added to your cart'), findsOneWidget);
    });
  });

  testWidgets('checkout lists the free cartons at ₹0', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = TestApp(
      tokens: signedInTokens,
      cartRepository: StubCartRepository(freeCart()),
    );
    await app.pump(tester);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push(Routes.cart);
    await tester.pumpAndSettle();
    router.push(Routes.checkout);
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.byKey(const Key('checkout-free-lines')), findsOneWidget);
    expect(textOf(tester, 'free-line-total-4001-volumeOffer'), '₹0');
    expect(textOf(tester, 'free-line-value-4002-reward'), '₹140');
    expect(find.text('Free cartons'), findsWidgets);
  });

  testWidgets('order detail shows the order\'s free cartons at ₹0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeCommerceBackend(
      latency: Duration.zero,
      rules: const FakeBillRules(freeUnitEvery: 10, minimumOrder: 0),
    );
    const water = CatalogVariant(
      id: 4001,
      name: '1 L x 12 (carton)',
      sellingPrice: '110.00',
      mrp: '110.00',
      stockStatus: StockStatus.inStock,
      orderableQuantity: 50,
      maxQtyPerOrder: 50,
    );
    await backend.setQuantity(
      4001,
      10,
      preview: CartLinePreview.of(water, 'Jivo Water'),
    );
    final cart = await backend.load();
    final order = await backend.placeOrder(
      PlaceOrderRequest(
        addressId: 1,
        paymentMethod: PaymentMethod.cod,
        expectedGrandTotal: cart.bill!.grandTotal,
      ),
      idempotencyKey: 'free-1',
    );
    final app = TestApp(tokens: signedInTokens, commerce: backend);
    await app.pump(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push(Routes.order(order.id));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('free-line-4001-volumeOffer')),
      findsOneWidget,
    );
    expect(textOf(tester, 'free-line-total-4001-volumeOffer'), '₹0');
    expect(textOf(tester, 'free-line-value-4001-volumeOffer'), '₹110');
    expect(find.text('Free cartons'), findsOneWidget); // the bill row
  });
}

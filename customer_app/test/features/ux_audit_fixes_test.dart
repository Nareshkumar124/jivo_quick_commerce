import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:customer_app/features/addresses/presentation/address_screens.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/widgets/bill_details.dart';
import 'package:customer_app/features/cart/presentation/widgets/cart_line_tile.dart';
import 'package:customer_app/features/catalog/presentation/widgets/price_tags.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:customer_app/features/orders/presentation/order_detail_screen.dart';
import 'package:customer_app/features/rating/presentation/rate_order_screen.dart';
import 'package:customer_app/shared/formatting/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../helpers/widget_harness.dart';
import 'cart/cart_fixtures.dart';

/// The 2026-11-10 UX audit fixes (design/audits/2026-11-10-customer-app.md):
/// text scaling at 1.3x and 2.0x on a 360 dp phone (CA-08, CA-18, CA-24),
/// the unsupplied-items notice (CA-27), safe amounts (CA-33) and
/// screen-reader details (CA-12, CA-34).
void main() {
  void phone(WidgetTester tester, {double height = 640}) {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Fails with the full report (which widget overflowed).
  void expectNoLayoutError(WidgetTester tester) {
    final error = tester.takeException();
    if (error is FlutterError) fail(error.toStringDeep());
    expect(error, isNull);
  }

  const address = SavedAddress(
    id: 7,
    input: AddressInput(
      label: AddressLabel.home,
      customLabel: 'Grandma home in Sector 14',
      house: 'Flat 4B',
      buildingStreet: 'Rose Apartments, MG Road',
      city: 'New Delhi',
      state: 'Delhi',
      pincode: '110001',
      lat: 28.6,
      lng: 77.2,
    ),
    isDefault: true,
    isServiceable: false,
  );

  OrderDetail order({
    OrderStatus status = OrderStatus.packed,
    PaymentMethod method = PaymentMethod.online,
    PaymentStatus paymentStatus = PaymentStatus.refundPending,
    List<OrderLineItem>? lines,
    List<OrderRefund> refunds = const [],
    String grandTotal = '990.00',
  }) => OrderDetail(
    id: 1,
    number: 'JQ-1042',
    status: status,
    paymentMethod: method,
    paymentStatus: paymentStatus,
    storeName: 'Store',
    lines:
        lines ??
        const [
          OrderLineItem(
            variantId: 101,
            productId: 1,
            productName: 'Jivo Canola Oil',
            variantName: '1 L',
            mrp: '299.00',
            sellingPrice: '250.00',
            quantity: 2,
            lineMrpTotal: '598.00',
            lineTotal: '250.00',
            quantityUnavailable: 1,
          ),
        ],
    itemCount: 1,
    bill: CartBill(
      mrpTotal: '598.00',
      itemTotal: '250.00',
      productDiscount: '48.00',
      couponDiscount: '0.00',
      deliveryFee: '0.00',
      smallCartFee: '0.00',
      handlingFee: '0.00',
      tip: '0.00',
      grandTotal: grandTotal,
      totalSavings: '48.00',
    ),
    createdAt: DateTime.utc(2026, 11, 10, 9, 30),
    refunds: refunds,
  );

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('CA-08 address row: label and both flags fit at ${scale}x', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        harness(
          ListView(
            children: [
              AddressListTile(
                address: address,
                onEdit: () {},
                onSetDefault: () {},
                onDelete: () {},
              ),
            ],
          ),
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();
      expectNoLayoutError(tester);
      expect(find.text('Grandma home in Sector 14'), findsOneWidget);
      expect(find.text('Not serviceable'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      // The flags carry an icon, not only a colour.
      expect(find.byIcon(Icons.location_off), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      // The menu names the address for screen readers.
      expect(
        find.byTooltip('More options for Grandma home in Sector 14'),
        findsOneWidget,
      );
    });

    testWidgets('CA-24 order status row: the longest status and the date '
        'fit at ${scale}x', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: OrderStatusRow(order: order()),
          ),
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();
      expectNoLayoutError(tester);
      expect(find.text('Packed, rider on the way to store'), findsOneWidget);
      expect(find.textContaining('10 Nov 2026'), findsOneWidget);
    });

    testWidgets('CA-18 cart line: stacked from 1.3x, nothing overflows at '
        '${scale}x', (tester) async {
      phone(tester, height: 1000);
      final line = cartLine(
        name: 'Jivo Cold Pressed Canola Oil Pouch',
        lineTotal: '124999.00',
      );
      await tester.pumpWidget(
        harness(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [CartLineTile(line: line)],
          ),
          overrides: [
            cartRepositoryProvider.overrideWithValue(
              StubCartRepository(cartSnapshot(lines: [line])),
            ),
          ],
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();
      expectNoLayoutError(tester);
      final name = tester.getRect(
        find.text('Jivo Cold Pressed Canola Oil Pouch'),
      );
      final total = tester.getRect(find.text('₹1,24,999'));
      if (scale >= 1.3) {
        // The total sits on its own row under the name: the name keeps the
        // full width next to the image.
        expect(total.top, greaterThanOrEqualTo(name.bottom));
      } else {
        // Side by side: the total is in the trailing column.
        expect(total.left, greaterThanOrEqualTo(name.right));
      }
    });
  }

  testWidgets('CA-18 Remove shows Undo, which puts the quantity back', (
    tester,
  ) async {
    phone(tester, height: 800);
    final line = cartLine();
    final repo = StubCartRepository(cartSnapshot(lines: [line]));
    await tester.pumpWidget(
      harness(
        CartLineTile(line: line),
        overrides: [cartRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pumpAndSettle();
    // The server's cart after the remove: the line is gone.
    repo.snapshot = cartSnapshot(lines: const []);
    await tester.tap(find.byKey(const ValueKey('cart-line-remove-101')));
    await tester.pumpAndSettle();
    expect(find.text('Removed Jivo Canola Oil 1 L'), findsOneWidget);
    expect(repo.calls, contains('set:101:0'));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'set:101:2');
  });

  testWidgets('CA-18 an out-of-stock line is removed without Undo', (
    tester,
  ) async {
    phone(tester, height: 800);
    final line = cartLine(orderable: 0, issue: CartIssueCode.outOfStock);
    final repo = StubCartRepository(cartSnapshot(lines: [line]));
    await tester.pumpWidget(
      harness(
        CartLineTile(line: line),
        overrides: [cartRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pumpAndSettle();
    repo.snapshot = cartSnapshot(lines: const []);
    await tester.tap(find.byKey(const ValueKey('cart-line-remove-101')));
    await tester.pumpAndSettle();
    expect(find.text('Removed Jivo Canola Oil 1 L'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('CA-18 Undo refused for stock shows the mapped error', (
    tester,
  ) async {
    phone(tester, height: 800);
    final line = cartLine();
    final repo = _FailingSetCart(cartSnapshot(lines: [line]));
    await tester.pumpWidget(
      harness(
        CartLineTile(line: line),
        overrides: [cartRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pumpAndSettle();
    repo.snapshot = cartSnapshot(lines: const []);
    await tester.tap(find.byKey(const ValueKey('cart-line-remove-101')));
    await tester.pumpAndSettle();
    repo.failNextSet = const ApiError(
      code: ApiErrorCode.stockUnavailable,
      statusCode: 409,
      details: {
        'items': [
          {'variant_id': 101, 'orderable_quantity': 1},
        ],
      },
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Only 1 of Jivo Canola Oil 1 L can be ordered now.'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('CA-27 unsupplied items notice', () {
    testWidgets('online: the lines and the server refund', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        harness(
          UnsuppliedItemsNotice(
            order: order(
              refunds: [
                OrderRefund(
                  amount: '250.00',
                  status: RefundStatus.pending,
                  createdAt: DateTime.utc(2026, 11, 10, 9, 40),
                  reason: RefundReason.itemsUnavailable,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text("1 item couldn't be supplied"), findsOneWidget);
      expect(find.text('Jivo Canola Oil 1 L: 1 of 2'), findsOneWidget);
      expect(
        find.text('₹250 is being refunded to your original payment method.'),
        findsOneWidget,
      );
    });

    testWidgets('COD: the new amount to pay the rider, from the server', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        harness(
          UnsuppliedItemsNotice(
            order: order(
              method: PaymentMethod.cod,
              paymentStatus: PaymentStatus.codPending,
              lines: [
                for (var i = 0; i < 3; i++)
                  OrderLineItem(
                    variantId: 100 + i,
                    productId: i,
                    productName: 'Item $i',
                    variantName: '1 L',
                    mrp: '100.00',
                    sellingPrice: '90.00',
                    quantity: 3,
                    lineMrpTotal: '300.00',
                    lineTotal: '180.00',
                    quantityUnavailable: 1,
                  ),
              ],
            ),
          ),
        ),
      );
      expect(find.text("3 items couldn't be supplied"), findsOneWidget);
      expect(find.text('Item 0 1 L: 1 of 3'), findsOneWidget);
      expect(find.text('Item 1 1 L: 1 of 3'), findsOneWidget);
      expect(find.text('Item 2 1 L: 1 of 3'), findsNothing);
      expect(find.text('and 1 more'), findsOneWidget);
      expect(find.text('Pay ₹990 to the rider'), findsOneWidget);
    });
  });

  group('CA-33 a malformed amount', () {
    test('shows a dash instead of throwing', () {
      expect(displayRupees('.50'), '—');
      expect(displayRupees(null), '—');
      expect(displayRupees('1240.00'), '₹1,240');
    });

    testWidgets('one bad bill row does not break the bill', (tester) async {
      await tester.pumpWidget(
        harness(
          const BillDetails(
            bill: CartBill(
              mrpTotal: '.50',
              itemTotal: '498.00',
              productDiscount: '100.00',
              couponDiscount: '0.00',
              deliveryFee: '0.00',
              smallCartFee: '0.00',
              handlingFee: '0.00',
              tip: '0.00',
              grandTotal: '999.00',
              totalSavings: '0.00',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('—'), findsWidgets);
      expect(find.text('₹999'), findsOneWidget);
    });
  });

  testWidgets('CA-34 read-only stars are one stop: "Rated 4 out of 5"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(const StarRatingPicker(value: 4, onChanged: null)),
    );
    expect(find.bySemanticsLabel('Rated 4 out of 5'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    semantics.dispose();
  });

  testWidgets('CA-12 product detail names the diet mark in words', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const Column(
          children: [
            VegMarkWithLabel(isVeg: true),
            VegMarkWithLabel(isVeg: false),
          ],
        ),
      ),
    );
    expect(find.text('Veg'), findsOneWidget);
    expect(find.text('Non-veg'), findsOneWidget);
    expect(find.byKey(const Key('non-veg-triangle')), findsOneWidget);
  });
}

/// Fails the next quantity change with [failNextSet].
class _FailingSetCart extends StubCartRepository {
  _FailingSetCart(super.snapshot);

  Object? failNextSet;

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) {
    final failure = failNextSet;
    if (failure != null) {
      failNextSet = null;
      throw failure;
    }
    return super.setQuantity(variantId, quantity, preview: preview);
  }
}

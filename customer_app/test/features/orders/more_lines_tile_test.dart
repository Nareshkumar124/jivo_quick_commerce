import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:customer_app/features/orders/presentation/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_harness.dart';

/// CA-29 "+N" thumbnail tile: `line_count` (API #57) minus the thumbnails.
OrderListItem row({int lineCount = 0, int images = 0, int itemCount = 9}) =>
    OrderListItem(
      id: 1,
      number: 'JV-261117-000001',
      status: OrderStatus.delivered,
      paymentMethod: PaymentMethod.cod,
      paymentStatus: PaymentStatus.paid,
      storeName: 'Jivo Sector 14',
      itemCount: itemCount,
      grandTotal: '753.00',
      createdAt: DateTime.utc(2026, 11, 17, 6),
      imageUrls: [for (var i = 0; i < images; i++) 'http://localhost/$i.png'],
      lineCount: lineCount,
    );

void main() {
  setUpAll(initializeFormatting);

  group('moreLines', () {
    test('line_count minus the thumbnails shown', () {
      expect(row(lineCount: 7, images: 4).moreLines, 3);
      expect(row(lineCount: 5, images: 2).moreLines, 3);
    });

    test('0 when every line has a thumbnail, or nothing was sent', () {
      expect(row(lineCount: 4, images: 4).moreLines, 0);
      expect(row().moreLines, 0);
    });

    test('never negative when line_count is below the thumbnails', () {
      expect(row(lineCount: 1, images: 3).moreLines, 0);
      expect(row(lineCount: -2, images: 1).moreLines, 0);
    });

    test('only the 4 thumbnails drawn count as shown', () {
      expect(row(lineCount: 6, images: 5).moreLines, 2);
    });
  });

  Future<void> pumpRow(
    WidgetTester tester,
    OrderListItem order, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        ListView(children: [OrderListTile(order: order)]),
        textScaler: TextScaler.linear(scale),
      ),
    );
    await tester.pump();
  }

  testWidgets('"+3" after 4 thumbnails, read as "and 3 more products"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(tester, row(lineCount: 7, images: 4));

    final tile = find.byKey(const Key('order-more-lines'));
    expect(tile, findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(tester.getSize(tile), const Size(40, 40));
    expect(
      find.bySemanticsLabel(RegExp('and 3 more products')),
      findsOneWidget,
    );
    // Units stay the units ("9 items"), not the lines.
    expect(find.textContaining('9 items'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('singular label for one more line', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(tester, row(lineCount: 3, images: 2));
    expect(find.text('+1'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('and 1 more product\\b')), findsOne);
    semantics.dispose();
  });

  testWidgets('no tile when every line has a thumbnail', (tester) async {
    await pumpRow(tester, row(lineCount: 2, images: 2));
    expect(find.byKey(const Key('order-more-lines')), findsNothing);
  });

  testWidgets('no tile when line_count is below the thumbnails', (
    tester,
  ) async {
    await pumpRow(tester, row(lineCount: 1, images: 3));
    expect(find.byKey(const Key('order-more-lines')), findsNothing);
  });

  testWidgets('fits its 40 dp tile at 2.0x text', (tester) async {
    await pumpRow(tester, row(lineCount: 120, images: 4), scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('+116'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('order-more-lines'))),
      const Size(40, 40),
    );
  });
}

import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:customer_app/features/orders/presentation/order_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_harness.dart';

/// The reorder report's text per reason (`03 §2.10`).
void main() {
  testWidgets('a line below today\'s minimum says why it was not added', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ReorderResultDialog(
          orderLines: 2,
          result: ReorderResult(
            addedCount: 1,
            unavailable: [
              ReorderSkippedItem(
                variantId: 1501,
                productName: 'Jivo Water',
                variantName: '1 L x 12',
                reason: ReorderSkipReason.belowMinimum,
                requestedQuantity: 2,
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.text(
        "• Jivo Water (1 L x 12) wasn't added: it now has a higher minimum "
        'order quantity',
      ),
      findsOneWidget,
    );
  });
}

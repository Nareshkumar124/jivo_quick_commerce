import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app/theme.dart';
import 'package:customer_app/shared/widgets/product_image.dart';

void main() {
  Widget host(bool onWell) => MaterialApp(
    home: ProductImage(url: 'http://localhost/x.png', onWell: onWell),
  );

  testWidgets('onWell wraps the image in a multiply filter', (tester) async {
    await tester.pumpWidget(host(true));
    final filter = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(
      filter.colorFilter,
      ColorFilter.mode(const CustomerColors().imageWell, BlendMode.multiply),
    );
  });

  testWidgets('without onWell there is no filter', (tester) async {
    await tester.pumpWidget(host(false));
    expect(find.byType(ColorFiltered), findsNothing);
  });
}

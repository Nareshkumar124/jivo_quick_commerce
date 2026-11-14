import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../cart/presentation/cart_bar.dart';
import 'catalog_controllers.dart';
import 'widgets/paged_product_grid.dart';

/// Every product the store sells, as a grid. The cart's "Add more" opens it,
/// so customers land on what they can add (back returns to the cart).
class AllProductsScreen extends StatelessWidget {
  const AllProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allProducts)),
      bottomNavigationBar: const CartBar(),
      body: PagedProductGrid(
        query: const AllProductsQuery(),
        emptyMessage: l10n.productsEmpty,
      ),
    );
  }
}

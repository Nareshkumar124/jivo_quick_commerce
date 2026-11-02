import 'package:customer_app/features/catalog/domain/catalog_models.dart';

/// A variant as the API sends it: money as decimal strings, the stepper cap
/// in `orderable_quantity`, `units_left` only when LOW_STOCK.
CatalogVariant variant({
  int id = 101,
  String name = '1 L',
  String price = '249.00',
  String mrp = '299.00',
  String discountAmount = '50.00',
  int discountPercent = 16,
  StockStatus status = StockStatus.inStock,
  int orderable = 5,
  int? unitsLeft,
  int maxQty = 5,
}) => CatalogVariant(
  id: id,
  name: name,
  sellingPrice: price,
  mrp: mrp,
  discountAmount: discountAmount,
  discountPercent: discountPercent,
  stockStatus: status,
  orderableQuantity: orderable,
  unitsLeft: unitsLeft,
  maxQtyPerOrder: maxQty,
);

/// A one-variant product card.
CatalogProduct product({
  int id = 1,
  String name = 'Jivo Canola Oil',
  CatalogVariant? only,
  List<CatalogVariant>? variants,
}) {
  final all = variants ?? [only ?? variant()];
  return CatalogProduct(
    id: id,
    slug: 'jivo-canola-oil',
    name: name,
    defaultVariantId: all.first.id,
    variants: all,
  );
}

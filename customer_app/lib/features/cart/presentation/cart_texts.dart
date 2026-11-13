import 'package:flutter/widgets.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../domain/cart.dart';

/// The one place that turns the cart and checkout's server codes into text
/// (rule 4). Codes map to ARB strings filled with the server's own values
/// (`thresholds`, `orderable_quantity`, error `details`). The server's
/// English `message` is shown only for a code this build doesn't know, and
/// for an applied coupon's reason, which carries no amount to fill in.

/// The flag on a cart line ("Out of stock", "Only 2 available",
/// "Order at least 5").
String lineIssueText(AppLocalizations l10n, CartLine line) {
  final issue = line.issue!;
  return switch (issue.code) {
    CartIssueCode.outOfStock => l10n.outOfStock,
    // Fewer than the minimum can be sold: out of stock (`maxSelectable`).
    CartIssueCode.quantityUnavailable when line.orderableQuantity <= 0 =>
      l10n.outOfStock,
    CartIssueCode.quantityUnavailable => l10n.onlyAvailable(
      line.orderableQuantity,
    ),
    CartIssueCode.minQtyRequired when line.orderableQuantity <= 0 =>
      l10n.outOfStock,
    CartIssueCode.minQtyRequired => l10n.minQtyLineIssue(line.minQty),
    CartIssueCode.unknown => issue.message,
  };
}

/// The fix on a flagged line: down to `orderable_quantity`, up to the
/// minimum per order, or remove.
String lineFixText(AppLocalizations l10n, CartLine line) =>
    line.orderableQuantity <= 0
    ? l10n.removeAction
    : line.issue?.code == CartIssueCode.minQtyRequired
    ? l10n.updateQuantityTo(line.minQty)
    : l10n.updateQuantityTo(line.orderableQuantity);

/// Why checkout is disabled: the server's first blocker.
String? checkoutBlockerText(AppLocalizations l10n, CartSnapshot cart) {
  final blockers = cart.checkout.blockers;
  if (blockers.isEmpty) return null;
  final blocker = blockers.first;
  final thresholds = cart.thresholds;
  return switch (blocker.code) {
    CheckoutBlockerCode.cartEmpty => l10n.cartEmpty,
    CheckoutBlockerCode.addressRequired => l10n.chooseSavedAddress,
    CheckoutBlockerCode.notServiceable => l10n.blockerNotServiceable,
    CheckoutBlockerCode.storeClosed => l10n.cartStoreClosed,
    CheckoutBlockerCode.stockUnavailable => l10n.cartProblemsBanner,
    CheckoutBlockerCode.minQtyRequired => l10n.blockerMinQtyRequired,
    CheckoutBlockerCode.minOrderNotMet => switch (thresholds) {
      CartThresholds(:final minOrderValue, :final amountToMinOrder?) =>
        l10n.minimumOrderShortfall(
          formatRupees(minOrderValue),
          formatRupees(amountToMinOrder),
        ),
      CartThresholds(:final minOrderValue) => l10n.minimumOrderNotMet(
        formatRupees(minOrderValue),
      ),
      null => blocker.message,
    },
    CheckoutBlockerCode.minUnitsNotMet =>
      minUnitsWarning(l10n, thresholds) ??
          switch (thresholds) {
            CartThresholds(:final minOrderUnits) when minOrderUnits > 0 =>
              l10n.minimumUnitsNotMet(
                minOrderUnits,
                orderUnitLabel(l10n, thresholds),
              ),
            _ => blocker.message,
          },
    CheckoutBlockerCode.couponInvalid => l10n.blockerCouponInvalid,
    CheckoutBlockerCode.couponExpired => l10n.blockerCouponExpired,
    CheckoutBlockerCode.couponNotEligible => l10n.blockerCouponNotEligible,
    CheckoutBlockerCode.couponUsageExceeded => l10n.blockerCouponUsed,
    CheckoutBlockerCode.unknown => blocker.message,
  };
}

/// What an order unit is called: the server's `order_unit_label`
/// ("cartons"), or "items" when it sends none.
String orderUnitLabel(AppLocalizations l10n, CartThresholds? thresholds) {
  final label = thresholds?.orderUnitLabel.trim() ?? '';
  return label.isEmpty ? l10n.orderUnitsDefault : label;
}

/// "Add 2 more cartons to place your order (minimum 5 cartons)" while the
/// cart is short of the store's `min_order_units` (any mix of products);
/// null when the rule is met or off. All numbers are the server's.
String? minUnitsWarning(AppLocalizations l10n, CartThresholds? thresholds) {
  final short = thresholds?.unitsToMinOrder;
  if (thresholds == null || short == null || short <= 0) return null;
  return l10n.minimumUnitsShortfall(
    short,
    thresholds.minOrderUnits,
    orderUnitLabel(l10n, thresholds),
  );
}

/// Why a listed coupon can't be applied.
String couponIneligibleText(AppLocalizations l10n, CouponOffer offer) =>
    switch (offer.ineligibility) {
      CouponIneligibility.minOrderValue when offer.amountToUnlock != null =>
        l10n.couponAddMore(formatRupees(offer.amountToUnlock!)),
      CouponIneligibility.minOrderValue => l10n.couponBelowMinimum,
      CouponIneligibility.firstOrderOnly => l10n.couponFirstOrderOnly,
      CouponIneligibility.noEligibleItems => l10n.couponNoEligibleItems,
      CouponIneligibility.store => l10n.couponWrongStore,
      CouponIneligibility.unknown ||
      null => offer.message ?? l10n.couponNotApplicable,
    };

/// A failed cart or checkout call, with the server's `details` where they
/// say what changed (`06 §2.5`, `§2.6`); otherwise the generic message.
/// [cart] (or [names], by variant id) names the lines in stock problems.
String cartErrorText(
  BuildContext context,
  Object error, {
  CartSnapshot? cart,
  Map<int, String> names = const {},
}) {
  final l10n = AppLocalizations.of(context);
  final apiError = ApiError.from(error);
  final details = apiError.details;
  switch (apiError.code) {
    case ApiErrorCode.priceChanged:
      final before = details['expected_grand_total'];
      final after = details['grand_total'];
      if (before is String && after is String) {
        return l10n.priceChangedDetail(
          formatRupees(before),
          formatRupees(after),
        );
      }
    case ApiErrorCode.stockUnavailable:
      final lines = _stockLines(l10n, details['items'], cart, names);
      if (lines.isNotEmpty) return lines.join('\n');
    case ApiErrorCode.maxQtyExceeded:
      final max = details['max_qty_per_order'];
      if (max is num) return l10n.maxQtyReached(max.toInt());
    case ApiErrorCode.minQtyRequired:
      // Named when the line is known (checkout); otherwise jivo_core's
      // "at least N of this item" below.
      final minimum = apiError.minQtyPerOrder;
      final variantId = details['variant_id'];
      if (minimum != null && variantId is num) {
        final name = _lineName(variantId.toInt(), cart, names);
        if (name != null) return l10n.minQtyRequiredFor(minimum, name);
      }
    case ApiErrorCode.minOrderNotMet:
      final minimum = details['min_order_value'];
      final short = details['amount_to_min_order'];
      if (minimum is String && short is String) {
        return l10n.minimumOrderShortfall(
          formatRupees(minimum),
          formatRupees(short),
        );
      }
    case ApiErrorCode.minUnitsNotMet:
      final minimum = apiError.minOrderUnits;
      final short = apiError.unitsToMinOrder;
      if (minimum != null && short != null && short > 0) {
        return l10n.minimumUnitsShortfall(
          short,
          minimum,
          orderUnitLabel(l10n, cart?.thresholds),
        );
      }
    case ApiErrorCode.couponNotEligible:
      final reason = details['reason'];
      final toUnlock = details['amount_to_unlock'];
      if (reason == 'MIN_ORDER_VALUE' && toUnlock is String) {
        return l10n.couponAddMore(formatRupees(toUnlock));
      }
      if (reason == 'FIRST_ORDER_ONLY') return l10n.couponFirstOrderOnly;
      if (reason == 'NO_ELIGIBLE_ITEMS') return l10n.couponNoEligibleItems;
      if (reason == 'STORE') return l10n.couponWrongStore;
    default:
      break;
  }
  return describeErrorWithDetails(context, apiError);
}

/// `details.items[{variant_id, requested_quantity, orderable_quantity}]`
/// as one line per item (at most two, so the message stays short).
List<String> _stockLines(
  AppLocalizations l10n,
  Object? items,
  CartSnapshot? cart,
  Map<int, String> names,
) {
  if (items is! List) return const [];
  final out = <String>[];
  for (final item in items.take(2)) {
    if (item is! Map) continue;
    final variantId = item['variant_id'];
    final orderable = item['orderable_quantity'];
    if (variantId is! num || orderable is! num) continue;
    final name = _lineName(variantId.toInt(), cart, names);
    if (name == null) continue;
    out.add(
      orderable <= 0
          ? l10n.stockOutDetail(name)
          : l10n.stockOnlyDetail(orderable.toInt(), name),
    );
  }
  return out;
}

/// "Product Variant" for [variantId] from [names] or the [cart]'s line.
String? _lineName(int variantId, CartSnapshot? cart, Map<int, String> names) {
  final line = cart?.lineFor(variantId);
  return names[variantId] ??
      (line == null ? null : '${line.productName} ${line.variantName}');
}

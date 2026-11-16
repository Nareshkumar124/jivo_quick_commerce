# ADR 0001: Volume (slab) prices per variant

- **Status:** accepted (PM, 2026-11-13). Changes the bill formula in 08 §6.2.
- **Context:** the store now sells Jivo Water by the box to shopkeepers. The price per box depends on how many boxes the whole order has, any mix of sizes. Example: 1 L is ₹90 from 5 boxes, ₹87 from 25, ₹85 from 50, ₹82 from 100 and ₹80 from 250. Prices include GST.

## Decision
1. **Data.** A new table `catalog.VariantPriceTier` (`variant`, `min_order_units` ≥ 1, `price` > 0 and ≤ MRP; unique per variant and units). A variant with no tiers is priced exactly as before.
2. **One tier per order.** The tier is chosen by the **tier units**: the sum of min(quantity, orderable quantity) over every cart line whose variant has tiers. Each tiered line then takes its own variant's price at the highest tier reached. Below the lowest tier, the normal price applies (store override, else `selling_price`).
3. **A tier never raises a price.** When a store override is lower than the tier price, the override stays.
4. **One place.** The unit price is fixed in `cart.services.load_lines()` (`apply_price_tiers()`), before `compute_bill()`, which stays the only money function. The cart, checkout, coupons, fee thresholds and the minimum order value all see the same prices.
5. **Snapshot.** Order placement stores the applied unit price on the order line (`OrderItem.selling_price`). Recalculation after items are unavailable (08 §6.3) uses that snapshot and never re-tiers, so the amount payable never goes up.
6. **API.** `VariantSummary.price_tiers [{min_order_units, price}]` (the rate chart) and, on each cart line, `price_per_unit` and `price_tier`.
7. **Setup.** `manage.py set_price_tiers --file apps/catalog/data/jivo_water_price_tiers.json` (dry run by default) sets the tiers. It also sets MRP = selling price = the lowest-tier rate, so no false "% off" is shown.

## Consequences
- Above the lowest tier, the bill shows the slab saving as `product_discount` (MRP − tier price). This is a real saving, not a markup.
- Removing units after the order is placed keeps the order-time prices, even if the remaining units would fall into a dearer slab.
- Catalog list queries gain one constant prefetch query for the tiers.

## Alternatives considered
- A tier chosen per variant (each size counted alone): rejected, because the business rule counts all boxes together.
- Store-level slab tables: not needed yet. Tiers are per variant and apply at every store.

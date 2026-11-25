# ADR 0002: Flat water rates, "buy 10 get 1 free" cartons, and free-carton rewards

- **Status:** accepted (user + PM, 2026-11-25). It changes the bill and stock rules in 08 §6, the referral reward in 08 and 06, and the customer Rewards screen (03). The slab prices from ADR 0001 stop being used (the data is removed). The tier code stays, but sits unused.
- **Context:** the user's new wholesale rules for Jivo Water (2026-11-25). The answers to the open questions came from the user in chat, and are marked **(user)** below.

## Business rules
1. **Flat rates per carton, GST included** (the same basis as ADR 0001):

   | Size | Rate |
   |---|---|
   | 1 L | ₹110 |
   | 250 ml | ₹110 |
   | 500 ml | ₹140 |

   These rates apply to every order. MRP = selling price, so no false "% off" is shown. All `VariantPriceTier` rows for these variants are deleted. This is a PM data step on staging, not code.
2. **Minimum: 5 paid cartons per order.** This is already built (`PricingConfig.min_order_units = 5`, `MIN_UNITS_NOT_MET`). **Free cartons never count toward it.**
3. **Volume offer: 1 free carton for every 10 paid cartons**, so `free = paid_units // N`. N is a new per-store setting, `PricingConfig.free_unit_every`: 0 means off, and GGN-01 uses 10. `paid_units` is counted like `order_units` (each line counts min(quantity, orderable)).
   - **Which carton (user):** the **cheapest size in the order**, added automatically. Cheapest means the lowest unit price among the paid lines. On a tie, pick the size with more paid units, then the lowest variant id. (1 L and 250 ml are both ₹110.)
   - **No stock:** if that size can't supply paid + free, use the next-cheapest size in the order that can. If no size can, give no free carton. The cart then shows a notice, not a blocker.
4. **Free cartons cost ₹0.** They are not part of `item_total`, so fees, coupon minimums, COD limits and payment amounts are unchanged. The bill gets a new field, `free_items_value` (MRP × free quantity), which is added to `total_savings`. `grand_total` is unchanged. `compute_bill()` stays the only money function.
5. **Stock.** Free cartons are reserved at order placement together with the paid lines (the same transaction and `select_for_update`, variant-id order; a variant's paid and free units are reserved together). They are committed at pickup (T9) with a `StockMovement`, exactly like paid units.
6. **After ordering, free cartons are fixed.** This follows the user's ADR 0001 rule that prices never re-tier. If some paid cartons can't be supplied, the free cartons already earned stay. If a free carton itself can't be supplied, it is dropped (₹0, so there is nothing to refund).
7. **Welcome reward.** Every customer account **created from now on** gets **one** free-carton reward on its first login (the OTP login that creates the account). Accounts that already exist don't get one. This is enforced once per account in the database.
8. **Referral reward (user):** after the friend's **first delivered order**, which is the existing trigger with its existing anti-abuse and VOID rules, **both** the referrer and the friend get one free-carton reward. This replaces the ₹90 personal coupons. One referral per referred user, as today.
9. **Using a reward (user):** in Rewards, the customer taps **Use** and **picks a size**. The reward is attached to the cart as a free line of that size.
   - The order still needs **5 paid cartons**.
   - **One reward or one coupon per order:** a reward takes the order's coupon slot.
   - A reward stacks with the volume offer.
   - It expires after `ReferralSettings.reward_validity_days`, which is 30 days for both the welcome and the referral reward.
10. **Statuses:**
    - **AVAILABLE:** can be used.
    - **CLAIMED:** on an order that is placed but not yet delivered.
    - **USED:** that order was delivered.
    - **EXPIRED.**

    A cancelled or payment-failed order puts the reward back to AVAILABLE, if it hasn't expired. USED and EXPIRED rewards are hidden from the main list and shown only in the history.
11. **History:** rewards earned (welcome and referral), rewards claimed and used, and the volume-offer free cartons of each delivered order.
12. **Old ₹90 rewards (user):** the WELCOME90 coupon is switched off (a PM data step). New referral rewards are free cartons. ₹90 personal coupons already given keep working until they expire.
13. **No duplicates:**
    - one welcome reward per user (DB unique)
    - one referral per referred user (as today)
    - a reward can be used once (its usage limit is 1, checked under `select_for_update` at order placement)
    - the reward returns only through the cancel and payment-failed paths

## Design (reuse; no second rewards system)
- **A reward is a personal coupon** (`promotions.Coupon` with `owner`, from `create_personal_coupon`). It has a new `DiscountType`, **`FREE_UNIT`** (one free carton), plus a `source`: `WELCOME`, `REFERRAL_REFERRER`, `REFERRAL_REFERRED` or `NONE`.
  - The existing "My coupons" screen becomes **Rewards** in the app.
  - Redemption and history use the existing coupon redemption records, plus the order's free lines.
- **Free lines** are computed in `cart.services`, next to `load_lines()`, and are passed into `compute_bill()`. They are stored on the order as `OrderItem` rows with `is_free=True`, selling price 0, and a `free_source` of `VOLUME_OFFER` or `REWARD`. They are never priced by the app.

## API (the backend finalizes names in `openapi/schema.yaml`; the app follows the schema)
- **Cart body** (every cart response):
  - `free_lines`: a list of `{product, variant, quantity, mrp, value, source}`. `source` is `VOLUME_OFFER` or `REWARD`.
  - `free_offer`: `{every, paid_units, free_units, units_to_next_free, message, notice}`, or null when the store has no offer.
    - Example `message`: "Add 8 more cartons to get 1 more free".
    - `notice` is set when a free carton can't be supplied.
  - `bill.free_items_value`.
- **Apply a reward:** the existing apply-coupon endpoint takes `free_variant_id`, which is required for `FREE_UNIT` coupons and must be a variant sold at the cart's store. The cart's coupon body and the coupon list show `discount_type`, `source` and `free_variant_id`.
- **`GET /api/v1/account/rewards/`:**
  - `available`: AVAILABLE and CLAIMED rewards, each `{code, title, source, status, expires_at, order_number}`
  - `history`: `{at, kind, title, quantity, order_number}`, where `kind` is `EARNED`, `CLAIMED`, `USED`, `EXPIRED` or `VOLUME_FREE`
- **Orders:** order detail and invoices show the free lines at ₹0, plus `free_items_value`.
- **Referral summary:** says the reward is "1 free carton" for both people, using a reward-type flag. It no longer shows a ₹ amount.

## Open item
- **Possibility:** GST treatment of free cartons on the invoice (shown at ₹0). Jivo's accountant should confirm this before launch.

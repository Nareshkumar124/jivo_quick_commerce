# ADR 0003: Every free carton is 1 L; welcome and referral rewards give 2 cartons

- **Status:** accepted (user, 2026-11-26). It amends ADR 0002. Everything in 0002 that this file does not change still holds.
- **Context:** the user changed two rules after using the 0002 build on the test server.

## Decisions (user)
1. **Every free carton is the 1 L carton.** This applies to both kinds of free carton:
   - the volume offer (1 free per 10 paid)
   - rewards (welcome and referral)

   The paid sizes in the order don't matter. Example: 10 paid cartons of 250 ml or 500 ml give 1 free **1 L** carton.
   - The free size is a store setting, `PricingConfig.free_unit_variant`. It is a nullable FK to `catalog.ProductVariant`; GGN-01 points it at the 1 L × 12 variant (id 328 on staging).
   - When it is set, it replaces the 0002 "cheapest size, tie-break, stock fallback" rule and the customer's size choice. When it is null, the 0002 rule stays (a backward-compatible default).
   - **No stock** for the fixed size: no free carton. The cart shows the `free_offer.notice` (never a blocker), the same as 0002 §3.
   - **Rewards with a fixed size:** the customer doesn't pick a size. `POST /cart/coupon/` accepts the reward **without** `free_variant_id`, and the server uses the store's free variant. If a client sends a different variant id, the server returns 422 `COUPON_NOT_ELIGIBLE`, reason `FREE_VARIANT_UNAVAILABLE`. The 0002 "same category as a paid line" check doesn't apply to the fixed variant.
2. **A reward can be more than 1 carton.**
   - A FREE_UNIT coupon's `value` is the **number of free cartons**: a whole number ≥ 1. This replaces the `coupon_free_unit_is_one` check with a "whole number from 1 to 10" check.
   - The reward's free line has quantity = `value`, reserved and committed like the other free units.
3. **Quantities are settings:** `ReferralSettings.welcome_reward_quantity` (default 1) and `ReferralSettings.reward_quantity` for the referral reward, for each person (default 1). Staging sets **both to 2**. New rewards use the setting at the moment they are created; rewards given earlier keep their own quantity.
4. **Nothing else changes:** 1 free per 10 paid; free cartons outside `item_total`; the 5-paid-carton minimum; the statuses; one reward per order; free cartons fixed after ordering.

## API changes (additive; the backend finalizes the names in the schema)
- **Cart `free_offer`:** adds `free_variant`, `{id, name, product_name}` or null.
- **CouponOffer and cart `coupon`:** add `free_quantity` (int; null for non-FREE_UNIT). `free_variant_id` is pre-filled with the store's fixed free variant when one is set.
- **`POST /cart/coupon/`:** `free_variant_id` becomes optional when the store has a fixed free variant.
- **`GET /account/rewards/` `available[]`:** adds `quantity` (int) and `free_variant` (`{id, name, product_name}` or null).
- **`GET /account/referral/`:** `reward_quantity` comes from the setting (2), and `reward_label` reads "2 free cartons". Also add `welcome_reward_quantity` if it is easy.

## App
- **Rewards:** show "2 free cartons · 1 L × 12" from `quantity` and `free_variant`. **Use** applies the reward directly with no size sheet when the server gives a fixed free variant; the size sheet remains only as a fallback for a null free variant.
- **Referral copy:** use the server's `reward_quantity`: "You and your friend each get 2 free cartons".
- The cart already renders the server's `free_lines` and their quantities.

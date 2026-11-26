# ADR 0004: Admin management of bottle prices, offers and delivery pincodes

- **Status:** accepted (user, 2026-11-26). It builds on ADRs 0002 and 0003.
- **Context:** the user wants authorized staff to change prices, offers and delivery areas from the admin panel, with no code changes. Delivery starts with pincode **110027** (Delhi) only.
- **Who can edit (user):** **Super Admin only** (and Django superusers). Every other role can, at most, view these pages per the 05 §3 matrix; it is never allowed to change them. Each section gets its own permission, granted only to the Super Admin group in `accounts.roles.sync_roles()`: `catalog.manage_prices`, `promotions.manage_offers` and `stores.manage_delivery_pincodes`.

## 1. Delivery locations (pincodes)
- **New model `stores.DeliveryPincode`:**
  - `store` (FK DarkStore)
  - `pincode` (6 digits, `pincode_validator`)
  - `area_name` (an optional label, e.g. "Rajouri Garden")
  - `is_active`
  - timestamps
  - unique (store, pincode)

  It **replaces** the `DarkStore.serviceable_pincodes` list from the unmerged pincode branch. That list field is dropped before merge; it never reached main.
- **Pincode mode.** A store with **any** DeliveryPincode rows is in pincode mode. A store with no rows keeps today's polygon-only behaviour.
- **Address check** (`cart.services.serves()`, the single gate for the cart blocker, the cart address and placement): in pincode mode, the address pincode (stripped) must be an **active** pincode of that store.
- **Location check** (`check_serviceability(lat, lng)`, before any address exists). In pincode mode, the point must fall inside the outline of one of the store's **active** pincodes. The outline is buffered by 250 m, because pincode boundaries are approximate. The address check above stays the exact rule. The `service_area` polygon is not used in pincode mode.
- **Outlines:**
  - **New model `stores.PincodeBoundary`:** `pincode` (unique), `geom` (MultiPolygon, 4326), `source`.
  - **`manage.py import_pincode_boundaries --file <geojson>`:** a dry run by default; `--commit` saves. It is idempotent.
  - **Data file:** `backend/apps/stores/data/pincodes_delhi.geojson` covers **all Delhi pincodes**. It merges the Department of Posts "All India Pincode Boundary" (data.gov.in, GODL-India) and the GSDL pincode polygons (mirror: github.com/ramSeraph/indian_admin_boundaries, release `postal`), simplified to a small file. Record the sources and license in a README next to it.
  - A pincode with no outline can still be added. The admin page then warns: "No map outline for this pincode. Customers are checked by their address pincode only."
- **Customer message** when not served: "We don't deliver here yet. We deliver in <active pincodes or area names, at most 3, then 'and more'>. We'll come to your area soon." It is built in one place and used by both checks.
- **Cache:** the serviceability snapshot includes each store's active pincodes and their buffered outlines, and it bumps on any DeliveryPincode change. A newly activated pincode works at once.
- **Services** (the admin calls only these; each writes an `AuditLog` entry): `add_delivery_pincode`, `update_delivery_pincode` and `set_delivery_pincode_active`, with validation (format, duplicates, the store exists).
- **Staging setup** (PM data step): GGN-01 gets one active pincode, 110027 ("Rajouri Garden / Tagore Garden / Subhash Nagar").

## 2. Bottle prices
- **Service `catalog.services.set_variant_price(variant, price, actor)`:**
  - Sets **MRP = selling price = price**. This is the user's rule since ADR 0001: no false "% off".
  - Validates that the price is > 0 and ≤ ₹10,000, with 2 decimals.
  - Refuses a price on a variant that still has `VariantPriceTier` rows. The admin must remove those first, so there are no conflicting prices.
  - Writes an `AuditLog` entry with the old and new price, and saves through the model so the catalog cache is invalidated.
- **Consistency:**
  - Carts and checkout read the live price, so they change at once.
  - **Placed orders keep their price snapshot**, as today. Doc 08 §6: nothing re-prices an order.
  - A store `price_override`, if set, still wins at that store. The page shows it.

## 3. Offers
These are the existing models; nothing new is stored:
- the **volume offer** per store: `PricingConfig.free_unit_every` (0 = off) and `free_unit_variant`
- **rewards:** `ReferralSettings.is_enabled`, `welcome_reward_quantity` and `reward_quantity`
- **public coupons:** `promotions.Coupon` with `owner=NULL`, to create, edit, enable/disable and set the end date

Services that the admin calls, each with an `AuditLog` entry:
- `set_volume_offer`
- `set_reward_quantities`
- create, update and set-active functions for public coupons, reusing the existing coupon validation

Rules:
- Value > 0.
- PERCENT ≤ 100.
- `ends_at` after `starts_at`.
- A unique active code.
- FREE_UNIT can't be a public coupon (ADR 0002).

A disabled or expired coupon is already hidden and refused by the existing coupon checks. Keep that, and test it.

## 4. Admin UI (admin-panel-dev)
Add a new sidebar group **"Store management"** with three pages. They are visible only to holders of the permissions above:
1. **Bottle prices:** a table of the sellable variants, showing the product, size, current price and any store override. Edit a price, then a confirm dialog shows old → new, then Save, then a success or error message.
2. **Offers:** three cards:
   - Buy-N-get-1 (on/off, N, free size)
   - Rewards (welcome and referral quantities, referral on/off)
   - Coupons (a list with an Enable/Disable toggle, Edit and Add)
   Every change shows a confirm dialog and a message.
3. **Delivery locations:** the pincodes per store, each showing its active state, area name and "has outline" yes/no. Add, Edit and Activate/Deactivate, each with a confirm dialog. Show a warning when an active pincode has no outline.

Plain words throughout, for staff with no technical background.

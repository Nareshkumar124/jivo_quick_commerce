# 01: Project Overview

## 1. Vision

Deliver Jivo Wellness products (edible oils, wellness beverages and the rest of the Jivo range) to customers' doors in **10–30 minutes**. Orders are fulfilled from **dark stores**, small warehouses placed close to customers, and delivered by Jivo's own rider fleet.

The experience should match leading quick-commerce apps (Blinkit, Zepto, Swiggy Instamart): instant serviceability check, fast browsing, one-tap reorder, live rider tracking, and reliable payments.

## 2. What makes this different from Blinkit

| Aspect | Blinkit | Jivo Quick Commerce |
|--------|---------|---------------------|
| Catalog | Multi-brand, ~10k+ SKUs | **Single brand (Jivo)**, small catalog (tens to low hundreds of SKUs) |
| Sellers | Many sellers/brands | **Jivo is the only seller**. No vendor or marketplace module. |
| Fleet | Large gig fleet | Smaller fleet attached to each dark store. Riders are employees or contracted partners (see [11-open-decisions.md](11-open-decisions.md)) |
| Focus | Assortment breadth | Brand experience, freshness, wellness content, repeat purchase |

Because there is no marketplace, the design leaves out seller onboarding, commissions and settlement. The product catalog is managed centrally, and stock is managed per dark store.

## 3. Scope

### 3.1 In scope for v1 (launch)

**Customer app**
- Phone + OTP login, profile, multiple saved addresses with map pin
- Location-based serviceability check and store assignment
- Home (banners, categories, collections), category listing, product detail, search
- Cart with live stock checks, bill breakdown, coupons, rider tip, delivery instructions
- Payments: Razorpay (UPI, cards, net banking, wallets) and Cash on Delivery
- Order placement, live order tracking on a map, order history, reorder, cancellation, GST invoice download
- Push notifications, ratings, help and support tickets, account deletion

**Rider app**
- Phone + OTP login, onboarding with KYC documents, admin approval
- Online/offline (shift) toggle, background location sharing
- Order offers with accept/reject, pickup at store, navigation, delivery OTP verification
- COD cash collection, cash-in-hand tracking and deposits
- Earnings, delivery history, support

**Backend + Admin/Ops panel (Django)**
- REST API for both apps, WebSockets for real-time updates
- Master data: catalog, dark stores with geofenced service areas, inventory per store
- Order management, store pick/pack console, rider dispatch (automatic + manual), rider live map
- Promotions (coupons, banners, collections), pricing and fee configuration
- Payments, refunds, reconciliation, GST invoices
- Dashboard, reports, support tickets, CMS pages, app configuration (force update, maintenance mode)
- Role-based access for Jivo staff, plus an audit log

### 3.2 Out of scope for v1 (candidates for v2)
- Scheduled / slot-based delivery
- Subscriptions (e.g., monthly oil refills)
- Wallet, cashback, referral program, loyalty points
- Order batching (one rider carrying several orders)
- Masked calling between rider and customer
- In-app chat support (v1 uses tickets + call)
- Multi-language UI (v1 is English. Hindi is a v2 candidate.)
- Web storefront for customers
- Two-way SAP integration (v1 may use CSV import/export; see open decisions)

## 4. User roles

| Role | Uses | Description |
|------|------|-------------|
| **Customer** | Customer app | Browses, orders, pays and tracks deliveries |
| **Rider** | Rider app | Picks up packed orders from a dark store and delivers them |
| **Store Staff** (picker/packer) | Ops panel: Store Console | Accepts incoming orders for *their* store, picks and packs items, hands orders to riders |
| **Store Manager** | Ops panel | Everything Store Staff can do, plus inventory adjustments, rider cash deposits, store open/close for *their* store |
| **Catalog Manager** | Admin panel | Manages categories, products, variants, images, collections, banners |
| **Operations / Dispatch** | Ops panel | Watches the live order board across stores, assigns riders manually, handles escalations and cancellations |
| **Support Agent** | Admin panel | Handles tickets, views orders and customers, can trigger refunds within limits |
| **Finance** | Admin panel | Payments, refunds, reconciliation, GST reports, rider payouts |
| **Super Admin** | Everything | Full access, user and role management, system configuration |

The full permission matrix is in [05-admin-and-store-panel.md](05-admin-and-store-panel.md#3-roles--permissions).

## 5. Key business rules (v1 defaults; all configurable)

| Rule | Default | Where configured |
|------|---------|------------------|
| Minimum order value | ₹99 | Per store pricing config |
| Delivery fee | ₹25, free above ₹299 | Per store pricing config |
| Small-cart fee | ₹15 below ₹149 | Per store pricing config |
| Handling fee | ₹0 | Per store pricing config |
| COD | Enabled, max order value ₹2,000 | Per store pricing config |
| Max quantity per SKU per order | 5 | Per variant |
| Online payment window | 15 minutes, then the order auto-fails and stock is released | Global setting |
| Customer self-cancellation | Allowed until the store starts packing | Global setting |
| Rider offer timeout | 30 seconds | Global setting |
| Rider COD cash-in-hand limit | ₹5,000 | Per rider (default global) |
| Delivery OTP | 4 digits, required for every delivery | Global setting |

These values are placeholders until Jivo confirms them (see [11-open-decisions.md](11-open-decisions.md)).

## 6. Assumptions

1. Jivo will operate one or more dark stores, each with a defined delivery area (a polygon drawn on a map).
2. Product prices are **GST-inclusive** (MRP-style retail pricing). GST is broken out on the invoice.
3. A customer's cart and order belong to exactly **one** dark store, the one serving their delivery address.
4. Each rider belongs to one home dark store at a time.
5. Android is the priority platform for both apps. The customer app also ships on iOS. The rider app is Android-only in v1 unless Jivo decides otherwise.
6. Jivo provides brand assets (logo, colors, fonts, product photos and descriptions) and owns all third-party accounts (Razorpay, SMS provider, Google Cloud/Firebase, Play Console, Apple Developer).

## 7. Success metrics (to track after launch)

| Metric | Target (initial) |
|--------|------------------|
| Median order-to-delivery time | ≤ 20 minutes |
| Order acceptance by store | ≤ 60 seconds from placement |
| Rider assignment | ≤ 2 minutes from acceptance |
| Payment success rate | ≥ 95% of online attempts |
| Order cancellation rate (store/rider-caused) | < 2% |
| App crash-free sessions | ≥ 99.5% |
| Repeat purchase within 30 days | Tracked; target to be set by Jivo |

## 8. Glossary

| Term | Meaning |
|------|---------|
| **Dark store** | A small, customer-free warehouse used only to fulfil online orders |
| **Service area / geofence** | The polygon on the map that a dark store delivers to |
| **Serviceability** | Whether a given location falls inside an active store's service area while that store is open |
| **SKU / Variant** | A specific sellable unit, e.g., "Jivo Canola Oil, 1 L". A *product* can have several variants. |
| **On hand** | Physical units in a store |
| **Reserved** | Units held for orders that are placed but not yet picked up |
| **Available** | `on_hand − reserved`, which is what customers can buy |
| **Pick / Pack** | Store staff collect the items (pick) and bag and seal them (pack) |
| **Dispatch** | Finding and assigning a rider to an order |
| **Offer** | A time-limited request to a rider to take an order |
| **Delivery OTP** | A code shown to the customer that the rider must enter to complete delivery |
| **COD** | Cash on Delivery |
| **Cash in hand** | COD cash a rider has collected but not yet deposited |
| **RTO / Return** | A failed delivery whose items go back to the store |
| **AOV / GMV** | Average Order Value / Gross Merchandise Value |
| **ETA** | Estimated time of arrival shown to the customer |
| **DLT** | TRAI's Distributed Ledger registration, required in India to send transactional SMS such as OTPs |
| **HSN / SAC** | Tax classification codes printed on GST invoices for goods / services |

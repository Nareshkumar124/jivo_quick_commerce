# 11: Open Decisions & Long-lead Items

Each decision has a **recommended default** so work can continue. When Jivo confirms or changes one, update the Status column and the affected docs.
Status: 🟡 open · 🟢 decided · 🔵 using default (not yet confirmed)

## 1. Decisions

| ID | Decision | Recommended default | Needed by | Owner | Status |
|----|----------|---------------------|-----------|-------|--------|
| D-01 | Payment gateway | **Razorpay** (UPI intent, cards, netbanking, wallets, refunds API, QR for COD-UPI, Flutter SDK) | Phase 3 | Jivo Finance | 🟡 |
| D-02 | SMS / OTP provider | **MSG91**, or Jivo's existing provider if it has one. Must support DLT templates. | Phase 1 | Jivo IT | 🟡 |
| D-03 | Maps provider | **Google Maps Platform** (Maps SDK, Places autocomplete, Geocoding). Alternatives for cost: Ola Maps, Mappls (MapmyIndia). Needs a billing account and restricted API keys. | Phase 2 | Jivo IT | 🟡 |
| D-04 | Staff login for the web panel | Use **Jivo Auth (auth.jivo.in)** for staff/admin SSO if it is the company standard. Customers and riders stay on phone OTP. Until integrated, staff use Django's built-in login. The `User.auth_id` column is reserved so the switch needs no data remodel. | Phase 1 (decide), integrate by Phase 7 | Jivo IT | 🟡 |
| D-05 | Hosting | **AWS ap-south-1 (Mumbai)**: ECS/EC2 + RDS PostgreSQL (PostGIS) + ElastiCache Redis + S3 + CloudFront. Or Jivo's existing cloud/servers. | Phase 0 (staging), Phase 8 (prod) | Jivo IT | 🟡 |
| D-06 | App names, package IDs, branding | Customer: "Jivo" / `in.jivo.quick`. Rider: "Jivo Rider" / `in.jivo.rider`. Domain e.g. `api.<jivo-domain>`. Brand kit (logo, colours, fonts) from Jivo marketing. | Phase 0 (IDs), Phase 2 (brand UI) | Jivo Marketing | 🟡 |
| D-07 | Rider app on iOS? | **Android only** for v1 (most riders use Android; halves rider QA). | Phase 5 | Jivo Ops | 🔵 |
| D-08 | Launch footprint | One city, **1–2 dark stores** for launch. Need addresses, coordinates, delivery polygons, opening hours. | Phase 2 | Jivo Ops | 🟡 |
| D-09 | Business rule values | As in [01 §5](01-project-overview.md#5-key-business-rules-v1-defaults-all-configurable). Fee thresholds compare against the item total *before* the coupon. | Phase 3 | Jivo Business | 🔵 |
| D-10 | Refund policy for failed deliveries & cancellations | As in [08 §6.4](08-order-lifecycle.md#64-refund-policy-defaults-to-be-confirmed-in-d-10) | Phase 4 | Jivo Business + Legal | 🔵 |
| D-11 | Store developer accounts | Jivo owns a **Google Play Console** and an **Apple Developer** (organisation) account. Requires a D-U-N-S number for Apple. Background-location declaration for the rider app. | Play: Phase 5 · Apple: Phase 6 | Jivo IT | 🟡 |
| D-12 | GST details | GSTIN per store state, HSN + GST rate per product, GST on delivery/handling fees (SAC), treatment of rider tips, whether e-invoicing (IRN) applies to B2C invoices, invoice series format | Phase 4 | Jivo Finance | 🟡 |
| D-13 | Flutter API client | **Generate** the Dart client (`packages/jivo_api`) from the OpenAPI schema with openapi-generator 7.26.0 `dart-dio` (json_serializable), via `packages/tool/generate_api.sh`. Hand-write only if the generated code proves unsuitable. | Phase 0 | Tech lead | 🟢 |
| D-14 | Rider KYC policy | Required: photo, Aadhaar (masked), PAN; DL + RC for motorised vehicles. Store masked numbers only. Delete documents 1 year after offboarding. Background verification is an offline process (out of system scope). | Phase 5 | Jivo HR / Ops | 🟡 |
| D-15 | Test & reviewer accounts | Fixed-OTP test phone numbers on staging. In production, a single allow-listed reviewer number per store (Google/Apple review) that can only see a sandbox store. | Phase 1 (staging), Phase 8 (prod) | Tech lead | 🔵 |
| D-16 | Rider engagement & pay | In-house or contracted riders, per-order base pay + distance pay + tips pass-through + incentives; weekly payouts done offline (bank transfer) and recorded in the panel | Phase 5 | Jivo Ops / HR | 🟡 |
| D-17 | **SAP integration** | v1: catalog (item codes, MRP) and stock inward via **CSV import/export** from Jivo's SAP. Daily sales export to SAP as CSV. v2: API-based sync (item master → catalog, sales orders/invoices → SAP). The `sap_item_code` field is reserved on variants. | Phase 2 (CSV format) | Jivo IT / SAP team | 🟡 |
| D-18 | Code hosting & CI | **GitHub** + GitHub Actions (or Jivo's GitLab/Bitbucket) | Phase 0 | Tech lead | 🟡 |
| D-19 | Push, crash & analytics | Firebase (FCM + Analytics) + Sentry (backend and apps) | Phase 0 (projects), Phase 5 (FCM) | Tech lead | 🔵 |
| D-20 | Customer support contacts | Support phone, email, hours; grievance officer name and contact (legal requirement) | Phase 7 | Jivo CX / Legal | 🟡 |
| D-21 | Product content | Product list, variants, MRPs, descriptions, label data (ingredients, nutrition, FSSAI), and **photos** on a white background (min 1000×1000) | Phase 2 | Jivo Catalog / Marketing | 🟡 |
| D-22 | Store hardware | Per store: a tablet or PC with Chrome for the packing console, speakers, a thermal label printer (for pickup code / QR on bags), stable internet | Phase 4 (pilot) | Jivo Ops | 🟡 |
| D-23 | Admin panel theme | **django-unfold** for Django Admin. Ops Console with HTMX + Alpine.js, styled to match. | Phase 0 | Tech lead | 🔵 |
| D-24 | Hindi / regional languages | English only in v1, with all strings externalised for later localisation | n/a | Jivo Marketing | 🔵 |

## 2. Long-lead items (start immediately; Jivo-owned)

These take days to weeks of external processing. If they are late, they block phases even when the code is ready.

| Item | Why | Typical lead time | Must be ready by |
|------|-----|-------------------|------------------|
| **TRAI DLT registration** (entity, sender ID header, OTP + order-update templates) via the chosen SMS provider | No OTP SMS can be delivered without it | 1–3 weeks | Phase 1 staging test (test numbers may use fixed OTP meanwhile); **mandatory for Phase 8** |
| **Razorpay account + KYC** (test keys immediately, live keys after KYC) | Payments | Test: same day; Live: 1–2 weeks | Test keys: Phase 3; Live: Phase 8 |
| **Google Play Console** (organisation account, verification) | Internal testing builds, rider background location review | 2–7 days, plus review time | Phase 5 |
| **Apple Developer Program** (organisation, D-U-N-S) | TestFlight and App Store | 1–3 weeks | Phase 6 |
| **Google Cloud billing + Maps API keys**, Firebase projects (dev/staging/prod) | Maps, geocoding, push | 1–2 days | Phase 2 (maps), Phase 5 (FCM) |
| **Domain + DNS** for API/admin (e.g., `api.`, `ops.`) and TLS | Staging and prod URLs | 1–2 days | Phase 0 (staging) |
| **GST/FSSAI data** (GSTINs, HSN, rates, licence numbers) | Invoices and product compliance info | Internal | Phase 2 (product data), Phase 4 (invoices) |
| **Product catalog + photos** | Nothing to sell without it | 1–3 weeks of content work | Phase 2 (sample of ~20), Phase 7 (full) |
| **Dark store setup** (location, polygon, hardware, staff) | Pilot | Weeks | Phase 8 pilot |
| **Riders recruited** for the pilot (3–5) | Pilot and UAT | Weeks | Phase 8 |
| **Legal pages** (Terms, Privacy, Refund policy, grievance officer) | Store listing and compliance | 1–2 weeks of legal review | Phase 7 |

## 3. Decision log

| Date | ID | Decision | Decided by |
|------|----|----------|-----------|
| | | | |

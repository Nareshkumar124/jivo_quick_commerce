# shop.jivo.in import: stage 1 report (2026-11-09)

Stage 1 is preparation only. Nothing was loaded into any database or server. Source: https://shop.jivo.in (WordPress + WooCommerce, not Shopify). Read through the public WooCommerce Store API (`/wp-json/wc/store/v1/products`, one request per product/variation, 1.2 s delay, normal browser User-Agent) plus the shop pages for products the list endpoint hides. Raw dumps and images are in the gitignored `data/incoming/shop_jivo_in/`. Rebuild with `data/tools/scrape_shop_jivo_in.py`, `build_shop_jivo_in.py`, `postprocess_manifest.py`, then `validate_catalog.py`.

## 1. Counts

| Item | Count |
|---|---|
| Products found on the site (parents) | 22 |
| Products in the import files | 12 (all Jivo edible oils) |
| Variants in `variants.csv` | 34 (22 active single packs, 12 inactive multi-pack bundles) |
| Products not imported | 10 (section 6) |
| Image rows in the manifest | 223 (72 product-level, 151 variant-level) |
| Unique image files downloaded | 178 (21 duplicates by hash skipped), 161 MB |
| Images over 5 MB | 2 (originals kept, section 7) |
| Images below 1000 px | 6 (coconut oil and one yellow mustard back label, 679 px) |

## 2. Category mapping

The site has Super Oils, Super Juice, Super Food, Special Offers and Uncategorized (flat). We map to our two-level tree and reuse existing slugs; no new categories are needed for the oils.

| Site category / product type | Our category slug |
|---|---|
| Super Oils: Cold Pressed Canola | `canola-oil` (under `edible-oils`) |
| Super Oils: Pomace, Extra Light, Extra Virgin olive | `olive-oil` |
| Super Oils: Kachi Ghani and Yellow Mustard | `mustard-oil` |
| Super Oils: Groundnut, Sunflower, Soyabean, Rice Bran, Gold Refined, Extra Virgin Coconut | `other-oils` ("Groundnut, Sunflower & More") |
| Super Juice (wheatgrass packs) | `health-juices` under `wellness-beverages` (blocked: no prices) |
| Super Food | no products of its own (its count of 3 is the combos) |
| Special Offers | combos, not imported |

`categories.csv` holds the 5 oil categories with the seed's values, so the import matches the existing rows instead of duplicating them.

## 3. Price table (MRP = site regular price, selling = site sale price, copied unchanged)

| SKU (proposed) | Product | Pack | MRP | Selling | Discount | Active |
|---|---|---|---|---|---|---|
| JVW-GNT-1L | Jivo Cold Pressed Groundnut Oil | 1 L | 560.00 | 210.00 | 62% | yes |
| JVW-GNT-5L | Jivo Cold Pressed Groundnut Oil | 5 L | 2800.00 | 1040.00 | 63% | yes |
| JVW-GNT-2X1L | Jivo Cold Pressed Groundnut Oil | 2 x 1 L | 800.00 | 420.00 | 48% | no (bundle) |
| JVW-GNT-5P1L | Jivo Cold Pressed Groundnut Oil | 5 L + 1 L | 3360.00 | 1230.00 | 63% | no (bundle) |
| JVW-KGM-1L | Jivo Kachi Ghani Mustard Oil | 1 L | 255.00 | 180.00 | 29% | yes |
| JVW-KGM-5L | Jivo Kachi Ghani Mustard Oil | 5 L | 1250.00 | 900.00 | 28% | yes |
| JVW-SOY-1L | Jivo Soyabean Oil | 1 L | 225.00 | 175.00 | 22% | yes |
| JVW-SOY-5L | Jivo Soyabean Oil | 5 L | 1100.00 | 875.00 | 20% | yes |
| JVW-SUN-1L | Jivo Cold Pressed Sunflower Oil | 1 L | 275.00 | 190.00 | 31% | yes |
| JVW-SUN-5L | Jivo Cold Pressed Sunflower Oil | 5 L | 1350.00 | 950.00 | 30% | yes |
| JVW-CAN-1L | Jivo Cold Pressed Canola Oil | 1 L | 375.00 | 220.00 | 41% | yes |
| JVW-CAN-5L | Jivo Cold Pressed Canola Oil | 5 L | 1650.00 | 1099.00 | 33% | yes |
| JVW-CAN-2X1L | Jivo Cold Pressed Canola Oil | 2 x 1 L | 750.00 | 440.00 | 41% | no (bundle) |
| JVW-CAN-5X1L | Jivo Cold Pressed Canola Oil | 5 x 1 L | 1875.00 | 1099.00 | 41% | no (bundle) |
| JVW-CAN-5P1L | Jivo Cold Pressed Canola Oil | 5 L + 1 L | 2025.00 | 1299.00 | 36% | no (bundle) |
| JVW-CAN-2X5L | Jivo Cold Pressed Canola Oil | 2 x 5 L | 3300.00 | 2199.00 | 33% | no (bundle) |
| JVW-POM-1L | Jivo Pomace Olive Oil | 1 L | 1049.00 | 399.00 | 62% | yes |
| JVW-POM-5L | Jivo Pomace Olive Oil | 5 L | 4999.00 | 1995.00 | 60% | yes |
| JVW-YMU-1L | Jivo Yellow Mustard Oil | 1 L | 375.00 | 259.00 | 31% | yes |
| JVW-YMU-2X1L | Jivo Yellow Mustard Oil | 2 x 1 L | 790.00 | 469.00 | 41% | no (bundle) |
| JVW-XLO-1L | Jivo Extra Light Olive Oil | 1 L | 1499.00 | 500.00 | 67% | yes |
| JVW-XLO-5L | Jivo Extra Light Olive Oil | 5 L | 6499.00 | 2500.00 | 62% | yes |
| JVW-XLO-2X1L | Jivo Extra Light Olive Oil | 2 x 1 L | 2998.00 | 1000.00 | 67% | no (bundle) |
| JVW-XLO-5P1L | Jivo Extra Light Olive Oil | 5 L + 1 L | 7998.00 | 2969.00 | 63% | no (bundle) |
| JVW-EVO-1L | Jivo Extra Virgin Olive Oil | 1 L | 1799.00 | 725.00 | 60% | yes |
| JVW-EVO-2L | Jivo Extra Virgin Olive Oil | 2 L | 2700.00 | 1450.00 | 46% | yes |
| JVW-EVO-5L | Jivo Extra Virgin Olive Oil | 5 L | 7999.00 | 3625.00 | 55% | yes |
| JVW-EVO-2X1L | Jivo Extra Virgin Olive Oil | 2 x 1 L | 2998.00 | 1450.00 | 52% | no (bundle) |
| JVW-EVO-5X1L | Jivo Extra Virgin Olive Oil | 5 x 1 L | 8995.00 | 3625.00 | 60% | no (bundle) |
| JVW-RBO-1L | Jivo Rice Bran Oil | 1 L | 285.00 | 189.00 | 34% | yes |
| JVW-RBO-5L | Jivo Rice Bran Oil | 5 L | 1425.00 | 949.00 | 33% | yes |
| JVW-GLD-1L | Jivo Gold Refined Oil | 1 L | 225.00 | 167.00 | 26% | yes |
| JVW-GLD-5L | Jivo Gold Refined Oil | 5 L | 1050.00 | 815.00 | 22% | yes |
| JVW-COC-500 | Jivo Extra Virgin Coconut Oil | 500 ml | 399.00 | 269.00 | 33% | yes |

13 variants have a discount above 50%, none above 70% (list in `data/reports/2026-11-09-validation.md`). The extreme ones are olive oils and groundnut: Extra Light 1 L 1499 to 500 (67%), Pomace 1 L 1049 to 399 (62%), Groundnut 1 L 560 to 210 (63%), Extra Virgin 1 L 1799 to 725 (60%). The site "regular price" looks like a compare-at price and may not be the MRP printed on the pack. Legal Metrology needs the printed MRP, so Jivo must confirm it.

## 4. Comparison with the demo catalog (`backend/apps/catalog/seed.py`)

Slugs differ on four products (site: `jivo-cold-press-canola-oil`, `jivo-cold-press-groundnut-oil`, `jivo-cold-press-sunflower-oil`, `jivo-first-pressed-yellow-mustard-oil`) and all SKUs differ (`JVW-...` vs `JV-...`), so an import adds new rows next to the demo rows and overwrites nothing.

| Demo SKU | Pack | Demo MRP / price | Site MRP / price | Verdict |
|---|---|---|---|---|
| JV-CAN-CP-1L | 1 L | 349 / 279 | 375 / 220 | match, prices differ |
| JV-CAN-CP-2L | 2 L | 680 / 549 | none (only a 2 x 1 L bundle, 750 / 440) | demo only |
| JV-CAN-CP-5L | 5 L | 1650 / 1299 | 1650 / 1099 | match, selling differs |
| JV-OLV-POM-1L, 5L | 1 L, 5 L | 899/699, 3999/2999 | 1049/399, 4999/1995 | match, prices differ a lot |
| JV-OLV-XL-1L | 1 L | 999 / 799 | 1499 / 500 | match, prices differ a lot |
| JV-OLV-EV-500 | 500 ml | 799 / 649 | none (site: 1 L, 2 L, 5 L) | pack only in demo |
| JV-MUS-KG-1L, 5L | 1 L, 5 L | 210/189, 1000/899 | 255/180, 1250/900 | match |
| JV-MUS-YL-1L | 1 L | 230 / 199 | 375 / 259 | match, prices differ |
| JV-GNT-1L | 1 L | 280 / 249 | 560 / 210 | match, MRP doubled |
| JV-SUN-1L | 1 L | 190 / 165 | 275 / 190 | match |
| JV-RBO-1L | 1 L | 200 / 179 | 285 / 189 | match |

- New on the site: Soyabean Oil, Gold Refined Oil, Extra Virgin Coconut Oil, plus 5 L, 2 L and multi-pack sizes of several oils.
- Demo only: Refined Canola Oil, the four juices (wheatgrass, aloe, amla, karela-jamun), wheatgrass powder and tablets, chia, flax, quinoa, pumpkin seeds. The site sells only Jivo oils, plus out-of-stock wheatgrass juice packs.
- The demo label data (FSSAI number, HSN, GST, shelf life) is placeholder and was not copied.

## 5. Missing fields ("needs Jivo input")

| Field | Missing | Note |
|---|---|---|
| `gst_rate` | 12 of 12 | **Import blocker**: the model requires 0 to 28. D-12 is open. |
| `hsn_code` | 12 of 12 | optional for import, needed for invoices |
| `fssai_license_no` | 12 of 12 | never invented |
| `manufacturer`, `marketer`, `consumer_care` | 12 of 12 | |
| `shelf_life`, `storage_instructions`, `nutrition` | 12 of 12 | the pomace text mentions 24 months and storage inside the description; not extracted |
| `ingredients` | 11 of 12 | only Gold Refined filled, from the site text (80% rice bran, 20% sunflower) |
| `country_of_origin` | 7 of 12 | filled where the site states it: EVOO and Pomace Spain; Soyabean, Sunflower and Coconut India |
| `is_veg` | 4 of 12 | the site says "Vegetarian" for 8; the other 4 import with the model default (veg) |
| `sap_item_code`, `barcode`, `weight_grams` | 34 variants | site SKUs are per product (e.g. JSOCN-20228 for every canola size), so they cannot be variant keys |

Other notes:
- Proposed SKUs `JVW-<product>-<size>` are placeholders until Jivo gives SAP codes.
- Multi-pack bundles ("1+1", "5+1", "5+5") are imported inactive with net quantity such as "2 x 1 L" or "5 L + 1 L". The groundnut label "5+1" is read as 5 L + 1 L (assumption).
- `max_qty_per_order` is 5 everywhere.
- Descriptions are the site text as plain text; `short_description` is the first sentences up to 300 characters.
- Two names were normalised for casing (Cold-Pressed to Cold Pressed, JIVO to Jivo).

## 6. Not imported (and why)

| Site product | Reason |
|---|---|
| Sano Pomace Olive Oil | brand Sano, not Jivo; decision needed |
| Canola 5L + Extra Light Olive 1L combo; Canola 5L + Extra Virgin Olive 1L combo; Canola 5L + Premium Tea Leaves 250g; Canola 5L + Kirpa Desi Ghee 1 kg | multi-product bundles (no bundle type in our model; tea and ghee are out of scope) |
| Wheatgrass Juice: Apple, Mango, Blueberry, Mojito (sugar free), Punjabi Jeera (24 x 160 ml) | out of stock on the site: price 0 and no variants. These are 12-packs and 24-packs, not single bottles. A second Mojito page returns 404. |

## 7. Images

- Manifest: `data/manifests/shop_jivo_in_images.csv` (file path relative to `data/incoming/shop_jivo_in/images/`, source URL, size, sha256, format, kind, alt text, white-background check). Every active variant is covered: product-level images apply to all its variants, and 151 images are variant-specific.
- The gallery mixes pack shots (kind front/back: 51 files, all white background) with lifestyle photos. 159 images are flagged as not white (87 lifestyle, 72 other). For 7 of 12 products the first product-level image is a lifestyle photo, with the pack shots attached to the variants. The loader should put pack front shots first.
- Over 5 MB: `jivo-extra-virgin-olive-oil/242072-L2.png` and `242069-L3.png` (6.0 MB each, lifestyle). The backend rejects over 5 MB, so recompress or skip them.
- Below 1000 px: all coconut oil files and the yellow mustard back label (679 px). The backend minimum is 200 px, so they load, but they miss our 1000 px guideline.
- One non-square image: `jivo-gold-refined-oil/26341-Jivo-Gold.webp` (1306 x 1500); the backend pads to a white square.
- Alt text: the site has none, so the manifest uses "<Product> <pack> - image N".
- Rights: the owner confirmed shop.jivo.in is Jivo's own store. Photos stay out of git.

## 8. How to load it (nothing has been run)

1. Fill GST (and HSN) per product in `data/catalog/products.csv` from Jivo Finance, or the import fails on `gst_rate`.
2. Admin: Categories, Import `categories.csv`; Products, Import `products.csv`; SKUs, Import `variants.csv`. Each shows a dry-run preview, then Confirm import (format in `docs/admin-panel-architecture.md` section 10).
3. Images: **no import command exists**; the admin takes one upload at a time. Gap for the backend agent: a management command (for example `import_catalog_images --manifest data/manifests/shop_jivo_in_images.csv --root data/incoming/shop_jivo_in/images`) that creates `ProductImage` rows (variant set when `sku` is filled), idempotent by sha256. The alternative is manual upload in the admin product inlines.
4. Stock: Inventory, Stock inward (`sku,quantity`) per store.
5. Re-check any time: `python -I data/tools/validate_catalog.py`.

## 9. Blocked or open

- GST rate: required by the model and unknown (blocks the import).
- No image loader (backend gap).
- Label compliance data (FSSAI, manufacturer, nutrition, shelf life, consumer care) is not on the site.
- Real MRPs and SAP item codes need Jivo confirmation.

## 10. Final decisions applied (DL-67)

- `gst_rate` = 5.00 on all 12 products. **GST 5% is a test-server placeholder, to be confirmed by Finance.** HSN and FSSAI stay blank. This clears the import blocker in section 9.
- Website prices are used as they are.
- `data/catalog/deactivate_demo_skus.csv` lists the 13 demo oil SKUs to deactivate. Non-oil demo products stay active.
- The 2 EVOO PNGs over 5 MB were recompressed to JPEG (about 1.1 MB each). The 679 px coconut images are kept (warning only).
- The manifest now starts every product and variant with a front pack shot (the first active variant's front shot was added as product-level image 1).
- Validator: 0 hard errors.

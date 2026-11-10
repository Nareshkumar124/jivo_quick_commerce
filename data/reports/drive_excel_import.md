# Amazon Excel import (Agent A, 2026-11-10)

Source: `Vegetable_Oils_2026-11-10T11_04.xlsm` (Amazon vendor listing template, gitignored in `data/incoming/`). Test server only. Built by `data/tools/build_amazon_excel.py`; the row-by-row decisions are in `data/manifests/excel_row_map.csv` (sheet, row, EAN, decision, reason, product, SKU).

## Counts

- Real rows read: 250
- Included: 100 rows (23 map onto live SKUs, 77 are new variants)
- Skipped: 145 multipack or combo, 5 other brand, 0 single units without MRP
- **New products: 37** (catalog now 49 products), **new variants: 77** (catalog now 111 variants, 76 active new ones), **new categories: 8** (plus 2 existing beverage categories listed so the file is self-consistent), **stock rows: 76**
- 32 active new variants still have no photo in `drive_images.csv` (seeds, spices, sodas, ghee, quinoa, honey, gift box, olives and the refined canola pouch). They are listed in `2026-11-10-validation.md`.
- No duplicate listings of the same product, size and pack were found among the included rows.

| Sheet | Included | Multipack or combo | Other brand |
|---|---|---|---|
| CEREAL | 3 | 1 | 1 |
| COFFEE | 1 | 0 | 0 |
| DAIRY_BASED_BUTTER | 3 | 3 | 1 |
| DRINK_FLAVORED | 1 | 1 | 0 |
| EDIBLE_OIL_VEGETABLE | 64 | 135 | 1 |
| FOOD | 1 | 0 | 1 |
| GROCERY | 1 | 0 | 0 |
| HERB | 7 | 1 | 0 |
| HONEY | 1 | 0 | 0 |
| JUICE_AND_JUICE_DRINK | 2 | 1 | 0 |
| NUT_AND_SEED | 14 | 0 | 0 |
| SNACK_MIX | 0 | 0 | 1 |
| WATER | 2 | 3 | 0 |

## Skipped: no MRP

There are **no single-unit Jivo or Sano rows without an MRP**. Every row with no MRP is a multi-item combo (for example "Canola Oil & Sunflower Oil", "Pack of 2", "5L + 1L"), so it is skipped under the combo rule (reason `multipack` in the row map). Number of combo rows with no MRP: 124. If Jivo wants any combo sold, it needs a price and a decision on how to sell it (fixed bundle SKU or two items).

## Skipped: other brands

| Sheet | Row | Brand | Title | Size | EAN | MRP |
|---|---|---|---|---|---|---|
| EDIBLE_OIL_VEGETABLE | 168 | Oleev | Oleev, Olive Pomace Oil, Pet, 1L | 1 l (Pack of 1) | 8908000863361 | 1100.0 |
| FOOD | 7 | Mala's | Mala's Choco Hazelnut Paste, 600 g | 600 g (Pack of 1) | 8901689703188 | 400.00 |
| CEREAL | 11 | NATURELAND ORGANICS | Natureland Organics Wheat Suji/Sooji 500 Gm - Organic Sooji | 500 g (Pack of 1) | 8906066850103 | 75.0 |
| DAIRY_BASED_BUTTER | 9 | Divinne Harvset | Divine Harvest A2 Cow Ghee 200 ml / Made from Milk Fat / No Added Colo |  | 8905604004206 | 1000 |
| SNACK_MIX | 7 | NutriOrganics | NutriOrganics 100% Natural Premium Mix Dry Fruits 1Kg With Almonds/Cas | 1 kg (Pack of 1) |  | 1199.00 |

## Existing live SKUs: current price against the Excel MRP

Nothing was changed on these 34 SKUs except filling blank fields: the EAN into `barcode` (22 SKUs; JVW-EVO-5L stays blank because its EAN 8905604000000 looks like a placeholder), plus the blank label fields and highlights of the 12 existing products. Prices are as they are on the server. Please decide on the differences (a difference is a decision for Jivo, not for the data agent).

| SKU | Server MRP | Server selling price | Excel MRP | MRP difference | Excel row |
|---|---|---|---|---|---|
| JVW-GNT-1L | 560.00 | 210.00 | 400.00 | -160.00 | EDIBLE_OIL_VEGETABLE 54 |
| JVW-GNT-5L | 2800.00 | 1040.00 | 2800.00 | same | EDIBLE_OIL_VEGETABLE 56 |
| JVW-KGM-1L | 255.00 | 180.00 | 255.00 | same | EDIBLE_OIL_VEGETABLE 11 |
| JVW-KGM-5L | 1250.00 | 900.00 | 1250.00 | same | EDIBLE_OIL_VEGETABLE 58 |
| JVW-SOY-1L | 225.00 | 175.00 | 225.00 | same | EDIBLE_OIL_VEGETABLE 36 |
| JVW-SOY-5L | 1100.00 | 875.00 | 1100.00 | same | EDIBLE_OIL_VEGETABLE 43 |
| JVW-SUN-1L | 275.00 | 190.00 | 275.00 | same | EDIBLE_OIL_VEGETABLE 53 |
| JVW-SUN-5L | 1350.00 | 950.00 | 1350.00 | same | EDIBLE_OIL_VEGETABLE 57 |
| JVW-CAN-1L | 375.00 | 220.00 | 375.00 | same | EDIBLE_OIL_VEGETABLE 77 |
| JVW-CAN-5L | 1650.00 | 1099.00 | 1650.00 | same | EDIBLE_OIL_VEGETABLE 55 |
| JVW-POM-1L | 1049.00 | 399.00 | 1049.00 | same | EDIBLE_OIL_VEGETABLE 50 |
| JVW-POM-5L | 4999.00 | 1995.00 | 4999.00 | same | EDIBLE_OIL_VEGETABLE 51 |
| JVW-YMU-1L | 375.00 | 259.00 | 375.00 | same | EDIBLE_OIL_VEGETABLE 40 |
| JVW-XLO-1L | 1499.00 | 500.00 | 1499.00 | same | EDIBLE_OIL_VEGETABLE 47 |
| JVW-XLO-5L | 6499.00 | 2500.00 | 6499.00 | same | EDIBLE_OIL_VEGETABLE 48 |
| JVW-EVO-1L | 1799.00 | 725.00 | 1799.00 | same | EDIBLE_OIL_VEGETABLE 42 |
| JVW-EVO-2L | 2700.00 | 1450.00 | 2700.00 | same | EDIBLE_OIL_VEGETABLE 18 |
| JVW-EVO-5L | 7999.00 | 3625.00 | 7999.00 | same | EDIBLE_OIL_VEGETABLE 61 |
| JVW-RBO-1L | 285.00 | 189.00 | 285.00 | same | EDIBLE_OIL_VEGETABLE 49 |
| JVW-RBO-5L | 1425.00 | 949.00 | 1425.00 | same | EDIBLE_OIL_VEGETABLE 52 |
| JVW-GLD-1L | 225.00 | 167.00 | 225.00 | same | EDIBLE_OIL_VEGETABLE 39 |
| JVW-GLD-5L | 1050.00 | 815.00 | 1049.00 | -1.00 | EDIBLE_OIL_VEGETABLE 46 |
| JVW-COC-500 | 399.00 | 269.00 | 695.00 | +296.00 | EDIBLE_OIL_VEGETABLE 15 |

20 of 23 MRPs match. Server selling prices are far below MRP on many SKUs (13 SKUs have a discount over 50%; see the validation report), which the Excel cannot confirm because it holds MRP only.

## Judgement calls to confirm

- **Grouping:** `JVW-KGM`, `SUN`, `CAN`, `POM`, `XLO`, `EVO`, `RBO`, `COC` etc. got extra sizes (2 L, 3 L, 4 L, 200 ml, 250 ml, 500 ml) as new variants. Their `sort_order` continues after the live ones, so a new 3 L chip shows after the 5 L chip. Change in Admin if Jivo wants size order.
- **Row 13** ("Jivo Sunflower Oil 4 Litres", MRP 1038) is filed under Cold Pressed Sunflower Oil although its title does not say cold pressed. Row 78 (3 L) does say it.
- **Row 33** ("First Pressed Mustard Oil") and **row 35** ("First Pressed Sunflower Oil") are separate products, not the live Kachi Ghani Mustard or Cold Pressed Sunflower products. Row 40 (yellow mustard) maps to the live Yellow Mustard product.
- **Premium Olive Oil** (rows 152 to 154, tin) and **So Olive Oil** (rows 34, 37, a rice bran and olive blend) are their own products.
- **Pouches:** rows 14 and 68 are 1 L pouches, kept as variants "1 L Pouch" (SKU suffix `1LP`) under their oils. Row 75 (JVW-CAN-1LP) is **Refined** canola in its title, description and first bullet, so it sits in its own product `jivo-refined-canola-oil` (category canola-oil), not under Cold Pressed Canola Oil. It has no photo yet.
- **Wheatgrass Ginger Ale (JVW-WGG-200, JUICE row 8)** is set inactive and has no test stock: the vendor SKU says "200 ml (Pack of 6)" and the weight is 1.2 kg, so it may really be a 6-pack. Jivo must confirm the pack size and price.
- **Junk Excel text is not copied:** cells that only repeat their column label ("Product Description", "Ingredients") or one generic word ("Fiber") are ignored, an importer address without a company name is dropped, the peach soda description (spring water text) is blank, and highlights that are attribute keys, "Sales Package", bare "Health Benefits", or size-specific on multi-size products are dropped. Premium Olive Oil has a description built from its bullet points.
- **Soyabean Oil country:** the live product says India, the Excel (row 36) says Argentina. The site value is kept and no importer is set. Jivo must say which is right.
- **Honey (row 7):** the sheet size says "1 l" but title and weight say 1 kg; stored as 1 kg (1000 g).
- **Fizzy Soda Lemon (row 8):** sheet size says 700 ml, title and the other flavours say 750 ml; stored as 750 ml.
- **Pumpkin seeds (rows 7, 19, 20)** are titled "with Free Sampler". Treated as single units (the sampler is a promotion, not a second item). Say if they must be skipped.
- **Dry Fruits Gift Box (FOOD 8):** one box (360 g plus 2 diyas), MRP 1999. Included; it is a festival item.
- **Extra Virgin Olive Oil 5 L (row 155, MRP 8274):** sheet says 6000 ml and the title also mentions a 1 L sunflower oil, so it is skipped as a bundle. The live 5 L SKU (JVW-EVO-5L) uses row 61 (MRP 7999).
- **Wheatgrass Jeera (DRINK 7) and Shikanji (JUICE 7)** are 24 x 160 ml cases, skipped as multipacks.
- Mala's, Oleev, Natureland, Divine Harvest and NutriOrganics are not Jivo brands and were skipped (list above). The Divine Harvest brand is misspelled in the sheet.
- Some prices look unusual and are copied as given: A2 Ghee 500 ml 2200 and 1 L 4000, Desi Ghee 500 ml 849, Fizzy Soda 750 ml 30 and 55, Wheatgrass 200 ml 100 and 500 ml 100. Please check them with Jivo.

## Data copied from the Excel, and what is still missing

- Copied when present: description, highlights (from the bullet headings), ingredients, shelf life (in days), storage, country of origin, manufacturer (name and address as written), importer (only for imported oils), veg mark ("Vegetarian" or vegan/vegetarian diet type), EAN as barcode.
- **Not in the Excel, so left blank (never invented):** FSSAI licence number, consumer care contact, marketer, nutrition table, and storage instructions for almost all products. `sap_item_code` is blank because `vendor_sku` is an Amazon ID.
- **HSN:** left blank as decided. The Excel does hold HSN codes on 111 rows, but they are inconsistent (the same kind of oil has different codes, some are 6 or 7 digits, juice rows carry a medicine code). Finance should confirm them (D-12).
- **Country of origin conflicts inside the sheet:** Extra Light Olive Oil (India on row 30, Spain on the others) and Extra Virgin Coconut Oil (Spain on row 15, India on the others). The most common value is used: Spain for the olive oil, India for the coconut oil.
- The Kashmiri Saffron sheet row has no description text; the description was built from its bullet points. The honey description had a typo ("ivo Sano Honey"), corrected to "Jivo".
- **GST 5.00 is a test-server placeholder** on all 37 new products, to be confirmed by Finance (D-12). See `data/catalog/README.md`.
- EAN looks like a placeholder (barcode left blank): 1
- description left blank (Excel text is about another product): 1

## Questions for Jivo

1. Real selling prices for the 77 new variants (they are set equal to MRP for the test server). The 34 live SKUs have discounted prices that do not appear in the Excel.
2. Which MRP is right where the live server and the Excel differ (table above)?
3. GST rate and HSN code for every product type (oils, seeds, honey, ghee, spices, soda, coffee, juices).
4. FSSAI licence number, consumer care contact and marketer name for the label fields.
5. Should combos and multi-packs (145 rows) be sold at all, and as fixed bundle SKUs?
6. Should the 5 other brands (Mala's, Oleev, Natureland Organics, Divine Harvest, NutriOrganics) be sold?
7. SAP item codes for every SKU (D-17).
8. Confirm the mapping calls above (rows 13, 33, 35, the sampler pumpkin seeds, the gift box).
9. Is the Wheatgrass Ginger Ale 200 ml one bottle or a pack of 6 (JVW-WGG-200, inactive until confirmed)?
10. Country of origin for Soyabean Oil: India (site) or Argentina (Excel)?
11. Real EAN for the Extra Virgin Olive Oil 5 L (JVW-EVO-5L); the Excel value 8905604000000 looks like a placeholder.


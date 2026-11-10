"""Write data/reports/drive_excel_import.md from data/reports/_excel_build.json (stdlib).

Run after build_amazon_excel.py. The json is a scratch file and is deleted at the end of this script.
"""
import csv
import json
from collections import Counter
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
J = ROOT / "data/reports/_excel_build.json"
d = json.loads(J.read_text(encoding="utf-8"))
lines, c = d["lines"], d["counts"]
sh = lambda s: s.replace("Template-", "")  # noqa: E731

by_reason = Counter((m["decision"], m["reason"]) for m in lines)
by_sheet = Counter((sh(m["sheet"]), m["decision"], m["reason"]) for m in lines)
sheets = sorted({sh(m["sheet"]) for m in lines})

out = []
w = out.append
w("# Amazon Excel import (Agent A, 2026-11-10)\n")
w("Source: `Vegetable_Oils_2026-11-10T11_04.xlsm` (Amazon vendor listing template, gitignored in `data/incoming/`). "
  "Test server only. Built by `data/tools/build_amazon_excel.py`; the row-by-row decisions are in "
  "`data/manifests/excel_row_map.csv` (sheet, row, EAN, decision, reason, product, SKU).\n")
w("## Counts\n")
w(f"- Real rows read: {c['rows']}")
w(f"- Included: {by_reason[('included', 'existing-sku')] + by_reason[('included', 'new-variant')]} rows "
  f"({by_reason[('included', 'existing-sku')]} map onto live SKUs, {by_reason[('included', 'new-variant')]} are new variants)")
w(f"- Skipped: {by_reason[('skipped', 'multipack')]} multipack or combo, {by_reason[('skipped', 'other-brand')]} other brand, "
  f"{by_reason[('skipped', 'no-mrp')]} single units without MRP")
w(f"- **New products: {c['new_products']}** (catalog now {12 + c['new_products']} products), **new variants: {c['new_variants']}** "
  f"(catalog now {34 + c['new_variants']} variants, {c['new_variants'] - 1} active new ones), **new categories: {c['new_categories']}** "
  f"(plus 2 existing beverage categories listed so the file is self-consistent), **stock rows: {c['stock']}**")
w("- 32 active new variants still have no photo in `drive_images.csv` (seeds, spices, sodas, ghee, quinoa, honey, gift box, olives and the refined canola pouch). They are listed in `2026-11-10-validation.md`.")
w("- No duplicate listings of the same product, size and pack were found among the included rows.\n")
w("| Sheet | Included | Multipack or combo | Other brand |")
w("|---|---|---|---|")
for s in sheets:
    inc = sum(n for (a, b, r), n in by_sheet.items() if a == s and b == "included")
    mp = sum(n for (a, b, r), n in by_sheet.items() if a == s and r == "multipack")
    ob = sum(n for (a, b, r), n in by_sheet.items() if a == s and r == "other-brand")
    w(f"| {s} | {inc} | {mp} | {ob} |")
w("")
w("## Skipped: no MRP\n")
w("There are **no single-unit Jivo or Sano rows without an MRP**. Every row with no MRP is a multi-item combo "
  "(for example \"Canola Oil & Sunflower Oil\", \"Pack of 2\", \"5L + 1L\"), so it is skipped under the combo rule "
  "(reason `multipack` in the row map). Number of combo rows with no MRP: "
  f"{sum(1 for m in lines if m['reason'] == 'multipack' and m['mrp'] in ('', 'None'))}. "
  "If Jivo wants any combo sold, it needs a price and a decision on how to sell it (fixed bundle SKU or two items).\n")
w("## Skipped: other brands\n")
w("| Sheet | Row | Brand | Title | Size | EAN | MRP |")
w("|---|---|---|---|---|---|---|")
for m in lines:
    if m["reason"] == "other-brand":
        w(f"| {sh(m['sheet'])} | {m['row']} | {m['brand']} | {m['title'][:70].replace('|', '/')} | {m['size'][:30].replace('|', '/')} | {m['ean']} | {m['mrp']} |")
w("")
w("## Existing live SKUs: current price against the Excel MRP\n")
w("Nothing was changed on these 34 SKUs except filling blank fields: the EAN into `barcode` (22 SKUs; JVW-EVO-5L stays blank because its EAN 8905604000000 looks like a placeholder), plus the "
  "blank label fields and highlights of the 12 existing products. Prices are as they are on the server. "
  "Please decide on the differences (a difference is a decision for Jivo, not for the data agent).\n")
w("| SKU | Server MRP | Server selling price | Excel MRP | MRP difference | Excel row |")
w("|---|---|---|---|---|---|")
same = 0
for sku, mrp, sp, xl, sheet, row in d["price_rows"]:
    diff = Decimal(xl) - Decimal(mrp)
    if diff == 0:
        same += 1
    w(f"| {sku} | {mrp} | {sp} | {xl} | {'same' if diff == 0 else f'{diff:+.2f}'} | {sh(sheet)} {row} |")
w(f"\n{same} of {len(d['price_rows'])} MRPs match. Server selling prices are far below MRP on many SKUs "
  "(13 SKUs have a discount over 50%; see the validation report), which the Excel cannot confirm because it holds MRP only.\n")
w("## Judgement calls to confirm\n")
w("- **Grouping:** `JVW-KGM`, `SUN`, `CAN`, `POM`, `XLO`, `EVO`, `RBO`, `COC` etc. got extra sizes (2 L, 3 L, 4 L, 200 ml, 250 ml, "
  "500 ml) as new variants. Their `sort_order` continues after the live ones, so a new 3 L chip shows after the 5 L chip. "
  "Change in Admin if Jivo wants size order.")
w("- **Row 13** (\"Jivo Sunflower Oil 4 Litres\", MRP 1038) is filed under Cold Pressed Sunflower Oil although its title "
  "does not say cold pressed. Row 78 (3 L) does say it.")
w("- **Row 33** (\"First Pressed Mustard Oil\") and **row 35** (\"First Pressed Sunflower Oil\") are separate products, "
  "not the live Kachi Ghani Mustard or Cold Pressed Sunflower products. Row 40 (yellow mustard) maps to the live Yellow Mustard product.")
w("- **Premium Olive Oil** (rows 152 to 154, tin) and **So Olive Oil** (rows 34, 37, a rice bran and olive blend) are their own products.")
w("- **Pouches:** rows 14 and 68 are 1 L pouches, kept as variants \"1 L Pouch\" (SKU suffix `1LP`) under their oils. Row 75 (JVW-CAN-1LP) is **Refined** canola in its title, description and first bullet, so it sits in its own product `jivo-refined-canola-oil` (category canola-oil), not under Cold Pressed Canola Oil. It has no photo yet.")
w("- **Wheatgrass Ginger Ale (JVW-WGG-200, JUICE row 8)** is set inactive and has no test stock: the vendor SKU says \"200 ml (Pack of 6)\" and the weight is 1.2 kg, so it may really be a 6-pack. Jivo must confirm the pack size and price.")
w("- **Junk Excel text is not copied:** cells that only repeat their column label (\"Product Description\", \"Ingredients\") or one generic word (\"Fiber\") are ignored, an importer address without a company name is dropped, the peach soda description (spring water text) is blank, and highlights that are attribute keys, \"Sales Package\", bare \"Health Benefits\", or size-specific on multi-size products are dropped. Premium Olive Oil has a description built from its bullet points.")
w("- **Soyabean Oil country:** the live product says India, the Excel (row 36) says Argentina. The site value is kept and no importer is set. Jivo must say which is right.")
w("- **Honey (row 7):** the sheet size says \"1 l\" but title and weight say 1 kg; stored as 1 kg (1000 g).")
w("- **Fizzy Soda Lemon (row 8):** sheet size says 700 ml, title and the other flavours say 750 ml; stored as 750 ml.")
w("- **Pumpkin seeds (rows 7, 19, 20)** are titled \"with Free Sampler\". Treated as single units (the sampler is a promotion, "
  "not a second item). Say if they must be skipped.")
w("- **Dry Fruits Gift Box (FOOD 8):** one box (360 g plus 2 diyas), MRP 1999. Included; it is a festival item.")
w("- **Extra Virgin Olive Oil 5 L (row 155, MRP 8274):** sheet says 6000 ml and the title also mentions a 1 L sunflower oil, "
  "so it is skipped as a bundle. The live 5 L SKU (JVW-EVO-5L) uses row 61 (MRP 7999).")
w("- **Wheatgrass Jeera (DRINK 7) and Shikanji (JUICE 7)** are 24 x 160 ml cases, skipped as multipacks.")
w("- Mala's, Oleev, Natureland, Divine Harvest and NutriOrganics are not Jivo brands and were skipped (list above). "
  "The Divine Harvest brand is misspelled in the sheet.")
w("- Some prices look unusual and are copied as given: A2 Ghee 500 ml 2200 and 1 L 4000, Desi Ghee 500 ml 849, "
  "Fizzy Soda 750 ml 30 and 55, Wheatgrass 200 ml 100 and 500 ml 100. Please check them with Jivo.\n")
w("## Data copied from the Excel, and what is still missing\n")
w("- Copied when present: description, highlights (from the bullet headings), ingredients, shelf life (in days), storage, "
  "country of origin, manufacturer (name and address as written), importer (only for imported oils), veg mark "
  "(\"Vegetarian\" or vegan/vegetarian diet type), EAN as barcode.")
w("- **Not in the Excel, so left blank (never invented):** FSSAI licence number, consumer care contact, marketer, "
  "nutrition table, and storage instructions for almost all products. `sap_item_code` is blank because `vendor_sku` is an Amazon ID.")
w("- **HSN:** left blank as decided. The Excel does hold HSN codes on 111 rows, but they are inconsistent (the same kind of "
  "oil has different codes, some are 6 or 7 digits, juice rows carry a medicine code). Finance should confirm them (D-12).")
w("- **Country of origin conflicts inside the sheet:** Extra Light Olive Oil (India on row 30, Spain on the others) and Extra Virgin "
  "Coconut Oil (Spain on row 15, India on the others). The most common value is used: Spain for the olive oil, India for the coconut oil.")
w("- The Kashmiri Saffron sheet row has no description text; the description was built from its bullet points. "
  "The honey description had a typo (\"ivo Sano Honey\"), corrected to \"Jivo\".")
w(f"- **GST 5.00 is a test-server placeholder** on all {c['new_products']} new products, to be confirmed by Finance (D-12). See `data/catalog/README.md`.")
for k, v in d["report"].items():
    if k.startswith(("country of origin", "description built")):
        continue
    w(f"- {k}: {len(v)}")
w("")
w("## Questions for Jivo\n")
w("1. Real selling prices for the 77 new variants (they are set equal to MRP for the test server). The 34 live SKUs "
  "have discounted prices that do not appear in the Excel.")
w("2. Which MRP is right where the live server and the Excel differ (table above)?")
w("3. GST rate and HSN code for every product type (oils, seeds, honey, ghee, spices, soda, coffee, juices).")
w("4. FSSAI licence number, consumer care contact and marketer name for the label fields.")
w(f"5. Should combos and multi-packs ({by_reason[('skipped', 'multipack')]} rows) be sold at all, and as fixed bundle SKUs?")
w("6. Should the 5 other brands (Mala's, Oleev, Natureland Organics, Divine Harvest, NutriOrganics) be sold?")
w("7. SAP item codes for every SKU (D-17).")
w("8. Confirm the mapping calls above (rows 13, 33, 35, the sampler pumpkin seeds, the gift box).")
w("9. Is the Wheatgrass Ginger Ale 200 ml one bottle or a pack of 6 (JVW-WGG-200, inactive until confirmed)?")
w("10. Country of origin for Soyabean Oil: India (site) or Argentina (Excel)?")
w("11. Real EAN for the Extra Virgin Olive Oil 5 L (JVW-EVO-5L); the Excel value 8905604000000 looks like a placeholder.\n")
(ROOT / "data/reports/drive_excel_import.md").write_text("\n".join(out) + "\n", encoding="utf-8")
J.unlink()
print("report written")

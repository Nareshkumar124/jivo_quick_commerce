# Drive photo selection report (2026-11-10)

Source: Jivo Google Drive folder "E-COM Product's listing images" (read-only). Photos are copied to the gitignored `data/incoming/drive_images/`; nothing from there is tracked.

## Counts

| Item | Count |
|---|---|
| Image files indexed (JPEG/PNG, after removing 88 macOS `._` junk files) | 1,315 readable (+1 unreadable `Copy of ._1.png`) |
| Skipped folders | Combo Images, Videos, Arshdeep Videos, Divine Harvest |
| Included Excel rows (Agent A map) | 100 |
| Rows already live with photos (not touched) | 20 |
| Rows given photos | 47 SKUs, 196 variant images (up to 5 each) |
| Product-scope front images added (new products only) | 17 |
| Manifest rows in `drive_images.csv` | 213 |
| Re-encoded copies (4000 px or 3001 px sources, over 3000 px) | 79 (JPEG q90, long side 2048) |
| Included rows with NO photo | 33 |

Whole index: 452 images under 1000 px (mostly A+ banners), 478 not square (A+ banners), 918 not white (lifestyle/A+), 33 over 5 MB (not chosen or re-encoded).

## How images were chosen
Order: front, back, nutrition/ingredient label, side views (max 2), then lifestyle photos (max 2) up to 5. Only white-background, square, at least 1000 px pack shots count as pack shots. Skipped: A+ banners, EAN/barcode, FSSAI and chart images, "1.jpg/2.jpg" mock-ups with unclear background, the 1,200 x 628 "No Text No Logo" banners (not square).

Flagged: no chosen image is small or non-square. Lifestyle images are `not-white` on purpose. The manifest `notes` column says which files were re-encoded.

## Manifest check
`python -I data/tools/check_image_manifest.py data/manifests/drive_images.csv data/incoming/drive_images`: 213 rows, 0 problems (file exists, size at most 5 MB, JPEG/PNG/WebP, at least 200 px, SHA-256 matches, product/SKU exist in products.csv/variants.csv, no duplicates). This copies the checks of `_parse_image_row` and `_check_image_file` offline; the real `import_images` dry run needs the products imported first.

## Things Jivo should look at
- JVW-DSG-500 (Jivo Desi Ghee 500 ML): the photo folder is named "Kripa Ghee" and the jar says "kirpa desi ghee", not Jivo. Confirm the brand before going live.
- JVW-COC-1L: two coconut 1 L sets exist; I used the `New Coconut Label` folder.
- JVW-SOL-1L: two So Olive 1 L sets (2000 px and 4000 px); I used the 4000 px set ("so olive front/back").
- JVW-SES-1L: the lifestyle photos sit at the product level (not per size) and are shared.
- JVW-WGG-200 (Ginger Ale wheatgrass): `4.png` is a composition panel (label); `3.png` is a barcode and was left out.
- JVW-KGM-1LP (mustard pouch): only front and back (other pouch images are not white background).
- JVW-A2G-500/1L: the "label" image is a nutrition-facts shot of the jar side.

## Included rows with NO photo (33)
| Sheet | Row | SKU | Title | Reason |
|---|---|---|---|---|
| HONEY | 7 | SNO-HON-1KG | Jivo Sano Pure Honey 1 Kg | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 7 | JVW-PMP-800G | Jivo Premium Raw Pumpkin Seeds for Eating wit | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 8 | JVW-SFS-800G | Jivo Premium Raw Sunflower Seeds for Eating P | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 9 | JVW-CHA-200G | JIVO Raw Unroasted Chia Seeds For High Protei | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 10 | JVW-CHA-800G | JIVO Raw Unroasted Chia Seeds For High Protei | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 11 | JVW-FLX-800G | Jivo Premium 100% Natural & Non-GMO Flax Seed | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 12 | JVW-SFS-200G | Jivo Premium Raw Sunflower Seeds for Eating P | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 13 | JVW-SFS-400G | Jivo Premium Raw Sunflower Seeds for Eating P | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 14 | JVW-BSL-200G | Jivo Raw Basil Seeds for weight loss - 200gm | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 15 | JVW-FLX-400G | flax seeds | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 16 | JVW-CHA-400G | Jivo Premium Raw Chia seeds I Rich in Calcium | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 17 | JVW-BSL-400G | Jivo Basil Organic Basil Seeds (400) | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 18 | JVW-FLX-200G | Jivo Premium 100% Natural Flax Seeds | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 19 | JVW-PMP-200G | Jivo Premium Raw Pumpkin Seeds for Eating wit | no matching photo in the Drive photo folders |
| NUT_AND_SEED | 20 | JVW-PMP-400G | Jivo Premium Raw Pumpkin Seeds for Eating wit | no matching photo in the Drive photo folders |
| EDIBLE_OIL_VEGETABLE | 68 | JVW-SOY-1LP | Jivo Soyabean Oil Pouch 1L - Pure & Healthy C | no matching photo in the Drive photo folders |
| EDIBLE_OIL_VEGETABLE | 73 | SNO-CLO-1L | sano Classic Olive Oil 1L, Ideal For All Indi | no matching photo in the Drive photo folders |
| EDIBLE_OIL_VEGETABLE | 75 | JVW-CAN-1LP | JIVO Canola Oil 1 ltr Refined Pouch | no matching photo in the Drive photo folders |
| DRINK_FLAVORED | 8 | JVW-FZL-750 | Jivo Fizzy Soda | no matching photo in the Drive photo folders |
| FOOD | 8 | JVW-GFT-360G | Jivo Dry Fruits Gift Box | no matching photo in the Drive photo folders |
| WATER | 7 | JVW-XFZ-750 | Jivo Extra Fizzy Soda, 750 ml, Soda (Pack of  | no matching photo in the Drive photo folders |
| WATER | 10 | JVW-FZP-750 | Jivo Fizzy Soda | no matching photo in the Drive photo folders |
| CEREAL | 7 | JVW-QNA-400G | Jivo Premium Quinoa Gluten Free | no matching photo in the Drive photo folders |
| CEREAL | 8 | JVW-QNA-200G | Jivo Premium Quinoa Gluten Free | no matching photo in the Drive photo folders |
| CEREAL | 9 | JVW-QNA-800G | Jivo Premium Quinoa Gluten Free | no matching photo in the Drive photo folders |
| HERB | 7 | JVW-CUM-100G | Jivo Cumin Seeds 100g - Fresh & Aromatic | no matching photo in the Drive photo folders |
| HERB | 8 | JVW-BCD-100G | Jivo Whole Black Cardamom | no matching photo in the Drive photo folders |
| HERB | 9 | JVW-BPR-100G | Jivo Black Pepper Whole Natural Peppercorns | no matching photo in the Drive photo folders |
| HERB | 10 | JVW-GCD-100G | Jivo Green Cardamom 8mm Elaichi | no matching photo in the Drive photo folders |
| HERB | 11 | JVW-CLV-100G | Jivo Whole Clove (Laung) 100 gm | no matching photo in the Drive photo folders |
| HERB | 12 | JVW-CIN-100G | Jivo Premium Organic Cinnamon Bark, 100G | no matching photo in the Drive photo folders |
| HERB | 13 | JVW-SAF-1G | Jivo Pure Kashmiri Saffron | no matching photo in the Drive photo folders |
| GROCERY | 7 | JVW-BSO-470G | Jivo Black Sliced Olives – 470g | no matching photo in the Drive photo folders |

Groups: seeds (14 rows), quinoa (3), herbs and spices (7), honey, olives, dry-fruit gift box, fizzy sodas and soda water (4) have no photos in Drive at all. The Drive has no pouch photos for soyabean or canola oil, and no Sano Classic Olive 1 L photos.

The "Water" folder holds 250 ml, 500 ml and 1 L mineral-water bottles, but the Excel water rows are 24-packs and 12-packs (out of scope).

## Questions for Jivo
1. Please send pack shots for seeds, quinoa, herbs, honey, olives, the gift box and the fizzy sodas.
2. Confirm the Kripa vs Jivo brand on the Desi Ghee jar.
3. Confirm which coconut 1 L and So Olive 1 L label is current.

## Files
- `data/manifests/drive_image_index.csv` (index), `drive_image_selection.csv` (by sheet and row), `drive_images.csv` (final manifest)
- `data/tools/index_drive_images.py`, `select_drive_images.py`, `check_image_manifest.py`

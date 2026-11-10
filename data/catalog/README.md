# Catalog import files

Import-ready CSVs for the admin import (django-import-export). The column order is the one in `backend/apps/catalog/admin/resources.py`; the full format is `docs/admin-panel-architecture.md` section 10.

| File | Admin screen | Key |
|---|---|---|
| `categories.csv` | Categories, Import | `slug` |
| `products.csv` | Products, Import | `slug` |
| `variants.csv` | SKUs, Import | `sku` |

Import in that order. Each import shows a dry run first, then Confirm import. Imports never delete.

Source: shop.jivo.in (stage 1, see `data/reports/shop_jivo_in_import.md`). Empty tax, licence and label columns are "needs Jivo input" and are never invented. `gst_rate` is required by the model, so fill it in `products.csv` before importing.

Images are not part of these files. The mapping is `data/manifests/shop_jivo_in_images.csv`; the photos themselves live in the gitignored `data/incoming/shop_jivo_in/images/`.

Check the files without touching any database: `python -I data/tools/validate_catalog.py`.

## GST placeholder (DL-67)

`gst_rate` is 5.00 on all 12 products. **GST 5% is a test-server placeholder, to be confirmed by Finance** (D-12). The import format has no note column, so this README and the report carry the note. `hsn_code` and `fssai_license_no` are blank on purpose (not invented).

## Demo SKUs to deactivate

`deactivate_demo_skus.csv` lists the 13 demo oil SKUs that the real products replace (`is_active` 0, plus the replacing `JVW-` SKU). Apply it after the real variants are in, by hand in Admin, SKUs (the import never deletes; setting `is_active` 0 is an update). Non-oil demo products, and the demo Refined Canola Oil (JV-CAN-RF-1L, no site equivalent), stay active.

## Amazon Excel extension (2026-11-10, test server only)

The files now also hold Jivo's Amazon listing export (`data/incoming/Vegetable_Oils_2026-11-10T11_04.xlsm`, gitignored): 12 live plus 37 new products, 34 live plus 77 new variants (JVW-WGG-200 inactive), and 8 new categories (`seeds-and-dry-fruits`, `ghee-and-butter`, `honey`, `spices-and-herbs`, `cereals-and-grains`, `coffee-and-tea`, `pantry`, `water-and-soda`). `wellness-beverages` and `wheatgrass` already exist on the server (seed_demo) and are listed with the same values so the file is self-consistent. The explanation, counts and questions for Jivo are in `data/reports/drive_excel_import.md`; every Excel row and its decision is in `data/manifests/excel_row_map.csv`. Rebuild with `data/tools/build_amazon_excel.py` (needs openpyxl and the workbook).

Rules applied: brands Jivo and Sano only; single units only (no multi-packs or combos); rows with no MRP skipped; the 34 live SKUs keep their slugs, SKUs and prices (only blank fields were filled, mostly `barcode` from the EAN); new variants have `selling_price` = `mrp` (no discount); `max_qty_per_order` 5; `sap_item_code` blank (the sheet's `vendor_sku` is an Amazon ID).

**GST 5% is a test-server placeholder on every new product, to be confirmed by Finance (D-12), as in DL-67.** `hsn_code`, `fssai_license_no`, `consumer_care`, `marketer` and `nutrition` are blank because the Excel does not hold them reliably (never invented).

### Test stock list

`stock_test_store.csv` (`sku,quantity`) lists 50 units for each of the 76 active new variants. **There is no stock import format**, so this file is test-only: the PM loads it by hand into the test store's inventory (not through the catalog import, and never to production). Live SKUs are not in it.

### Images

Photos are mapped separately (`data/manifests/*_images.csv`). 32 active new variants still have none; until they do, run the validator with `--images-pending`, otherwise a variant with no image is a hard error.

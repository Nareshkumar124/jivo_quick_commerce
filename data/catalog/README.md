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

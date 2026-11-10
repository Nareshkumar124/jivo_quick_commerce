# Catalog validation (shop.jivo.in + Amazon Excel import)

## Hard errors (rule: count)
- none

## Needs Jivo input (rule: count)
- compliance: consumer_care missing: 49
- compliance: country_of_origin missing: 1
- compliance: fssai_license_no missing: 49
- compliance: ingredients missing: 4
- compliance: marketer missing: 49
- compliance: nutrition missing: 49
- compliance: storage_instructions missing: 46
- identity: sap_item_code missing (D-17): 111
- images: active variant has no image yet (--images-pending): 32
- tax: hsn_code missing: 49

## Warnings (rule: count)
- compliance: manufacturer has no address/pincode: 10
- identity: 8
- images: background not white (non-lifestyle): 72
- images: below 1000 px (accepted by owner, DL-67): 6
- images: not square: 5
- price: discount over 50%: 13
  - variant JVW-GNT-1L: 560.00 -> 210.00
  - variant JVW-GNT-5L: 2800.00 -> 1040.00
  - variant JVW-GNT-5P1L: 3360.00 -> 1230.00
  - variant JVW-POM-1L: 1049.00 -> 399.00
  - variant JVW-POM-5L: 4999.00 -> 1995.00
  - variant JVW-XLO-1L: 1499.00 -> 500.00
  - variant JVW-XLO-5L: 6499.00 -> 2500.00
  - variant JVW-XLO-2X1L: 2998.00 -> 1000.00
  - variant JVW-XLO-5P1L: 7998.00 -> 2969.00
  - variant JVW-EVO-1L: 1799.00 -> 725.00
  - variant JVW-EVO-5L: 7999.00 -> 3625.00
  - variant JVW-EVO-2X1L: 2998.00 -> 1450.00
  - variant JVW-EVO-5X1L: 8995.00 -> 3625.00

## Notes

- Strict run: `python -I data/tools/validate_catalog.py` gives 0 errors except rule images: 32 active new variants have no photo in Agent B's `drive_images.csv`. With `--images-pending` there are 0 hard errors. The 32 are listed in the strict run's output.
- Catalog: 49 products, 111 variants (JVW-WGG-200 inactive), 15 categories, 76 test stock rows.
- The "Needs Jivo input" counts are per product (49) or per variant (111): expected gaps, not failures. GST 5.00 is the test-server placeholder (D-12); `hsn_code` is blank everywhere.
- 13 discounts over 50% are live SKUs, unchanged. New variants have selling price = MRP.

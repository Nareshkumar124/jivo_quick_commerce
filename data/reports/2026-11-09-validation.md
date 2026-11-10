# Catalog validation (shop.jivo.in import)

## Hard errors (rule: count)
- none

## Needs Jivo input (rule: count)
- compliance: consumer_care missing: 12
- compliance: country_of_origin missing: 7
- compliance: fssai_license_no missing: 12
- compliance: ingredients missing: 11
- compliance: is_veg not stated on site (import defaults to 1): 4
- compliance: manufacturer missing: 12
- compliance: marketer missing: 12
- compliance: nutrition missing: 12
- compliance: shelf_life missing: 12
- compliance: storage_instructions missing: 12
- identity: sap_item_code missing (D-17): 34
- tax: hsn_code missing: 12

## Warnings (rule: count)
- images: background not white (non-lifestyle): 72
- images: below 1000 px (accepted by owner, DL-67): 6
- images: not square: 1
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

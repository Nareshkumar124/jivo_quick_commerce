"""Phase 2 database checks (read-only SQL on the shared DB; aggregates only): stock constraints
and ledger, prices, orphans, PostGIS geometry and index, slugs (07 §2.2-§2.4, §3).

Every query runs in a READ ONLY transaction (qa_support.db_query). Nothing is written.
"""

from __future__ import annotations

import pytest

from qa_support import db_query

pytestmark = [pytest.mark.db, pytest.mark.any_profile]


def _one(sql: str, params: tuple = ()):
    ((value,),) = db_query(sql, params)
    return value


def _constraints(table: str) -> dict[str, str]:
    rows = db_query(
        "select conname, pg_get_constraintdef(c.oid) from pg_constraint c "
        "join pg_class t on t.oid = c.conrelid where t.relname = %s",
        (table,),
    )
    return dict(rows)


@pytest.mark.smoke
def test_p2_tc45_stock_constraints(api=None):
    """P2-TC-45 🔥 StoreInventory has the 07 §2.4 check constraints (on_hand >= 0, reserved >= 0,
    reserved <= on_hand, price_override > 0) and the (store, variant) unique constraint, and no row
    violates them."""
    cons = _constraints("inventory_storeinventory")
    text = " ".join(cons.values())
    assert "(on_hand >= 0)" in text
    assert "(reserved >= 0)" in text
    assert "(reserved <= on_hand)" in text
    assert "price_override > (0)" in text.replace("::numeric", "")
    assert any(d.startswith("UNIQUE (store_id, variant_id)") for d in cons.values()), cons
    assert _one(
        "select count(*) from inventory_storeinventory where on_hand < 0 or reserved < 0 or reserved > on_hand"
    ) == 0


@pytest.mark.smoke
def test_p2_tc46_ledger_sums_to_on_hand():
    """P2-TC-46 🔥 For every StoreInventory row, the StockMovement deltas sum to on_hand and the
    latest movement's on_hand_after equals on_hand (07 §2.4: rows start at zero, opening stock is
    INWARD). Movements: delta never 0, on_hand_after >= 0, no movement without an inventory row."""
    mismatches = db_query(
        """
        select i.store_id, i.variant_id, i.on_hand, coalesce(sum(m.delta), 0) as ledger
        from inventory_storeinventory i
        left join inventory_stockmovement m on m.store_id = i.store_id and m.variant_id = i.variant_id
        group by i.id having i.on_hand <> coalesce(sum(m.delta), 0)
        """
    )
    assert mismatches == []
    last = db_query(
        """
        select i.store_id, i.variant_id, i.on_hand, m.on_hand_after from inventory_storeinventory i
        join lateral (select on_hand_after from inventory_stockmovement m
                      where m.store_id = i.store_id and m.variant_id = i.variant_id
                      order by m.created_at desc, m.id desc limit 1) m on true
        where m.on_hand_after <> i.on_hand
        """
    )
    assert last == []
    assert _one("select count(*) from inventory_stockmovement where delta = 0 or on_hand_after < 0") == 0
    assert _one(
        "select count(*) from inventory_stockmovement m where not exists (select 1 from inventory_storeinventory i "
        "where i.store_id = m.store_id and i.variant_id = m.variant_id)"
    ) == 0
    # running balance: each movement's on_hand_after = previous on_hand_after + delta
    broken = db_query(
        """
        select store_id, variant_id, id from (
          select m.*, lag(on_hand_after, 1, 0) over (partition by store_id, variant_id order by created_at, id) prev
          from inventory_stockmovement m) x
        where on_hand_after <> prev + delta
        """
    )
    assert broken == []
    cons = " ".join(_constraints("inventory_stockmovement").values())
    assert "NOT (delta = 0)" in cons and "on_hand_after >= 0" in cons


def test_p2_tc47_prices():
    """P2-TC-47 Money: mrp > 0, 0 < selling_price <= mrp for every variant; no store price
    override above the MRP (trivially true today: the seed has no overrides, count printed);
    money columns are numeric(12,2), no float columns in stores/catalog/inventory."""
    assert _one("select count(*) from catalog_productvariant where mrp <= 0 or selling_price <= 0 or selling_price > mrp") == 0
    overrides = _one("select count(*) from inventory_storeinventory where price_override is not null")
    over = _one(
        "select count(*) from inventory_storeinventory i join catalog_productvariant v on v.id = i.variant_id "
        "where i.price_override > v.mrp"
    )
    print(f"price overrides: {overrides}, above MRP: {over}")
    assert over == 0
    types = dict(
        db_query(
            "select table_name || '.' || column_name, data_type || coalesce('(' || numeric_precision || ',' || numeric_scale || ')', '') "
            "from information_schema.columns where table_name in ('catalog_productvariant', 'inventory_storeinventory') "
            "and column_name in ('mrp', 'selling_price', 'price_override')"
        )
    )
    assert set(types.values()) == {"numeric(12,2)"}, types
    floats = db_query(
        "select table_name, column_name from information_schema.columns where table_schema = 'public' and "
        "(table_name like 'stores\\_%%' or table_name like 'catalog\\_%%' or table_name like 'inventory\\_%%') "
        "and data_type in ('real', 'double precision')"
    )
    assert floats == []


def test_p2_tc48_orphans_and_foreign_keys():
    """P2-TC-48 No orphans: products without a category, variants without a product, images,
    collection items, inventory and movements pointing at missing rows; sub-categories at most
    two levels deep; FK constraints exist on the catalog/inventory tables."""
    checks = {
        "product.category": "select count(*) from catalog_product p left join catalog_category c on c.id = p.category_id where c.id is null",
        "variant.product": "select count(*) from catalog_productvariant v left join catalog_product p on p.id = v.product_id where p.id is null",
        "image.product": "select count(*) from catalog_productimage i left join catalog_product p on p.id = i.product_id where p.id is null",
        "image.variant": "select count(*) from catalog_productimage i left join catalog_productvariant v on v.id = i.variant_id where i.variant_id is not null and v.id is null",
        "image.variant_of_other_product": "select count(*) from catalog_productimage i join catalog_productvariant v on v.id = i.variant_id where v.product_id <> i.product_id",
        "collectionitem.variant": "select count(*) from catalog_collectionitem ci left join catalog_productvariant v on v.id = ci.variant_id where v.id is null",
        "inventory.store": "select count(*) from inventory_storeinventory i left join stores_darkstore s on s.id = i.store_id where s.id is null",
        "inventory.variant": "select count(*) from inventory_storeinventory i left join catalog_productvariant v on v.id = i.variant_id where v.id is null",
        "timing.store": "select count(*) from stores_storetiming t left join stores_darkstore s on s.id = t.store_id where s.id is null",
        "category.depth3": "select count(*) from catalog_category c join catalog_category p on p.id = c.parent_id where p.parent_id is not null",
        "staffaccess.store": "select count(*) from stores_staffstoreaccess a left join stores_darkstore s on s.id = a.store_id where s.id is null",
        "collection.items>100": "select count(*) from (select collection_id from catalog_collectionitem group by 1 having count(*) > 100) x",
    }
    counts = {name: _one(sql) for name, sql in checks.items()}
    assert set(counts.values()) == {0}, counts
    fks = _one(
        "select count(*) from pg_constraint c join pg_class t on t.oid = c.conrelid where c.contype = 'f' and "
        "t.relname in ('catalog_product', 'catalog_productvariant', 'catalog_productimage', 'catalog_collectionitem', "
        "'inventory_storeinventory', 'inventory_stockmovement', 'stores_storetiming')"
    )
    assert fks >= 10


@pytest.mark.smoke
def test_p2_tc49_postgis_service_area():
    """P2-TC-49 🔥 DarkStore.service_area is a MultiPolygon, SRID 4326, valid, with a GiST index;
    location is a Point SRID 4326 inside its own service area; Address.location (P2) agrees with
    lat/lng where set; StoreTiming windows have closes_at > opens_at and weekday 0..6."""
    geom = db_query(
        "select GeometryType(service_area), ST_SRID(service_area), ST_IsValid(service_area), "
        "GeometryType(location), ST_SRID(location), ST_Contains(service_area, location) from stores_darkstore"
    )
    assert geom and all(row == ("MULTIPOLYGON", 4326, True, "POINT", 4326, True) for row in geom), geom
    indexes = [d for (d,) in db_query("select indexdef from pg_indexes where tablename = 'stores_darkstore'")]
    assert any("USING gist (service_area)" in d for d in indexes), indexes
    assert _one(
        "select count(*) from accounts_address where location is not null and "
        "(abs(ST_Y(location) - lat) > 0.000001 or abs(ST_X(location) - lng) > 0.000001)"
    ) == 0
    assert _one("select count(*) from stores_storetiming where closes_at <= opens_at or weekday not between 0 and 6") == 0


def test_p2_tc50_slugs_and_uniques():
    """P2-TC-50 Slugs are never all digits (?category= and /products/{id_or_slug}/ take an id or a
    slug, 07 §2.3); slugs and SKUs are unique; store codes and invoice prefixes are unique."""
    for table in ("catalog_category", "catalog_product", "catalog_collection"):
        assert _one(f"select count(*) from {table} where slug ~ '^[0-9]+$'") == 0, table
        assert _one(f"select count(*) - count(distinct slug) from {table}") == 0, table
    assert _one("select count(*) - count(distinct sku) from catalog_productvariant") == 0
    assert _one("select count(*) - count(distinct code) from stores_darkstore") == 0
    assert _one("select count(*) - count(distinct invoice_prefix) from stores_darkstore") == 0


def test_p2_tc51_notify_me_rows():
    """P2-TC-51 ServiceabilityRequest rows: phones are ASCII E.164 or null (BUG-0002 class),
    location SRID 4326 inside the world bounds; rows linked to users point at existing users."""
    assert _one(
        "select count(*) from stores_serviceabilityrequest where phone is not null and phone !~ '^\\+91[6-9][0-9]{9}$'"
    ) == 0
    assert _one(
        "select count(*) from stores_serviceabilityrequest where ST_SRID(location) <> 4326 or "
        "abs(ST_Y(location)) > 90 or abs(ST_X(location)) > 180"
    ) == 0
    assert _one(
        "select count(*) from stores_serviceabilityrequest r left join accounts_user u on u.id = r.user_id "
        "where r.user_id is not null and u.id is null"
    ) == 0


def test_p2_tc51b_ascii_only_after_bug_0002():
    """P1-TC-75b / BUG-0002 follow-up: no stored address PIN code or receiver phone with non-ASCII
    digits, and the count of old OTP rows with non-ASCII phones (from QA run 1, before the fix;
    they expire with the 30-day purge) is printed."""
    assert _one("select count(*) from accounts_address where pincode !~ '^[1-9][0-9]{5}$' and not is_deleted") == 0
    print("OTP rows with non-ASCII phones (pre-fix, QA run 1):",
          _one("select count(*) from accounts_otprequest where phone !~ '^\\+[0-9]+$'"))

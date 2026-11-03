"""Inventory admin (05 §2 "Inventory", 05 §3 "Inventory adjust" / "Inventory view").

- Role matrix for every screen and action: the 7 roles, a superuser flag, a non-staff user and an
  anonymous visitor.
- Store scoping: Store Manager / Store Staff see only their stores. Another store's row is
  "missing" (admin change view: redirect to the index; custom and history views: 404).
- Stock changes only through `apps.inventory.services`: `on_hand` / `reserved` are never
  editable, the ledger is read-only for everyone, and every change writes a StockMovement.
"""

import pytest
from django.contrib import admin
from django.contrib.auth.models import Group
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection
from django.test import Client, RequestFactory
from django.test.utils import CaptureQueriesContext
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory
from apps.catalog.tests.factories import VariantFactory
from apps.inventory.admin import StockMovementAdmin, parse_inward_csv
from apps.inventory.models import MovementType, StockMovement, StoreInventory
from apps.inventory.tests.factories import stock
from apps.ops_console.tests.helpers import (
    INVENTORY_ADJUST_ROLES,
    INVENTORY_VIEW_ROLES,
    PRINCIPALS,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def shop():
    """Two stores with one SKU each; the store-scoped roles in the tests get `own` only."""
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    variant = VariantFactory(sku="JV-CAN-1L", sap_item_code="SAP-1001")
    return {
        "own": own,
        "other": other,
        "variant": variant,
        "own_row": stock(own, variant, 10),
        "other_row": stock(other, variant, 7),
    }


def manager_of(store, role=roles.STORE_MANAGER):
    user = staff_in_role(role)
    grant_store_access(user, store)
    return user


def ledger(store, variant):
    return StockMovement.objects.filter(store=store, variant=variant)


# --------------------------------------------------------------------------- role matrix

PAGES = {
    # url name -> (allowed principals, needs the own row id)
    "admin:inventory_storeinventory_changelist": (INVENTORY_VIEW_ROLES, False),
    "admin:inventory_storeinventory_change": (INVENTORY_VIEW_ROLES, True),
    "admin:inventory_storeinventory_history": (INVENTORY_VIEW_ROLES, True),
    "admin:inventory_storeinventory_adjust": (INVENTORY_ADJUST_ROLES, True),
    "admin:inventory_storeinventory_inward": (INVENTORY_ADJUST_ROLES, False),
    "admin:inventory_stockmovement_changelist": (INVENTORY_VIEW_ROLES, False),
}


@pytest.mark.parametrize("url_name", sorted(PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_page_matrix(client, shop, principal, url_name):
    allowed, with_row = PAGES[url_name]
    login_with_stores(client, principal, shop["own"])
    args = [shop["own_row"].pk] if with_row else []
    response = client.get(reverse(url_name, args=args))
    expected = expected_status(principal, allowed)
    assert response.status_code == expected, (principal, url_name)
    if expected == 302:
        assert reverse("admin:login") in response["Location"]


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_ledger_entry_is_view_only(client, shop, principal):
    login_with_stores(client, principal, shop["own"])
    movement = ledger(shop["own"], shop["variant"]).get()
    response = client.get(reverse("admin:inventory_stockmovement_change", args=[movement.pk]))
    assert response.status_code == expected_status(principal, INVENTORY_VIEW_ROLES)
    if response.status_code == 200:
        assert b'name="delta"' not in response.content
        assert b'name="_save"' not in response.content


# --------------------------------------------------------------------------- store scoping


class TestStoreScoping:
    @pytest.mark.parametrize("role", [roles.STORE_MANAGER, roles.STORE_STAFF])
    def test_list_shows_only_own_store(self, client, shop, role):
        client.force_login(manager_of(shop["own"], role))
        response = client.get(reverse("admin:inventory_storeinventory_changelist"))
        rows = list(response.context["cl"].result_list)
        assert [row.pk for row in rows] == [shop["own_row"].pk]
        html = response.content.decode()
        assert "NOI-18" not in html  # not even in the store filter
        assert "Jivo Noida 18" not in html

    @pytest.mark.parametrize("role", [roles.STORE_MANAGER, roles.STORE_STAFF])
    def test_other_store_row_answers_like_a_missing_one(self, client, shop, role):
        client.force_login(manager_of(shop["own"], role))
        other = shop["other_row"].pk
        change = client.get(reverse("admin:inventory_storeinventory_change", args=[other]))
        assert change.status_code == 404
        save = client.post(
            reverse("admin:inventory_storeinventory_change", args=[other]),
            {"is_available": "", "low_stock_threshold": "1", "_save": "Save"},
        )
        assert save.status_code == 404
        history = client.get(reverse("admin:inventory_storeinventory_history", args=[other]))
        assert history.status_code == 404
        version = shop["other_row"].history.latest().history_id
        version_page = client.get(
            reverse("admin:inventory_storeinventory_simple_history", args=[other, version])
        )
        assert version_page.status_code == 404

    def test_other_store_adjust_is_404_and_changes_nothing(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        url = reverse("admin:inventory_storeinventory_adjust", args=[shop["other_row"].pk])
        assert client.get(url).status_code == 404
        response = client.post(url, {"kind": "inward", "quantity": "5", "reason": "GRN 1"})
        assert response.status_code == 404
        shop["other_row"].refresh_from_db()
        assert shop["other_row"].on_hand == 7
        assert ledger(shop["other"], shop["variant"]).count() == 1

    def test_ledger_shows_only_own_store(self, client, shop):
        client.force_login(manager_of(shop["own"], roles.STORE_STAFF))
        response = client.get(reverse("admin:inventory_stockmovement_changelist"))
        stores = {movement.store_id for movement in response.context["cl"].result_list}
        assert stores == {shop["own"].pk}
        other = ledger(shop["other"], shop["variant"]).get()
        detail = client.get(reverse("admin:inventory_stockmovement_change", args=[other.pk]))
        assert detail.status_code == 404
        history = client.get(reverse("admin:inventory_stockmovement_history", args=[other.pk]))
        assert history.status_code == 404

    def test_inward_refuses_another_store(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        response = client.post(
            reverse("admin:inventory_storeinventory_inward"),
            {"store": shop["other"].pk, "pasted": "JV-CAN-1L,5", "reason": "GRN 2"},
        )
        assert response.status_code == 200
        assert "Select a valid choice" in response.content.decode()
        assert ledger(shop["other"], shop["variant"]).count() == 1

    def test_global_roles_see_every_store(self, client, shop):
        client.force_login(staff_in_role(roles.FINANCE))
        response = client.get(reverse("admin:inventory_storeinventory_changelist"))
        assert {row.store_id for row in response.context["cl"].result_list} == {
            shop["own"].pk,
            shop["other"].pk,
        }


# --------------------------------------------------------------------------- adjustments


class TestAdjustThroughTheService:
    def url(self, row):
        return reverse("admin:inventory_storeinventory_adjust", args=[row.pk])

    def test_inward_adds_and_writes_the_ledger(self, client, shop):
        user = manager_of(shop["own"])
        client.force_login(user)
        response = client.post(
            self.url(shop["own_row"]), {"kind": "inward", "quantity": "24", "reason": "GRN 77"}
        )
        assert response.status_code == 302
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].on_hand == 34
        movement = ledger(shop["own"], shop["variant"]).order_by("-id").first()
        assert (movement.type, movement.delta, movement.on_hand_after) == (
            MovementType.INWARD,
            24,
            34,
        )
        assert movement.created_by == user
        assert movement.reason == "GRN 77"

    def test_damage_subtracts(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        client.post(
            self.url(shop["own_row"]), {"kind": "damage", "quantity": "3", "reason": "Leaking"}
        )
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].on_hand == 7
        assert ledger(shop["own"], shop["variant"]).order_by("-id").first().delta == -3

    def test_audit_count_sets_on_hand(self, client, shop):
        client.force_login(SuperUserFactory())
        client.post(
            self.url(shop["own_row"]), {"kind": "count", "quantity": "4", "reason": "Cycle count"}
        )
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].on_hand == 4
        last = ledger(shop["own"], shop["variant"]).order_by("-id").first()
        assert (last.type, last.delta) == (MovementType.AUDIT_ADJUSTMENT, -6)

    def test_service_error_is_shown_on_the_form(self, client, shop):
        """On hand cannot drop below the units reserved by orders (the service's rule)."""
        row = stock(shop["own"], shop["variant"], 0, reserved=8)  # orders arrive in P3
        client.force_login(manager_of(shop["own"]))
        response = client.post(
            self.url(row), {"kind": "damage", "quantity": "5", "reason": "Broken"}
        )
        assert response.status_code == 200
        assert "on hand cannot go below that" in response.content.decode()
        row.refresh_from_db()
        assert row.on_hand == 10
        assert ledger(shop["own"], shop["variant"]).count() == 1

    def test_zero_quantity_and_missing_reason_are_refused(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        response = client.post(self.url(shop["own_row"]), {"kind": "inward", "quantity": "0"})
        html = response.content.decode()
        assert response.status_code == 200
        assert "This field is required" in html  # reason
        response = client.post(
            self.url(shop["own_row"]), {"kind": "inward", "quantity": "0", "reason": "x"}
        )
        assert "The quantity cannot be zero." in response.content.decode()
        assert ledger(shop["own"], shop["variant"]).count() == 1

    @pytest.mark.parametrize("role", [roles.STORE_STAFF, roles.OPS, roles.FINANCE])
    def test_view_roles_cannot_post_adjustments(self, client, shop, role):
        client.force_login(manager_of(shop["own"], role))
        response = client.post(
            self.url(shop["own_row"]), {"kind": "inward", "quantity": "5", "reason": "x"}
        )
        assert response.status_code == 403
        assert ledger(shop["own"], shop["variant"]).count() == 1


class TestStockFieldsAreNeverEditable:
    def change_url(self, row):
        return reverse("admin:inventory_storeinventory_change", args=[row.pk])

    def test_posting_on_hand_and_reserved_changes_nothing(self, client, shop):
        """A superuser saves the change form with forged stock values: only the settings move,
        through the services, and the ledger is untouched."""
        client.force_login(SuperUserFactory())
        row = shop["own_row"]
        response = client.post(
            self.change_url(row),
            {
                "is_available": "on",
                "low_stock_threshold": "9",
                "rack_location": "A-3",
                "price_override": "",
                "on_hand": "999",
                "reserved": "5",
                "_save": "Save",
            },
        )
        assert response.status_code == 302, response.content.decode()[:2000]
        row.refresh_from_db()
        assert (row.on_hand, row.reserved) == (10, 0)
        assert (row.low_stock_threshold, row.rack_location) == (9, "A-3")
        assert ledger(shop["own"], shop["variant"]).count() == 1

    def test_price_override_above_mrp_shows_the_service_message(self, client, shop):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        row = shop["own_row"]
        response = client.post(self.change_url(row), {"price_override": "999.00", "_save": "Save"})
        assert response.status_code == 200
        assert "Cannot be above the MRP (349.00)." in response.content.decode()
        row.refresh_from_db()
        assert row.price_override is None

    def test_catalog_manager_sets_a_store_price(self, client, shop):
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        row = shop["own_row"]
        response = client.post(self.change_url(row), {"price_override": "299.00", "_save": "Save"})
        assert response.status_code == 302
        row.refresh_from_db()
        assert str(row.price_override) == "299.00"
        assert row.history.latest().price_override == row.price_override  # audit trail

    def test_store_manager_cannot_change_the_price(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        row = shop["own_row"]
        page = client.get(self.change_url(row)).content.decode()
        assert 'name="price_override"' not in page
        assert 'name="low_stock_threshold"' in page
        client.post(
            self.change_url(row),
            {
                "is_available": "on",
                "low_stock_threshold": "5",
                "rack_location": "",
                "price_override": "1.00",
                "_save": "Save",
            },
        )
        row.refresh_from_db()
        assert row.price_override is None

    def test_catalog_manager_post_changes_only_the_price(self, client, shop):
        """Tamper: the Catalog Manager's form holds only `price_override`; forged values for
        the other settings and the stock numbers are ignored."""
        client.force_login(staff_in_role(roles.CATALOG_MANAGER))
        row = shop["own_row"]
        before = (row.is_available, row.low_stock_threshold, row.rack_location)
        response = client.post(
            self.change_url(row),
            {
                "price_override": "299.00",
                # is_available omitted: an unticked checkbox, i.e. "switch off"
                "low_stock_threshold": "1",
                "rack_location": "FORGED",
                "on_hand": "999",
                "reserved": "9",
                "_save": "Save",
            },
        )
        assert response.status_code == 302
        row.refresh_from_db()
        assert str(row.price_override) == "299.00"
        assert (row.is_available, row.low_stock_threshold, row.rack_location) == before
        assert (row.on_hand, row.reserved) == (10, 0)
        assert ledger(shop["own"], shop["variant"]).count() == 1

    def test_store_staff_post_is_refused(self, client, shop):
        """Tamper: Store Staff may change nothing here, so a forged change POST is a 403."""
        client.force_login(manager_of(shop["own"], roles.STORE_STAFF))
        row = shop["own_row"]
        response = client.post(
            self.change_url(row),
            {
                "low_stock_threshold": "1",
                "rack_location": "FORGED",
                "price_override": "1.00",
                "on_hand": "999",
                "_save": "Save",
            },
        )
        assert response.status_code == 403
        row.refresh_from_db()
        assert (row.is_available, row.low_stock_threshold, row.rack_location) == (True, 5, "")
        assert (row.price_override, row.on_hand) == (None, 10)

    def test_a_change_between_check_and_save_is_a_message_not_a_500(
        self, client, shop, monkeypatch
    ):
        """The form validates (dry run and model checks pass), then another user lowers the MRP
        below the new store price before the real save. Nothing is saved, not even the settings
        applied before the failing one, and the page says why."""
        from decimal import Decimal

        from apps.catalog.models import ProductVariant
        from apps.inventory import admin as inventory_admin

        real_apply = inventory_admin.apply_settings
        calls = []

        def apply_settings(*args, **kwargs):
            calls.append(args)
            if len(calls) == 2:  # 1: the form's dry run; 2: save_model, after validation
                ProductVariant.objects.filter(pk=shop["variant"].pk).update(
                    mrp=Decimal("250.00"), selling_price=Decimal("199.00")
                )
            return real_apply(*args, **kwargs)

        monkeypatch.setattr(inventory_admin, "apply_settings", apply_settings)
        client.force_login(staff_in_role(roles.SUPER_ADMIN))
        row = shop["own_row"]
        history_before = row.history.count()
        url = self.change_url(row)
        response = client.post(
            url,
            {
                # is_available unticked (switch off) is applied before the price fails
                "low_stock_threshold": "7",
                "rack_location": "B-1",
                "price_override": "299.00",
                "_save": "Save",
            },
        )
        assert response.status_code == 302
        assert len(calls) == 2
        assert response["Location"] == url
        page = client.get(url).content.decode()
        assert "Not saved: Cannot be above the MRP (250.00)." in page
        assert "was changed successfully" not in page
        row.refresh_from_db()
        assert row.price_override is None
        assert (row.is_available, row.low_stock_threshold, row.rack_location) == (True, 5, "")
        assert row.history.count() == history_before  # the rolled-back save left no history

    def test_view_roles_get_a_read_only_page(self, client, shop):
        client.force_login(manager_of(shop["own"], roles.STORE_STAFF))
        page = client.get(self.change_url(shop["own_row"])).content.decode()
        for field in ("is_available", "low_stock_threshold", "price_override", "on_hand"):
            assert f'name="{field}"' not in page

    def test_rows_cannot_be_added_or_deleted(self, client, shop):
        client.force_login(SuperUserFactory())
        assert client.get(reverse("admin:inventory_storeinventory_add")).status_code == 403
        delete = reverse("admin:inventory_storeinventory_delete", args=[shop["own_row"].pk])
        assert client.get(delete).status_code == 403

    def test_history_is_never_a_revert(self, client, shop):
        client.force_login(SuperUserFactory())
        row = shop["own_row"]
        version = row.history.earliest().history_id
        url = reverse("admin:inventory_storeinventory_simple_history", args=[row.pk, version])
        assert client.get(url).status_code == 200
        assert client.post(url, {"low_stock_threshold": "1"}).status_code == 403


def _request_for(user):
    request = RequestFactory().get("/admin/")
    request.user = user
    return request


def test_no_admin_exposes_stock_numbers_or_edits_the_ledger():
    """Guard: walks every registered ModelAdmin, its inlines and import resources. Fails if any
    of them makes `on_hand` / `reserved` editable or allows a StockMovement to be written."""
    superuser = SuperUserFactory()
    request = _request_for(superuser)
    for model, model_admin in admin.site._registry.items():
        targets = [(model, model_admin)]
        targets += [(inline.model, inline) for inline in model_admin.get_inline_instances(request)]
        for target_model, target in targets:
            if target_model is StoreInventory:
                row = None
                form = (
                    target.get_form(request, row)
                    if hasattr(target, "get_form")
                    else target.get_formset(request, row).form
                )
                assert not {"on_hand", "reserved"} & set(form.base_fields), target
                readonly = set(target.get_readonly_fields(request, row))
                assert {"on_hand", "reserved"} <= readonly, target
                editable_in_list = set(getattr(target, "list_editable", ()) or ())
                assert not {"on_hand", "reserved"} & editable_in_list, target
            if target_model is StockMovement:
                assert not target.has_add_permission(request), target
                assert not target.has_change_permission(request), target
                assert not target.has_delete_permission(request), target
        for resource in getattr(model_admin, "resource_classes", []) or []:
            assert resource._meta.model not in (StoreInventory, StockMovement), resource
    ledger_admin = admin.site._registry[StockMovement]
    assert isinstance(ledger_admin, StockMovementAdmin)
    assert ledger_admin.get_actions(request) == {}


def test_ledger_writes_are_refused_over_http(client, shop):
    client.force_login(SuperUserFactory())
    movement = ledger(shop["own"], shop["variant"]).get()
    change = reverse("admin:inventory_stockmovement_change", args=[movement.pk])
    assert client.post(change, {"delta": "500", "reason": "forged"}).status_code == 403
    delete = reverse("admin:inventory_stockmovement_delete", args=[movement.pk])
    assert client.post(delete, {"post": "yes"}).status_code == 403
    assert client.get(reverse("admin:inventory_stockmovement_add")).status_code == 403
    movement.refresh_from_db()
    assert movement.delta == 10


# --------------------------------------------------------------------------- availability actions


class TestAvailabilityActions:
    URL = "admin:inventory_storeinventory_changelist"

    def test_manager_switches_own_items_off(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        response = client.post(
            reverse(self.URL),
            {"action": "mark_unavailable", "_selected_action": [shop["own_row"].pk]},
        )
        assert response.status_code == 302
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].is_available is False

    def test_other_store_rows_in_the_post_are_ignored(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        client.post(
            reverse(self.URL),
            {"action": "mark_unavailable", "_selected_action": [shop["other_row"].pk]},
        )
        shop["other_row"].refresh_from_db()
        assert shop["other_row"].is_available is True

    @pytest.mark.parametrize("role", [roles.STORE_STAFF, roles.OPS, roles.CATALOG_MANAGER])
    def test_view_roles_cannot_run_it(self, client, shop, role):
        client.force_login(manager_of(shop["own"], role))
        response = client.post(
            reverse(self.URL),
            {"action": "mark_unavailable", "_selected_action": [shop["own_row"].pk]},
        )
        # The role has no actions at all, so the POST is just the list page again.
        assert response.status_code == 200
        assert "mark_unavailable" not in response.content.decode()
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].is_available is True


# --------------------------------------------------------------------------- bulk inward (CSV)


def csv_upload(text: str) -> SimpleUploadedFile:
    return SimpleUploadedFile("inward.csv", text.encode("utf-8-sig"), content_type="text/csv")


class TestBulkInward:
    URL = "admin:inventory_storeinventory_inward"

    def test_preview_is_a_dry_run(self, client, shop):
        second = VariantFactory(sku="JV-OLV-1L")
        client.force_login(manager_of(shop["own"]))
        response = client.post(
            reverse(self.URL),
            {
                "store": shop["own"].pk,
                "file": csv_upload("sku,quantity\nJV-CAN-1L,24\nJV-OLV-1L,6\n"),
                "reason": "GRN 501",
            },
        )
        assert response.status_code == 200
        preview = response.context["preview"]
        assert [(row.sku, row.quantity, row.before, row.after) for row in preview] == [
            ("JV-CAN-1L", 24, 10, 34),
            ("JV-OLV-1L", 6, 0, 6),
        ]
        # Nothing changed: no movement, no new inventory row.
        assert StockMovement.objects.count() == 2
        assert not StoreInventory.objects.filter(variant=second).exists()
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].on_hand == 10

    def test_confirm_applies_through_the_service(self, client, shop):
        VariantFactory(sku="JV-OLV-1L", sap_item_code="SAP-2002")
        client.force_login(manager_of(shop["own"]))
        response = client.post(
            reverse(self.URL),
            {
                "confirm": "yes",
                "store": shop["own"].pk,
                "payload": "sku,quantity\nJV-CAN-1L,24\nSAP-2002,6\n",
                "reason": "GRN 501",
            },
        )
        assert response.status_code == 302
        assert response["Location"].endswith(f"?store={shop['own'].pk}")
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].on_hand == 34
        olive = StoreInventory.objects.get(store=shop["own"], variant__sku="JV-OLV-1L")
        assert olive.on_hand == 6
        assert StockMovement.objects.filter(type=MovementType.INWARD, reason="GRN 501").count() == 2

    def test_preview_page_hands_its_rows_to_the_confirm_step(self, client, shop):
        """Round trip through the rendered preview: the hidden store, reason and payload the
        page carries are exactly what the confirm POST needs."""
        import html as html_lib
        import re

        client.force_login(manager_of(shop["own"]))
        preview = client.post(
            reverse(self.URL),
            {
                "store": shop["own"].pk,
                "file": csv_upload("sku,quantity\nJV-CAN-1L,24\n"),
                "reason": "GRN 900",
            },
        ).content.decode()
        form = preview[preview.index('data-testid="inward-preview"') :]
        hidden = dict(re.findall(r'<input type="hidden" name="(\w+)" value="([^"]*)"', form))
        payload = re.search(r'<textarea name="payload"[^>]*>(.*?)</textarea>', form, re.S)
        data = {
            "confirm": hidden["confirm"],
            "store": hidden["store"],
            "reason": html_lib.unescape(hidden["reason"]),
            "payload": html_lib.unescape(payload.group(1)),
        }
        response = client.post(reverse(self.URL), data)
        assert response.status_code == 302
        shop["own_row"].refresh_from_db()
        assert shop["own_row"].on_hand == 34
        assert ledger(shop["own"], shop["variant"]).filter(reason="GRN 900").count() == 1

    def test_unknown_sku_is_reported_and_nothing_applies(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        response = client.post(
            reverse(self.URL),
            {
                "store": shop["own"].pk,
                "pasted": "JV-CAN-1L,5\nNOPE-1,3",
                "reason": "GRN 9",
            },
        )
        assert response.status_code == 200
        assert "line 2: unknown SKU &#x27;NOPE-1&#x27;." in response.content.decode()
        assert response.context["preview"] is None
        assert StockMovement.objects.count() == 2

    def test_bad_quantities_are_reported_per_line(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        response = client.post(
            reverse(self.URL),
            {"store": shop["own"].pk, "pasted": "JV-CAN-1L,2.5\nJV-CAN-1L", "reason": "x"},
        )
        html = response.content.decode()
        assert "line 1: the quantity must be a whole number above 0." in html
        assert "line 2: expected 2 values (sku,quantity), found 1." in html

    def test_store_choices_are_the_adjustable_stores(self, client, shop):
        client.force_login(manager_of(shop["own"]))
        form = client.get(reverse(self.URL)).context["form"]
        assert list(form.fields["store"].queryset) == [shop["own"]]

    def test_view_role_cannot_post(self, client, shop):
        client.force_login(manager_of(shop["own"], roles.STORE_STAFF))
        response = client.post(
            reverse(self.URL),
            {"confirm": "yes", "store": shop["own"].pk, "payload": "JV-CAN-1L,5", "reason": "x"},
        )
        assert response.status_code == 403
        assert StockMovement.objects.count() == 2


def test_csv_parser_accepts_optional_header_and_rejects_bad_lines():
    rows = parse_inward_csv("JV-A,1\r\nJV-B,20\r\n")
    assert [(row.sku, row.quantity) for row in rows] == [("JV-A", 1), ("JV-B", 20)]
    assert len(parse_inward_csv("SKU, Quantity\nJV-A,1")) == 1
    with pytest.raises(Exception, match="no rows"):
        parse_inward_csv("sku,quantity\n")
    with pytest.raises(Exception, match="line 1"):
        parse_inward_csv(",3")


# --------------------------------------------------------------------------- CSRF


class TestCsrf:
    """Every admin POST needs the CSRF token (the test client skips the check by default)."""

    def csrf_client(self, user):
        client = Client(enforce_csrf_checks=True)
        client.force_login(user)
        return client

    def test_adjust_without_token_is_refused(self, shop):
        client = self.csrf_client(manager_of(shop["own"]))
        url = reverse("admin:inventory_storeinventory_adjust", args=[shop["own_row"].pk])
        response = client.post(url, {"kind": "inward", "quantity": "5", "reason": "x"})
        assert response.status_code == 403
        assert ledger(shop["own"], shop["variant"]).count() == 1
        token = client.get(url).cookies["csrftoken"].value
        response = client.post(
            url,
            {"kind": "inward", "quantity": "5", "reason": "x", "csrfmiddlewaretoken": token},
        )
        assert response.status_code == 302
        assert ledger(shop["own"], shop["variant"]).count() == 2

    def test_inward_without_token_is_refused(self, shop):
        client = self.csrf_client(manager_of(shop["own"]))
        response = client.post(
            reverse("admin:inventory_storeinventory_inward"),
            {"confirm": "yes", "store": shop["own"].pk, "payload": "JV-CAN-1L,5", "reason": "x"},
        )
        assert response.status_code == 403
        assert StockMovement.objects.count() == 2


# --------------------------------------------------------------------------- query counts


def _list_queries(client, url) -> int:
    with CaptureQueriesContext(connection) as queries:
        assert client.get(url).status_code == 200
    return len(queries)


def test_inventory_list_queries_do_not_grow(client, shop, django_assert_max_num_queries):
    client.force_login(manager_of(shop["own"]))
    url = reverse("admin:inventory_storeinventory_changelist")
    few = _list_queries(client, url)
    for _ in range(30):
        stock(shop["own"], VariantFactory(), 3)
    many = _list_queries(client, url)
    assert few == many
    with django_assert_max_num_queries(few):
        client.get(url)


def test_ledger_list_queries_do_not_grow(client, shop):
    client.force_login(staff_in_role(roles.OPS))
    url = reverse("admin:inventory_stockmovement_changelist")
    few = _list_queries(client, url)
    for _ in range(30):
        stock(shop["other"], VariantFactory(), 2)
    assert _list_queries(client, url) == few


def test_store_filter_lists_only_visible_stores(client, shop):
    manager = manager_of(shop["own"])
    group = Group.objects.get(name=roles.STORE_MANAGER)
    assert manager.groups.filter(pk=group.pk).exists()
    client.force_login(manager)
    html = client.get(reverse("admin:inventory_stockmovement_changelist")).content.decode()
    assert "GGN-01" in html
    assert "NOI-18" not in html

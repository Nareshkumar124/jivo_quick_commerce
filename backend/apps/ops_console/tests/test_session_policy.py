"""BUG-0006 on the Ops Console (05 §5): staff sessions end 8 h after login, and admin roles also
after 2 h idle (`apps.accounts.middleware`); ops.js tags automatic htmx refreshes with
`X-Ops-Background` so they can be told apart from user activity."""

from datetime import timedelta
from pathlib import Path

import pytest
from django.contrib.auth import SESSION_KEY
from django.contrib.staticfiles import finders
from django.urls import reverse
from freezegun import freeze_time

from apps.accounts import roles
from apps.ops_console.access import BACKGROUND_HEADER, is_background
from apps.ops_console.tests.helpers import login_with_stores
from apps.stores.tests.factories import DarkStoreFactory

START = "2026-11-03 04:00:00"  # 09:30 IST


def _signed_in(client) -> bool:
    return SESSION_KEY in client.session


@pytest.mark.django_db
def test_ops_admin_role_signed_out_after_2_hours_idle(client):
    with freeze_time(START) as frozen:
        login_with_stores(client, roles.OPS)
        assert client.get(reverse("ops:dashboard")).status_code == 200
        frozen.tick(timedelta(hours=2, minutes=1))
        response = client.get(reverse("ops:dashboard"))
        assert response.status_code == 302
        assert not _signed_in(client)


@pytest.mark.django_db
def test_ops_store_staff_signed_out_after_8_hours_however_active(client):
    store = DarkStoreFactory()
    with freeze_time(START) as frozen:
        login_with_stores(client, roles.STORE_STAFF, store)
        frozen.tick(timedelta(hours=7, minutes=59))
        assert client.get(reverse("ops:packing", args=[store.code])).status_code == 200
        frozen.tick(timedelta(minutes=2))
        assert client.get(reverse("ops:packing", args=[store.code])).status_code == 302
        assert not _signed_in(client)


def test_background_refreshes_are_tagged(rf):
    script = Path(finders.find("ops/js/ops.js")).read_text(encoding="utf-8")
    assert "htmx:configRequest" in script
    assert f'"{BACKGROUND_HEADER}"' in script
    assert '"ops:live": true' in script
    assert '"ops:refresh": true' in script
    poll = rf.get("/ops/", HTTP_HX_REQUEST="true", HTTP_X_OPS_BACKGROUND="1")
    click = rf.get("/ops/", HTTP_HX_REQUEST="true")
    plain = rf.get("/ops/", HTTP_X_OPS_BACKGROUND="1")  # not htmx: a page load is activity
    assert is_background(poll)
    assert not is_background(click)
    assert not is_background(plain)

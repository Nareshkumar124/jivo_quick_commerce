"""Release security review (2026-11-16): the report views check the "any report" capability at
the view layer (the service still checks each report), and the export redirect is rebuilt with
`urlencode` from the form's own fields, never from a client-supplied query string."""

from urllib.parse import parse_qs, urlsplit

import pytest
from django.urls import reverse
from freezegun import freeze_time

from apps.accounts import roles
from apps.ops_console import capabilities
from apps.ops_console.tests.helpers import login_with_stores
from apps.reports import services
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

TODAY = "2026-11-03"
NOON_IST = "2026-11-03T06:30:00Z"
# Staff roles with no report permission at all (05 §3 "Reports").
NO_REPORT_ROLES = (roles.SUPPORT, roles.STORE_STAFF)
EVIL = "next=https://evil.example/&x=1%0D%0ASet-Cookie:a=b"


def _urls():
    return [
        ("get", reverse("ops:reports")),
        ("get", reverse("ops:report", args=["sales_summary"])),
        ("post", reverse("ops:report-export", args=["sales_summary"])),
        ("get", reverse("ops:report-export-download", args=[1])),
    ]


@pytest.fixture
def service_never_called(monkeypatch):
    def boom(*args, **kwargs):
        raise AssertionError("the view layer must refuse before the reports service runs")

    for name in (
        "available_reports",
        "user_exports",
        "export_download_url",
        "request_export",
        "run_report",
        "report_csv",
    ):
        monkeypatch.setattr(services, name, boom)


@pytest.mark.parametrize("principal", NO_REPORT_ROLES)
def test_report_views_refuse_at_the_view_layer(client, principal, service_never_called):
    store = DarkStoreFactory()
    user = login_with_stores(client, principal, store)
    assert not capabilities.allowed(user, capabilities.PRODUCT_REPORT)
    for method, url in _urls():
        response = getattr(client, method)(url)
        assert response.status_code == 403, url


@pytest.mark.parametrize(
    "principal", [roles.FINANCE, roles.CATALOG_MANAGER, roles.OPS, roles.STORE_MANAGER]
)
def test_report_index_still_open_for_report_roles(client, principal):
    login_with_stores(client, principal, DarkStoreFactory())
    assert client.get(reverse("ops:reports")).status_code == 200


@freeze_time(NOON_IST)
def test_export_redirect_is_built_from_the_validated_filters(client, monkeypatch):
    store = DarkStoreFactory(code="AAA-01")
    calls = []
    monkeypatch.setattr(services, "request_export", lambda *a, **k: calls.append(k))
    login_with_stores(client, roles.STORE_MANAGER, store)
    response = client.post(
        reverse("ops:report-export", args=["sales_summary"]),
        {"date_from": TODAY, "date_to": TODAY, "store": store.pk, "query": EVIL},
    )
    assert response.status_code == 302
    location = urlsplit(response["Location"])
    assert location.path == reverse("ops:report", args=["sales_summary"])
    assert parse_qs(location.query) == {
        "date_from": [TODAY],
        "date_to": [TODAY],
        "store": [str(store.pk)],
    }
    assert "evil" not in response["Location"]
    assert len(calls) == 1
    assert calls[0]["store_id"] == store.pk


@freeze_time(NOON_IST)
def test_export_redirect_without_store_and_on_invalid_filters(client, monkeypatch):
    monkeypatch.setattr(services, "request_export", lambda *a, **k: None)
    login_with_stores(client, roles.FINANCE)
    url = reverse("ops:report-export", args=["sales_summary"])
    ok = client.post(url, {"date_from": TODAY, "date_to": TODAY, "query": "evil=1"})
    assert parse_qs(urlsplit(ok["Location"]).query) == {"date_from": [TODAY], "date_to": [TODAY]}

    # Invalid filters keep the posted filter fields (so the page shows the error next to them),
    # percent-encoded; nothing else from the request reaches the Location header.
    bad = client.post(
        url, {"date_from": TODAY, "date_to": "2026-11-01\r\nSet-Cookie: a=b", "query": EVIL}
    )
    assert bad.status_code == 302
    location = urlsplit(bad["Location"])
    assert location.path == reverse("ops:report", args=["sales_summary"])
    assert "\r" not in bad["Location"]
    assert "\n" not in bad["Location"]
    assert "evil" not in bad["Location"]
    assert set(parse_qs(location.query)) <= {"date_from", "date_to", "store"}

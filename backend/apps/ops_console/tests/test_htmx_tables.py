"""HTMX partials and the data table component: search, filters, pagination, query counts."""

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.ops_console.tests.helpers import staff_in_role

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}
URL = "/ops/dashboard/signups/"


@pytest.fixture
def ops_client(client):
    client.force_login(staff_in_role(roles.OPS))
    return client


def test_url_names():
    assert reverse("ops:dashboard") == "/ops/"
    assert reverse("ops:dashboard-signups") == URL


def test_partial_is_only_the_results_region(ops_client):
    UserFactory(name="Meera Shah")
    response = ops_client.get(URL, **HX)
    html = response.content.decode()
    assert response.status_code == 200
    assert "<html" not in html
    assert html.lstrip().startswith('<div id="recent-signups-results"')
    assert "Meera Shah" in html
    assert "<form" not in html  # the search form is never swapped (keeps focus)


def test_dashboard_renders_the_table_with_its_form(ops_client):
    UserFactory(name="Meera Shah")
    html = ops_client.get("/ops/").content.decode()
    assert 'hx-get="/ops/dashboard/signups/"' in html
    assert 'hx-target="#recent-signups-results"' in html
    assert 'name="q"' in html
    assert 'name="status"' in html
    assert "Meera Shah" in html


def test_search_by_name_phone_and_email(ops_client):
    UserFactory(name="Meera Shah", phone="+919811100001")
    UserFactory(name="Ravi Kumar", phone="+919811100002", email="ravi@example.com")
    by_name = ops_client.get(URL, {"q": "meera"}, **HX).content.decode()
    assert "Meera Shah" in by_name
    assert "Ravi Kumar" not in by_name
    by_phone = ops_client.get(URL, {"q": "100002"}, **HX).content.decode()
    assert "Ravi Kumar" in by_phone
    assert "Meera Shah" not in by_phone
    by_email = ops_client.get(URL, {"q": "ravi@exa"}, **HX).content.decode()
    assert "Ravi Kumar" in by_email


def test_status_filter_and_badges(ops_client):
    UserFactory(name="Active One")
    UserFactory(name="Blocked One", is_active=False)
    UserFactory(name="Leaving One", deleted_at=timezone.now())
    html = ops_client.get(URL, {"status": "blocked"}, **HX).content.decode()
    assert "Blocked One" in html
    assert "Active One" not in html
    assert "Leaving One" not in html
    assert "bg-red-100" in html  # the danger badge for "Blocked"


def test_invalid_filter_is_ignored_not_an_error(ops_client):
    UserFactory(name="Meera Shah")
    response = ops_client.get(URL, {"status": "nonsense"}, **HX)
    assert response.status_code == 200
    assert "Meera Shah" in response.content.decode()


def test_empty_results_state(ops_client):
    html = ops_client.get(URL, {"q": "nobody-matches-this"}, **HX).content.decode()
    assert 'data-testid="empty-state"' in html
    assert "No customers found" in html


def test_pagination_keeps_search_and_filters(ops_client):
    for index in range(23):
        UserFactory(name=f"Page Person {index:02d}")
    html = ops_client.get(URL, {"q": "Page Person", "page": 2}, **HX).content.decode()
    assert "11\u201320 of 23" in html
    assert 'aria-current="page">2<' in html
    assert "?q=Page+Person&amp;page=3" in html
    # an out-of-range page falls back to the last page
    last = ops_client.get(URL, {"q": "Page Person", "page": 99}, **HX).content.decode()
    assert "21\u201323 of 23" in last


def test_phone_is_shown_in_full_to_customer_roles(ops_client):
    UserFactory(name="Meera Shah", phone="+919811122233")
    assert "+919811122233" in ops_client.get(URL, **HX).content.decode()


def _query_count(client, rows: int) -> int:
    for index in range(rows):
        UserFactory(name=f"Row {index}")
    with CaptureQueriesContext(connection) as queries:
        response = client.get(URL, **HX)
    assert response.status_code == 200
    return len(queries)


def test_table_queries_do_not_grow_with_rows(client, django_assert_max_num_queries):
    client.force_login(staff_in_role(roles.OPS))
    few = _query_count(client, 2)
    many = _query_count(client, 30)  # 32 customers, one page of 10 shown
    assert few == many
    with django_assert_max_num_queries(8):
        client.get(URL, **HX)


def test_dashboard_query_budget(client, django_assert_max_num_queries):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    for index in range(30):
        UserFactory(name=f"Row {index}")
    with django_assert_max_num_queries(25):
        assert client.get("/ops/").status_code == 200

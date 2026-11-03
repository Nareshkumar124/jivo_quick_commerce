"""Ops dashboard shell (05 §1.1, Phase 1 subset): real data only, IST day boundaries, cards per
permission. Expected numbers are written out by hand or counted with independent ORM queries."""

import re
from datetime import date

import pytest
from django.contrib.auth.models import Group
from django.urls import reverse
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts import roles
from apps.accounts.models import Customer, User
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.cms.models import AppConfig, AppVersionPolicy
from apps.ops_console import selectors
from apps.ops_console.tests.helpers import ROLES, staff_in_role

pytestmark = pytest.mark.django_db

# 2026-11-03 01:30 IST. "Today" in IST is 3 Nov although the UTC date is still 2 Nov.
NOW = "2026-11-02T20:00:00Z"


def create_at(moment: str, **kwargs):
    with freeze_time(moment):
        return UserFactory(**kwargs)


@pytest.fixture
def population():
    """Customers around the IST day and week boundaries, plus accounts that must not count."""
    people = {
        "today": create_at("2026-11-02T19:00:00Z"),  # 3 Nov 00:30 IST: today
        "yesterday": create_at("2026-11-02T18:00:00Z"),  # 2 Nov 23:30 IST: not today
        "week_edge_in": create_at("2026-10-27T18:31:00Z"),  # 28 Oct 00:01 IST: day 7 of 7
        "week_edge_out": create_at("2026-10-27T18:29:00Z"),  # 27 Oct 23:59 IST: outside
        "blocked": create_at("2026-09-01T10:00:00Z", is_active=False),
        "deletion": create_at("2026-09-01T10:00:00Z", deleted_at=timezone.now()),
        "anonymised_today": create_at(
            "2026-11-02T19:30:00Z",
            is_active=False,
            deleted_at=timezone.now(),
            anonymised_at=timezone.now(),
            phone=None,
            name="",
        ),
    }
    with freeze_time("2026-11-02T19:10:00Z"):
        StaffUserFactory()  # staff are never customers
    return people


@freeze_time(NOW)
def test_customer_stats_match_the_database(population):
    stats = selectors.customer_stats()
    assert stats == selectors.CustomerStats(
        total=6,  # 7 customers, the anonymised one excluded
        active=4,  # today, yesterday, week_edge_in, week_edge_out
        blocked=1,
        deletion_requested=1,
        new_today=2,  # "today" and the account created and anonymised today (a sign-up event)
        new_last_7_days=4,  # today, yesterday, week_edge_in, anonymised_today
    )
    # Cross-check against independent queries.
    live = Customer.objects.filter(anonymised_at__isnull=True)
    assert stats.total == live.count()
    assert stats.total == stats.active + stats.blocked + stats.deletion_requested
    assert stats.blocked == live.filter(is_active=False, deleted_at__isnull=True).count()
    assert not User.objects.filter(is_staff=True, pk__in=live.values("pk")).exists()


@freeze_time(NOW)
def test_signups_per_day_buckets_by_ist_day(population):
    series = selectors.signups_per_day(14)
    assert len(series) == 14
    assert series[0][0] == date(2026, 10, 21)
    assert series[-1] == (date(2026, 11, 3), 2)
    by_day = dict(series)
    assert by_day[date(2026, 11, 2)] == 1  # "yesterday": 18:00 UTC is still 2 Nov in IST
    assert by_day[date(2026, 10, 28)] == 1
    assert by_day[date(2026, 10, 27)] == 1  # 18:29 UTC = 23:59 IST on 27 Oct
    assert sum(by_day.values()) == 5


@freeze_time(NOW)
def test_dashboard_renders_real_numbers_for_super_admin(client, population):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    response = client.get(reverse("ops:dashboard"))
    assert response.status_code == 200
    html = response.content.decode()

    def kpi(testid):
        match = re.search(
            rf'data-testid="{testid}".*?data-kpi-value>\s*(\d+)\s*<', html, flags=re.DOTALL
        )
        return int(match.group(1))

    assert kpi("kpi-total") == 6
    assert kpi("kpi-active") == 4
    assert kpi("kpi-blocked") == 1
    assert kpi("kpi-deletion") == 1
    assert kpi("kpi-new-today") == 2
    assert kpi("kpi-new-7d") == 4

    chart = response.context["signups_chart"]
    assert chart["labels"][-1] == "03 Nov"
    assert chart["datasets"][0]["data"][-1] == 2
    assert chart["total"] == 5
    assert 'id="signups-chart-data"' in html
    assert 'data-ops-chart="signups-chart-data"' in html

    assert 'data-testid="staff-roles"' in html
    assert 'data-testid="app-config"' in html


def test_staff_per_role_counts_active_staff(client):
    staff_in_role(roles.OPS)
    staff_in_role(roles.OPS)
    staff_in_role(roles.OPS, is_active=False)  # not counted
    both = staff_in_role(roles.SUPPORT)
    both.groups.add(Group.objects.get(name=roles.FINANCE))  # counts in both roles
    SuperUserFactory()
    StaffUserFactory()  # no role
    data = selectors.staff_per_role()
    counts = dict(data.roles)
    assert list(counts) == list(ROLES)
    assert counts[roles.OPS] == 2
    assert counts[roles.SUPPORT] == 1
    assert counts[roles.FINANCE] == 1
    assert counts[roles.CATALOG_MANAGER] == 0
    assert (
        data.superusers
        == User.objects.filter(is_staff=True, is_active=True, is_superuser=True).count()
    )
    assert (
        data.without_role
        == User.objects.filter(is_staff=True, is_active=True, groups__isnull=True).count()
    )

    admin = staff_in_role(roles.SUPER_ADMIN)
    client.force_login(admin)
    html = client.get(reverse("ops:dashboard")).content.decode()
    assert f'data-role="{roles.OPS}">2<' in html


def test_app_config_card_reads_without_writing(client):
    AppConfig.objects.all().delete()
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    html = client.get(reverse("ops:dashboard")).content.decode()
    assert "Not configured yet" in html
    assert not AppConfig.objects.exists()  # the dashboard never creates the singleton


def test_app_config_card_shows_maintenance_and_versions(client):
    config = AppConfig.load()
    config.maintenance = True
    config.maintenance_message = "Back at 6 AM"
    config.save()
    AppVersionPolicy.objects.update_or_create(
        app="customer",
        platform="android",
        defaults={
            "config": config,
            "min_supported_version": "1.2.0",
            "latest_version": "1.4.0",
            "store_url": "https://play.google.com/store/apps/details?id=in.jivo.quick",
        },
    )
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    html = client.get(reverse("ops:dashboard")).content.decode()
    assert "On: apps blocked" in html
    assert "Back at 6 AM" in html
    assert "1.2.0" in html
    assert "1.4.0" in html


# role -> (customers, staff, app config, stores cards, catalog cards, stock cards)
CARDS = {
    roles.SUPER_ADMIN: (True, True, True, True, True, True),
    roles.OPS: (True, False, False, True, True, True),
    roles.SUPPORT: (True, False, False, False, True, False),
    roles.STORE_MANAGER: (False, False, False, True, True, True),
    roles.STORE_STAFF: (False, False, False, False, True, True),
    roles.CATALOG_MANAGER: (False, False, False, False, True, True),
    roles.FINANCE: (False, False, False, False, False, True),
}


@pytest.mark.parametrize("role", ROLES)
def test_cards_follow_permissions(client, role):
    customers, staff, app_config, stores, catalog, stock_cards = CARDS[role]
    client.force_login(staff_in_role(role))
    html = client.get(reverse("ops:dashboard")).content.decode()
    assert ('data-testid="customer-kpis"' in html) is customers
    assert ('data-testid="signups-chart"' in html) is customers
    assert ('data-testid="staff-roles"' in html) is staff
    assert ('data-testid="app-config"' in html) is app_config
    assert ('data-testid="kpi-stores-active"' in html) is stores
    assert ('data-testid="kpi-products"' in html) is catalog
    assert ('data-testid="kpi-low-stock"' in html) is stock_cards
    assert "No dashboard cards for your role yet" not in html  # every role has a card now


def test_role_without_permissions_gets_the_empty_state(client):
    client.force_login(StaffUserFactory())
    html = client.get(reverse("ops:dashboard")).content.decode()
    assert "No dashboard cards for your role yet" in html
    assert 'data-testid="operations-kpis"' not in html


def test_no_fake_kpis_before_their_phase(client):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    html = client.get(reverse("ops:dashboard")).content.decode().lower()
    html = re.sub(r"[a-z0-9]{32,}", " ", html)  # CSRF tokens: random letters could spell "aov"
    for word in ("gmv", "revenue", "orders today", "online riders", "aov"):
        assert not re.search(rf"\b{word}\b", html), word


def test_kpi_partial_polls_and_matches(client):
    UserFactory()
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse("ops:dashboard-kpis"), HTTP_HX_REQUEST="true")
    html = response.content.decode()
    assert response.status_code == 200
    assert "<html" not in html
    assert 'hx-trigger="every 60s"' in html
    assert 'id="customer-kpis"' in html
    assert (
        response.context["customers"].total
        == Customer.objects.filter(anonymised_at__isnull=True).count()
    )

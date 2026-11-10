"""P7 CMS pages and FAQs admin (05 §2; T-711 PM default: pages Super Admin only, FAQs Super
Admin and Support), by model permissions."""

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.cms.models import FAQ, Page
from apps.ops_console.tests.helpers import (
    PRINCIPALS,
    SUPERUSER,
    expected_status,
    login_as,
)

pytestmark = pytest.mark.django_db

PAGE_ROLES = frozenset({roles.SUPER_ADMIN, SUPERUSER})
FAQ_ROLES = frozenset({roles.SUPER_ADMIN, SUPERUSER, roles.SUPPORT})


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_pages_matrix(client, principal):
    page = Page.objects.create(slug="about", title="About", body_html="<p>Hi</p>")
    login_as(client, principal)
    expected = expected_status(principal, PAGE_ROLES)
    assert client.get(reverse("admin:cms_page_changelist")).status_code == expected
    assert client.get(reverse("admin:cms_page_change", args=[page.pk])).status_code == expected


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_faqs_matrix(client, principal):
    faq = FAQ.objects.create(app="customer", category="Orders", question="Q?", answer="A.")
    login_as(client, principal)
    expected = expected_status(principal, FAQ_ROLES)
    assert client.get(reverse("admin:cms_faq_changelist")).status_code == expected
    assert client.get(reverse("admin:cms_faq_change", args=[faq.pk])).status_code == expected


def test_page_body_is_sanitised_on_save(client):
    login_as(client, roles.SUPER_ADMIN)
    response = client.post(
        reverse("admin:cms_page_add"),
        {
            "slug": "terms",
            "title": "Terms",
            "body_html": '<p>Ok</p><script>alert(1)</script><a href="javascript:x()">x</a>',
            "is_published": "on",
        },
    )
    assert response.status_code == 302
    body = Page.objects.get(slug="terms").body_html
    assert "<script" not in body
    assert "javascript:" not in body
    assert "<p>Ok</p>" in body


def test_support_adds_faq_but_html_is_refused(client):
    login_as(client, roles.SUPPORT)
    data = {"app": "customer", "category": "Orders", "sort_order": 1, "is_active": "on"}
    response = client.post(
        reverse("admin:cms_faq_add"), {**data, "question": "<b>Q</b>", "answer": "A"}
    )
    assert response.status_code == 200
    assert not FAQ.objects.exists()
    response = client.post(
        reverse("admin:cms_faq_add"), {**data, "question": "How long?", "answer": "10 min."}
    )
    assert response.status_code == 302
    assert FAQ.objects.get().question == "How long?"

"""T-711 (P7 lookahead): CMS pages and FAQs (06 §2.7, 07 §2.9; api-requests #35 and #37).

No phase-7 plan file exists yet, so these tests cite T-711 and the api-requests items instead of
P7-TC ids.
"""

import io
from unittest import mock

import pytest
import redis
from django.core.exceptions import ValidationError

from apps.cms import services
from apps.cms.html import sanitize_html
from apps.cms.models import FAQ, PAGE_SLUGS, Page
from apps.cms.seed import seed_pages_and_faqs

PAGES = "/api/v1/pages/"
FAQS = "/api/v1/faqs/"


# --------------------------------------------------------------------------- sanitiser


class TestSanitizer:
    """T-711: server-side allow-list (headings, p, lists, blockquote, strong/em, safe links)."""

    def test_keeps_allowed_markup(self):
        html = (
            "<h1>T</h1><h2>S</h2><p>a <strong>b</strong> <em>c</em><br>d</p>"
            "<ul><li>x</li></ul><ol><li>y</li></ol><blockquote><p>q</p></blockquote>"
        )
        assert sanitize_html(html) == html

    @pytest.mark.parametrize(
        "href", ["https://jivo.in/terms", "mailto:support@jivo.in", "tel:+911800123456"]
    )
    def test_keeps_safe_links(self, href):
        assert sanitize_html(f'<a href="{href}">x</a>') == f'<a href="{href}">x</a>'

    @pytest.mark.parametrize(
        "href",
        [
            "javascript:alert(1)",
            "JaVaScRiPt:alert(1)",
            "http://jivo.in",
            "/relative",
            "data:text/html,x",
            "//evil.example",
        ],
    )
    def test_drops_unsafe_links(self, href):
        assert sanitize_html(f'<a href="{href}">x</a>') == "<a>x</a>"

    @pytest.mark.parametrize(
        "html",
        [
            # entity-encoded scheme
            '<a href="&#106;avascript:alert(1)">x</a>',
            '<a href="&#x6A;&#x61;vascript:alert(1)">x</a>',
            '<a href="javascript&colon;alert(1)">x</a>',
            # tab / newline inside the scheme
            '<a href="jav' + chr(9) + 'ascript:alert(1)">x</a>',
            '<a href="jav' + chr(10) + 'ascript:alert(1)">x</a>',
            '<a href="java&#x09;script:alert(1)">x</a>',
            # leading space or control characters
            '<a href=" javascript:alert(1)">x</a>',
            '<a href="' + chr(1) + 'javascript:alert(1)">x</a>',
            # https look-alikes
            '<a href="https:javascript:alert(1)">x</a>',
            '<a href="vbscript:msgbox(1)">x</a>',
        ],
    )
    def test_obfuscated_link_schemes_lose_href(self, html):
        """Review fix 1: no obfuscated scheme keeps an href."""
        cleaned = sanitize_html(html)
        assert "href" not in cleaned or 'href="https:' in cleaned
        assert "javascript" not in cleaned.lower().replace("<a>x</a>", "")
        assert "vbscript" not in cleaned.lower()

    @pytest.mark.parametrize(
        "html",
        [
            "<svg onload=alert(1)><circle/></svg>",
            '<svg><a href="javascript:alert(1)">x</a></svg>',
            '<math><mi xlink:href="javascript:alert(1)">x</mi></math>',
            "<p><style>p{background:url(javascript:alert(1))}</style>t</p>",
            "<scr<script>ipt>alert(1)</scr</script>ipt>",
            "<p><script>alert(1)</script></p>",
            "<<script>script>alert(1)<</script>/script>",
            '<p title="</p><script>alert(1)</script>">x</p>',
            '<img src=x onerror="alert(1)">',
            "<iframe srcdoc='<script>alert(1)</script>'></iframe>",
            '<form action="https://evil"><input name=x></form>',
            "<p>a</p><!--<script>alert(1)</script>-->",
        ],
    )
    def test_mutated_and_foreign_markup(self, html):
        """Review fix 1: svg/math, nested and mutated markup never yield a live tag or handler."""
        cleaned = sanitize_html(html).lower()
        for needle in (
            "<script",
            "<style",
            "<svg",
            "<math",
            "<img",
            "<iframe",
            "<form",
            "<input",
            "onload",
            "onerror",
            "javascript:",
            "xlink",
            "srcdoc",
        ):
            assert needle not in cleaned, (needle, cleaned)
        allowed = {"p", "a", "br", "strong", "em", "b", "i", "ul", "ol", "li", "blockquote"}
        import re

        tags = set(re.findall(r"</?([a-z0-9]+)", cleaned))
        assert tags <= allowed | {f"h{n}" for n in range(1, 7)}, tags

    def test_removes_scripts_handlers_styles_and_unknown_tags(self):
        html = (
            '<script>alert("x")</script><style>p{}</style><iframe src="x">f</iframe>'
            '<p onclick="steal()" style="color:red" class="c">t</p><img src=x onerror=y>'
            '<a href="https://jivo.in" target="_blank" onmouseover="x">l</a><!-- c -->'
            "<span>kept text</span>"
        )
        assert sanitize_html(html) == '<p>t</p><a href="https://jivo.in">l</a>kept text'

    def test_empty(self):
        assert sanitize_html("") == ""
        assert sanitize_html(None) == ""


# --------------------------------------------------------------------------- pages


@pytest.fixture
def page(db):
    return Page.objects.create(
        slug="refund-policy",
        title="Refund Policy",
        body_html='<h1>Refunds</h1><script>x</script><p onclick="y">5-7 days</p>',
    )


@pytest.mark.django_db
class TestPageApi:
    def test_returns_sanitised_page(self, api_client, page):
        """T-711, #37: `{slug, title, html, updated_at}`; stored HTML already sanitised."""
        page.refresh_from_db()
        assert page.body_html == "<h1>Refunds</h1><p>5-7 days</p>"
        response = api_client.get(f"{PAGES}refund-policy/")
        assert response.status_code == 200
        body = response.json()
        assert set(body) == {"slug", "title", "html", "updated_at"}
        assert body["slug"] == "refund-policy"
        assert body["title"] == "Refund Policy"
        assert body["html"] == "<h1>Refunds</h1><p>5-7 days</p>"
        assert body["updated_at"].endswith("Z")
        assert response["Cache-Control"] == "public, max-age=300"

    def test_html_written_around_save_is_sanitised_on_read(self, api_client, page):
        Page.objects.filter(pk=page.pk).update(body_html="<p>a</p><script>x</script>")
        assert api_client.get(f"{PAGES}refund-policy/").json()["html"] == "<p>a</p>"

    def test_update_fields_save_still_sanitises(self, page):
        page.body_html = "<p>b</p><script>x</script>"
        page.title = "New"
        page.save(update_fields=["title"])
        page.refresh_from_db()
        assert page.body_html == "<p>b</p>"

    def test_unknown_slug_is_404(self, api_client, db):
        response = api_client.get(f"{PAGES}nope/")
        assert response.status_code == 404
        assert response.json()["error"]["code"] == "NOT_FOUND"
        assert response.json()["error"]["message"] == "Page not found."

    def test_unpublished_is_404(self, api_client, page):
        page.is_published = False
        page.save()
        assert api_client.get(f"{PAGES}refund-policy/").status_code == 404

    def test_public_and_ignores_a_bad_token(self, api_client, page):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer not-a-token")
        assert api_client.get(f"{PAGES}refund-policy/").status_code == 200

    def test_cached_and_invalidated_on_save(self, api_client, page, django_assert_num_queries):
        api_client.get(f"{PAGES}refund-policy/")
        with django_assert_num_queries(0):  # page and app config both come from the cache
            assert api_client.get(f"{PAGES}refund-policy/").status_code == 200
        page.title = "Refunds and returns"
        page.save()
        assert api_client.get(f"{PAGES}refund-policy/").json()["title"] == "Refunds and returns"

    def test_missing_page_cached_then_created(self, api_client, db):
        assert api_client.get(f"{PAGES}about/").status_code == 404
        Page.objects.create(slug="about", title="About", body_html="<p>a</p>")
        assert api_client.get(f"{PAGES}about/").status_code == 200

    def test_delete_invalidates(self, api_client, page):
        api_client.get(f"{PAGES}refund-policy/")
        page.delete()
        assert api_client.get(f"{PAGES}refund-policy/").status_code == 404

    def test_redis_down_reads_database(self, api_client, page):
        down = redis.ConnectionError
        with (
            mock.patch.object(services.cache, "get", side_effect=down),
            mock.patch.object(services.cache, "set", side_effect=down),
        ):
            response = api_client.get(f"{PAGES}refund-policy/")
        assert response.status_code == 200

    def test_maintenance_applies(self, api_client, page):
        from apps.cms.models import AppConfig

        config = AppConfig.load()
        config.maintenance = True
        config.save()
        assert api_client.get(f"{PAGES}refund-policy/").status_code == 503


# --------------------------------------------------------------------------- FAQs


def faq(app="customer", category="Orders", question="Q?", answer="A.", sort_order=0, **kw):
    return FAQ.objects.create(
        app=app,
        category=category,
        question=question,
        answer=answer,
        sort_order=sort_order,
        **kw,
    )


@pytest.mark.django_db
class TestFaqApi:
    def test_grouped_and_ordered(self, api_client):
        """T-711, #35: flat list in display order, categories consecutive."""
        a = faq(category="Payments", question="P1", sort_order=30)
        b = faq(category="Orders", question="O1", sort_order=10)
        c = faq(category="Payments", question="P0", sort_order=5)
        d = faq(category="Orders", question="O2", sort_order=40)
        faq(question="hidden", is_active=False)
        faq(app="rider", question="rider only")
        response = api_client.get(FAQS, {"app": "customer"})
        assert response.status_code == 200
        body = response.json()
        # Payments starts at sort_order 5, Orders at 10.
        assert [row["id"] for row in body] == [c.pk, a.pk, b.pk, d.pk]
        assert set(body[0]) == {"id", "category", "question", "answer"}
        assert response["Cache-Control"] == "public, max-age=300"

    def test_rider_app(self, api_client):
        faq(question="customer only")
        r = faq(app="rider", category="Cash", question="Deposit?")
        assert [row["id"] for row in api_client.get(FAQS, {"app": "rider"}).json()] == [r.pk]

    def test_empty(self, api_client):
        assert api_client.get(FAQS, {"app": "customer"}).json() == []

    @pytest.mark.parametrize("query", [{}, {"app": "shop"}])
    def test_app_required(self, api_client, query):
        response = api_client.get(FAQS, query)
        assert response.status_code == 400
        assert response.json()["error"]["code"] == "VALIDATION_ERROR"
        assert "app" in response.json()["error"]["details"]

    def test_cached_and_invalidated(self, api_client, django_assert_num_queries):
        item = faq(question="Old?")
        api_client.get(FAQS, {"app": "customer"})
        with django_assert_num_queries(0):  # served from the cache
            api_client.get(FAQS, {"app": "customer"})
        item.question = "New?"
        item.save()
        assert api_client.get(FAQS, {"app": "customer"}).json()[0]["question"] == "New?"
        item.delete()
        assert api_client.get(FAQS, {"app": "customer"}).json() == []

    def test_answer_must_be_plain_text(self):
        item = FAQ(app="customer", category="Orders", question="Q?", answer="<b>bold</b>")
        with pytest.raises(ValidationError) as exc:
            item.full_clean()
        assert "answer" in exc.value.message_dict
        FAQ(app="customer", category="Orders", question="Q?", answer="1 < 2 and 3 > 2").full_clean()


# --------------------------------------------------------------------------- seed


@pytest.mark.django_db
def test_seed_is_idempotent_and_marked_placeholder():
    """T-711: placeholder pages clearly marked; FAQs for both apps; re-running changes nothing."""
    seed_pages_and_faqs(io.StringIO(), {})
    seed_pages_and_faqs(io.StringIO(), {})
    assert sorted(Page.objects.values_list("slug", flat=True)) == sorted(PAGE_SLUGS)
    for page in Page.objects.all():
        assert "Placeholder; legal text pending." in page.body_html
        assert page.body_html == sanitize_html(page.body_html)
    assert FAQ.objects.filter(app="customer").count() >= 4
    assert FAQ.objects.filter(app="rider").exists()
    count = FAQ.objects.count()
    seed_pages_and_faqs(io.StringIO(), {})
    assert FAQ.objects.count() == count


@pytest.mark.django_db
def test_seed_keeps_an_edited_page():
    Page.objects.create(slug="terms", title="Final terms", body_html="<p>final</p>")
    seed_pages_and_faqs(io.StringIO(), {})
    assert Page.objects.get(slug="terms").body_html == "<p>final</p>"


def test_seed_demo_lists_the_p7_steps():
    from apps.core.management.commands.seed_demo import SEED_STEPS

    assert "apps.cms.seed.seed_pages_and_faqs" in SEED_STEPS
    assert "apps.support.seed.seed_tickets" in SEED_STEPS

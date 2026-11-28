"""Launch policy pages (2026-11-28, docs/legal/policies.md): the public `/legal/` web view and
`manage.py load_legal_pages`."""

import io

import pytest
from django.core.management import CommandError, call_command
from django.test import override_settings

from apps.cms import services
from apps.cms.html import sanitize_html
from apps.cms.legal_pages import BASE_URL_TOKEN, LEGAL_PAGES, page_html
from apps.cms.models import PAGE_SLUGS, AppConfig, Page
from apps.cms.web_views import LEGAL_CSP

pytestmark = pytest.mark.django_db

BASE = "https://quick.jivo.in"


def run(*args) -> str:
    out = io.StringIO()
    call_command("load_legal_pages", *args, stdout=out)
    return out.getvalue()


# --------------------------------------------------------------------------- web view


class TestLegalWebView:
    def test_published_page_renders_without_login(self, client):
        Page.objects.create(
            slug="terms",
            title="Terms of use",
            body_html='<p>Hello <script>alert(1)</script><a href="mailto:info@jivo.in">x</a></p>',
        )
        response = client.get("/legal/terms/")
        assert response.status_code == 200
        assert response["Content-Type"].startswith("text/html")
        assert response["Content-Security-Policy"] == LEGAL_CSP
        html = response.content.decode()
        assert "<title>Terms of use · Jivo Quick Commerce</title>" in html
        assert '<a href="mailto:info@jivo.in">x</a>' in html
        assert "alert(1)" not in html
        assert "<script" not in html
        assert 'name="viewport"' in html

    def test_title_is_escaped(self, client):
        Page.objects.create(slug="contact", title="<b>Contact</b>", body_html="<p>x</p>")
        html = client.get("/legal/contact/").content.decode()
        assert "&lt;b&gt;Contact&lt;/b&gt;" in html

    def test_unpublished_page_is_404(self, client):
        Page.objects.create(slug="privacy", title="P", body_html="<p>x</p>", is_published=False)
        assert client.get("/legal/privacy/").status_code == 404

    def test_unknown_page_is_404(self, client):
        assert client.get("/legal/no-such-page/").status_code == 404

    def test_post_not_allowed(self, client):
        Page.objects.create(slug="terms", title="T", body_html="<p>x</p>")
        assert client.post("/legal/terms/").status_code == 405

    def test_index_lists_only_published_legal_pages_in_order(self, client):
        Page.objects.create(slug="about", title="About Jivo", body_html="<p>a</p>")
        Page.objects.create(slug="rider-agreement", title="Partner", body_html="<p>r</p>")
        Page.objects.create(slug="contact", title="Contact us", body_html="<p>c</p>")
        Page.objects.create(slug="terms", title="Terms of use", body_html="<p>t</p>")
        Page.objects.create(
            slug="privacy", title="Hidden", body_html="<p>p</p>", is_published=False
        )
        response = client.get("/legal/")
        assert response.status_code == 200
        assert response["Content-Security-Policy"] == LEGAL_CSP
        assert response["Cache-Control"] == "public, max-age=60"
        html = response.content.decode()
        assert "Hidden" not in html
        assert 'href="/legal/about/"' not in html
        assert 'href="/legal/rider-agreement/"' not in html
        assert html.index('href="/legal/terms/"') < html.index('href="/legal/contact/"')

    def test_page_security_and_cache_headers(self, client):
        Page.objects.create(slug="terms", title="T", body_html="<p>x</p>")
        response = client.get("/legal/terms/")
        csp = response["Content-Security-Policy"]
        assert "default-src 'none'" in csp
        assert "script-src" not in csp  # falls back to default-src 'none': no scripts at all
        assert "frame-ancestors 'none'" in csp
        assert "form-action 'none'" in csp
        assert response["Cache-Control"] == "public, max-age=60"
        assert response["X-Frame-Options"] == "DENY"

    def test_index_empty(self, client):
        assert "No policies are published yet." in client.get("/legal/").content.decode()

    @override_settings(
        SECURE_SSL_REDIRECT=True, SECURE_PROXY_SSL_HEADER=("HTTP_X_FORWARDED_PROTO", "https")
    )
    def test_works_behind_the_production_proxy(self, client):
        """Production settings: HTTPS via the proxy header passes, plain HTTP redirects."""
        Page.objects.create(slug="terms", title="T", body_html="<p>x</p>")
        assert client.get("/legal/terms/", HTTP_X_FORWARDED_PROTO="https").status_code == 200
        assert client.get("/legal/terms/").status_code == 301

    def test_app_guard_does_not_apply(self, client):
        """Maintenance answers 503 on the API only; the policy pages stay readable."""
        Page.objects.create(slug="terms", title="T", body_html="<p>x</p>")
        config = AppConfig.load()
        config.maintenance = True
        config.save()
        assert client.get("/legal/terms/").status_code == 200


# --------------------------------------------------------------------------- slugs and API


def test_launch_slugs_are_known():
    assert set(LEGAL_PAGES) <= set(PAGE_SLUGS)


def test_new_slugs_served_by_the_app_api(api_client):
    run()
    for slug in ("delivery-policy", "contact", "delete-account"):
        response = api_client.get(f"/api/v1/pages/{slug}/")
        assert response.status_code == 200
        assert response.json()["slug"] == slug


def test_bodies_survive_the_sanitiser_unchanged():
    """The embedded HTML uses only allowed markup, so nothing is silently dropped on save."""
    for slug, (title, _) in LEGAL_PAGES.items():
        html = page_html(slug)
        assert title
        assert sanitize_html(html) == html.strip()
        assert "<table" not in html
        assert BASE_URL_TOKEN not in html


def test_privacy_links_to_delete_account_under_the_base_url():
    run("--base-url", "https://jqc.jivo.in")
    privacy = Page.objects.get(slug="privacy").body_html
    assert '<a href="https://jqc.jivo.in/legal/delete-account/">' in privacy
    assert "Sentry (app error reports" in privacy
    # Without --base-url the link uses the production site.
    assert 'href="https://quick.jivo.in/legal/delete-account/"' in page_html("privacy")


def test_delete_account_page_covers_both_apps():
    run()
    body = Page.objects.get(slug="delete-account").body_html
    assert "Jivo Rider" in body
    assert "Delete my account" in body
    assert "8 years" in body


# --------------------------------------------------------------------------- command


class TestLoadLegalPages:
    def test_creates_the_published_pages(self):
        out = run()
        assert sorted(Page.objects.values_list("slug", flat=True)) == sorted(LEGAL_PAGES)
        assert all(Page.objects.values_list("is_published", flat=True))
        terms = Page.objects.get(slug="terms")
        assert terms.title == "Terms of use"
        assert "Jivo Mart Pvt. Ltd." in terms.body_html
        assert "Done: 6 change(s) written." in out

    def test_is_idempotent(self):
        run("--base-url", BASE)
        before = list(Page.objects.order_by("slug").values_list("slug", "updated_at"))
        out = run("--base-url", BASE)
        assert "Done: 0 change(s) written." in out
        assert list(Page.objects.order_by("slug").values_list("slug", "updated_at")) == before

    def test_updates_an_existing_page_and_publishes_it(self):
        Page.objects.create(
            slug="refund-policy", title="Old", body_html="<p>old</p>", is_published=False
        )
        out = run()
        page = Page.objects.get(slug="refund-policy")
        assert page.title == "Refund and cancellation policy"
        assert page.is_published
        assert "within 48 hours" in page.body_html
        assert "update page refund-policy  (title, body_html, is_published)" in out

    def test_leaves_other_pages_alone(self):
        Page.objects.create(slug="about", title="About", body_html="<p>about</p>")
        run()
        assert Page.objects.get(slug="about").body_html == "<p>about</p>"

    def test_without_base_url_config_untouched(self):
        before = AppConfig.load()
        run()
        after = AppConfig.load()
        assert after.terms_url == before.terms_url
        assert after.terms_version == before.terms_version

    def test_base_url_sets_app_config(self):
        run("--base-url", BASE + "/")
        config = AppConfig.load()
        assert config.support_phone == "+918595349565"
        assert config.support_email == "info@jivo.in"
        assert config.terms_url == f"{BASE}/legal/terms/"
        assert config.privacy_url == f"{BASE}/legal/privacy/"
        assert config.refund_url == f"{BASE}/legal/refund-policy/"
        assert config.terms_version == "2026-11-28"
        # The cached snapshot the API serves is dropped on save.
        assert services.get_app_config().terms_version == "2026-11-28"

    def test_dry_run_writes_nothing(self):
        Page.objects.create(slug="terms", title="Old", body_html="<p>old</p>")
        out = run("--base-url", BASE, "--dry-run")
        assert "create page privacy" in out
        assert "update page terms" in out
        assert "update config terms_version" in out
        assert "Dry run: " in out
        assert Page.objects.count() == 1
        assert Page.objects.get(slug="terms").title == "Old"
        assert AppConfig.load().terms_version != "2026-11-28"

    def test_api_cache_refreshed_after_load(self, api_client):
        """A cached 404 for a new slug is dropped when the command creates the page."""
        assert api_client.get("/api/v1/pages/delivery-policy/").status_code == 404
        run()
        assert api_client.get("/api/v1/pages/delivery-policy/").status_code == 200

    @pytest.mark.parametrize(
        "url", ["http://quick.jivo.in", "quick.jivo.in", "https://", "https://x.in/?a=1"]
    )
    def test_rejects_bad_base_url(self, url):
        with pytest.raises(CommandError):
            run("--base-url", url)
        assert not Page.objects.exists()

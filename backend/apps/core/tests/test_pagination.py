"""Pagination (02 §5): ?page=&page_size=, default 20, max 100, {count, next, previous, results}."""

import pytest

pytestmark = pytest.mark.urls("apps.core.tests.urls")


def test_default_page_size_and_shape(api_client):
    body = api_client.get("/t/numbers/").json()
    assert set(body) == {"count", "next", "previous", "results"}
    assert body["count"] == 250
    assert body["results"] == list(range(1, 21))
    assert body["previous"] is None
    assert body["next"].endswith("/t/numbers/?page=2")


def test_page_and_page_size(api_client):
    body = api_client.get("/t/numbers/", {"page": 3, "page_size": 50}).json()
    assert body["results"] == list(range(101, 151))
    assert "page=2" in body["previous"]
    assert "page=4" in body["next"]


def test_page_size_is_capped_at_100(api_client):
    body = api_client.get("/t/numbers/", {"page_size": 1000}).json()
    assert len(body["results"]) == 100


@pytest.mark.parametrize("page_size", ["0", "-5", "abc"])
def test_invalid_page_size_falls_back_to_default(api_client, page_size):
    body = api_client.get("/t/numbers/", {"page_size": page_size}).json()
    assert len(body["results"]) == 20


@pytest.mark.parametrize("page", ["99", "abc", "0"])
def test_invalid_page_is_not_found_envelope(api_client, page):
    response = api_client.get("/t/numbers/", {"page": page})
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"

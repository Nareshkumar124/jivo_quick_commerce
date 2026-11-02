"""JSON 404/500 handlers for API paths (DEBUG off); Django's HTML pages elsewhere."""

import json

import pytest
from django.test import RequestFactory

from apps.core.views import handler404, handler500


@pytest.mark.parametrize("path", ["/api/v1/nope/", "/health/nope"])
def test_404_is_json_envelope_for_api_paths(path):
    response = handler404(RequestFactory().get(path), Exception("x"))
    assert response.status_code == 404
    assert json.loads(response.content)["error"]["code"] == "NOT_FOUND"


def test_404_is_html_elsewhere():
    response = handler404(RequestFactory().get("/somewhere/"), Exception("x"))
    assert response.status_code == 404
    assert response["Content-Type"].startswith("text/html")


def test_500_is_json_envelope_for_api_paths():
    response = handler500(RequestFactory().get("/api/v1/orders/"))
    assert response.status_code == 500
    assert json.loads(response.content) == {
        "error": {
            "code": "SERVER_ERROR",
            "message": "Something went wrong. Please try again.",
            "details": {},
        }
    }


def test_500_is_html_elsewhere():
    response = handler500(RequestFactory().get("/admin/"))
    assert response.status_code == 500
    assert response["Content-Type"].startswith("text/html")


@pytest.mark.django_db
def test_unknown_api_url_uses_the_json_handler(client):
    response = client.get("/api/v1/does-not-exist/")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"

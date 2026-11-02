"""Client-info middleware (02 §5): X-App-Name, X-App-Version, X-Platform -> request.client_info."""

import pytest
from asgiref.sync import async_to_sync
from django.http import HttpResponse
from django.test import RequestFactory

from apps.core.middleware import ClientInfo, client_info_middleware


@pytest.mark.parametrize(
    ("headers", "expected"),
    [
        (
            {"X-App-Name": "customer", "X-App-Version": "1.4.2", "X-Platform": "android"},
            ClientInfo("customer", "1.4.2", None, "android"),
        ),
        (
            {"X-App-Name": " Rider ", "X-App-Version": "2.0.0+37", "X-Platform": "IOS"},
            ClientInfo("rider", "2.0.0", 37, "ios"),
        ),
        ({}, ClientInfo()),
        (
            {"X-App-Name": "admin", "X-App-Version": "1.x", "X-Platform": "windows"},
            ClientInfo(),
        ),
        ({"X-App-Version": "1.2.3.4.5"}, ClientInfo()),
        ({"X-App-Version": "3"}, ClientInfo(app_version="3")),
    ],
)
def test_from_headers(headers, expected):
    assert ClientInfo.from_headers(headers) == expected


def test_version_tuple_and_is_app():
    info = ClientInfo.from_headers({"X-App-Name": "customer", "X-App-Version": "1.10.0+5"})
    assert info.version_tuple == (1, 10, 0)
    assert info.version_tuple > (1, 9, 9)
    assert info.is_app
    assert ClientInfo().version_tuple is None
    assert not ClientInfo().is_app


def _request():
    return RequestFactory().get(
        "/", headers={"X-App-Name": "rider", "X-App-Version": "1.0.1", "X-Platform": "android"}
    )


def test_sync_middleware_sets_client_info():
    seen = {}

    def view(request):
        seen["info"] = request.client_info
        return HttpResponse("ok")

    response = client_info_middleware(view)(_request())
    assert response.status_code == 200
    assert seen["info"] == ClientInfo("rider", "1.0.1", None, "android")


def test_async_middleware_sets_client_info():
    seen = {}

    async def view(request):
        seen["info"] = request.client_info
        return HttpResponse("ok")

    response = async_to_sync(client_info_middleware(view))(_request())
    assert response.status_code == 200
    assert seen["info"].app_name == "rider"


@pytest.mark.urls("apps.core.tests.urls")
def test_client_info_reaches_drf_views(api_client):
    response = api_client.get(
        "/t/client-info/",
        headers={"X-App-Name": "customer", "X-App-Version": "1.0.0+12", "X-Platform": "ios"},
    )
    assert response.json() == {
        "app_name": "customer",
        "app_version": "1.0.0",
        "build_number": 12,
        "platform": "ios",
    }

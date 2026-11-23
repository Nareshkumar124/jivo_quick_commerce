"""Private-bucket links signed for a public host (S3_PRESIGN_ENDPOINT_URL), user report 2026-11-23:
on jqc.jivo.in invoice/KYC/support links pointed at the internal http://minio:9000.

No network: presigning is local, and upload/exists requests are answered by a `before-send` hook
that records the URL the client would have called."""

from urllib.parse import parse_qs, urlsplit

import pytest
from botocore.awsrequest import AWSResponse
from django.core.files.base import ContentFile

from apps.core.storage import PrivateS3Storage

INTERNAL = "http://minio:9000"
PUBLIC = "https://jqc.jivo.in"
BASE = {
    "bucket_name": "jivo-media",
    "endpoint_url": INTERNAL,
    "access_key": "test-key",
    "secret_key": "test-secret",
    "region_name": "ap-south-1",
    "addressing_style": "path",
    "default_acl": None,
    "file_overwrite": False,
    "querystring_auth": True,
}


class _Headers(dict):
    def get_all(self, name, default=None):  # botocore reads some headers this way
        value = self.get(name)
        return [value] if value is not None else default


class _Raw:
    def stream(self, **kwargs):
        yield b""


def _record_requests(storage: PrivateS3Storage) -> list[str]:
    """Answer every request of the storage's own (internal) client: HEAD is a 404 (the name is
    free, so `save()` keeps it), everything else an empty 200."""
    seen: list[str] = []

    def fake_send(request, **kwargs):
        seen.append(request.url)
        status = 404 if request.method == "HEAD" else 200
        return AWSResponse(request.url, status, _Headers({"ETag": '"abc"'}), _Raw())

    storage.connection.meta.client.meta.events.register_first("before-send.s3", fake_send)
    return seen


def _host(url: str) -> str:
    parts = urlsplit(url)
    return f"{parts.scheme}://{parts.netloc}"


def test_url_signed_for_public_host_when_set():
    storage = PrivateS3Storage(**BASE, presign_endpoint_url=PUBLIC)
    url = storage.url("invoices/2026/INV-1.pdf", expire=600)
    parts = urlsplit(url)
    assert _host(url) == PUBLIC
    assert parts.path == "/jivo-media/invoices/2026/INV-1.pdf"  # path-style, same bucket
    query = parse_qs(parts.query)
    assert query["X-Amz-Algorithm"] == ["AWS4-HMAC-SHA256"]  # signature v4
    assert query["X-Amz-Expires"] == ["600"]
    assert query["X-Amz-Signature"][0]
    assert query["X-Amz-Credential"][0].startswith("test-key/")
    assert "/ap-south-1/s3/" in query["X-Amz-Credential"][0]


def test_url_signed_for_internal_endpoint_when_unset():
    storage = PrivateS3Storage(**BASE)
    url = storage.url("invoices/2026/INV-1.pdf", expire=600)
    assert _host(url) == INTERNAL
    assert urlsplit(url).path == "/jivo-media/invoices/2026/INV-1.pdf"
    assert "Signature" in urlsplit(url).query


def test_uploads_and_reads_stay_on_internal_endpoint():
    storage = PrivateS3Storage(**BASE, presign_endpoint_url=PUBLIC)
    seen = _record_requests(storage)
    name = storage.save("support/a.txt", ContentFile(b"hello"))
    assert name == "support/a.txt"
    storage.exists(name)
    storage.delete(name)
    assert len(seen) >= 3  # HEAD (name check), PUT (upload), HEAD, DELETE
    assert seen, "the storage made no requests"
    assert all(_host(url) == INTERNAL for url in seen), seen
    # Signing afterwards still targets the public host.
    assert _host(storage.url(name)) == PUBLIC


def test_storage_survives_pickling():
    import pickle

    storage = PrivateS3Storage(**BASE, presign_endpoint_url=PUBLIC)
    storage.url("x.pdf")
    clone = pickle.loads(pickle.dumps(storage))  # noqa: S301 (own object, round trip)
    assert _host(clone.url("x.pdf")) == PUBLIC


def test_unknown_option_still_rejected():
    from django.core.exceptions import ImproperlyConfigured

    with pytest.raises(ImproperlyConfigured):
        PrivateS3Storage(**BASE, presign_endpoint="typo")


def test_settings_wire_private_storage_and_leave_public_alone():
    from config.settings import base

    assert base.STORAGES["default"]["BACKEND"] == "apps.core.storage.PrivateS3Storage"
    assert "presign_endpoint_url" in base.STORAGES["default"]["OPTIONS"]
    assert base.STORAGES["public"]["BACKEND"] == "storages.backends.s3.S3Storage"
    assert "presign_endpoint_url" not in base.STORAGES["public"]["OPTIONS"]

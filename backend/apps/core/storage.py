"""Storage aliases.

- `default`: private bucket, signed URLs (KYC documents, invoices, support attachments, report
  exports). `PrivateS3Storage` can sign those links against a public endpoint (see below).
- `public`: public catalog media (product, category and banner images), plain URLs served by a
  CDN in the cloud. Never put personal data here. URLs must not expire: cached API payloads hold
  them.
"""

import threading

from botocore.config import Config
from django.core.files.storage import Storage, storages
from storages.backends.s3 import S3Storage
from storages.utils import clean_name


def public_storage() -> Storage:
    """Callable storage for public media fields (resolved at runtime, so tests can swap it)."""
    return storages["public"]


class PrivateS3Storage(S3Storage):
    """The private bucket, with presigned links that phones can open.

    In a Docker deployment `endpoint_url` is the internal MinIO address (`http://minio:9000`),
    which a phone cannot reach. When `presign_endpoint_url` is set (e.g. `https://jqc.jivo.in`),
    `url()` signs with a client pointed at that public host (path-style, signature v4, same
    credentials, region and bucket); nginx proxies `/<bucket>/` to MinIO with the original Host
    header, so the signature still matches. Uploads, reads, `exists()` and `delete()` keep using
    the internal `endpoint_url`. Unset, `url()` behaves exactly like `S3Storage.url()`.
    """

    def __init__(self, **settings):
        super().__init__(**settings)
        self._presign_clients = threading.local()

    def get_default_settings(self):
        return {**super().get_default_settings(), "presign_endpoint_url": None}

    def __getstate__(self):
        state = super().__getstate__()
        state.pop("_presign_clients", None)
        return state

    def __setstate__(self, state):
        super().__setstate__(state)
        self._presign_clients = threading.local()

    @property
    def presign_client(self):
        client = getattr(self._presign_clients, "client", None)
        if client is None:
            config = self.client_config.merge(
                Config(signature_version="s3v4", s3={"addressing_style": "path"})
            )
            client = self._create_session().client(
                "s3",
                region_name=self.region_name,
                endpoint_url=self.presign_endpoint_url,
                config=config,
                verify=self.verify,
            )
            self._presign_clients.client = client
        return client

    def url(self, name, parameters=None, expire=None, http_method=None):
        if not self.presign_endpoint_url or self.custom_domain or not self.querystring_auth:
            return super().url(name, parameters=parameters, expire=expire, http_method=http_method)
        name = self._normalize_name(clean_name(name))
        params = parameters.copy() if parameters else {}
        params["Bucket"] = self.bucket_name
        params["Key"] = name
        return self.presign_client.generate_presigned_url(
            "get_object",
            Params=params,
            ExpiresIn=self.querystring_expire if expire is None else expire,
            HttpMethod=http_method,
        )

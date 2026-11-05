"""Create and check the local MinIO buckets the backend expects (idempotent).

Usage (from the repo root; needs the backend's uv environment for Django + boto3):

    uv run --project backend python infra/scripts/minio_buckets.py            # init + verify
    uv run --project backend python infra/scripts/minio_buckets.py --verify-only

What it does, reading endpoint, credentials and bucket names from the Django storage settings
(``config.settings.local`` unless DJANGO_SETTINGS_MODULE says otherwise, so ``backend/.env``
overrides apply):

* creates the private bucket (``STORAGES["default"]``, S3_MEDIA_BUCKET, default ``jivo-media``)
  and the public bucket (``STORAGES["public"]``, S3_PUBLIC_MEDIA_BUCKET, default ``jivo-public``);
* puts the public-read policy (anonymous ``s3:GetObject`` only) on the public bucket, exactly as
  ``apps/catalog/seed.py::ensure_public_bucket`` does;
* verifies: a test object round-trips in the private bucket and is NOT anonymously readable
  (HTTP 403), and a test object in the public bucket IS anonymously readable (HTTP 200). Test
  objects are deleted afterwards.

Refuses to run against anything but a localhost endpoint. Never prints credentials.
Exit codes: 0 ok, 1 a check failed, 2 configuration error.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from urllib.parse import urlparse

BACKEND_DIR = Path(__file__).resolve().parents[2] / "backend"


def _anon_status(url: str) -> int:
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            return resp.status
    except urllib.error.HTTPError as exc:
        return exc.code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--verify-only", action="store_true", help="check, don't create")
    args = parser.parse_args()

    sys.path.insert(0, str(BACKEND_DIR))
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
    import django

    django.setup()
    from django.core.files.storage import storages

    private, public = storages["default"], storages["public"]
    endpoint = getattr(private, "endpoint_url", None)
    host = urlparse(endpoint or "").hostname
    if host not in {"localhost", "127.0.0.1"}:
        print(f"refusing: S3 endpoint is not local ({endpoint!r})", file=sys.stderr)
        return 2

    client = private.connection.meta.client
    existing = {b["Name"] for b in client.list_buckets().get("Buckets", [])}
    ok = True
    for bucket in (private.bucket_name, public.bucket_name):
        if bucket in existing:
            print(f"bucket {bucket}: exists")
        elif args.verify_only:
            print(f"bucket {bucket}: MISSING")
            ok = False
        else:
            client.create_bucket(Bucket=bucket)
            print(f"bucket {bucket}: created")
    if not ok:
        return 1

    if not args.verify_only:
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{public.bucket_name}/*"],
                }
            ],
        }
        client.put_bucket_policy(Bucket=public.bucket_name, Policy=json.dumps(policy))
        print(f"bucket {public.bucket_name}: public-read policy (s3:GetObject) set")

    base = endpoint.rstrip("/")
    key = f"healthcheck/{uuid.uuid4().hex}.txt"
    body = b"jivoqc minio check\n"
    for bucket, want in ((private.bucket_name, 403), (public.bucket_name, 200)):
        client.put_object(Bucket=bucket, Key=key, Body=body)
        fetched = client.get_object(Bucket=bucket, Key=key)["Body"].read()
        anon = _anon_status(f"{base}/{bucket}/{key}")
        client.delete_object(Bucket=bucket, Key=key)
        good = fetched == body and anon == want
        ok &= good
        print(
            f"bucket {bucket}: authenticated put/get {'ok' if fetched == body else 'MISMATCH'}; "
            f"anonymous GET -> HTTP {anon} (expected {want}) {'ok' if good else 'FAIL'}"
        )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

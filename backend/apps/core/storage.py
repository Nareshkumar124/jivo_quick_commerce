"""Storage aliases.

- `default`: private bucket, signed URLs (KYC documents and invoices in later phases).
- `public`: public catalog media (product, category and banner images), plain URLs served by a
  CDN in the cloud. Never put personal data here. URLs must not expire: cached API payloads hold
  them.
"""

from django.core.files.storage import Storage, storages


def public_storage() -> Storage:
    """Callable storage for public media fields (resolved at runtime, so tests can swap it)."""
    return storages["public"]

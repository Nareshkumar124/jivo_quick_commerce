"""Field-level encryption (09 §3: bank account numbers and KYC document numbers).

Values are encrypted with Fernet (AES-128-CBC + HMAC-SHA256) under `FIELD_ENCRYPTION_KEYS`, a
comma-separated list of Fernet keys: the first encrypts, every key decrypts, so a key can be
rotated by putting the new one first and re-saving the rows. Generate a key with
`uv run python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`.

Local development and tests may leave the setting empty: a key is then derived from
`SECRET_KEY`. Staging and production must set it (deploy check `delivery.E001`) and refuse to
encrypt or decrypt without it, so a missing key fails loudly instead of using a guessable one.

Ciphertext is never shown: the panel and the API show masked values only.
"""

import base64
import hashlib
from functools import lru_cache

from cryptography.fernet import Fernet, InvalidToken, MultiFernet
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured

DEPLOYED_ENVIRONMENTS = frozenset({"staging", "production"})


class DecryptionError(Exception):
    """The value was not encrypted with any configured key (or was tampered with)."""


def _derived_key() -> bytes:
    digest = hashlib.sha256(f"jqc-field-encryption:{settings.SECRET_KEY}".encode()).digest()
    return base64.urlsafe_b64encode(digest)


@lru_cache(maxsize=4)
def _fernet(keys: tuple[str, ...], environment: str) -> MultiFernet:
    if not keys:
        if environment in DEPLOYED_ENVIRONMENTS:
            raise ImproperlyConfigured(
                "FIELD_ENCRYPTION_KEYS must be set in staging and production (09 §3)."
            )
        return MultiFernet([Fernet(_derived_key())])
    try:
        return MultiFernet([Fernet(key.encode()) for key in keys])
    except ValueError as exc:
        raise ImproperlyConfigured(
            "FIELD_ENCRYPTION_KEYS holds a value that is not a Fernet key."
        ) from exc


def fernet() -> MultiFernet:
    keys = tuple(key.strip() for key in getattr(settings, "FIELD_ENCRYPTION_KEYS", []) if key)
    return _fernet(keys, settings.APP_ENVIRONMENT)


def encrypt(value: str) -> str:
    """Ciphertext (ASCII) of `value`; "" stays ""."""
    if not value:
        return ""
    return fernet().encrypt(value.encode()).decode("ascii")


def decrypt(token: str) -> str:
    """Plain text of a value from `encrypt()`; "" stays ""."""
    if not token:
        return ""
    try:
        return fernet().decrypt(token.encode("ascii")).decode()
    except InvalidToken as exc:
        raise DecryptionError("The value cannot be decrypted with the configured keys.") from exc

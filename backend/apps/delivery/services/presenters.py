"""API bodies for the rider endpoints (shapes in `apps.delivery.serializers`)."""

from datetime import datetime, timedelta

from django.conf import settings
from django.core.files.storage import default_storage
from django.utils import timezone

from apps.cms.services import rider_location_settings
from apps.core.money import money_str
from apps.delivery.choices import DocumentType
from apps.delivery.models import Rider, RiderDocument
from apps.delivery.services.riders import missing_documents


def signed_url(name: str, seconds: int) -> str:
    """A short-lived link to a private-bucket object (S3/MinIO presigned URL)."""
    try:
        return default_storage.url(name, expire=seconds)
    except TypeError:  # storages without signed URLs (tests: in-memory)
        return default_storage.url(name)


def store_body(store) -> dict | None:
    if store is None:
        return None
    return {"id": store.pk, "name": store.name, "city": store.city}


def home_store_body(store) -> dict | None:
    if store is None:
        return None
    return {**store_body(store), "lat": store.location.y, "lng": store.location.x}


def cash_body(rider: Rider) -> dict:
    return {
        "cash_in_hand": money_str(rider.cash_in_hand),
        "cash_limit": money_str(rider.cash_limit),
        "limit_reached": rider.cash_limit_reached,
    }


def document_body(document: RiderDocument) -> dict:
    return {
        "doc_type": document.doc_type,
        "status": document.status,
        "doc_number_masked": document.doc_number_masked or None,
        "review_note": document.review_note,
        "uploaded_at": document.uploaded_at,
        "reviewed_at": document.reviewed_at,
    }


def bank_body(rider: Rider) -> dict | None:
    if not rider.has_bank_account:
        return None
    return {
        "holder_name": rider.bank_account_name,
        "account_number_masked": f"XXXXXX{rider.bank_account_last4}",
        "ifsc": rider.ifsc,
        "upi_id": rider.upi_id or None,
        "updated_at": rider.bank_updated_at,
    }


def photo(rider: Rider, documents, now: datetime) -> tuple[str | None, datetime | None]:
    document = next((d for d in documents if d.doc_type == DocumentType.PHOTO), None)
    if document is None or not document.file:
        return None, None
    seconds = settings.RIDER_PHOTO_URL_EXPIRY_SECONDS
    return signed_url(document.file.name, seconds), now + timedelta(seconds=seconds)


def today_body(rider: Rider, now: datetime) -> dict:
    """The home "Today" card. Deliveries and earnings arrive with slices 5.3/5.4; online time
    with the shifts of slice 5.2 (`shifts.online_seconds_today`)."""
    from apps.delivery.services import summary

    return summary.today(rider, now)


def profile_body(rider: Rider, now: datetime | None = None) -> dict:
    now = now or timezone.now()
    documents = list(rider.documents.all())
    url, expires_at = photo(rider, documents, now)
    missing = missing_documents(rider, documents)
    from apps.accounts.choices import RiderStatus

    return {
        "id": rider.pk,
        "phone": rider.user.phone,
        "status": rider.status,
        "rejection_reason": rider.rejection_reason,
        "suspension_reason": rider.suspension_reason,
        "full_name": rider.full_name,
        "dob": rider.dob,
        "emergency_contact_name": rider.emergency_contact_name,
        "emergency_contact_phone": rider.emergency_contact_phone,
        "vehicle_type": rider.vehicle_type,
        "vehicle_number": rider.vehicle_number or None,
        "preferred_store": store_body(rider.preferred_store),
        "home_store": home_store_body(rider.home_store),
        "photo_url": url,
        "photo_url_expires_at": expires_at,
        "rating_avg": f"{rider.rating_avg:.1f}" if rider.rating_avg is not None else None,
        "documents": [document_body(d) for d in documents],
        "required_documents": rider.required_documents,
        "missing_documents": missing,
        "bank_account": bank_body(rider),
        "ready_for_review": (
            rider.status == RiderStatus.PENDING_KYC and not missing and rider.has_bank_account
        ),
        "is_online": rider.is_online,
        "cash": cash_body(rider),
        "today": today_body(rider, now),
        "created_at": rider.created_at,
    }


def location_settings() -> dict:
    return rider_location_settings()

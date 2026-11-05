"""The rider's own profile (06 §3, 04 §2.2): register, edit, upload KYC documents, bank details.

Rider status rules (07 §2.8, D-14 default; staff transitions are in `kyc`):

| From | To | By |
|------|----|----|
| (none) | PENDING_KYC | rider registers |
| PENDING_KYC | ACTIVE / REJECTED | ops approve / reject (`kyc`) |
| REJECTED | PENDING_KYC | rider re-submits (see below) |
| ACTIVE | SUSPENDED | ops suspend (`kyc`) |
| SUSPENDED | ACTIVE | ops reinstate (`kyc`) |

Re-submission: any profile change or upload that leaves nothing required missing or rejected.

Editing: PENDING_KYC and REJECTED riders may change every profile field; ACTIVE and SUSPENDED
riders only their emergency contact (vehicle and store changes go through ops). Documents: a new
upload replaces the current copy of that type and goes to review (PENDING); an APPROVED copy
cannot be replaced (409). An ACTIVE rider whose document ops rejected (e.g. an expired licence)
stays ACTIVE but cannot go online until the replacement is approved (`kyc.online_blockers`).
"""

import io
import logging

from django.conf import settings
from django.core.files.base import ContentFile
from django.db import IntegrityError, transaction
from django.utils import timezone
from PIL import Image, ImageOps, UnidentifiedImageError

from apps.accounts.choices import RiderStatus
from apps.core.crypto import encrypt
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.delivery import validators
from apps.delivery.choices import DocumentStatus, DocumentType
from apps.delivery.models import Rider, RiderDocument
from apps.stores.models import DarkStore

logger = logging.getLogger(__name__)

MSG_NOT_RIDER = "Register as a rider first."
MSG_NOT_ACTIVE = "Your rider account is not active."
MSG_ALREADY_REGISTERED = "You are already registered as a rider."
MSG_LOCKED_FIELD = "This cannot be changed after approval. Contact ops."
MSG_APPROVED_DOCUMENT = "This document is approved and cannot be replaced."
MSG_NOT_NEEDED = "This document is not needed for your vehicle."
MSG_BAD_IMAGE = "Upload a JPEG or PNG photo."
MSG_UNKNOWN_STORE = "Choose a store from the list."
MSG_STAFF = "Staff accounts cannot register as riders."

EDITABLE_WHEN_APPROVED = frozenset({"emergency_contact_name", "emergency_contact_phone"})
OPEN_STATUSES = frozenset({RiderStatus.PENDING_KYC, RiderStatus.REJECTED})
MAX_IMAGE_PIXELS = 40_000_000  # 40 MP: far above any phone photo, far below a decompression bomb
JPEG_QUALITY = 88


# --------------------------------------------------------------------------- lookup


def rider_for(user, *, lock: bool = False) -> Rider | None:
    queryset = Rider.objects.select_related("user", "preferred_store", "home_store")
    if lock:
        queryset = queryset.select_for_update(of=("self",))
    return queryset.filter(user=user).first()


def require_rider(user, *, lock: bool = False, active: bool = False) -> Rider:
    """The caller's rider profile, or 403 `PERMISSION_DENIED` with `details.rider_status`."""
    rider = rider_for(user, lock=lock)
    if rider is None:
        raise ApiError(
            ErrorCode.PERMISSION_DENIED,
            MSG_NOT_RIDER,
            details={"rider_status": RiderStatus.NONE},
        )
    if active and rider.status != RiderStatus.ACTIVE:
        raise ApiError(
            ErrorCode.PERMISSION_DENIED,
            MSG_NOT_ACTIVE,
            details={"reason": "RIDER_NOT_ACTIVE", "rider_status": rider.status},
        )
    return rider


def active_stores():
    return DarkStore.objects.filter(is_active=True).order_by("city", "name", "id")


def _store(store_id: int) -> DarkStore:
    store = active_stores().filter(pk=store_id).first()
    if store is None:
        raise ApiError(
            ErrorCode.VALIDATION_ERROR, details={"preferred_store_id": [MSG_UNKNOWN_STORE]}
        )
    return store


# --------------------------------------------------------------------------- completeness


def missing_documents(rider: Rider, documents=None) -> list[str]:
    """Required document types not uploaded yet or REJECTED, in the app's order."""
    documents = rider.documents.all() if documents is None else documents
    status = {doc.doc_type: doc.status for doc in documents}
    return [
        doc_type
        for doc_type in rider.required_documents
        if status.get(doc_type) in (None, DocumentStatus.REJECTED)
    ]


def is_complete(rider: Rider) -> bool:
    return not missing_documents(rider) and rider.has_bank_account


def _after_change(rider: Rider, now) -> list[str]:
    """Mark the application (re)submitted once complete: a REJECTED rider goes back to
    PENDING_KYC (re-submission), a PENDING_KYC one gets `submitted_at`. Returns the fields
    changed (to save)."""
    if rider.status not in OPEN_STATUSES or not is_complete(rider):
        return []
    changed = ["submitted_at"]
    rider.submitted_at = now
    if rider.status == RiderStatus.REJECTED:
        rider.status = RiderStatus.PENDING_KYC
        rider.rejection_reason = ""
        changed += ["status", "rejection_reason"]
    return changed


# --------------------------------------------------------------------------- register & edit


def register(user, data: dict) -> Rider:
    """`POST /rider/register/`: create the profile in PENDING_KYC (04 §2.2). Once only (409
    `INVALID_STATE_TRANSITION` after that; edit with PATCH /rider/me/)."""
    if user.is_staff:
        raise ApiError(ErrorCode.PERMISSION_DENIED, MSG_STAFF)
    store = _store(data["preferred_store_id"])
    existing = rider_for(user)
    if existing is not None:
        raise _already_registered(existing)
    try:
        with transaction.atomic():
            rider = Rider.objects.create(
                user=user,
                status=RiderStatus.PENDING_KYC,
                full_name=data["full_name"],
                dob=data["dob"],
                emergency_contact_name=data["emergency_contact_name"],
                emergency_contact_phone=data["emergency_contact_phone"],
                vehicle_type=data["vehicle_type"],
                vehicle_number=data.get("vehicle_number") or "",
                preferred_store=store,
            )
            if not user.name.strip():
                user.name = data["full_name"]
                user.save(update_fields=["name", "updated_at"])
    except IntegrityError:  # a concurrent registration of the same user won
        raise _already_registered(rider_for(user)) from None
    logger.info("Rider %s registered (user %s)", rider.pk, user.pk)
    return rider_for(user)


def _already_registered(rider: Rider | None) -> ApiError:
    return ApiError(
        ErrorCode.INVALID_STATE_TRANSITION,
        MSG_ALREADY_REGISTERED,
        details={"rider_status": rider.status if rider else RiderStatus.PENDING_KYC},
    )


def update_profile(user, data: dict) -> Rider:
    """`PATCH /rider/me/`. See the module doc for which fields each status may change."""
    with transaction.atomic():
        rider = require_rider(user, lock=True)
        if rider.status not in OPEN_STATUSES:
            locked = sorted(
                name
                for name in data
                if name not in EDITABLE_WHEN_APPROVED and _differs(rider, name, data[name])
            )
            if locked:
                raise ApiError(
                    ErrorCode.VALIDATION_ERROR,
                    details={name: [MSG_LOCKED_FIELD] for name in locked},
                )
        changed = []
        for name, value in data.items():
            if name == "preferred_store_id":
                if value != rider.preferred_store_id:
                    rider.preferred_store = _store(value)
                    changed.append("preferred_store")
            elif getattr(rider, name) != value:
                setattr(rider, name, value)
                changed.append(name)
        if changed:
            changed += _after_change(rider, timezone.now())
            rider.save(update_fields=[*set(changed), "updated_at"])
    return rider_for(user)


def _differs(rider: Rider, name: str, value) -> bool:
    if name == "preferred_store_id":
        return value != rider.preferred_store_id
    return getattr(rider, name) != value


# --------------------------------------------------------------------------- documents


def _clean_image(upload) -> ContentFile:
    """Decode the upload (JPEG/PNG only), apply the EXIF orientation and re-encode as a plain
    JPEG: no metadata (EXIF, GPS) is kept (09 §3, DPDP data minimisation)."""
    try:
        upload.seek(0)
        with Image.open(upload) as probe:
            if probe.format not in ("JPEG", "PNG"):
                raise ApiError(ErrorCode.VALIDATION_ERROR, details={"file": [MSG_BAD_IMAGE]})
            width, height = probe.size
        if width * height > MAX_IMAGE_PIXELS:
            raise ApiError(
                ErrorCode.VALIDATION_ERROR, details={"file": ["The image is too large."]}
            )
        upload.seek(0)
        with Image.open(upload) as image:
            image = ImageOps.exif_transpose(image)
            if image.mode not in ("RGB", "L"):
                image = image.convert("RGB")
            buffer = io.BytesIO()
            image.save(buffer, "JPEG", quality=JPEG_QUALITY, optimize=True)
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        raise ApiError(ErrorCode.VALIDATION_ERROR, details={"file": [MSG_BAD_IMAGE]}) from None
    return ContentFile(buffer.getvalue(), name="document.jpg")


def upload_document(user, *, doc_type: str, upload, number: str) -> RiderDocument:
    """`POST /rider/documents/` (any rider status). Replaces the current copy of that type and
    sends it to review; the number is stored masked (Aadhaar) or encrypted + masked (PAN, DL,
    RC). The old file is deleted after commit."""
    content = _clean_image(upload)
    now = timezone.now()
    saved: list[str] = []
    try:
        document = _store_document(user, doc_type, content, number, now, saved)
    except BaseException:
        # A failed transaction must not leave the new object behind in the bucket.
        for name in saved:
            _delete_file(name)
        raise
    logger.info("Rider %s uploaded %s", document.rider_id, doc_type)
    return document


def _store_document(user, doc_type, content, number, now, saved: list[str]) -> RiderDocument:
    with transaction.atomic():
        rider = require_rider(user, lock=True)
        if doc_type not in rider.required_documents:
            raise ApiError(ErrorCode.VALIDATION_ERROR, details={"doc_type": [MSG_NOT_NEEDED]})
        document = (
            RiderDocument.objects.select_for_update().filter(rider=rider, doc_type=doc_type).first()
        )
        if document is not None and document.status == DocumentStatus.APPROVED:
            raise ApiError(
                ErrorCode.INVALID_STATE_TRANSITION,
                MSG_APPROVED_DOCUMENT,
                details={"doc_type": doc_type, "status": document.status},
            )
        old_name = document.file.name if document is not None else None
        if document is None:
            document = RiderDocument(rider=rider, doc_type=doc_type)
        document.status = DocumentStatus.PENDING
        document.review_note = ""
        document.reviewed_by = None
        document.reviewed_at = None
        document.uploaded_at = now
        document.doc_number_masked = (
            validators.mask_document_number(doc_type, number) if number else ""
        )
        # Aadhaar is never stored in full (masked only); PAN, DL and RC are kept encrypted.
        document.number_encrypted = (
            encrypt(number) if number and doc_type != DocumentType.AADHAAR_FRONT else ""
        )
        document.file.save(content.name, content, save=False)
        saved.append(document.file.name)
        document.save()
        transaction.on_commit(lambda: _delete_file(old_name))
        changed = _after_change(rider, now)
        if changed:
            rider.save(update_fields=[*changed, "updated_at"])
    return document


def _delete_file(name: str | None) -> None:
    if not name:
        return
    from django.core.files.storage import default_storage

    try:
        default_storage.delete(name)
    except Exception:  # best effort: an orphan file is harmless, a failed upload is not
        logger.warning("Could not delete replaced KYC file", exc_info=True)


# --------------------------------------------------------------------------- bank


def set_bank_account(user, *, holder_name: str, account_number: str, ifsc: str, upi_id: str = ""):
    """`PUT /rider/bank-account/` (any status). The account number is stored encrypted, shown
    as the last 4 digits; every change is kept in the rider's history (simple_history)."""
    now = timezone.now()
    with transaction.atomic():
        rider = require_rider(user, lock=True)
        rider.bank_account_name = holder_name
        rider.bank_account_number_encrypted = encrypt(account_number)
        rider.bank_account_last4 = account_number[-4:]
        rider.ifsc = ifsc
        rider.upi_id = upi_id or ""
        rider.bank_updated_at = now
        changed = [
            "bank_account_name",
            "bank_account_number_encrypted",
            "bank_account_last4",
            "ifsc",
            "upi_id",
            "bank_updated_at",
            *_after_change(rider, now),
        ]
        rider.save(update_fields=[*changed, "updated_at"])
    return rider


def document_upload_limit() -> int:
    return settings.RIDER_DOCUMENT_MAX_BYTES

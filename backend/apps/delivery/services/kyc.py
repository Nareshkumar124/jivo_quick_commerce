"""Staff actions on riders (05 §2 "Riders", 05 §3 "Rider approval / suspend"): what the Riders
admin calls. Each one:

- checks the permission `delivery.review_rider` (Super Admin, Ops / Dispatch) and fetches the
  rider **inside the caller's store scope** (`staff_riders`), locked; a rider outside it is
  "not found", never fetched first and checked after;
- writes the audit log (05 §5) in the same transaction, with ids, statuses and reason lengths
  only (no personal data);
- leaves the rider's history to simple_history.

Errors (for the admin's messages): `PermissionDenied` (role), `ValidationError` (not found,
bad input, a rule not met) and `ApiError(INVALID_STATE_TRANSITION)` (wrong rider or document
status; `.message` is readable).

Store Manager has "view own" (05 §3): `staff_riders(user)` returns the riders whose home or
preferred store is one of theirs; it may not review.
"""

from datetime import datetime
from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from apps.accounts.choices import RiderStatus
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.delivery.choices import DocumentStatus
from apps.delivery.models import Rider, RiderDocument
from apps.delivery.services.riders import missing_documents
from apps.stores.services import stores_for

REVIEW = "delivery.review_rider"
VIEW = "delivery.view_rider"
# DL-61 (a): the ops delivery actions on a rider (force offline, set the cash limit): Super Admin,
# Ops/Dispatch, Store Manager for riders whose home store is theirs.
OPS_DELIVERY = "delivery.dispatch_order"
OPEN_FILES = "delivery.view_kyc_document_file"

MSG_NO_PERMISSION = "You do not have permission to do this."
MSG_NOT_FOUND = "Rider not found."
MSG_DOC_NOT_FOUND = "Document not found."
MSG_REASON = "Give a reason (shown to the rider)."
REASON_MAX = 300


# --------------------------------------------------------------------------- scope


def _record(ip, *args):
    """`audit.record` with the request IP the panel passes (`ip=`)."""
    return audit.record(*args, ip=ip)


def _has(user, perm: str) -> bool:
    return bool(user and user.is_active and user.is_staff and user.has_perm(perm))


def can_review(user) -> bool:
    return _has(user, REVIEW)


def staff_riders(user):
    """Riders a staff user may see: home or preferred store in `stores_for(user)` (05 §3)."""
    if not _has(user, VIEW):
        return Rider.objects.none()
    stores = stores_for(user)
    return Rider.objects.filter(Q(home_store__in=stores) | Q(preferred_store__in=stores))


def _locked(user, rider_id: int, perm: str = REVIEW) -> Rider:
    """The rider, row-locked, if `user` has `perm` and the rider is in scope. The KYC actions
    (`REVIEW`) see the home or preferred store; the ops delivery actions (`OPS_DELIVERY`, DL-61)
    only riders whose home store is one of the user's stores."""
    if not _has(user, perm):
        raise PermissionDenied(MSG_NO_PERMISSION)
    if perm == REVIEW:
        ids = staff_riders(user).filter(pk=rider_id).values("pk")
    else:
        ids = Rider.objects.filter(pk=rider_id, home_store__in=stores_for(user)).values("pk")
    rider = (
        Rider.objects.select_for_update(of=("self",))
        .select_related("preferred_store", "home_store")
        .filter(pk__in=ids)
        .first()
    )
    if rider is None:
        raise ValidationError(MSG_NOT_FOUND)
    return rider


def _reason(reason: str) -> str:
    reason = " ".join((reason or "").split())
    if not reason:
        raise ValidationError(MSG_REASON)
    if len(reason) > REASON_MAX:
        raise ValidationError(f"Keep the reason under {REASON_MAX} characters.")
    return reason


def _state(message: str, **details) -> ApiError:
    return ApiError(ErrorCode.INVALID_STATE_TRANSITION, message, details=details)


# --------------------------------------------------------------------------- documents


def _locked_document(user, document_id: int) -> RiderDocument:
    if not can_review(user):
        raise PermissionDenied(MSG_NO_PERMISSION)
    ids = staff_riders(user).values("pk")
    document = (
        RiderDocument.objects.select_for_update(of=("self",))
        .filter(pk=document_id, rider__in=ids)
        .first()
    )
    if document is None:
        raise ValidationError(MSG_DOC_NOT_FOUND)
    return document


def approve_document(document_id: int, *, by, ip: str | None = None) -> RiderDocument:
    """PENDING (or REJECTED) -> APPROVED. Approving an approved document changes nothing."""
    with transaction.atomic():
        document = _locked_document(by, document_id)
        if document.status == DocumentStatus.APPROVED:
            return document
        before = document.status
        document.status = DocumentStatus.APPROVED
        document.review_note = ""
        document.reviewed_by = by
        document.reviewed_at = timezone.now()
        document.save(
            update_fields=["status", "review_note", "reviewed_by", "reviewed_at", "updated_at"]
        )
        _record(
            ip,
            by,
            "rider.document_approve",
            document,
            {"rider": document.rider_id, "doc_type": document.doc_type, "from": before},
        )
    return document


def reject_document(document_id: int, *, by, ip: str | None = None, note: str) -> RiderDocument:
    """Any status -> REJECTED with a note shown to the rider (api-requests #25). The rider's
    status does not change: an ACTIVE rider stays ACTIVE (and cannot go online until a new copy
    is approved); a PENDING_KYC rider is asked for a new copy. A rider already online stays
    online (ops can set them offline)."""
    note = _reason(note)
    with transaction.atomic():
        document = _locked_document(by, document_id)
        before = document.status
        document.status = DocumentStatus.REJECTED
        document.review_note = note
        document.reviewed_by = by
        document.reviewed_at = timezone.now()
        document.save(
            update_fields=["status", "review_note", "reviewed_by", "reviewed_at", "updated_at"]
        )
        _record(
            ip,
            by,
            "rider.document_reject",
            document,
            {
                "rider": document.rider_id,
                "doc_type": document.doc_type,
                "from": before,
                "note_length": len(note),
            },
        )
    return document


def document_file_url(document_id: int, *, by, ip: str | None = None) -> tuple[str, datetime]:
    """A short-lived signed link to a KYC file (09 §3: authorised staff only, private bucket).
    Needs `delivery.view_kyc_document_file` and the rider in scope. Every opening is audited."""
    from datetime import timedelta

    from apps.delivery.services.presenters import signed_url

    if not _has(by, OPEN_FILES):
        raise PermissionDenied(MSG_NO_PERMISSION)
    ids = staff_riders(by).values("pk")
    document = RiderDocument.objects.filter(pk=document_id, rider__in=ids).first()
    if document is None or not document.file:
        raise ValidationError(MSG_DOC_NOT_FOUND)
    seconds = settings.KYC_FILE_URL_EXPIRY_SECONDS
    with transaction.atomic():
        _record(
            ip,
            by,
            "rider.document_view",
            document,
            {"rider": document.rider_id, "doc_type": document.doc_type},
        )
    return signed_url(document.file.name, seconds), timezone.now() + timedelta(seconds=seconds)


def document_number(document_id: int, *, by, ip: str | None = None) -> str:
    """The full PAN/DL/RC number (decrypted) for verification by an authorised reviewer;
    audited. Aadhaar is never stored in full ("" for it and for image-only documents)."""
    if not can_review(by) or not _has(by, OPEN_FILES):
        raise PermissionDenied(MSG_NO_PERMISSION)
    ids = staff_riders(by).values("pk")
    document = RiderDocument.objects.filter(pk=document_id, rider__in=ids).first()
    if document is None:
        raise ValidationError(MSG_DOC_NOT_FOUND)
    with transaction.atomic():
        _record(
            ip,
            by,
            "rider.document_number_view",
            document,
            {"rider": document.rider_id, "doc_type": document.doc_type},
        )
    return document.number()  # ValidationError (readable) when it cannot be decrypted


# --------------------------------------------------------------------------- rider status


def approve_rider(
    rider_id: int, *, by, ip: str | None = None, home_store_id: int | None = None, cash_limit=None
) -> Rider:
    """PENDING_KYC -> ACTIVE (04 §2.2). Needs every required document APPROVED and bank
    details. The home store defaults to the preferred store and must be in the caller's scope;
    `cash_limit` defaults to the rider's current limit (₹5,000 for a new rider)."""
    with transaction.atomic():
        rider = _locked(by, rider_id)
        if rider.status != RiderStatus.PENDING_KYC:
            raise _state(
                "Only a rider waiting for KYC review can be approved.", status=rider.status
            )
        documents = list(rider.documents.all())
        pending = [
            doc_type
            for doc_type in rider.required_documents
            if not any(
                d.doc_type == doc_type and d.status == DocumentStatus.APPROVED for d in documents
            )
        ]
        if pending:
            raise ValidationError(
                "Approve every required document first: " + ", ".join(pending) + "."
            )
        if not rider.has_bank_account:
            raise ValidationError("The rider has not added bank details yet.")
        store = _scoped_store(by, home_store_id or rider.preferred_store_id)
        rider.home_store = store
        if cash_limit is not None:
            rider.cash_limit = _cash_limit(cash_limit)
        rider.status = RiderStatus.ACTIVE
        rider.rejection_reason = ""
        rider.approved_at = timezone.now()
        rider.approved_by = by
        rider.save()
        _record(
            ip,
            by,
            "rider.approve",
            rider,
            {"home_store": store.pk, "cash_limit": str(rider.cash_limit)},
        )
    return rider


def reject_rider(rider_id: int, *, by, ip: str | None = None, reason: str) -> Rider:
    """PENDING_KYC -> REJECTED with a reason shown to the rider. The rider can fix what is
    asked (re-upload, edit the profile); once nothing required is missing or rejected the
    application returns to PENDING_KYC by itself (`riders._after_change`)."""
    reason = _reason(reason)
    with transaction.atomic():
        rider = _locked(by, rider_id)
        if rider.status != RiderStatus.PENDING_KYC:
            raise _state(
                "Only a rider waiting for KYC review can be rejected.", status=rider.status
            )
        rider.status = RiderStatus.REJECTED
        rider.rejection_reason = reason
        rider.save(update_fields=["status", "rejection_reason", "updated_at"])
        _record(ip, by, "rider.reject", rider, {"reason_length": len(reason)})
    return rider


def suspend_rider(rider_id: int, *, by, ip: str | None = None, reason: str) -> Rider:
    """ACTIVE -> SUSPENDED. The rider is set offline (shift ended, reason ADMIN). Refused while
    the rider has an active delivery task (reassign it first, slice 5.3)."""
    from apps.delivery.services import shifts

    reason = _reason(reason)
    with transaction.atomic():
        rider = _locked(by, rider_id)
        if rider.status != RiderStatus.ACTIVE:
            raise _state("Only an active rider can be suspended.", status=rider.status)
        if shifts.has_active_task(rider):
            raise _state("The rider is on a delivery. Reassign it first.", status=rider.status)
        shifts.end_open_shift(rider, reason=shifts.ShiftEndReason.ADMIN, by=by)
        rider.status = RiderStatus.SUSPENDED
        rider.suspension_reason = reason
        rider.is_online = False
        rider.save(update_fields=["status", "suspension_reason", "is_online", "updated_at"])
        _record(ip, by, "rider.suspend", rider, {"reason_length": len(reason)})
    return rider


def reinstate_rider(rider_id: int, *, by, ip: str | None = None) -> Rider:
    """SUSPENDED -> ACTIVE."""
    with transaction.atomic():
        rider = _locked(by, rider_id)
        if rider.status != RiderStatus.SUSPENDED:
            raise _state("Only a suspended rider can be reinstated.", status=rider.status)
        rider.status = RiderStatus.ACTIVE
        rider.suspension_reason = ""
        rider.save(update_fields=["status", "suspension_reason", "updated_at"])
        _record(ip, by, "rider.reinstate", rider, {})
    return rider


def set_home_store(rider_id: int, store_id: int, *, by, ip: str | None = None) -> Rider:
    """Move a rider to another home store (offline riders only: offers follow the store)."""
    with transaction.atomic():
        rider = _locked(by, rider_id)
        if rider.is_online:
            raise _state("Set the rider offline first.", status=rider.status)
        store = _scoped_store(by, store_id)
        before = rider.home_store_id
        rider.home_store = store
        rider.save(update_fields=["home_store", "updated_at"])
        _record(ip, by, "rider.home_store", rider, {"from": before, "to": store.pk})
    return rider


def set_cash_limit(rider_id: int, amount, *, by, ip: str | None = None) -> Rider:
    """Change a rider's cash-in-hand limit (04 §2.7). Money: a 2-decimal amount, 0 or more.
    DL-61 (a): Super Admin, Ops, Store Manager (riders of their own stores)."""
    limit = _cash_limit(amount)
    with transaction.atomic():
        rider = _locked(by, rider_id, OPS_DELIVERY)
        before = rider.cash_limit
        rider.cash_limit = limit
        rider.save(update_fields=["cash_limit", "updated_at"])
        _record(
            ip, by, "rider.cash_limit", rider, {"from": str(before), "to": str(rider.cash_limit)}
        )
    return rider


def _cash_limit(amount) -> Decimal:
    try:
        value = Decimal(str(amount))
    except (InvalidOperation, ValueError):
        raise ValidationError("Enter the limit in rupees, e.g. 5000.00.") from None
    if not value.is_finite() or value < 0 or value != value.quantize(Decimal("0.01")):
        raise ValidationError("Enter the limit in rupees, e.g. 5000.00.")
    if value > Decimal("1000000.00"):
        raise ValidationError("The limit is too high.")
    return value


def _scoped_store(user, store_id: int):
    store = stores_for(user).filter(pk=store_id, is_active=True).first()
    if store is None:
        raise ValidationError("Choose an active store you manage.")
    return store


def online_blockers(rider: Rider) -> list[str]:
    """Why a rider may not go online (04 §2.3, api-requests #25), as reason codes; [] when
    nothing blocks. Distance to the store and permissions are checked at shift start."""
    if rider.status != RiderStatus.ACTIVE:
        return ["RIDER_NOT_ACTIVE"]
    if (
        missing_documents(rider)
        or rider.documents.exclude(status=DocumentStatus.APPROVED)
        .filter(doc_type__in=rider.required_documents)
        .exists()
    ):
        return ["DOCUMENTS_NOT_APPROVED"]
    return []

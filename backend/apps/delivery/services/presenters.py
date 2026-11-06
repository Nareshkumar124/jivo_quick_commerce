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
        "deposit_required": rider.cash_limit_reached or rider.cash_skipped_at is not None,
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


# --------------------------------------------------------------------------- offers & tasks (5.3)


def _locality(order) -> str:
    """Area only, never the full address (04 §2.4)."""
    snapshot = order.address_snapshot or {}
    parts = [snapshot.get("area", ""), snapshot.get("city", "")]
    return ", ".join(part for part in parts if part)


def _units(order) -> int:
    return sum(item.quantity - item.quantity_unavailable for item in order.items.all())


def _payment_type(order) -> str:
    from apps.delivery.choices import PaymentType
    from apps.orders.choices import PaymentMethod

    return PaymentType.COD if order.payment_method == PaymentMethod.COD else PaymentType.PREPAID


def _cod_amount(order) -> str | None:
    from apps.orders.choices import PaymentMethod

    return money_str(order.grand_total) if order.payment_method == PaymentMethod.COD else None


def offer_body(offer, order, task) -> dict:
    return {
        "id": offer.pk,
        "task_id": task.pk,
        "store_name": order.store.name,
        "drop_locality": _locality(order),
        "distance_km": str(task.distance_km),
        "payment_type": _payment_type(order),
        "cod_amount": _cod_amount(order),
        "estimated_payout": money_str(task.payout_amount),
        "item_count": _units(order),
        "offered_at": offer.offered_at,
        "expires_at": offer.expires_at,
    }


def current_offer_body(offer, now) -> dict:
    if offer is None:
        return {"offer": None, "server_time": now}
    task = offer.task
    return {"offer": offer_body(offer, task.order, task), "server_time": now}


def task_body(task) -> dict:
    """`RiderTask` (06 §3, api-requests #13). The full address and phone are revealed only
    here, i.e. after accepting."""
    from apps.delivery.services.tasks import (
        not_reachable_after,
        otp_attempts_remaining,
        pickup_attempts_remaining,
    )
    from apps.orders.choices import OrderStatus

    order = task.order
    store = order.store
    items = [
        {
            "name": item.product_name,
            "variant": item.variant_name,
            "quantity": item.quantity - item.quantity_unavailable,
        }
        for item in order.items.all()
        if item.quantity > item.quantity_unavailable
    ]
    instructions = order.instructions or {}
    previous = task.cod_amount_previous
    return {
        "id": task.pk,
        "status": task.status,
        "order_id": order.pk,
        "order_number": order.order_number,
        "order_status": order.status,
        "ready_for_pickup": order.status == OrderStatus.PACKED,
        "payment_type": _payment_type(order),
        "cod_amount_due": _cod_amount(order),
        "cod_amount_previous": (
            money_str(previous)
            if previous is not None and _cod_amount(order) and previous != order.grand_total
            else None
        ),
        "store": {
            "id": store.pk,
            "name": store.name,
            "address": store.address,
            "phone": store.phone,
            "lat": store.location.y,
            "lng": store.location.x,
        },
        "customer_address": order.address_snapshot,
        "instructions": {
            "chips": list(instructions.get("chips", [])),
            "note": instructions.get("note", ""),
        },
        "items": items,
        "item_count": sum(item["quantity"] for item in items),
        "distance_km": str(task.distance_km),
        "estimated_payout": money_str(task.payout_amount),
        "geofence": {
            "store_radius_m": settings.RIDER_STORE_GEOFENCE_M,
            "customer_radius_m": settings.RIDER_CUSTOMER_GEOFENCE_M,
        },
        "delivery_otp": {
            "length": settings.DELIVERY_OTP_LENGTH,
            "attempts_remaining": otp_attempts_remaining(task),
            "locked": task.otp_locked_at is not None,
        },
        "pickup_code": {
            "attempts_remaining": pickup_attempts_remaining(task),
            "locked": task.pickup_locked_at is not None,
        },
        "cod_qr": _cod_qr(task),
        "assigned_at": task.assigned_at,
        "arrived_store_at": task.arrived_store_at,
        "picked_up_at": task.picked_up_at,
        "arrived_customer_at": task.arrived_customer_at,
        "not_reachable_after": not_reachable_after(task),
        "delivered_at": task.delivered_at,
        "failed_at": task.failed_at,
        "fail_reason": task.fail_reason or None,
        "returned_at": task.returned_at,
        "earnings": _earnings(task),
    }


def _cod_qr(task) -> dict | None:
    """The open QR (PENDING/PAID), else the newest; from the prefetched `cod_qrs`."""
    from apps.delivery.services import cod_qr

    qrs = sorted(task.cod_qrs.all(), key=lambda qr: (qr.created_at, qr.pk), reverse=True)
    chosen = next((qr for qr in qrs if qr.status in cod_qr.OPEN), qrs[0] if qrs else None)
    return cod_qr.body(chosen)


def _earnings(task) -> dict | None:
    """The task's pay lines (DL-61 c: from pickup), or null before pickup."""
    from apps.delivery.services.earnings import task_earnings_body

    return task_earnings_body(list(task.earnings.all()))


def task_queryset():
    from apps.delivery.models import DeliveryTask

    return DeliveryTask.objects.select_related("order__store", "store", "rider").prefetch_related(
        "order__items", "cod_qrs", "earnings"
    )


def current_task_body(rider, now) -> dict:
    from apps.delivery.services.tasks import active_task, recent_task

    task = active_task(rider)
    if task is not None:
        task = task_queryset().get(pk=task.pk)
        return {"task": task_body(task), "recent_task": None, "server_time": now}
    recent = recent_task(rider, now)
    return {
        "task": None,
        "recent_task": (
            {
                "id": recent.pk,
                "order_number": recent.order.order_number,
                "status": recent.status,
                "ended_at": recent.ended_at,
            }
            if recent
            else None
        ),
        "server_time": now,
    }

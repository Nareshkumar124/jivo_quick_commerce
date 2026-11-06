"""Notifications (08 §9): who gets which push, SMS and inbox entry for an event, and the inbox.

Entry points:
- `notify(user, event, context, ...)`: one event for one user. Records a `Notification` (keyed
  on `dedupe_key`, so it is idempotent per event, user and order) and, after commit, queues
  the push and SMS tasks for the channels the event uses (`apps.notifications.catalog`).
- `send_push(user, event, data)` / `send_sms(user, event, data)`: the same, one channel only
  (Phase 5 calls `send_push` for rider offers and amount changes).
- `notify_order(order, event, **extra)`: `notify` for the order's customer with the order's
  context (Phase 5: `order.out_for_delivery` with `rider_name` and `otp`, `order.rider_arrived`).
- `notify_order_event(event, order_id)`: the customer side of the order domain events.

Delivery (`deliver_push`, `deliver_sms`, run by Celery) claims a channel PENDING -> SENDING with
a conditional UPDATE, so two workers or a retried task never send the same channel twice. A
worker that dies while SENDING leaves the channel there (at most once beats a duplicate SMS).
"""

import logging
import re
import uuid
from collections.abc import Mapping
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound

from apps.accounts.choices import AppName
from apps.core.money import ZERO, rupees
from apps.notifications import push as push_backend
from apps.notifications.catalog import EventSpec, get_spec
from apps.notifications.choices import Channel, DeliveryStatus
from apps.notifications.models import Notification, NotificationTemplate
from apps.notifications.sms import SmsError, SmsOutcomeUnknown, SmsRejected, mask_phone, send_sms

logger = logging.getLogger(__name__)

MSG_NOT_FOUND = "Notification not found."
_PLACEHOLDER = re.compile(r"\{\{\s*([a-z_][a-z0-9_]*)\s*\}\}")
_SPACES = re.compile(r"\s{2,}")


# --------------------------------------------------------------------------- inbox


def app_of_token(token) -> str:
    """The app an access token was issued to (`app` claim, 02 §6); customer if absent."""
    app = token.get("app") if token is not None else None
    return app if app in AppName.values else AppName.CUSTOMER


def inbox(user, app: str):
    return Notification.objects.filter(user=user, app=app, in_inbox=True).order_by(
        "-created_at", "-id"
    )


def mark_read(user, app: str, notification_id: int) -> Notification:
    notification = inbox(user, app).filter(pk=notification_id).first()
    if notification is None:
        raise NotFound(MSG_NOT_FOUND)
    if notification.read_at is None:
        now = timezone.now()
        Notification.objects.filter(pk=notification.pk, read_at__isnull=True).update(
            read_at=now, updated_at=now
        )
        notification.refresh_from_db(fields=["read_at", "updated_at"])
    return notification


def mark_all_read(user, app: str) -> int:
    now = timezone.now()
    return inbox(user, app).filter(read_at__isnull=True).update(read_at=now, updated_at=now)


def purge_old_notifications(now=None, batch_size: int = 5000) -> int:
    """Delete notifications older than NOTIFICATION_RETENTION_DAYS (beat, daily), in batches."""
    cutoff = (now or timezone.now()) - timedelta(days=settings.NOTIFICATION_RETENTION_DAYS)
    total = 0
    while True:
        ids = list(
            Notification.objects.filter(created_at__lt=cutoff).values_list("pk", flat=True)[
                :batch_size
            ]
        )
        if not ids:
            return total
        deleted, _ = Notification.objects.filter(pk__in=ids).delete()
        total += deleted


def sweep_stuck_sends(now=None) -> int:
    """Channels left SENDING longer than NOTIFICATION_STUCK_SEND_MINUTES (a worker died while
    sending): mark them FAILED and blank their texts (they can hold an OTP). Never resent:
    the message may have gone out. Logged at ERROR (ops alert). Beat, every 15 minutes."""
    cutoff = (now or timezone.now()) - timedelta(minutes=settings.NOTIFICATION_STUCK_SEND_MINUTES)
    stamp = timezone.now()
    stuck = Notification.objects.filter(updated_at__lt=cutoff)
    push_ids = list(stuck.filter(push_status=DeliveryStatus.SENDING).values_list("pk", flat=True))
    sms_ids = list(stuck.filter(sms_status=DeliveryStatus.SENDING).values_list("pk", flat=True))
    if push_ids:
        Notification.objects.filter(pk__in=push_ids, push_status=DeliveryStatus.SENDING).update(
            push_status=DeliveryStatus.FAILED, push_body="", updated_at=stamp
        )
    if sms_ids:
        Notification.objects.filter(pk__in=sms_ids, sms_status=DeliveryStatus.SENDING).update(
            sms_status=DeliveryStatus.FAILED, sms_body="", updated_at=stamp
        )
    if push_ids or sms_ids:
        logger.error(
            "Notifications stuck while sending, marked FAILED: push=%s sms=%s", push_ids, sms_ids
        )
    return len(push_ids) + len(sms_ids)


# --------------------------------------------------------------------------- rendering


def render(text: str, context: Mapping[str, Any]) -> str:
    """`{{name}}` -> str(context[name]); unknown names render empty. No attribute access or
    format specs, so a template edited in the admin cannot read anything else."""

    def value(match: re.Match) -> str:
        found = context.get(match.group(1))
        return "" if found is None else str(found)

    return _SPACES.sub(" ", _PLACEHOLDER.sub(value, text)).strip()


def _template(event: str, channel: str, app: str) -> NotificationTemplate | None:
    return NotificationTemplate.objects.filter(
        event=event, channel=channel, app=app, is_active=True
    ).first()


def _texts(spec: EventSpec, context: Mapping[str, Any]) -> dict[str, str]:
    push_title, push_body, sms_body = spec.title, spec.body, spec.sms
    dlt_id = settings.SMS_DLT_TEMPLATE_IDS.get(spec.event, "")
    if (row := _template(spec.event, Channel.PUSH, spec.app)) is not None:
        push_title, push_body = row.title or push_title, row.body
    if spec.sms and (row := _template(spec.event, Channel.SMS, spec.app)) is not None:
        sms_body, dlt_id = row.body, row.dlt_template_id or dlt_id
    title = render(push_title, context)[:120]
    body = render(push_body, context)[:500]
    return {
        "title": title,
        "body": body,
        "inbox_body": render(spec.inbox_body, context)[:500] if spec.inbox_body else body,
        "sms_body": render(sms_body, context)[:500] if sms_body else "",
        "dlt_id": dlt_id,
    }


FCM_KEYS = {
    # api-requests #30: {type: order|product|collection|category, order_id | slug}
    AppName.CUSTOMER: ("order_id", "slug"),
    # api-requests #41: {type: offer.new|offer.withdrawn|task.updated, offer_id?, task_id?}
    AppName.RIDER: ("offer_id", "task_id"),
}


def push_data(spec: EventSpec, context: Mapping[str, Any]) -> dict[str, str]:
    """What the notification row keeps: the FCM payload fields (`fcm_payload`), plus the
    inbox `link` (`jivo://`) and the event name. Every value a string."""
    data = {"event": spec.event, "type": spec.data_type}
    for key in FCM_KEYS.get(spec.app, ()):
        if context.get(key) not in (None, ""):
            data[key] = str(context[key])
    if spec.link and (link := render(spec.link, context)):
        data["link"] = link
    return data


def fcm_payload(app: str, data: Mapping[str, Any]) -> dict[str, str]:
    """The FCM data payload exactly as the apps parse it (06 §4.3): `type` plus its ids. A
    customer notification with no `type`-routable id falls back to `{link}`."""
    payload = {"type": str(data["type"])} if data.get("type") else {}
    for key in FCM_KEYS.get(app, ()):
        if data.get(key) not in (None, ""):
            payload[key] = str(data[key])
    if app == AppName.CUSTOMER and len(payload) <= 1:
        return {"link": str(data["link"])} if data.get("link") else payload
    return payload


# --------------------------------------------------------------------------- notify


def _can_receive(user) -> bool:
    return bool(user and user.is_active and user.deleted_at is None and user.anonymised_at is None)


def notify(
    user,
    event: str,
    context: Mapping[str, Any] | None = None,
    *,
    order_id: int | None = None,
    dedupe_key: str | None = None,
    push: bool = True,
    sms: bool = True,
) -> Notification | None:
    """Notify `user` of `event` (see the module doc). Safe to call twice: the second call finds
    the first notification (and only queues channels it adds). Returns None when the event is
    unknown or the user cannot receive notifications (inactive, deleted)."""
    spec = get_spec(event)
    if spec is None:
        logger.error("notify: unknown event %s (user %s)", event, getattr(user, "pk", None))
        return None
    if not _can_receive(user):
        logger.info("notify: user %s cannot receive %s, skipped", getattr(user, "pk", None), event)
        return None
    context = dict(context or {})
    if order_id is not None:
        context.setdefault("order_id", order_id)
    order_id = order_id if order_id is not None else _int_or_none(context.get("order_id"))
    if dedupe_key is None:
        ref = context.get("ref") or order_id or context.get("offer_id") or context.get("task_id")
        dedupe_key = f"{event}:{user.pk}:{ref if ref not in (None, '') else uuid.uuid4().hex}"
    texts = _texts(spec, context)
    wants_push = push and spec.push
    wants_sms = sms and bool(texts["sms_body"])
    with transaction.atomic():
        notification, created = Notification.objects.select_for_update().get_or_create(
            dedupe_key=dedupe_key[:200],
            defaults={
                "user": user,
                "app": spec.app,
                "event": event,
                "category": spec.category,
                "title": texts["title"],
                "body": texts["inbox_body"],
                "data": push_data(spec, context),
                "order_id": order_id,
                "in_inbox": spec.inbox,
                "push_status": DeliveryStatus.PENDING if wants_push else DeliveryStatus.NONE,
                "push_title": texts["title"] if wants_push else "",
                "push_body": texts["body"] if wants_push else "",
                "sms_status": DeliveryStatus.PENDING if wants_sms else DeliveryStatus.NONE,
                "sms_body": texts["sms_body"] if wants_sms else "",
                "sms_dlt_template_id": texts["dlt_id"] if wants_sms else "",
            },
        )
        if not created:
            changed = []
            if wants_push and notification.push_status == DeliveryStatus.NONE:
                notification.push_status = DeliveryStatus.PENDING
                notification.push_title, notification.push_body = texts["title"], texts["body"]
                changed += ["push_status", "push_title", "push_body"]
            if wants_sms and notification.sms_status == DeliveryStatus.NONE:
                notification.sms_status = DeliveryStatus.PENDING
                notification.sms_body = texts["sms_body"]
                notification.sms_dlt_template_id = texts["dlt_id"]
                changed += ["sms_status", "sms_body", "sms_dlt_template_id"]
            if changed:
                notification.save(update_fields=[*changed, "updated_at"])
        _queue(notification)
    return notification


def _queue(notification: Notification) -> None:
    """After commit, queue the channels still PENDING (again, after a lost queue: the claim in
    `deliver_*` keeps that safe)."""
    from apps.notifications import tasks

    pk = notification.pk
    if notification.push_status == DeliveryStatus.PENDING:
        transaction.on_commit(lambda: tasks.send_push_task.delay(pk))
    if notification.sms_status == DeliveryStatus.PENDING:
        transaction.on_commit(lambda: tasks.send_sms_task.delay(pk))


def send_push(user, event: str, data: Mapping[str, Any] | None = None) -> Notification | None:
    """Push only (no SMS) for `event`; `data` is the template context plus the ids
    (`order_id`, `offer_id`, `task_id`) and optionally `ref` / `dedupe_key`."""
    data = dict(data or {})
    return notify(user, event, data, dedupe_key=data.pop("dedupe_key", None), sms=False)


def send_sms_notification(
    user, event: str, data: Mapping[str, Any] | None = None
) -> Notification | None:
    """SMS only (no push) for `event` (events with SMS text in the catalog)."""
    data = dict(data or {})
    return notify(user, event, data, dedupe_key=data.pop("dedupe_key", None), push=False)


def _int_or_none(value) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


# --------------------------------------------------------------------------- delivery


def _claim(notification_id: int, field: str) -> bool:
    return bool(
        Notification.objects.filter(pk=notification_id, **{field: DeliveryStatus.PENDING}).update(
            **{field: DeliveryStatus.SENDING, "updated_at": timezone.now()}
        )
    )


def _finish(notification_id: int, channel: str, status: str) -> None:
    now = timezone.now()
    if channel == Channel.PUSH:
        values = {"push_status": status, "push_body": ""}
        if status == DeliveryStatus.SENT:
            values["push_sent_at"] = now
    else:
        values = {"sms_status": status, "sms_body": ""}
        if status == DeliveryStatus.SENT:
            values["sms_sent_at"] = now
    Notification.objects.filter(pk=notification_id).update(**values, updated_at=now)


def release_claim(notification_id: int, channel: str) -> None:
    """Back to PENDING after a transient failure, so the retry can claim it again."""
    field = "push_status" if channel == Channel.PUSH else "sms_status"
    Notification.objects.filter(pk=notification_id, **{field: DeliveryStatus.SENDING}).update(
        **{field: DeliveryStatus.PENDING}
    )


def fail(notification_id: int, channel: str) -> None:
    _finish(notification_id, channel, DeliveryStatus.FAILED)


def deliver_push(notification_id: int) -> str:
    """Send the push of one notification to the user's active devices of that app. Raises
    `PushError` (transient) after putting the channel back to PENDING."""
    from apps.accounts.models import Device

    if not _claim(notification_id, "push_status"):
        return "skipped"
    notification = Notification.objects.select_related("user").get(pk=notification_id)
    tokens = tuple(
        Device.objects.filter(
            user_id=notification.user_id, app=notification.app, is_active=True
        ).values_list("fcm_token", flat=True)
    )
    if not tokens or not _can_receive(notification.user):
        _finish(notification_id, Channel.PUSH, DeliveryStatus.SKIPPED)
        return "no_device"
    message = push_backend.PushMessage(
        tokens=tokens,
        title=notification.push_title,
        body=notification.push_body,
        data=fcm_payload(notification.app, notification.data),
        event=notification.event,
        app=notification.app,
    )
    try:
        result = push_backend.get_backend().send(message)
    except push_backend.PushDisabled:
        _finish(notification_id, Channel.PUSH, DeliveryStatus.SKIPPED)
        return "disabled"
    except push_backend.PushError:
        release_claim(notification_id, Channel.PUSH)
        raise
    if result.invalid_tokens:
        Device.objects.filter(fcm_token__in=result.invalid_tokens).update(
            is_active=False, updated_at=timezone.now()
        )
    status = DeliveryStatus.SENT if result.sent else DeliveryStatus.SKIPPED
    _finish(notification_id, Channel.PUSH, status)
    logger.info(
        "Push %s: notification=%s event=%s user=%s devices=%s",
        status,
        notification_id,
        notification.event,
        notification.user_id,
        result.sent,
    )
    return "sent" if result.sent else "no_valid_device"


def deliver_sms(notification_id: int) -> str:
    """Send the SMS of one notification to the user's phone (DLT template required). Raises
    `SmsError` (transient: nothing was sent) after putting the channel back to PENDING."""
    if not _claim(notification_id, "sms_status"):
        return "skipped"
    notification = Notification.objects.select_related("user").get(pk=notification_id)
    user = notification.user
    if not _can_receive(user) or not user.phone:
        _finish(notification_id, Channel.SMS, DeliveryStatus.SKIPPED)
        return "no_phone"
    if not notification.sms_dlt_template_id:
        logger.warning(
            "SMS for %s not sent: no DLT template id (SMS_DLT_TEMPLATE_IDS), notification=%s",
            notification.event,
            notification_id,
        )
        _finish(notification_id, Channel.SMS, DeliveryStatus.SKIPPED)
        return "no_dlt_template"
    try:
        send_sms(user.phone, notification.sms_body, notification.sms_dlt_template_id)
    except SmsError:
        release_claim(notification_id, Channel.SMS)
        raise
    except (SmsRejected, SmsOutcomeUnknown, ImproperlyConfigured) as exc:
        # Not retried: a rejected number cannot succeed, and an unknown outcome might already
        # have been delivered (no idempotency key at the gateway).
        logger.warning(
            "SMS for %s not sent (%s): notification=%s phone=%s",
            notification.event,
            type(exc).__name__,
            notification_id,
            mask_phone(user.phone),
        )
        _finish(notification_id, Channel.SMS, DeliveryStatus.FAILED)
        return "failed"
    _finish(notification_id, Channel.SMS, DeliveryStatus.SENT)
    logger.info(
        "SMS sent: notification=%s event=%s phone=%s",
        notification_id,
        notification.event,
        mask_phone(user.phone),
    )
    return "sent"


# --------------------------------------------------------------------------- order events


def _amount(value) -> str:
    """ "1,249.50" (no symbol: templates add ₹ or Rs)."""
    return rupees(value).lstrip("-").lstrip("₹")


def order_context(order) -> dict[str, Any]:
    from apps.orders.choices import PaymentMethod

    paid_online = order.payment_method == PaymentMethod.ONLINE and order.amount_paid > ZERO
    total = _amount(order.grand_total)
    if paid_online:
        amount_line = (
            f"New order total: ₹{total}. The difference will be refunded to your original "
            "payment method."
        )
        amount_line_sms = (
            f"New total Rs {total}. The difference will be refunded to your payment method."
        )
        refund_line = (
            "The amount you paid will be refunded to your original payment method in 5-7 "
            "working days."
        )
        refund_line_sms = "Your payment will be refunded in 5-7 working days."
    else:
        amount_line = f"New amount to pay on delivery: ₹{total}."
        amount_line_sms = f"New amount to pay on delivery: Rs {total}."
        refund_line = refund_line_sms = ""
    return {
        "order_id": order.pk,
        "order_number": order.order_number,
        "grand_total": total,
        "store_name": order.store.name,
        "amount_line": amount_line,
        "amount_line_sms": amount_line_sms,
        "refund_line": refund_line,
        "refund_line_sms": refund_line_sms,
    }


def cancel_refund_lines(order) -> dict[str, str]:
    """The refund sentence of a cancelled online order, with the **stored** refund amount
    (`Refund.amount` of `cancel:<order>`, or its newest retry), never a computed one. Empty
    when there is no such refund (COD, or nothing was paid)."""
    from django.db.models import Q

    from apps.core.money import money_str
    from apps.payments.models import Refund

    key = f"cancel:{order.pk}"
    refund = (
        Refund.objects.filter(order=order)
        .filter(Q(idempotency_key=key) | Q(idempotency_key__startswith=f"{key}:"))
        .order_by("-created_at", "-pk")
        .first()
    )
    if refund is None:
        return {}
    amount = money_str(refund.amount)
    return {
        "refund_line": f"A refund of ₹{amount} will reach your original payment method in 5-7 "
        "working days.",
        "refund_line_sms": f"Your refund of Rs {amount} will reach you in 5-7 working days.",
    }


def notify_refund_processed(refund) -> Notification | None:
    """`refund.processed` (08 §9: push + SMS) for a refund that reached PROCESSED, with its
    stored amount. Idempotent per refund. For payments to call after commit."""
    from apps.core.money import money_str

    order = refund.order
    return notify_order(
        order,
        "refund.processed",
        amount=money_str(refund.amount),
        dedupe_key=f"refund.processed:{order.user_id}:{refund.pk}",
    )


def notify_order(order, event: str, **extra) -> Notification | None:
    """`notify` the order's customer of `event`, with the order's context plus `extra`."""
    dedupe_key = extra.pop("dedupe_key", None)
    context = {**order_context(order), **extra}
    return notify(order.user, event, context, order_id=order.pk, dedupe_key=dedupe_key)


# Order domain events (apps.orders.events) -> the customer notification (08 §9). Events not
# listed (PAYMENT_PENDING, PACKING, PACKED, ops alerts) notify no customer. Phase 5 events with
# extra context (out for delivery with the OTP, rider arrived) are sent by Phase 5 itself with
# `notify_order`, since a domain event carries only the order id.
ORDER_EVENT_NOTIFICATIONS = {
    "order.placed": "order.placed",
    "order.payment_failed": "order.payment_failed",
    "order.accepted": "order.accepted",
    "order.items_adjusted": "order.items_adjusted",
    "order.cancelled": "order.cancelled",
    "order.delivered": "order.delivered",
    "order.delivery_failed": "order.delivery_failed",
}


def notify_order_event(event: str, order_id: int) -> Notification | None:
    from apps.orders.models import Order

    notification_event = ORDER_EVENT_NOTIFICATIONS.get(event)
    if notification_event is None:
        return None
    order = Order.objects.select_related("user", "store").filter(pk=order_id).first()
    if order is None:
        return None
    dedupe_key = None
    if event == "order.items_adjusted":
        # Several adjustments can happen; each lowers the total, so the total keys each one (two
        # quick adjustments read the same final order and send one message with the result).
        dedupe_key = f"{event}:{order.user_id}:{order.pk}:{order.grand_total}"
    context = order_context(order)
    if event == "order.cancelled":
        context.update(cancel_refund_lines(order))
    return notify(order.user, notification_event, context, order_id=order.pk, dedupe_key=dedupe_key)

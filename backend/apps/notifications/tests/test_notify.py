"""Notifications per event (08 §9): push / SMS / inbox, idempotency per (event, user, order),
delivery outcomes and retries, templates, FCM data payloads (api-requests #30, #41)."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts.models import Device
from apps.accounts.tests.factories import UserFactory
from apps.notifications import push, services, sms, tasks
from apps.notifications.choices import DeliveryStatus
from apps.notifications.models import Notification, NotificationTemplate
from apps.orders.choices import OrderStatus, PaymentMethod, PaymentStatus
from apps.orders.tests.factories import OrderFactory

pytestmark = pytest.mark.django_db


def device(user, app="customer", token=None) -> Device:
    return Device.objects.create(
        user=user,
        app=app,
        platform="android",
        fcm_token=token or f"fcm-{user.pk}-{app}-{Device.objects.count()}",
        app_version="1.0.0",
        last_seen_at=timezone.now(),
    )


@pytest.fixture
def run_on_commit(django_capture_on_commit_callbacks):
    def run(fn, *args, **kwargs):
        with django_capture_on_commit_callbacks(execute=True):
            return fn(*args, **kwargs)

    return run


@pytest.fixture
def order():
    return OrderFactory()


# --------------------------------------------------------------------------- order events


def test_placed_sends_push_sms_and_inbox(order, run_on_commit):
    """08 §9 T2/T3: customer push + SMS "Order placed"."""
    device(order.user)
    notification = run_on_commit(services.notify_order_event, "order.placed", order.pk)
    notification.refresh_from_db()
    assert notification.title == "Order placed"
    assert order.order_number in notification.body
    assert notification.in_inbox
    assert notification.link == f"jivo://orders/{order.pk}"
    assert notification.push_status == DeliveryStatus.SENT
    assert notification.sms_status == DeliveryStatus.SENT
    assert notification.push_body == notification.sms_body == ""  # cleared once final
    [message] = push.outbox
    assert message.title == "Order placed"
    assert message.data == {"type": "order", "order_id": str(order.pk)}  # #30
    [text] = sms.outbox
    assert text.to == order.user.phone
    assert text.dlt_template_id == "1007000000000000101"
    assert "Rs 300" in text.body
    assert order.order_number in text.body


def test_the_same_event_twice_notifies_once(order, run_on_commit):
    device(order.user)
    first = run_on_commit(services.notify_order_event, "order.placed", order.pk)
    second = run_on_commit(services.notify_order_event, "order.placed", order.pk)
    assert first.pk == second.pk
    assert Notification.objects.count() == 1
    assert len(push.outbox) == 1
    assert len(sms.outbox) == 1


@pytest.mark.parametrize(
    "event",
    ["order.payment_pending", "order.packing", "order.packed", "payment.late_capture"],
)
def test_events_without_a_customer_notification(order, event):
    assert services.notify_order_event(event, order.pk) is None
    assert not Notification.objects.exists()


def test_unknown_order_notifies_nobody():
    assert services.notify_order_event("order.placed", 999_999) is None


def test_accepted_is_push_only(order, run_on_commit):
    device(order.user)
    notification = run_on_commit(services.notify_order_event, "order.accepted", order.pk)
    notification.refresh_from_db()
    assert notification.title == "Order confirmed"
    assert notification.sms_status == DeliveryStatus.NONE
    assert sms.outbox == []


def test_items_adjusted_cod_says_the_new_amount_and_each_adjustment_notifies(order, run_on_commit):
    """08 §9 T8a: push + SMS with the new amount due (COD)."""
    first = run_on_commit(services.notify_order_event, "order.items_adjusted", order.pk)
    assert "New amount to pay on delivery: ₹300." in first.body
    assert "Rs 300" in sms.outbox[0].body
    order.grand_total = Decimal("150.00")
    order.item_total = Decimal("150.00")
    order.mrp_total = Decimal("200.00")
    order.save()
    second = run_on_commit(services.notify_order_event, "order.items_adjusted", order.pk)
    assert second.pk != first.pk
    assert "₹150." in second.body
    # A replay of the same adjustment (same total) is the same notification.
    again = run_on_commit(services.notify_order_event, "order.items_adjusted", order.pk)
    assert again.pk == second.pk


def test_items_adjusted_and_cancelled_online_mention_the_refund(run_on_commit):
    order = OrderFactory(
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.PAID,
        amount_paid=Decimal("300.00"),
    )
    adjusted = run_on_commit(services.notify_order_event, "order.items_adjusted", order.pk)
    assert "refunded to your original payment method" in adjusted.body
    cancelled = run_on_commit(services.notify_order_event, "order.cancelled", order.pk)
    assert cancelled.title == "Order cancelled"
    assert "refunded" in cancelled.body
    assert "refunded in 5-7 working days" in sms.outbox[-1].body


def test_cancelled_cod_has_no_refund_line(order, run_on_commit):
    cancelled = run_on_commit(services.notify_order_event, "order.cancelled", order.pk)
    assert cancelled.body == f"Order {order.order_number} has been cancelled."
    assert cancelled.link == f"jivo://orders/{order.pk}/detail"


def test_out_for_delivery_otp_only_in_push_and_sms_never_in_the_inbox(order, run_on_commit):
    """Phase 5 calls notify_order with the OTP; the stored inbox text never holds it."""
    device(order.user)
    order.status = OrderStatus.OUT_FOR_DELIVERY
    notification = run_on_commit(
        services.notify_order, order, "order.out_for_delivery", rider_name="Ravi", otp="4821"
    )
    notification.refresh_from_db()
    assert "4821" not in notification.body
    assert "4821" not in notification.title
    assert "4821" in push.outbox[0].body
    assert "4821" in sms.outbox[0].body
    assert "4821" not in notification.push_body + notification.sms_body  # cleared after send
    assert "Ravi" in notification.body


def test_order_event_task(order):
    assert tasks.notify_order_event("order.accepted", order.pk) == "notified"
    assert tasks.notify_order_event("order.packing", order.pk) == "none"


# --------------------------------------------------------------------------- rider (P5 calls)


def test_send_push_for_a_rider_offer_is_push_only_and_not_in_the_inbox(run_on_commit):
    """api-requests #41: {type: offer.new, offer_id, task_id}."""
    rider = UserFactory()
    device(rider, app="rider")
    device(rider, app="customer")  # the same person's customer app gets nothing
    notification = run_on_commit(
        services.send_push,
        rider,
        "rider.offer_new",
        {"offer_id": 9001, "task_id": 7001, "store_name": "Jivo Sector 14", "distance_km": "2.4"},
    )
    assert notification.app == "rider"
    assert not notification.in_inbox
    [message] = push.outbox
    assert len(message.tokens) == 1
    assert message.data == {"type": "offer.new", "offer_id": "9001", "task_id": "7001"}
    assert "Jivo Sector 14" in message.body
    assert sms.outbox == []
    # The same offer again: no second push.
    run_on_commit(services.send_push, rider, "rider.offer_new", {"offer_id": 9001})
    assert len(push.outbox) == 1


def test_rider_task_events_use_task_updated(run_on_commit):
    rider = UserFactory()
    device(rider, app="rider")
    run_on_commit(
        services.send_push,
        rider,
        "rider.cod_amount_changed",
        {
            "task_id": 7001,
            "order_number": "JV-1",
            "cod_amount_due": "250.00",
            "cod_amount_previous": "300.00",
            "ref": "7001:250.00",
        },
    )
    assert push.outbox[0].data == {"type": "task.updated", "task_id": "7001"}
    assert "₹250.00" in push.outbox[0].body


def test_send_sms_only_and_then_push_adds_the_channel(order, run_on_commit):
    device(order.user)
    context = services.order_context(order)
    notification = run_on_commit(
        services.send_sms_notification, order.user, "order.cancelled", context
    )
    notification.refresh_from_db()
    assert notification.sms_status == DeliveryStatus.SENT
    assert notification.push_status == DeliveryStatus.NONE
    again = run_on_commit(services.send_push, order.user, "order.cancelled", context)
    again.refresh_from_db()
    assert again.pk == notification.pk
    assert again.push_status == DeliveryStatus.SENT
    assert len(sms.outbox) == 1


def test_package_level_functions(order, run_on_commit):
    import apps.notifications as notifications

    assert run_on_commit(notifications.notify_order, order, "order.accepted").title == (
        "Order confirmed"
    )
    assert notifications.send_push(order.user, "rider.order_ready", {"task_id": 1}) is not None
    assert notifications.notify(order.user, "order.delivered", {"order_id": order.pk}) is not None


# --------------------------------------------------------------------------- guards


def test_unknown_event_and_users_who_cannot_receive(order):
    assert services.notify(order.user, "order.teleported", {}) is None
    order.user.deleted_at = timezone.now()
    order.user.save(update_fields=["deleted_at"])
    assert services.notify(order.user, "order.placed", {"order_id": order.pk}) is None
    assert not Notification.objects.exists()


def test_without_ids_each_call_is_its_own_notification(user):
    first = services.notify(user, "rider.task_cancelled", {})
    second = services.notify(user, "rider.task_cancelled", {})
    assert first.pk != second.pk


# --------------------------------------------------------------------------- delivery outcomes


def test_no_device_skips_the_push(order, run_on_commit):
    notification = run_on_commit(services.notify_order_event, "order.accepted", order.pk)
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.SKIPPED
    assert push.outbox == []


def test_disabled_push_backend_skips(order, run_on_commit, settings):
    """Until D-19 the default backend sends nothing: recorded, push SKIPPED."""
    settings.PUSH_BACKEND = "apps.notifications.push.DisabledPushBackend"
    device(order.user)
    notification = run_on_commit(services.notify_order_event, "order.accepted", order.pk)
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.SKIPPED
    assert notification.in_inbox


def test_console_push_backend_logs(order, run_on_commit, settings, caplog):
    settings.PUSH_BACKEND = "apps.notifications.push.ConsolePushBackend"
    device(order.user)
    notification = run_on_commit(services.notify_order_event, "order.accepted", order.pk)
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.SENT
    assert "Order confirmed" in caplog.text


def test_unregistered_tokens_deactivate_their_device(order, run_on_commit):
    good, bad = device(order.user), device(order.user)
    push.invalid_tokens.add(bad.fcm_token)
    run_on_commit(services.notify_order_event, "order.accepted", order.pk)
    bad.refresh_from_db()
    good.refresh_from_db()
    assert not bad.is_active
    assert good.is_active


def test_only_unregistered_tokens_means_skipped(order, run_on_commit):
    only = device(order.user)
    push.invalid_tokens.add(only.fcm_token)
    notification = run_on_commit(services.notify_order_event, "order.accepted", order.pk)
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.SKIPPED


def test_sms_without_a_dlt_template_is_skipped(order, run_on_commit, settings, caplog):
    """09 §4 TRAI DLT: never send an unregistered SMS."""
    settings.SMS_DLT_TEMPLATE_IDS = {}
    notification = run_on_commit(services.notify_order_event, "order.placed", order.pk)
    notification.refresh_from_db()
    assert notification.sms_status == DeliveryStatus.SKIPPED
    assert sms.outbox == []
    assert "no DLT template id" in caplog.text


@pytest.mark.parametrize("error", [sms.SmsRejected, sms.SmsOutcomeUnknown])
def test_sms_rejected_or_unknown_is_failed_not_retried(order, monkeypatch, error):
    def fail(*args):
        raise error("nope")

    monkeypatch.setattr(services, "send_sms", fail)
    notification = services.notify_order_event("order.placed", order.pk)
    assert services.deliver_sms(notification.pk) == "failed"
    notification.refresh_from_db()
    assert notification.sms_status == DeliveryStatus.FAILED
    assert services.deliver_sms(notification.pk) == "skipped"  # never twice


def test_transient_sms_error_releases_the_claim_for_the_retry(order, monkeypatch):
    calls = []

    def flaky(*args):
        calls.append(args)
        if len(calls) == 1:
            raise sms.SmsError("timeout before sending")

    monkeypatch.setattr(services, "send_sms", flaky)
    notification = services.notify_order_event("order.placed", order.pk)
    with pytest.raises(sms.SmsError):
        services.deliver_sms(notification.pk)
    notification.refresh_from_db()
    assert notification.sms_status == DeliveryStatus.PENDING
    assert services.deliver_sms(notification.pk) == "sent"
    assert len(calls) == 2


def test_transient_push_error_releases_the_claim(order, monkeypatch):
    device(order.user)

    class Flaky(push.BasePushBackend):
        def send(self, message):
            raise push.PushError("503")

    monkeypatch.setattr(push, "get_backend", Flaky)
    notification = services.notify_order_event("order.accepted", order.pk)
    with pytest.raises(push.PushError):
        services.deliver_push(notification.pk)
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.PENDING


def test_task_marks_failed_after_the_last_retry(order, monkeypatch):
    device(order.user)

    class Down(push.BasePushBackend):
        def send(self, message):
            raise push.PushError("503")

    monkeypatch.setattr(push, "get_backend", Down)
    notification = services.notify_order_event("order.accepted", order.pk)
    result = tasks.send_push_task.apply(
        args=(notification.pk,), retries=tasks.MAX_RETRIES, throw=False
    )
    assert result.get() == "failed"
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.FAILED


def test_task_retries_a_transient_error(order, monkeypatch):
    """Eager Celery runs the retry at once (the countdown is ignored)."""
    device(order.user)
    attempts = []

    class Flaky(push.BasePushBackend):
        def send(self, message):
            attempts.append(1)
            if len(attempts) == 1:
                raise push.PushError("503")
            return push.PushResult(sent=len(message.tokens))

    monkeypatch.setattr(push, "get_backend", Flaky)
    notification = services.notify_order_event("order.accepted", order.pk)
    assert tasks.send_push_task.apply(args=(notification.pk,), throw=False).get() == "sent"
    assert len(attempts) == 2


def test_claimed_channels_are_not_sent_again(order):
    device(order.user)
    notification = services.notify_order_event("order.accepted", order.pk)
    assert services.deliver_push(notification.pk) == "sent"
    assert services.deliver_push(notification.pk) == "skipped"
    assert len(push.outbox) == 1


def test_sms_to_a_user_without_a_phone_is_skipped(order):
    notification = services.notify_order_event("order.placed", order.pk)
    order.user.anonymised_at = timezone.now()
    order.user.save(update_fields=["anonymised_at"])
    assert services.deliver_sms(notification.pk) == "no_phone"
    assert services.deliver_push(notification.pk) == "no_device"


# --------------------------------------------------------------------------- templates


def test_template_rows_override_the_built_in_text(order, run_on_commit):
    NotificationTemplate.objects.create(
        event="order.placed", channel="PUSH", title="Got it!", body="#{{order_number}} received"
    )
    NotificationTemplate.objects.create(
        event="order.placed",
        channel="SMS",
        body="Jivo: order {{order_number}} placed",
        dlt_template_id="1007999",
    )
    NotificationTemplate.objects.create(
        event="order.accepted", channel="PUSH", title="Ignored", body="x", is_active=False
    )
    device(order.user)
    placed = run_on_commit(services.notify_order_event, "order.placed", order.pk)
    assert placed.title == "Got it!"
    assert placed.body == f"#{order.order_number} received"
    assert sms.outbox[0].body == f"Jivo: order {order.order_number} placed"
    assert sms.outbox[0].dlt_template_id == "1007999"
    accepted = services.notify_order_event("order.accepted", order.pk)
    assert accepted.title == "Order confirmed"


def test_render_is_plain_substitution():
    assert services.render("Hi {{ name }}, {{missing}}!", {"name": "Asha"}) == "Hi Asha, !"
    assert services.render("{{user.password}} {0} {name!r}", {"user": "x"}) == (
        "{{user.password}} {0} {name!r}"
    )


def test_fcm_payload_falls_back_to_the_link():
    assert services.fcm_payload("customer", {"type": "order", "link": "jivo://cart"}) == {
        "link": "jivo://cart"
    }
    assert services.fcm_payload("customer", {"type": "category", "slug": "oils"}) == {
        "type": "category",
        "slug": "oils",
    }
    assert services.fcm_payload("rider", {"type": "task.updated", "task_id": "3"}) == {
        "type": "task.updated",
        "task_id": "3",
    }


# --------------------------------------------------------------------------- retention


def test_purge_old_notifications(user, settings):
    settings.NOTIFICATION_RETENTION_DAYS = 90
    with freeze_time(timezone.now() - timedelta(days=91)):
        old = services.notify(user, "rider.task_cancelled", {"task_id": 1})
    recent = services.notify(user, "rider.task_cancelled", {"task_id": 2})
    assert tasks.purge_old_notifications() == 1
    assert not Notification.objects.filter(pk=old.pk).exists()
    assert Notification.objects.filter(pk=recent.pk).exists()


# --------------------------------------------------------------------------- code review f08c329


def _paid_online_order(amount="300.00"):
    from apps.payments.models import Gateway, Payment, PaymentAttemptStatus

    order = OrderFactory(
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.REFUND_PENDING,
        amount_paid=Decimal(amount),
    )
    payment = Payment.objects.create(
        order=order,
        gateway=Gateway.RAZORPAY,
        gateway_order_id=f"order_T{order.pk}",
        amount=Decimal(amount),
        status=PaymentAttemptStatus.CAPTURED,
    )
    return order, payment


def test_cancel_text_has_the_stored_refund_amount(run_on_commit):
    """PM default: the stored `Refund.amount` (money_str), never a computed one."""
    from apps.payments.models import Refund

    order, payment = _paid_online_order()
    Refund.objects.create(
        payment=payment,
        order=order,
        amount=Decimal("287.50"),
        reason="customer_cancel",
        idempotency_key=f"cancel:{order.pk}",
    )
    cancelled = run_on_commit(services.notify_order_event, "order.cancelled", order.pk)
    assert "A refund of ₹287.50 will reach your original payment method" in cancelled.body
    assert "Rs 287.50" in sms.outbox[-1].body


def test_cancel_text_uses_the_newest_retry_and_ignores_other_orders_keys():
    from apps.payments.models import Refund

    order, payment = _paid_online_order()
    other, other_payment = _paid_online_order()
    Refund.objects.create(
        payment=other_payment,
        order=other,
        amount=Decimal("1.00"),
        reason="customer_cancel",
        idempotency_key=f"cancel:{other.pk}",
    )
    assert services.cancel_refund_lines(order) == {}
    Refund.objects.create(
        payment=payment,
        order=order,
        amount=Decimal("300.00"),
        reason="customer_cancel",
        idempotency_key=f"cancel:{order.pk}",
        status="FAILED",
    )
    Refund.objects.create(
        payment=payment,
        order=order,
        amount=Decimal("299.00"),
        reason="customer_cancel",
        idempotency_key=f"cancel:{order.pk}:retry-1",
    )
    assert "₹299.00" in services.cancel_refund_lines(order)["refund_line"]


def test_refund_processed_has_the_stored_amount_and_is_once_per_refund(run_on_commit):
    import apps.notifications as notifications
    from apps.payments.models import Refund

    order, payment = _paid_online_order()
    refund = Refund.objects.create(
        payment=payment,
        order=order,
        amount=Decimal("120.00"),
        reason="item_unavailable",
        idempotency_key=f"t8a:{order.pk}:1:1",
        status="PROCESSED",
    )
    first = run_on_commit(notifications.notify_refund_processed, refund)
    again = run_on_commit(notifications.notify_refund_processed, refund)
    assert first.pk == again.pk
    assert "₹120.00" in first.body
    assert "Rs 120.00" in sms.outbox[0].body
    assert len(sms.outbox) == 1


def test_console_push_backend_never_logs_the_body(order, run_on_commit, settings, caplog):
    settings.PUSH_BACKEND = "apps.notifications.push.ConsolePushBackend"
    device(order.user)
    run_on_commit(
        services.notify_order, order, "order.out_for_delivery", rider_name="Ravi", otp="4821"
    )
    assert "Your order is on the way" in caplog.text
    assert "4821" not in caplog.text
    assert "body redacted" in caplog.text


@pytest.mark.parametrize(
    "backend",
    ["apps.notifications.push.ConsolePushBackend", "apps.notifications.push.LocmemPushBackend"],
)
@pytest.mark.parametrize("environment", ["staging", "production"])
def test_deployed_settings_refuse_dev_push_backends(settings, backend, environment):
    from apps.notifications.checks import check_push_backend

    settings.APP_ENVIRONMENT = environment
    settings.PUSH_BACKEND = backend
    [error] = check_push_backend(None)
    assert error.id == "notifications.E001"
    settings.PUSH_BACKEND = "apps.notifications.push.DisabledPushBackend"
    assert check_push_backend(None) == []


def test_dev_push_backends_are_fine_locally(settings):
    from apps.notifications.checks import check_push_backend

    settings.APP_ENVIRONMENT = "local"
    settings.PUSH_BACKEND = "apps.notifications.push.ConsolePushBackend"
    assert check_push_backend(None) == []


def test_sweeper_fails_and_blanks_sends_stuck_in_sending(order, caplog):
    notification = services.notify_order(
        order, "order.out_for_delivery", rider_name="Ravi", otp="4821"
    )
    fresh = services.notify_order_event("order.accepted", order.pk)
    Notification.objects.filter(pk__in=[notification.pk, fresh.pk]).update(
        push_status=DeliveryStatus.SENDING
    )
    Notification.objects.filter(pk=notification.pk).update(
        sms_status=DeliveryStatus.SENDING, updated_at=timezone.now() - timedelta(minutes=20)
    )
    assert tasks.sweep_stuck_sends() == 2
    notification.refresh_from_db()
    assert notification.push_status == notification.sms_status == DeliveryStatus.FAILED
    assert notification.push_body == notification.sms_body == ""
    assert "stuck while sending" in caplog.text
    fresh.refresh_from_db()
    assert fresh.push_status == DeliveryStatus.SENDING  # recent: maybe still in flight
    assert tasks.sweep_stuck_sends() == 0


def test_purge_runs_in_batches(user, settings):
    settings.NOTIFICATION_RETENTION_DAYS = 90
    with freeze_time(timezone.now() - timedelta(days=100)):
        for task_id in range(3):
            services.notify(user, "rider.task_cancelled", {"task_id": task_id})
    assert services.purge_old_notifications(batch_size=2) == 3
    assert not Notification.objects.exists()


@pytest.mark.django_db(transaction=True)
def test_two_workers_claiming_one_sms_send_it_once(monkeypatch):
    """The PENDING -> SENDING claim is a conditional UPDATE: two concurrent deliveries of the
    same notification send one SMS."""
    import threading

    from django.db import connection

    monkeypatch.setattr(services, "_queue", lambda notification: None)  # no eager task send
    order = OrderFactory()
    notification = services.notify_order_event("order.placed", order.pk)
    sent = []
    barrier = threading.Barrier(2)

    def slow_send(*args):
        sent.append(args)

    monkeypatch.setattr(services, "send_sms", slow_send)
    results = []

    def worker():
        try:
            barrier.wait(timeout=10)
            results.append(services.deliver_sms(notification.pk))
        finally:
            connection.close()

    threads = [threading.Thread(target=worker) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=60)
    assert sorted(results) == ["sent", "skipped"]
    assert len(sent) == 1


# --------------------------------------------------------------------------- Phase 7 (review)


def test_delivered_links_to_the_rating_screen(order, run_on_commit):
    """P7-TC-01: `order.delivered` opens the rating screen (`jivo://orders/{id}/rate`); the FCM
    payload stays `{type: order, order_id}` (#30)."""
    device(order.user)
    notification = run_on_commit(services.notify_order_event, "order.delivered", order.pk)
    assert notification.data["link"] == f"jivo://orders/{order.pk}/rate"
    assert "Rate your order" in notification.body
    [message] = push.outbox
    assert message.data == {"type": "order", "order_id": str(order.pk)}


@pytest.mark.parametrize(
    ("event", "app", "link"),
    [
        ("support.ticket_replied", "customer", "jivo://support/tickets/{id}"),
        ("support.ticket_replied_rider", "rider", "jivo://rider/help/tickets/{id}"),
    ],
)
def test_support_reply_specs_and_fcm_ticket_id(user, run_on_commit, event, app, link):
    """P7-TC-12: the support reply events: push + inbox in the right app, category support, no
    SMS, the ticket link, and `ticket_id` in the FCM data (`FCM_KEYS`)."""
    from apps.notifications.catalog import SPECS

    spec = SPECS[event]
    assert (spec.app, spec.category, spec.data_type, spec.sms) == (app, "support", "ticket", "")
    assert spec.push
    assert spec.inbox
    device(user, app="customer")
    device(user, app="rider")
    notification = run_on_commit(
        services.notify,
        user,
        event,
        {"ticket_id": 77, "ticket_number": "TK-000077"},
        dedupe_key=f"{event}:{user.pk}:1",
        sms=False,
    )
    assert notification.app == app
    assert notification.in_inbox
    assert notification.data["link"] == link.format(id=77)
    assert notification.data["ticket_id"] == "77"
    assert "TK-000077" in notification.body
    [message] = push.outbox
    assert len(message.tokens) == 1  # only the device of that app
    assert message.data == {"type": "ticket", "ticket_id": "77"}
    assert sms.outbox == []


def test_fcm_keys_carry_ticket_id_for_both_apps():
    assert "ticket_id" in services.FCM_KEYS["customer"]
    assert "ticket_id" in services.FCM_KEYS["rider"]
    payload = services.fcm_payload("customer", {"type": "ticket", "ticket_id": 5, "link": "x"})
    assert payload == {"type": "ticket", "ticket_id": "5"}

"""Phase 5 slice 5.3 wired into Phase 6 (the P5/P6 merge): ops alerts go to `/ws/ops/live/`
through `apps.realtime.publish_ops_alert`, and the customer is notified through
`apps.notifications` on T9 (with the OTP), AT_CUSTOMER, T10 and T13 (08 §9)."""

import pytest

from apps import notifications, realtime
from apps.delivery import hooks
from apps.delivery.models import DeliveryTask
from apps.delivery.tests.test_task_flow import AT_DROP, flow  # noqa: F401
from apps.notifications.models import Notification

pytestmark = pytest.mark.django_db


@pytest.fixture
def ops_alerts(monkeypatch):
    sent = []
    monkeypatch.setattr(realtime, "publish_ops_alert", lambda **kw: sent.append(kw))
    return sent


def test_ops_alert_resolves_the_store_from_the_order(flow, ops_alerts):  # noqa: F811
    f = flow()
    hooks.ops_alert("DELIVERY_OTP_LOCKED", {"order_id": f.order.pk, "order_number": "X1"})
    assert ops_alerts == [
        {
            "store_id": f.order.store_id,
            "code": "DELIVERY_OTP_LOCKED",
            "message_text": "Order X1: delivery OTP locked after too many wrong attempts.",
            "order_id": f.order.pk,
            "rider_id": None,
        }
    ]


def test_ops_alert_resolves_the_store_from_task_and_rider(flow, ops_alerts):  # noqa: F811
    f = flow()
    f.accept()
    task = DeliveryTask.objects.get(pk=f.task_id)
    hooks.ops_alert("MOCKED_LOCATION", {"rider_id": f.rider.pk, "task_id": task.pk})
    hooks.ops_alert("RIDER_STALE_ON_TASK", {"rider_id": f.rider.pk})
    assert [a["store_id"] for a in ops_alerts] == [task.store_id, f.rider.home_store_id]
    assert ops_alerts[0]["order_id"] == f.order.pk
    assert ops_alerts[1]["message_text"].startswith(f"Rider {f.rider.pk} ")


def test_ops_alert_without_a_store_is_only_logged(ops_alerts, caplog):
    hooks.ops_alert("RIDER_STALE_ON_TASK", {"rider_id": 999_999})
    assert ops_alerts == []
    assert "Ops alert RIDER_STALE_ON_TASK" in caplog.text


def test_ops_alert_never_raises(monkeypatch, flow):  # noqa: F811
    def boom(**kwargs):
        raise RuntimeError("channel layer down")

    monkeypatch.setattr(realtime, "publish_ops_alert", boom)
    hooks.ops_alert("DISPATCH_UNASSIGNED", {"order_id": flow().order.pk})


def test_ops_alert_codes_are_in_the_socket_contract():
    from apps.realtime.contract import ALERT_CODES

    assert set(hooks.OPS_ALERT_MESSAGES) <= set(ALERT_CODES)


def test_arrival_geofence_override_raises_an_ops_alert(
    flow,  # noqa: F811
    ops_alerts,
    django_capture_on_commit_callbacks,
):
    """Review L4."""
    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    f.pickup()
    with django_capture_on_commit_callbacks(execute=True):
        response = f.at_customer(lat=28.46, lng=77.05, override_reason="Gate closed")
    assert response.status_code == 200
    alert = next(a for a in ops_alerts if a["code"] == "ARRIVAL_GEOFENCE_OVERRIDE")
    assert alert["store_id"] == f.order.store_id
    assert alert["order_id"] == f.order.pk
    assert alert["rider_id"] == f.rider.pk
    assert "Gate closed" in alert["message_text"]


def test_arrival_inside_the_geofence_raises_no_alert(
    flow,  # noqa: F811
    ops_alerts,
    django_capture_on_commit_callbacks,
):
    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    f.pickup()
    with django_capture_on_commit_callbacks(execute=True):
        assert f.at_customer(**AT_DROP).status_code == 200
    assert not [a for a in ops_alerts if a["code"] == "ARRIVAL_GEOFENCE_OVERRIDE"]


def test_customer_notified_out_for_delivery_with_otp_and_rider_arrived(
    flow,  # noqa: F811
    django_capture_on_commit_callbacks,
    monkeypatch,
):
    """08 §9 T9 (push + SMS with the OTP; the inbox never shows it) and AT_CUSTOMER."""
    from apps.notifications import tasks as notification_tasks

    # Keep the queued texts (a sent push/SMS has its text blanked).
    monkeypatch.setattr(notification_tasks.send_push_task, "delay", lambda pk: None)
    monkeypatch.setattr(notification_tasks.send_sms_task, "delay", lambda pk: None)
    f = flow()
    f.accept()
    f.at_store()
    f.steps.pack(f.order)
    with django_capture_on_commit_callbacks(execute=True):
        assert f.pickup().status_code == 200
    otp = f.otp()
    out = Notification.objects.get(user=f.order.user, event="order.out_for_delivery")
    assert out.order_id == f.order.pk
    assert otp in out.push_body
    assert otp not in out.body
    with django_capture_on_commit_callbacks(execute=True):
        assert f.at_customer().status_code == 200
    assert Notification.objects.filter(user=f.order.user, event="order.rider_arrived").count() == 1


def test_customer_notified_on_delivered_once(flow, django_capture_on_commit_callbacks):  # noqa: F811
    """T10 through the order domain event (P6 fan-out), idempotent."""
    f = flow()
    f.to_customer()
    with django_capture_on_commit_callbacks(execute=True):
        assert f.deliver().status_code == 200
    notifications.notify_order(f.order, "order.delivered")  # a retried task: no duplicate
    assert Notification.objects.filter(user=f.order.user, event="order.delivered").count() == 1


def test_notify_order_hook_never_raises(monkeypatch, flow):  # noqa: F811
    def boom(*args, **kwargs):
        raise RuntimeError("db down")

    monkeypatch.setattr(notifications, "notify_order", boom)
    hooks.notify_order(flow().order, "order.rider_arrived", rider_name="R")
